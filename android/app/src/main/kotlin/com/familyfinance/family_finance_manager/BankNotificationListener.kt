package com.familyfinance.family_finance_manager

import android.app.Notification
import android.content.Context
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
        }
    }

    /** Hands the waiting notifications to Flutter, once. */
    fun take(context: Context): String {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        synchronized(this) {
            val pending = prefs.getString(PENDING, "[]") ?: "[]"
            prefs.edit().putString(PENDING, "[]").apply()
            return pending
        }
    }
}
