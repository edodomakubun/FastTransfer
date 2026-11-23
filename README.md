# FastTransfer ⚡ (Offline-First High-Speed Local Transfer)

Aplikasi transfer berkas, media (foto/video), dan dokumen antar perangkat (Android & PC Windows) secara **offline** di jaringan lokal (Wi-Fi / Hotspot) tanpa kuota internet, dengan kecepatan tinggi (**>10 MB/s hingga 80+ MB/s**).

---

## 🚀 Fitur Utama
1. **Offline-First & Zero Internet**: Tidak membutuhkan kuota internet atau server cloud. Berjalan 100% di jaringan lokal.
2. **Auto-Discovery (Tanpa Input IP Manual)**: Menggunakan UDP Broadcast (port `42100`) sehingga perangkat Android dan PC langsung saling mendeteksi saat berada di jaringan yang sama.
3. **High-Speed Transfer (>10 MB/s - 80+ MB/s)**:
   - Direct binary socket streaming (`bufferOutput = false`).
   - Ukuran chunk buffer optimal (512 KB per paket).
   - Zero-RAM disk piping (langsung ditulis ke disk/storage, anti-crash untuk file berukuran gigabyte).
   - Real-time speedometer (menampilkan kecepatan transfer dalam MB/s).
4. **Single Codebase**: Dibuat menggunakan **Flutter (Dart)** sehingga satu kode sumber bisa langsung dikompilasi menjadi aplikasi Android (`.apk`) dan PC Windows (`.exe`).

---

## 📁 Struktur Proyek
```text
APKTF/
├── lib/
│   ├── main.dart                      # Inisialisasi aplikasi, permission, & tema
│   ├── models/
│   │   ├── device_info.dart           # Model identitas perangkat di jaringan
│   │   └── transfer_task.dart         # Model task, status, & kalkulasi progress/speed
│   ├── services/
│   │   ├── discovery_service.dart     # Auto-discovery via UDP Broadcast
│   │   ├── file_server_service.dart   # HTTP Server lokal penerima file (streaming to disk)
│   │   └── transfer_client_service.dart # HTTP Client pengirim file berkecepatan tinggi
│   └── screens/
│       └── home_screen.dart           # Antarmuka Material 3 (Kirim, Pindai, & Riwayat)
├── android/
│   └── app/src/main/AndroidManifest.xml # Izin Wi-Fi multicast, network & storage
└── pubspec.yaml                       # Konfigurasi dependensi Flutter
```

---

## 🛠️ Langkah Menjalankan Aplikasi

### 1. Pasang Flutter SDK & Git di Windows (Sekali Saja)
Buka PowerShell / Terminal sebagai Administrator dan jalankan:
```powershell
winget install Git.Git -e
winget install Google.Flutter -e
```
*Setelah selesai, restart terminal Anda agar `flutter` terbaca di PATH.*

### 2. Jalankan Perintah Diagnosa Flutter
```powershell
flutter doctor
```

### 3. Jalankan Aplikasi di PC Windows
Di dalam folder `APKTF`, jalankan:
```powershell
flutter pub get
flutter run -d windows
```

### 4. Build Aplikasi untuk Android (.APK)
Untuk membuat installer Android:
```powershell
flutter build apk --release
```
File APK akan berada di: `build/app/outputs/flutter-apk/app-release.apk`.
Kirim file APK tersebut ke HP Android Anda dan pasang (install).

---

## 💡 Tips Mendapatkan Kecepatan Maksimal (>10 - 50+ MB/s)
* **Gunakan Wi-Fi Frekuensi 5 GHz (atau Hotspot HP 5 GHz):**
  * Masuk ke pengaturan Hotspot di HP Android, pilih **AP Band: 5.0 GHz Band** (bukan 2.4 GHz).
  * Hubungkan laptop PC ke Hotspot HP tersebut.
  * Anda akan mendapatkan kecepatan transfer stabil di kisaran **30 MB/s – 70 MB/s**.
