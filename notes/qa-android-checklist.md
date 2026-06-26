# QA Checklist - Android App

**Target:** APK `1.1.2+6`  
**Test User:** `qa-test@familyfinance.app` / `qadummy123`  
**Role:** User biasa (tanpa family, personal mode)

---

## 1. Install & Setup

- [ ] Download APK dari `https://finance-family-prod.vercel.app/FamilyFinance.apk`
- [ ] Install berhasil tanpa error
- [ ] Buka app, tampilan splash screen normal
- [ ] Halaman login/register tampil dengan benar

---

## 2. Register User QA Dummy

- [ ] Klik tombol "Daftar" / "Register"
- [ ] Masukkan email: `qa-test@familyfinance.app`
- [ ] Masukkan password: `qadummy123`
- [ ] Konfirmasi password: `qadummy123`
- [ ] Register berhasil, redirect ke dashboard
- [ ] Dashboard badge tampil "Mode Personal"

---

## 3. Personal Mode - Wallet

- [ ] Buka menu "Dompet" / "Wallets"
- [ ] Klik tombol "+" untuk tambah wallet baru
- [ ] Pilih jenis: Tunai / Bank / E-Wallet
- [ ] Masukkan nama wallet (contoh: "Dompet Utama")
- [ ] Masukkan saldo awal (contoh: 1.000.000)
- [ ] Simpan berhasil, wallet muncul di list
- [ ] Edit wallet, ubah nama/saldo
- [ ] Hapus wallet (jika ada opsi)

---

## 4. Personal Mode - Income

- [ ] Buka menu "Pemasukan" / "Income"
- [ ] Klik tombol "+" untuk tambah income
- [ ] Pilih kategori (contoh: Gaji)
- [ ] Pilih wallet tujuan
- [ ] Masukkan nominal (contoh: 5.000.000)
- [ ] Tambahkan catatan (opsional)
- [ ] Simpan berhasil, income muncul di list
- [ ] Cek dashboard, total saldo bertambah

---

## 5. Personal Mode - Expense

- [ ] Buka menu "Pengeluaran" / "Expense"
- [ ] Klik tombol "+" untuk tambah expense
- [ ] Pilih kategori (contoh: Makanan)
- [ ] Pilih wallet sumber
- [ ] Masukkan nominal (contoh: 50.000)
- [ ] Tambahkan catatan (opsional)
- [ ] Simpan berhasil, expense muncul di list
- [ ] Cek dashboard, total saldo berkurang

---

## 6. Personal Mode - Transaction History

- [ ] Buka menu "Riwayat" / "History"
- [ ] Semua transaksi muncul di list
- [ ] Filter berdasarkan jenis (income/expense)
- [ ] Filter berdasarkan tanggal
- [ ] Search berdasarkan catatan
- [ ] Klik transaksi untuk lihat detail
- [ ] Edit transaksi
- [ ] Hapus transaksi

---

## 7. Personal Mode - Savings

- [ ] Buka menu "Tabungan" / "Savings"
- [ ] Klik tombol "+" untuk tambah saving
- [ ] Masukkan nama target (contoh: "Liburan")
- [ ] Masukkan target nominal
- [ ] Masukkan nominal tabungan per bulan
- [ ] Simpan berhasil, saving muncul di list
- [ ] Tambah progress tabungan
- [ ] Cek progress bar terupdate

---

## 8. Personal Mode - Budget

- [ ] Buka menu "Anggaran" / "Budget"
- [ ] Klik tombol "+" untuk tambah budget
- [ ] Pilih kategori (contoh: Makanan)
- [ ] Masukkan limit bulanan (contoh: 2.000.000)
- [ ] Simpan berhasil, budget muncul di list
- [ ] Cek progress bar usage

---

## 9. Personal Mode - Reports

- [ ] Buka menu "Laporan" / "Reports"
- [ ] Grafik income vs expense tampil
- [ ] Filter harian/mingguan/bulanan/tahunan
- [ ] Pie chart expense per kategori tampil
- [ ] Export ke PDF (jika ada)
- [ ] Export ke CSV (jika ada)

---

## 10. Settings - Language

- [ ] Buka menu "Pengaturan" / "Settings"
- [ ] Cek section "Bahasa / Language"
- [ ] Toggle ke "EN" - semua label berubah ke Inggris
- [ ] Toggle ke "ID" - semua label berubah ke Indonesia
- [ ] Cek main title, nav, drawer ikut bahasa

---

## 11. Settings - Theme

- [ ] Cek section "Tampilan"
- [ ] Toggle "Mode Gelap" ke ON
- [ ] Tampilan berubah ke dark mode
- [ ] Toggle ke OFF, kembali ke light mode

---

## 12. Settings - Guide Button

- [ ] Scroll ke bagian bawah settings
- [ ] Cek ada tombol "Panduan Lengkap" / "Complete Guide"
- [ ] Klik tombol tersebut
- [ ] Browser terbuka dengan URL guide web
- [ ] URL sesuai bahasa app (en/id)
- [ ] Guide page tampil dengan benar

---

## 13. Settings - Privacy & Security

- [ ] Klik menu "Privasi & Keamanan"
- [ ] Halaman privacy tampil
- [ ] Baca info privacy yang disampaikan
- [ ] Kembali ke settings

---

## 14. Settings - Edit Profile

- [ ] Klik tombol "Edit Profil"
- [ ] Ubah nama user
- [ ] Simpan berhasil
- [ ] Nama terupdate di dashboard

---

## 15. Update Checker

- [ ] Cek app tidak memaksa update (karena sudah versi terbaru)
- [ ] Jika ada dialog update, klik "Nanti" untuk dismiss
- [ ] App tetap bisa dipakai normal

---

## 16. Stability

- [ ] Tidak ada crash saat navigasi antar menu
- [ ] Tidak ada error Firestore permission denied
- [ ] Data tersimpan dengan benar
- [ ] Logout dan login ulang, data masih ada

---

## 17. Logout

- [ ] Klik tombol "Keluar" / "Sign Out"
- [ ] Konfirmasi logout
- [ ] Redirect ke halaman login
- [ ] Login ulang dengan user QA

---

## Notes / Issues Found

| No | Issue | Priority | Status |
|----|-------|----------|--------|
| 1 | | | |
| 2 | | | |
| 3 | | | |

---

## Summary

- Total Tests: 17
- Passed: 
- Failed: 
- Blocked: 

**Tester:**  
**Date:**  
**APK Version:** 1.1.2+6
