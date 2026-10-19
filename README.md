# VOIDS - Auto Rejoin & Account Launcher

Script Auto Rejoin & Multi-Account Launcher untuk Termux Android (Rooted).

---

## 📋 Syarat & Persiapan Awal

1. **HP Android (Rooted)** dengan aplikasi **Termux**.
2. **Download Termux APK Official**:  
   🔗 [Download Termux APK v0.118.3 Universal](https://github.com/termux/termux-app/releases/download/v0.118.3/termux-app_v0.118.3+github-debug_universal.apk)

---

## 🚀 Langkah Instalasi & Penggunaan (First-Time Setup)

### 1. Install Dependency Termux
Buka Termux, lalu jalankan perintah ini (cukup 1x saat pertama kali setup):

```bash
termux-setup-storage && pkg update -y && pkg install -y lua53 tsu curl
```

### 2. Download & Jalankan Script VOIDS

```bash
curl -sL "https://raw.githubusercontent.com/Dhanniii/rejoin/main/void.lua" -o ~/void.lua && lua ~/void.lua
```

---

## 🔄 Cara Menjalankan Ulang di Kemudian Hari

Setelah instalasi awal selesai, untuk menjalankan script di kemudian hari, cukup ketik:

```bash
lua ~/void.lua
```

---

## 🔑 Informasi Lisensi Key & HWID

- **Lokasi Penyimpanan Key**:  
  Lisensi Key yang terverifikasi tersimpan otomatis di `/sdcard/Download/void_key.txt`.
- **Mengganti / Reset Lisensi Key**:  
  Hapus file `void_key.txt` dengan perintah:
  ```bash
  rm -f /sdcard/Download/void_key.txt
  ```
