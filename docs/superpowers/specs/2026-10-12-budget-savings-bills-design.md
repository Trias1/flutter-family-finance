# Budget, Tabungan & Tagihan dari scan — desain

Tanggal: 12 Okt 2026 · Status: menunggu review user

## Tujuan

User mau mulai ulang data dari screenshot. Uang yang **dimiliki** (saldo
rekening) tidak boleh pernah tercatat sebagai pengeluaran. Uang bisa
dialokasikan ke **Budget** (Transportasi, Makanan, Listrik, Internet, ...)
atau **Tabungan** (goal). Pengeluaran bisa dibayar dari Budget atau dari
Tabungan, dan masing-masing punya riwayat. Tagihan (listrik, internet) bisa
di-scan dan otomatis memotong budget kategorinya.

Aturan yang dipegang:
- Saldo dari screenshot = uang masuk/dimiliki, **tidak pernah** pengeluaran.
- Satu uang dicatat **sekali** (tidak dobel antara tagihan, pengeluaran,
  tabungan).
- Budget berkurang hanya dari pengeluaran yang di-scan/dicatat; tidak ada
  pengeluaran otomatis dari selisih saldo.
- Tanggal tagihan diatur user per tagihan, tidak di-hardcode.

Di luar lingkup (nanti): Utang/Piutang terhubung ke scan (Bagian 5), baca
notifikasi bank (ditunda, lihat AGENTS.md).

## Bagian 1 — Scan saldo: "Masukkan ke mana?"

Dialog saldo (`balance_sync.dart`) setelah screenshot saldo terbaca
(`BalanceParser`), juga saat belum ada goal:

1. Pilih saldo bila layar punya beberapa kantong (Total / Tabungan Neo /
   Neo NOW) — sudah ada.
2. Pilih tujuan: **Budget** | **Tabungan** | Batal.
   - **Budget**: pilih kategori pengeluaran (tanpa "Tabungan").
     - Belum ada budget kategori itu bulan ini → buat dengan
       `budgetAmount` = saldo (pemakaian bulan ini dihitung seperti
       sekarang, `spentInMonth`).
     - Sudah ada → tanya: **Ganti ke saldo sekarang** (Rp X) atau
       **Update nominal** (isi sendiri, default nominal lama).
   - **Tabungan**: pilih goal (goal di bank yang sama diutamakan) → saldo goal
     = saldo screenshot (sudah ada).
   - **Batal**: tidak mencatat apa pun, tidak lanjut ke alur struk.
3. Centang **"Catat juga sebagai pemasukan (Saldo awal)"**, default nyala.
   Bila nyala, simpan langsung pemasukan kategori **Saldo awal** dengan
   catatan `Untuk <Kategori/Goal> · Saldo <Bank> · <Kantong>`. Dimatikan
   untuk update saldo rutin supaya "In" tidak dobel.

Pengganti tombol "Catat pemasukan" dari commit a0a79d1. Chip "Untuk" di form
Pemasukan tetap ada untuk struk transfer masuk.

## Bagian 2 — Sumber uang pengeluaran: Budget / Tabungan

- `ExpenseModel` dapat field opsional **`savingId`**. Rules `/expenses` tidak
  membatasi key, jadi tidak perlu ubah rules.
- Form Pengeluaran: **Sumber uang** = Budget (default) | Tabungan (+ pilih
  goal).
- Arti data:
  - kategori **Tabungan** + `savingId` → **setor**: goal `+amount`.
  - kategori lain + `savingId` → **dibayar dari tabungan**: goal
    `-amount` (tidak di bawah 0), **budget tidak dipotong**
    (`BudgetRepository.applyExpense` dilewati).
  - tanpa `savingId` → seperti sekarang (budget per kategori; Tabungan lama
    dicocokkan lewat nama goal di catatan — tetap didukung untuk data lama).
- Edit/hapus mengembalikan efek lama lewat `savingId`, lalu menerapkan yang
  baru.
