# Panduan Penggunaan RMODZ Remote

RMODZ Remote adalah sistem bantuan jarak jauh berbasis **persetujuan (consent)**.
Satu perangkat menjalankan **Controller** (penolong), perangkat lain menjalankan
**Agent** (yang dibantu). Keduanya terhubung lewat server signaling, lalu
membentuk koneksi P2P WebRTC. Semua tindakan remote memerlukan persetujuan
eksplisit di sisi Agent.

---

## Ringkasan komponen

| Komponen       | Perangkat | Fungsi                                     |
|----------------|-----------|--------------------------------------------|
| **Server**     | PC / VPS  | Auth, pairing, signaling WebSocket, session |
| **Controller** | HP A      | Login, pasang kode, lihat layar, kontrol    |
| **Agent**      | HP B      | Didaftarkan, disetujui, dibantu remote      |

---

## 1. Menjalankan server

```bash
cd server
npm install
cp .env.example .env      # Windows: copy .env.example .env
npm run build
npm start
```

Server akan berjalan di `http://localhost:8080` (atau sesuai `PORT` di `.env`).

### Buka port 8080 di firewall (wajib untuk HP fisik)
Firewall Windows sering memblokir koneksi masuk dari HP. Jalankan sekali dengan
**Run as administrator**:

```powershell
powershell -ExecutionPolicy Bypass -File tools\open-firewall-8080.ps1
```

Bisa juga manual: `Windows Defender Firewall → Advanced settings → Inbound
Rules → New Rule → Port → TCP 8080 → Allow`.

> Untuk diakses dari HP, pakai **IP LAN** PC (cek dengan `ipconfig`, cari IPv4).
> Contoh `http://192.168.1.7:8080`. Pastikan port 8080 terbuka di firewall.

### Akses lintas jaringan (Cloudflare quick tunnel)
Kalau HP **tidak satu jaringan** dengan server (mis. HP pakai data seluler),
pakai tunnel gratis dari Cloudflare supaya server bisa diakses dari mana saja.
Media (screen/camera/mic) tetap P2P via WebRTC — tunnel hanya meneruskan
signaling WebSocket.

1. Pastikan server sudah jalan (`tools\start-server.bat`).
2. Jalankan `tools\start-tunnel.bat` (Butuh `tools\cloudflared.exe`; jika belum
   ada, unduh dari https://github.com/cloudflare/cloudflared/releases dan taruh
   di folder `tools\`).
3. Catat URL publik dari baris `https://<random>.trycloudflare.com` yang muncul.
4. Build APK dengan URL tersebut (lihat bagian 2), misal:
   `--dart-define=RMODZ_SERVER_URL=https://xxxxx.trycloudflare.com`.

> ⚠️ URL **berubah setiap restart** tunnel. Kalau URL berubah, kamu harus
> build ulang APK dengan URL baru. Untuk URL permanen, butuh *named tunnel* +
> domain sendiri.
>
> Tunnel tidak membuka port 8080 di firewall — firewall rule di atas tidak
> diperlukan jika pakai tunnel. Media antar jaringan yang bertemu NAT ketat
> tetap butuh **TURN server** (lihat `server/README.md`).

---

## 2. Build APK dengan alamat server yang benar

Default kedua app adalah `http://10.0.2.2:8080` (khusus **emulator Android**
untuk menuju localhost PC).

### Untuk perangkat fisik
Override alamat server saat build:

```bash
# Controller
cd controller
flutter build apk --release --dart-define=RMODZ_SERVER_URL=http://192.168.1.10:8080

# Agent
cd ../agent
flutter build apk --release --dart-define=RMODZ_SERVER_URL=http://192.168.1.10:8080
```

Versi **debug** (untuk tes) tinggal pakai `--debug` sebagai pengganti `--release`.

### Lokasi APK hasil build
- Controller: `controller/build/app/outputs/flutter-apk/app-release.apk`
- Agent: `agent/build/app/outputs/flutter-apk/app-release.apk`

---

## 3. Instal APK di dua HP

1. HP **A** (penolong) → instal APK Controller.
2. HP **B** (yang dibantu) → instal APK Agent.

> Kedua HP harus bisa mengakses server. Untuk jaringan LAN (satu Wi-Fi), arahkan
> ke IP LAN PC. Untuk beda jaringan, tambahkan **TURN server** (lihat bagian
> STUN/TURN di `server/README.md`).

---

## 4. Konfigurasi di HP B (Agent) — sekali saja

Buka app Agent, lalu beri izin:

1. **Kamera & Mikrofon** — untuk fitur camera/mic mendapat izin runtime.
2. **Notifikasi** — agar service remote terus berjalan.
3. **Aktifkan Accessibility "RMODZ"**:
   `Setelan → Aksesibilitas / Aksesbilitas → RMODZ → aktifkan`
   (dibutuhkan untuk kontrol sentuh/navigasi/teks).
4. Setujui **Foreground Service / screen capture** saat pertama kali diminta.

Agent otomatis mendaftarkan diri dan mendapatkan ID perangkat (bentuk
`RMDZ-XXXXXX`).

---

## 5. Alur pairing & remote (tiap sesi)

1. Di HP **B** (Agent): buka app → pada panel pairing, tekan **Generate
   pairing code** → muncul kode 6 digit.
2. Di HP **A** (Controller): buka app → login/register akun → masukkan kode
   6 digit tersebut.
3. Muncul dialog persetujuan di HP **B** → pengguna HP B **tekan Setujui**.
4. Controller meminta **session** + daftar izin (screen / camera / mic /
   control). Di HP B muncul dialog izin → pengguna Hp B pilih izin lalu
   **Setujui** (atau Tolak).
5. Koneksi WebRTC terbentuk. HP A kini dapat:
   - melihat **layar** HP B,
   - mengirim **tap / navigasi / teks** (jika izin *control* diberikan),
   - mengirim **file** lewat jalur data.
6. Kapan saja, salah satu sisi bisa **mengakhiri session** atau **mencabut izin**
   tertentu.

> Semua persetujuan adalah eksplisit di sisi Agent. Tidak ada remote diam-diam.

---

## Troubleshooting

- **App tidak terhubung ke server** → pastikan `RMODZ_SERVER_URL` benar saat
  build, HP satu jaringan dengan server, dan port terbuka.
- **Layar tidak muncul / hitam** → pastikan izin **screen capture (MediaProjection)**
  dan **Foreground Service** disetujui di Agent.
- **Sentuhan tidak bekerja** → pastikan **Accessibility RMODZ** aktif.
- **Tidak bisa terhubung antar jaringan yang berbeda** → butuh **TURN server**
  (lihat `server/README.md`).

---

## Setelan teknis

- Kedua app butuh **API 23+** (`minSdk = 23`).
- Koneksi P2P; STUN bawaan untuk jaringan normal, **TURN disarankan** untuk
  lintas NAT yang ketat.
- Build release memakai keystore di `android/rmodz-upload.keystore` (jangan
  commit ke repo; konfigurasi di `android/key.properties`).
