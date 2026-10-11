package com.familyfinance.family_finance_manager

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import org.json.JSONArray
import org.json.JSONObject

/**
 * Reads notifications only after the user turns on Notification access for
 * the app in Android settings. Keeps just the ones that mention an amount
 * (Rp / IDR) from apps other than chats, on the phone, until the app reads
 * them; everything else is ignored and never stored.
 */
class BankNotificationListener : NotificationListenerService() {
    override fun onNotificationPosted(sbn: StatusBarNotification) {
        try {
            BankNotificationStore.offer(this, sbn)
        } catch (_: Exception) {
            // Never let one odd notification stop the listener.
        }
    }
}

object BankNotificationStore {
    private const val PREFS = "bank_notifications"
    private const val PENDING = "pending"
    private const val RECENT = "recent"
    private const val MAX_PENDING = 100
    private const val MAX_TEXT = 600

    // Chats and social apps: people type amounts there, but those are not
    // transactions. Our own notifications are skipped too.
    private val IGNORED = setOf(
        "com.whatsapp",
        "com.whatsapp.w4b",
        "org.telegram.messenger",
        "org.thunderdog.challegram",
        "com.instagram.android",
        "com.facebook.orca",
        "com.facebook.katana",
        "jp.naver.line.android",
        "com.discord",
        "com.twitter.android",
        "com.zhiliaoapp.musically",
        "com.ss.android.ugc.trill",
    )

    private val AMOUNT = Regex("""(?i)(rp\.?|idr)\s?[0-9]""")

    // A rough first pass so codes and promos are never kept or announced;
    // the app's own parser (bank_notification_parser.dart) decides the rest.
    private val SKIP = Regex(
        """(?i)\b(otp|kode verifikasi|verification code|jangan berikan|password|pin anda|promo|diskon|discount|voucher|menangkan|undian|penawaran|dapatkan|cashback hingga|jatuh tempo|akan didebet|gagal|failed|dibatalkan|ditolak)\b""",
    )
    private val MONEY_WORDS = Regex(
        """(?i)\b(menerima|diterima|terima|masuk|bertambah|kredit|cr|received|incoming|credited|refund|cashback|top ?up|bayar|membayar|pembayaran|dibayar|transfer|kirim|mengirim|keluar|berkurang|debit|db|tarik|penarikan|belanja|pembelian|purchase|payment|paid|spent|qris)\b""",
    )

    private const val CHANNEL = "bank_transactions"
    private const val SUMMARY_ID = 7301
    const val EXTRA_OPEN_INBOX = "open_bank_inbox"

    fun offer(context: Context, sbn: StatusBarNotification) {
        val pkg = sbn.packageName ?: return
        if (pkg == context.packageName || pkg in IGNORED) return
        val n = sbn.notification ?: return
        if (n.flags and Notification.FLAG_GROUP_SUMMARY != 0) return
        if (n.flags and Notification.FLAG_ONGOING_EVENT != 0) return

        val extras = n.extras
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString().orEmpty()
        val big = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString()
        val text = (big ?: extras.getCharSequence(Notification.EXTRA_TEXT)?.toString()).orEmpty()
        val all = "$title\n$text"
        if (!AMOUNT.containsMatchIn(all)) return
        if (SKIP.containsMatchIn(all) || !MONEY_WORDS.containsMatchIn(all)) return

        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        // Banks often post the same notification again (updates, re-alerts).
        val fingerprint = "$pkg|$title|$text".hashCode().toString()
        val recent = JSONArray(prefs.getString(RECENT, "[]"))
        for (i in 0 until recent.length()) {
            if (recent.optString(i) == fingerprint) return
        }

        val label = try {
            val pm = context.packageManager
            pm.getApplicationLabel(pm.getApplicationInfo(pkg, 0)).toString()
        } catch (_: Exception) {
            pkg
        }
        val entry = JSONObject()
            .put("id", "${pkg}_${sbn.postTime}_${fingerprint}")
            .put("package", pkg)
            .put("app", label)
            .put("title", title.take(MAX_TEXT))
            .put("text", text.take(MAX_TEXT))
            .put("time", sbn.postTime)

        synchronized(this) {
            val pending = JSONArray(prefs.getString(PENDING, "[]"))
            pending.put(entry)
            val trimmed = JSONArray()
            val start = maxOf(0, pending.length() - MAX_PENDING)
            for (i in start until pending.length()) trimmed.put(pending.get(i))

            val newRecent = JSONArray()
            val from = maxOf(0, recent.length() - 49)
            for (i in from until recent.length()) newRecent.put(recent.get(i))
            newRecent.put(fingerprint)

            prefs.edit()
                .putString(PENDING, trimmed.toString())
                .putString(RECENT, newRecent.toString())
                .apply()
            showSummary(context, trimmed.length())
        }
    }

    /**
     * One notification from the app, updated as more arrive: "2 transactions
     * from bank notifications to check". Tapping it opens the review screen.
     * Quiet (the bank's own notification already made a sound).
     */
    private fun showSummary(context: Context, count: Int) {
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        val isId = context
            .getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .getString("flutter.locale", "en") == "id"
        if (manager.getNotificationChannel(CHANNEL) == null) {
            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL,
                    if (isId) "Transaksi dari notifikasi bank" else "Transactions from bank notifications",
                    NotificationManager.IMPORTANCE_DEFAULT,
                ).apply { setSound(null, null) },
            )
        }
        val open = Intent(context, MainActivity::class.java)
            .putExtra(EXTRA_OPEN_INBOX, true)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        val tap = PendingIntent.getActivity(
            context,
            SUMMARY_ID,
            open,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val title = if (isId) "Transaksi baru terdeteksi" else "New transaction detected"
        val text = if (isId) {
            "$count transaksi dari notifikasi bank menunggu dicek. Ketuk untuk cek."
        } else {
            "$count ${if (count == 1) "transaction" else "transactions"} from bank notifications to check. Tap to review."
        }
        val notification = Notification.Builder(context, CHANNEL)
            .setSmallIcon(R.drawable.ic_stat_bank)
            .setContentTitle(title)
            .setContentText(text)
            .setStyle(Notification.BigTextStyle().bigText(text))
            .setNumber(count)
            .setOnlyAlertOnce(true)
            .setAutoCancel(true)
            .setContentIntent(tap)
            .build()
        try {
            manager.notify(SUMMARY_ID, notification)
        } catch (_: SecurityException) {
            // Notifications turned off for the app: the Dashboard banner remains.
        }
    }

    /** The app has the transactions now; its banner takes over. */
    fun clearSummary(context: Context) {
        context.getSystemService(NotificationManager::class.java)?.cancel(SUMMARY_ID)
    }

    /** Hands the waiting notifications to Flutter, once. */
    fun take(context: Context): String {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        synchronized(this) {
            val pending = prefs.getString(PENDING, "[]") ?: "[]"
            prefs.edit().putString(PENDING, "[]").apply()
            clearSummary(context)
            return pending
        }
    }
}
