# RMODZ Remote — Handoff ke HP (1 Halaman)

## 📱 File APK (sudah di-build di laptop)
| HP | File | Ukuran |
|----|------|--------|
| **HP A (Controller)** | `controller/build/app/outputs/flutter-apk/app-release.apk` | 102 MB |
| **HP B (Agent/Target)** | `agent/build/app/outputs/flutter-apk/app-release.apk` | 84.8 MB |

> **Kirim ke HP:** Upload ke Google Drive / Telegram Saved Messages / SHAREit → download & install di HP masing-masing.

---

## ⚙️ Server + Tunnel (di laptop, jalan terus saat pakai)
```bash
# Terminal 1: Server
cd server && npm start

# Terminal 2: Tunnel (URL berubah tiap restart!)
tools\start-tunnel.bat
```
**URL sekarang:** `https://appointment-shuttle-outdoors-applicant.trycloudflare.com`  
*(Sudah dipakai saat build APK di atas)*

⚠️ **Restart tunnel = URL baru = harus build ulang APK.**

---

## 📋 Setup HP B (Agent/Target) — Sekali Saja
1. Install `app-release.apk` (Agent)
2. Buka app → Izinkan: **Kamera**, **Mikrofon**, **Notifikasi**
3. **Settings → Accessibility → RMODZ → ON** (wajib untuk touch/control)
4. Setujui **Screen Capture / Foreground Service** saat diminta

Agent otomatis daftar & dapat ID `RMDZ-XXXXXX`.

---

## 🔗 Pairing & Pakai (Tiap Sesi)

### Opsi A: QR Code (Cepat, direkomendasikan)
1. **HP B (Agent):** Buka app → QR code otomatis tampil di dashboard
2. **HP A (Controller):** Login/Daftar → Tekan **"Scan QR Code"** → Arahkan kamera ke QR code HP B
3. **Selesai:** Otomatis paired! Lanjut ke step 3 di bawah.

### Opsi B: Manual (Kode 6 digit)
1. **HP B (Agent):** Tekan **Generate pairing code** → kode 6 digit
2. **HP A (Controller):** Login/Daftar → Masukkan Device ID + kode → HP B tekan **Setujui**
3. Minta **Session** + pilih izin (Screen, Touch, Camera, Mic, File, Clipboard)
4. **HP B:** Pilih izin → **Setujui** (atau auto-accept jika sudah diaktifkan di Settings)
5. **Selesai:** HP A lihat layar HP B, kirim tap/swipe/drag, teks, file

---

## ⚡ Auto-Accept Sessions (Opsional)
Agar sesi berikutnya langsung konek tanpa konfirmasi di HP B:
1. **HP B (Agent):** Buka **Settings** → Aktifkan **"Auto-accept sessions from paired controllers"**
2. Sekali paired via QR, sesi selanjutnya langsung mulai saat HP A minta session.

---

## 🛠 Troubleshooting Cepat
| Gejala | Solusi |
|--------|--------|
| Layar hitam / tidak muncul | Pastikan HP B izin **Screen Capture** & **Foreground Service** ON |
| Sentuhan tidak jalan | Pastikan **Accessibility RMODZ** aktif di Settings HP B |
| Tidak konek ke server | Cek laptop: server + tunnel jalan? URL tunnel sama di APK? |
| HP beda pulau, media putus | Butuh TURN server (gratis: `turn:openrelay.metered.ca:443?transport=tcp` di `.env`) |
| QR scan gagal | Pastikan HP A izin Kamera. Coba manual (Device ID + kode 6 digit). |

---

## 📂 Lokasi File Penting
- **APK Controller:** `controller/build/app/outputs/flutter-apk/app-release.apk`
- **APK Agent:** `agent/build/app/outputs/flutter-apk/app-release.apk`
- **Server:** `server/` → `npm start`
- **Tunnel:** `tools/start-tunnel.bat` (perlu `tools/cloudflared.exe`)
- **URL Tunnel Sekarang:** `https://appointment-shuttle-outdoors-applicant.trycloudflare.com`