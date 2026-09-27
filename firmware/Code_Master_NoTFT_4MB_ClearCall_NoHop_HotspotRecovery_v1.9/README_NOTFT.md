# SmartBus Master No-TFT HotspotRecovery v1.9 (4 MB)

Branch-folder ini adalah salinan `Code_Master` untuk ESP32 Master tanpa aset
atau kode TFT.

## Konfigurasi

- Board: DOIT ESP32 DevKit V1
- Flash fisik: 4 MB
- Partisi: `default.csv` (mendukung OTA)
- Framework: Arduino ESP32 standar melalui `espressif32@7.0.1`
- Flasher: `esptool.py 4.11.0`, baud 115.200
- Audio DY-HV8F dan WebSocket head unit tetap aktif
- NAPT/internet sharing tidak disertakan dalam branch standar ini

## Audio DY-HV8F (DIP 000)

Firmware menggunakan integrated I/O mode dengan input aktif-LOW. Hubungkan:

| DY-HV8F | ESP32 |
| --- | --- |
| IO0 | GPIO13 |
| IO1 | GPIO14 |
| IO2 | GPIO19 |
| IO3 | GPIO21 |
| IO4 | GPIO22 |
| IO5 | GPIO23 |
| IO6 | GPIO25 |
| IO7 | GPIO26 |
| BUSY | GPIO15 |
| GND | GND |

Atur DIP ke `000` sebelum menyalakan modul. Semua input HIGH berarti idle;
firmware memberikan pulsa kombinasi biner LOW selama 150 ms untuk memilih
track 1 sampai 255. GPIO16 dan GPIO17 tidak lagi digunakan untuk audio.

Firmware memakai 16 track dari
`audio/track baru sudah di convert/TRACK_MAPPING.md`. Saat tombol panggil
ditekan, ID kursi dibaca otomatis dan pengumuman diputar dua kali. Format ID
`21A`, `A21`, maupun `SEAT-21A` didukung. Nomor 1 sampai 99 dirakit dari track
angka, `belas`, dan `puluh`; akhiran A/B memakai track 15/16.

## Perbaikan LED v1.6

- Pengumuman panggilan diputar oleh task audio terpisah, sehingga animasi LED
  tetap berjalan selama audio berlangsung.
- Dimmer 0% dan perintah OFF mengirim data hitam eksplisit agar LED benar-benar
  mati.
- Urutan warna strip dikoreksi dari `RBG` menjadi `GRB`, sehingga kontrol RGB
  manual kembali sesuai merah, hijau, dan biru.

## Dynamic sensor ID v1.7

Sensor tanpa ID tersimpan melapor sebagai `RandomID` dengan UID hardware unik.
Tekanan tombol panggilan pertamanya mengirim event `seatPairingRequired` hanya
ke head unit. ID yang dipilih aplikasi diteruskan kembali ke sensor yang cocok,
termasuk bila sensor berada di balik rangkaian Gateway. Sensor menyimpan ID ke
NVS dan mengirim konfirmasi `seatIdSaved`; `RandomID` tidak dimasukkan roster
dan tidak memicu audio sebelum provisioning selesai.

## Hybrid hotspot aman v1.8

Master tetap menyediakan AP `Seat-Monitoring-Bus` untuk seat/gateway dan pada
saat yang sama dapat menjadi client hotspot HP. Karena ESP32 hanya mempunyai
satu radio 2,4 GHz, sisi AP dan STA harus memakai channel yang sama.

Urutan boot dibuat aman:

1. Master membaca kredensial hotspot dari NVS; jika kosong, memakai
   `STA_SSID`/`STA_PASS` di `src/variables.h`.
2. Master mencoba hotspot maksimal 12 detik sebelum seat AP dinyalakan.
3. Jika tersambung, `Seat-Monitoring-Bus` dimulai pada channel hotspot.
4. Jika gagal, Master membatalkan STA dan menjalankan AP-only di channel 11.
5. Auto-reconnect bawaan driver dinonaktifkan agar AP seat tidak pindah channel
   tanpa dikendalikan firmware.

Hotspot boleh menyala setelah Master masuk fallback AP-only. Pemulihan otomatis
v1.9 akan mencari dan menyambungkannya kembali dengan aturan aman di bawah.

Perubahan SSID/password dari head unit disimpan ke NVS lalu Master melakukan
controlled reboot. Hotspot dicoba sebelum AP dibuka kembali, sehingga seat dan
gateway hanya melihat satu channel final setelah boot.

Aplikasi dapat menemukan Master melalui `bus-led.local`, IP terakhir, atau
scan subnet hotspot pada port WebSocket 81. `192.168.4.1` tetap tersedia ketika
head unit memakai AP langsung milik Master.

### Kredensial bawaan

Edit nilai berikut sebelum build bila ingin hotspot default yang berbeda:

```cpp
const char* STA_SSID = "iot_bus";
const char* STA_PASS = "iot_BUS@5758";
```

Nilai yang pernah dikirim aplikasi/serial dan tersimpan di NVS mempunyai
prioritas lebih tinggi daripada nilai bawaan firmware.

Perintah serial untuk menyimpan hotspot baru:

```text
connect NamaHotspot PasswordHotspot
```

Master akan menyimpan kredensial lalu restart. Gunakan `status` atau `wifi`
untuk melihat SSID dan IP STA yang diperoleh dari hotspot.

## Pemulihan hotspot otomatis v1.9

Ketika hotspot mati, jaringan seat tetap hidup melalui AP
`Seat-Monitoring-Bus`. Master mulai mencari SSID tersimpan setelah 5 detik dan
mengulang scan asynchronous setiap 15 detik tanpa menghentikan loop WebSocket,
LED, atau pemrosesan seat.

- Jika hotspot kembali pada channel yang sama, Master reconnect langsung tanpa
  memindahkan AP dan tanpa memutus seat.
- Jika hotspot kembali pada channel berbeda, Master menunggu sampai tidak ada
  panggilan aktif/pending, antrean audio kosong, dan pengumuman selesai. Setelah
  itu Master melakukan controlled restart dan membuka AP pada channel baru.
- Jika restart pemulihan gagal menyambung (contoh password salah), percobaan
  restart lintas-channel diblokir agar Master tidak reboot berulang. AP seat
  tetap aktif. Kirim kredensial baru atau restart manual untuk mencoba kembali.
- Tombol/perintah `disconnect` menonaktifkan recovery sampai boot berikutnya
  atau sampai kredensial baru dikirim.

Indikator LED built-in: solid berarti hotspot terhubung, kedip lambat berarti
recovery berjalan, dan kedip cepat berarti controlled restart akan dilakukan.

## Build dan upload

```powershell
pio run -e master_4mb
pio run -e master_4mb -t upload --upload-port COM9
```

Upload PlatformIO pada branch ini memakai perintah standar untuk board Master
4 MB yang terdeteksi dengan JEDEC flash ID `5e:4016`.
