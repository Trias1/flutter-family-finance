# Revamp Web Family Finance — Desain

Tanggal: 2026-10-09 · Target: `apps/web` (Next.js 16, Vercel) + audit keamanan web & Android

## Tujuan
1. Data di web ikut berubah dalam hitungan detik saat ada input dari Android, tanpa refresh.
2. Tampilan web rapi, menarik, dan tidak terlihat seperti template buatan AI.
3. Web dan app aman: tidak bisa di-bruteforce, tidak ada dependency dengan CVE yang diketahui, aturan Firestore ketat.

Di luar cakupan: fitur input/edit transaksi di web (web tetap untuk memantau), perubahan fitur Android.

## 1. Sync realtime
**Masalah sekarang:** setiap halaman dashboard memanggil `getDocs` sekali saat dibuka, jadi data tidak pernah update sendiri dan selalu diambil ulang tiap pindah halaman.

**Rancangan:**
- `src/lib/family-data.tsx`: `FamilyDataProvider` + hook `useFamilyData()`.
  - Membaca `users/{uid}` lalu `familyId`.
  - Memasang `onSnapshot` untuk `incomes`, `expenses`, `budgets`, `savings`, `debts` (filter `familyId`).
  - Menyediakan `{ status, incomes, expenses, budgets, savings, debts, lastSyncedAt, fromCache }`.
  - Semua listener dilepas saat logout atau ganti user.
- `src/lib/firebase.ts`: aktifkan `persistentLocalCache` (multi-tab) supaya data tampil instan saat web dibuka ulang.
- `DashboardShell` membungkus semua halaman `/dashboard/*` dengan provider ini.
- Indikator status di header: "Tersinkron · baru saja", "Menyinkronkan…", atau "Offline".

## 2. Tampilan
**Arah visual:** seperti aplikasi bank atau akuntansi yang tenang dan serius.
- Dilarang: gradient ungu/biru, glassmorphism, shadow besar dan blur, emoji, ikon besar dalam kotak warna-warni, teks hero yang berlebihan.
- Permukaan datar, garis 1px, radius kecil (6–8px). Satu warna aksen (biru tua), hijau/merah hanya untuk nominal.
- Angka memakai `tabular-nums` dan format Rupiah Indonesia, rata kanan di tabel.
- Hierarki tipografi yang jelas: label kecil uppercase, angka besar, teks pendukung abu-abu.

**Layout:** sidebar ramping di desktop, bottom nav di ponsel, lebar konten maksimum ~1200px.

**Halaman:**
- **Ringkasan:** saldo bulan ini, pemasukan, pengeluaran, sisa budget; grafik arus kas 6 bulan; budget yang hampir habis; 8 transaksi terakhir.
- **Transaksi:** tabel padat dengan filter bulan, jenis, dan kategori, plus pencarian. Di ponsel tampil sebagai daftar.
- **Budget & Tabungan:** progress bar tipis per kategori, target tabungan, dan progres.
- **Hutang:** daftar hutang/piutang dengan jatuh tempo dan sisa.
- **Laporan:** perbandingan bulanan, breakdown kategori.

**Komponen bersama** (`src/components/ui/`): `StatCard`, `Money`, `Section`, `EmptyState`, `Skeleton`, `ProgressBar`.

Dark mode tetap ada.

**Dihapus:** halaman dan menu Wallets, serta kartu wallet di dashboard, karena fitur Wallet sudah dihapus di Android.

## 3. Keamanan
**Web:**
- **Brute force login:** Firebase Auth sudah membatasi percobaan login (`auth/too-many-requests`). Tambahan di web:
  - Pesan error dibuat generik (tidak membedakan email tidak terdaftar dan password salah).
  - Jeda bertahap di sisi klien setelah beberapa kali gagal.
  - Rekomendasi: aktifkan Email Enumeration Protection dan App Check di Firebase Console.
- **API routes** (`/api/admin/*`, `/api/ai/chat`):
  - Wajib verifikasi Firebase ID token dan cek peran admin di server.
  - Rate limit per user/IP untuk `/api/ai/chat`.
  - Validasi input dan batas ukuran body.
  - Tidak boleh membocorkan error internal.
- **Header keamanan** di `next.config.ts`: CSP, `X-Frame-Options`/`frame-ancestors`, `X-Content-Type-Options`, `Referrer-Policy`, `Permissions-Policy`, HSTS.
- **Secret:** service account hanya dari environment variable Vercel, tidak pernah di repo atau bundle klien.

**Firestore rules:** review `firestore.rules`:
- Setiap koleksi hanya bisa diakses anggota keluarga (`familyId`).
- Tidak ada `allow read, write: if true`.
- Validasi field saat write.
- `user_public`, `app_config`, `devices` dibatasi sesuai peran.

**Android (Flutter):**
- Kunci dan secret tidak ter-hardcode.
- `android:allowBackup`, `usesCleartextTraffic`, exported components.
- Release build memakai minify/obfuscation.

**CVE:**
- `npm audit` di `apps/web`; upgrade paket rentan (termasuk Next.js ke patch terbaru).
- `flutter pub outdated` untuk paket dengan advisory yang diketahui.

## 4. Verifikasi
- `npm run build` dan `npm run lint` lolos; `npm audit` tanpa high/critical.
- Screenshot desktop dan ponsel untuk tiap halaman dashboard.
- Uji sync: ubah dokumen di Firestore, lalu web berubah tanpa refresh (perlu login akun pemilik).
- Laporan audit keamanan berisi temuan, apa yang sudah diperbaiki, dan apa yang harus diaktifkan manual di Console.

## Urutan kerja
1. Commit checkpoint untuk perubahan yang belum di-commit, di branch baru `web-revamp`.
2. Audit keamanan dan CVE.
3. Lapisan sync realtime.
4. Revamp tampilan per halaman.
5. Perbaikan keamanan, lalu verifikasi.
