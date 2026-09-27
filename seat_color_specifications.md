# 🚌 Spesifikasi & Dokumentasi Lengkap Layout Kursi Bus (43 Seats - Final Shifted Layout)

Dokumentasi ini mencatat aturan dan standar **tata letak penomoran kursi** (*Seat Numbering Scheme*), **garis pembatas kabin per 2 baris (kompartemen rapat & seimbang)**, dan **skema warna antarmuka** (*UI Color Scheme*) untuk modul **Seat Monitoring Bus**. Aturan ini dikunci secara permanen.

---

## 1. Ringkasan Dimensi & Tata Letak Kursi

- **Total Kapasitas Armada:** **43 Jok** (2 Kursi Depan A & B + 20 Kursi B + 21 Kursi A).
  - *Catatan:* Posisi **10B** sengaja dikosongkan (ruang akses pintu tengah / pintu darurat).
- **Dimensi Bodi Bus:**
  - Maksimal Lebar: `max-w-7xl` (leluasa dan memanjang).
  - Rasio Bodi (*Aspect Ratio*): `aspect-[28/6]`.
  - Lebar per Kursi: `width: 3.6%` (proporsional, rapi, dan seimbang).
- **Kabin Depan & Pengemudi:**
  - Kaca Depan (*Windshield*): `left: 2.2%`, lebar `1.8%`.
  - Sekat Kabin Supir (*Driver Cabin*): `left: 4.0%`, lebar `7.8%`.
  - Lorong Jalan Bus (*Aisle Corridor*): dimulai dari `left: 11.8%`.
- **Struktur Baris (Koordinat Vertikal / Y):**
  - **Baris Atas (*Top*):** `top: 27%` (sisi kanan bus / sejajar supir)
  - **Baris Tengah (*Middle*):** `middle: 44%` (sisi kanan bus)
  - **Lorong Jalan (*Aisle Corridor*):** `top: 59%` (jalan tengah bergaris putus-putus)
  - **Baris Bawah (*Bottom*):** `bottom: 78%` (sisi kiri bus)

---

## 2. Struktur Kompartemen 2 Baris (Terdistribusi Merata ke Belakang)

| Kompartemen | Kolom B (Kiri Bagian) | Kolom A (Kanan Bagian) | Posisi Garis Pembatas Putih |
| :---: | :---: | :---: | :---: |
| **Depan** | `Kursi A` & `Kursi B` (`left: 16.0%`) | - | `left: 19.7%` *(Pemisah Depan)* |
| **Bagian 1** | `3B, 2B, 1B` (`left: 23.4%`) | `3A, 2A, 1A` (`left: 27.6%`) | `left: 31.0%` *(Garis Pembatas 1)* |
| **Bagian 2** | `6B, 5B, 4B` (`left: 34.4%`) | `6A, 5A, 4A` (`left: 38.6%`) | `left: 42.0%` *(Garis Pembatas 2)* |
| **Bagian 3** | `9B, 8B, 7B` (`left: 45.4%`) | `9A, 8A, 7A` (`left: 49.6%`) | `left: 53.0%` *(Garis Pembatas 3)* |
| **Bagian 4** | `12B, 11B, (10B Kosong)` (`left: 56.4%`) | `12A, 11A, 10A` (`left: 60.6%`) | `left: 64.0%` *(Garis Pembatas 4)* |
| **Bagian 5** | `15B, 14B, 13B` (`left: 67.4%`) | `15A, 14A, 13A` (`left: 71.6%`) | `left: 75.0%` *(Garis Pembatas 5)* |
| **Bagian 6** | `18B, 17B, 16B` (`left: 78.4%`) | `18A, 17A, 16A` (`left: 82.6%`) | `left: 86.0%` *(Garis Pembatas 6)* |
| **Bagian 7** | `21B, 20B, 19B` (`left: 89.4%`) | `21A, 20A, 19A` (`left: 93.6%`) | *(Ujung belakang kabin dengan sisa ruang ~4.6%)* |

---

## 3. Skema Warna Kursi (Sensor Sabuk Pengaman / Seatbelt Integrated)

| Status Kursi | Simbol | Warna | Tailwind Token / Hex | Efek Visual |
| :--- | :---: | :---: | :---: | :--- |
| **Kosong (*Available*)** | `○` | **Hijau** | `emerald-500` (`#10b981`) | Glow hijau lembut, border emerald |
| **Terisi - Tanpa Seatbelt (`seatbelt: false`)** | `●` | **Biru** | `blue-500` (`#3b82f6`) | Glow biru tegas, border blue |
| **Terisi - Pakai Seatbelt (`seatbelt: true`)** | `●` | **Merah** | `red-500` (`#ef4444`) | Glow merah tegas, border red |
| **Panggilan (*Calling*)** | `🔔` | **Kuning / Amber** | `amber-500` (`#f59e0b`) | Animasi denyut (*pulse*), audio chime |

---

## 4. Panel Statistik Bawah

- **Kapasitas Armada:** `43 Jok`
- **Terisi (Occupied):** Angka merah `text-red-400 drop-shadow-[0_0_8px_rgba(239,68,68,0.6)]` (`Pax`)
- **Kosong (Available):** Angka hijau `text-emerald-400 drop-shadow-[0_0_8px_rgba(16,185,129,0.5)]` (`Jok`)