- Perbaiki bug "Tarik dari tabungan": sekarang goal dikurangi lalu expense
  "Tabungan" dengan nama goal menambah lagi (net 0). Penarikan jadi satu
  expense kategori **Lainnya** + `savingId` (goal berkurang sekali).
- "Out" bulan ini di Home: pengeluaran dari tabungan **ikut** dihitung (uang
  benar-benar keluar); setoran Tabungan tetap tidak dihitung (sudah begitu).

## Bagian 3 — Riwayat

- **Goal** (tap kartu goal): riwayat goal itu saja — expense dengan
  `savingId == goal.id` (setor/pengeluaran) + data lama yang cocok nama.
  Menggantikan riwayat sekarang yang sama untuk semua goal.
- **Budget** (tap kartu budget): daftar pengeluaran kategori itu bulan ini
  yang memotong budget (tanpa `savingId`).
- Daftar transaksi (History): label kecil **Budget** atau
  **Tabungan · <goal>** di baris pengeluaran.

## Bagian 4 — Tagihan bisa di-scan

- `BillModel` tambah:
  - **`category`**: kategori pengeluaran (default = nama tagihan, mis.
    Listrik, Internet; ditambahkan ke kategori pengeluaran bila belum ada).
  - **`payFromDay`** (1–31, opsional): "bisa dibayar mulai tanggal".
  - Jatuh tempo tetap `dueDate` (hari = "batas bayar tanggal").
  Rules `/bills` tidak membatasi key.
- Form Tagihan: Kategori, Bisa dibayar mulai tgl, Batas bayar tgl. Contoh
  user: Listrik 1–20, Internet 1–17 — diisi user, bukan di kode.
- Scan struk pengeluaran (bukan mutasi, bukan saldo): **BillMatcher** mencari
  tagihan belum lunas yang cocok:
  - kata kunci: nama/kategori tagihan; listrik → `pln, token, listrik`;
    internet → `indihome, telkom, biznet, first media, myrepublic, iconnet,
    wifi, internet`;
  - atau nominal sama (±1%) dan tanggal struk di dalam jendela bayar.
  Cocok → "Ini bayar tagihan **Internet** Rp X?" → Iya: satu pengeluaran
  (kategori tagihan, sumber Budget/Tabungan) + tagihan lunas. Tidak → alur
  pengeluaran biasa (tidak berubah).
- Tandai lunas manual di halaman Tagihan → "Catat sebagai pengeluaran?"
  (nominal terisi). Satu aksi, satu catatan.
- Tagihan **bulanan/mingguan/tahunan** yang lunas pindah ke jatuh tempo
  berikutnya (status kembali belum lunas untuk periode itu, `paidDate` =
  pembayaran terakhir). Perbaiki: batal-lunas mengosongkan `paidDate`.
- Status **telat** setelah lewat batas bayar; pengingat memakai batas bayar
  (mekanisme notifikasi yang ada).
- Budget Listrik/Internet otomatis terpotong karena pengeluaran memakai
  kategori itu (logika budget per kategori yang ada).

## Pengujian

Unit test (pure Dart) untuk:
- keputusan budget dari saldo (buat / ganti / update nominal);
- efek expense ke goal & budget (setor, bayar dari tabungan, tanpa goal,
  edit/hapus membalik efek; penarikan tidak net 0);
- BillMatcher (kata kunci, nominal + jendela tanggal, tidak cocok);
- jatuh tempo berikutnya (bulanan termasuk akhir bulan, mingguan, tahunan);
- saldo tidak pernah menghasilkan pengeluaran.
Lalu cek manual di emulator: scan screenshot Neo → Budget/Tabungan, struk
listrik/internet → tagihan lunas + budget terpotong.

## Rilis

Dikerjakan & dirilis per bagian bila perlu (1+2+3 dulu, lalu 4), dengan cek
izin APK seperti biasa (lihat memori Play Protect).
