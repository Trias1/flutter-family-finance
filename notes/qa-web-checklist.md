# QA Checklist - Web App

**Target:** `https://finance-family-prod.vercel.app`  
**Test User:** `qa-test@familyfinance.app` / `qadummy123`  
**Role:** User biasa (tanpa family, personal mode)

---

## 1. Localization - Landing Page

- [ ] Buka `/en`
- [ ] Semua teks dalam bahasa Inggris
- [ ] Tidak ada teks campur Indonesia
- [ ] Buka `/id`
- [ ] Semua teks dalam bahasa Indonesia
- [ ] Tidak ada teks campur Inggris
- [ ] Toggle bahasa berfungsi (jika ada toggle di navbar)

---

## 2. Localization - Guide Page

- [ ] Buka `/en/guide`
- [ ] Semua konten guide dalam bahasa Inggris
- [ ] Step 1-8 tampil lengkap
- [ ] Buka `/id/guide`
- [ ] Semua konten guide dalam bahasa Indonesia
- [ ] Step 1-8 tampil lengkap

---

## 3. Localization - Login Page

- [ ] Buka `/en/login`
- [ ] Label form dalam bahasa Inggris
- [ ] Tombol "Sign In", "Register", dll dalam bahasa Inggris
- [ ] Buka `/id/login`
- [ ] Label form dalam bahasa Indonesia
- [ ] Tombol "Masuk", "Daftar", dll dalam bahasa Indonesia

---

## 4. Public Features

- [ ] Landing page hero section tampil
- [ ] Features section tampil lengkap (9 features)
- [ ] Download APK button berfungsi
- [ ] Navbar responsive di mobile/desktop
- [ ] Theme toggle dark/light berfungsi

---

## 5. User Login

- [ ] Buka `/en/login` atau `/id/login`
- [ ] Masukkan email: `qa-test@familyfinance.app`
- [ ] Masukkan password: `qadummy123`
- [ ] Klik "Sign In" / "Masuk"
- [ ] Login berhasil
- [ ] Redirect ke dashboard user

---

## 6. User Dashboard - Overview

- [ ] Dashboard page tampil
- [ ] Total saldo tampil (jika ada wallet di Android)
- [ ] Income bulan ini tampil
- [ ] Expense bulan ini tampil
- [ ] Grafik trend tampil

---

## 7. User Dashboard - Transactions

- [ ] Buka menu "Transactions" / "Riwayat"
- [ ] Semua transaksi dari Android tampil
- [ ] Filter berdasarkan periode berfungsi
- [ ] Search berfungsi

---

## 8. User Dashboard - Wallets

- [ ] Buka menu "Wallets" / "Dompet"
- [ ] Semua wallet dari Android tampil
- [ ] Saldo per wallet tampil

---

## 9. User Dashboard - Reports

- [ ] Buka menu "Reports" / "Laporan"
- [ ] Grafik income vs expense tampil
- [ ] Filter periode berfungsi
- [ ] Export PDF/CSV berfungsi (jika ada)

---

## 10. User Dashboard - Budget & Savings

- [ ] Buka menu "Budget & Savings" / "Anggaran & Tabungan"
- [ ] Semua budget dari Android tampil
- [ ] Semua savings dari Android tampil
- [ ] Progress bar tampil

---

## 11. User Dashboard - Debts

- [ ] Buka menu "Debts" / "Hutang"
- [ ] Semua hutang/piutang dari Android tampil
- [ ] Status (Active/Paid/Overdue) tampil

---

## 12. User Dashboard - Guide

- [ ] Buka menu "Guide" / "Panduan" (jika ada di sidebar)
- [ ] Guide page tampil dengan konten lengkap
- [ ] Semua step bisa di-scroll/dibaca

---

## 13. Theme Toggle

- [ ] Cek toggle tema di navbar
- [ ] Toggle ke dark mode
- [ ] Tampilan berubah ke gelap
- [ ] Toggle ke light mode
- [ ] Tampilan berubah ke terang

---

## 14. Responsive Design

- [ ] Resize browser ke ukuran mobile (375px)
- [ ] Layout responsive, tidak ada elemen yang overflow
- [ ] Navbar collapse menjadi hamburger menu
- [ ] Sidebar collapse menjadi drawer
- [ ] Semua tombol tetap clickable

---

## 15. Logout

- [ ] Klik tombol "Sign Out" / "Keluar"
- [ ] Logout berhasil
- [ ] Redirect ke landing page atau login page

---

## 16. APK Download

- [ ] Klik tombol "Download APK" di landing page
- [ ] File APK terdownload
- [ ] Ukuran file ~67 MB

---

## 17. Security Check

- [ ] User biasa tidak bisa akses `/admin`
- [ ] Jika coba akses admin, redirect atau tampil "no permission"
- [ ] Data user lain tidak bisa dilihat

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
**Web Version:** 1.1.2
