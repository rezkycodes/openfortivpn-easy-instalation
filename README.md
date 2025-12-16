# 🔐 OpenFortiVPN Auto Installer

Script instalasi otomatis untuk **OpenFortiVPN** - Universal Linux Installer.

## 📋 Daftar Isi

- [Fitur](#-fitur)
- [Prasyarat](#-prasyarat)
- [Instalasi](#-instalasi)
- [Konfigurasi](#-konfigurasi)
- [Penggunaan](#-penggunaan)
- [Troubleshooting](#-troubleshooting)
- [FAQ](#-faq)

## ✨ Fitur

- ✅ **Auto-install** OpenFortiVPN dan dependencies
- ✅ **Konfigurasi otomatis** dengan template yang sudah disesuaikan
- ✅ **DTLS Support** untuk performa optimal (fallback ke TLS jika diperlukan)
- ✅ **Helper script** (`vpn`) untuk manajemen VPN yang mudah
- ✅ **Systemd service** untuk auto-start saat boot
- ✅ **Monitoring tools** built-in untuk troubleshooting
- ✅ **Firewall configuration** otomatis

## 🔧 Prasyarat

### Sistem Operasi
- **Linux** (Ubuntu, Debian, Fedora, RHEL, CentOS, Rocky, AlmaLinux, Arch, Manjaro, openSUSE, Alpine, Gentoo)
- Akses internet untuk download packages
- User dengan sudo privileges

### Package Requirements
Package berikut akan diinstall otomatis:
- `openfortivpn`
- `ppp`
- `resolvconf` (untuk Debian/Ubuntu)

## 📦 Instalasi

### 1. Download Project

```bash
cd /home/rezkycodes/Development/ScriptShell/openfortivpn-installer
```

### 2. Install OpenFortiVPN (Opsional)

Jika OpenFortiVPN belum terinstall, jalankan script installer multi-distro:

```bash
bash install-package.sh
```

Script ini akan:
- ✅ Detect distro Linux Anda otomatis
- ✅ Install OpenFortiVPN sesuai package manager (apt/dnf/pacman/zypper/apk)
- ✅ Install semua dependencies yang diperlukan

**Distro yang Didukung:**
- Ubuntu / Debian / Linux Mint / Pop!_OS (apt)
- Fedora / RHEL / CentOS / Rocky / AlmaLinux (dnf/yum)
- Arch Linux / Manjaro / EndeavourOS (pacman)
- openSUSE / SLES (zypper)
- Alpine Linux (apk)
- Gentoo (portage)

### 3. Setup Konfigurasi

Copy file example dan edit dengan kredensial Anda:

```bash
cp .env.openfortivpn.example .env.openfortivpn
nano .env.openfortivpn
```

Edit file `.env.openfortivpn` dengan kredensial VPN Anda:

```bash
# Gateway Settings
VPN_HOST="vpn.example.com"
VPN_PORT="10443"

# Authentication (GANTI DENGAN KREDENSIAL ANDA)
VPN_USER="username.anda"
VPN_PASS="password.anda"

# Certificate Validation (GANTI DENGAN CERT HASH ANDA)
VPN_CERT="your_certificate_hash_here"

# Profile Name
PROFILE_NAME="myvpn"
```

> [!CAUTION]
> File `.env.openfortivpn` berisi kredensial sensitif! Jangan share atau commit ke repository.

### 4. Jalankan Installer

```bash
bash install-openfortivpn.sh
```

Script akan:
1. ✅ Install OpenFortiVPN
2. ✅ Setup konfigurasi di `/etc/openfortivpn/myvpn.conf` (sesuai PROFILE_NAME)
3. ✅ Membuat helper script di `/usr/local/bin/vpn`
4. ✅ Setup systemd service
5. ✅ Konfigurasi firewall
6. ✅ Test koneksi (opsional)

## ⚙️ Konfigurasi

### File Konfigurasi

| File | Lokasi | Deskripsi |
|------|--------|-----------||
| **Package Installer** | `install-package.sh` | Install OpenFortiVPN multi-distro |
| **Main Installer** | `install-openfortivpn.sh` | Configurator dan setup VPN |
| **Environment** | `.env.openfortivpn` | Kredensial dan konfigurasi VPN |
| **OpenFortiVPN Config** | `/etc/openfortivpn/myvpn.conf` | File konfigurasi utama (sesuai profile) |
| **Helper Script** | `/usr/local/bin/vpn` | Command untuk kontrol VPN |
| **Systemd Service** | `/etc/systemd/system/openfortivpn@.service` | Service template |
| **Log File** | `/var/log/openfortivpn.log` | File log koneksi |

### Environment Variables

```bash
VPN_HOST          # Hostname VPN gateway
VPN_PORT          # Port VPN (default: 10443)
VPN_USER          # Username VPN Anda
VPN_PASS          # Password VPN Anda
VPN_CERT          # SHA256 hash dari server certificate
PROFILE_NAME      # Nama profil (default: myvpn)
```

## 🚀 Penggunaan

Setelah instalasi, gunakan command `vpn` untuk kontrol VPN:

### Connect ke VPN

```bash
vpn start
# atau
vpn connect
```

Output:
```
🔐 Connecting to VPN...
✅ VPN Connected!

Interface Info:
  IP: 10.x.x.x/32

Connection Type:
  ✅ DTLS (UDP) - High Performance Mode
```

### Disconnect dari VPN

```bash
vpn stop
# atau
vpn disconnect
```

### Cek Status VPN

```bash
vpn status
```

Output detail termasuk:
- Status koneksi (Connected/Disconnected)
- Protocol type (DTLS/TLS)
- IP Address
- Active routes
- Gateway latency

### Restart VPN

```bash
vpn restart
```

### Lihat Logs Real-time

```bash
vpn logs
# atau
vpn log
```

Tekan `Ctrl+C` untuk keluar.

### Test Koneksi

```bash
vpn test
```

Test akan melakukan:
1. Protocol check (DTLS/TLS)
2. Latency test ke gateway
3. DNS resolution test

### Bantuan

```bash
vpn
```

## 🔄 Auto-Start saat Boot (Opsional)

### Enable Auto-start

```bash
sudo systemctl enable openfortivpn@myvpn
sudo systemctl start openfortivpn@myvpn
```

### Disable Auto-start

```bash
sudo systemctl disable openfortivpn@myvpn
sudo systemctl stop openfortivpn@myvpn
```

### Monitor Service

```bash
# Check status
sudo systemctl status openfortivpn@myvpn

# Live logs
sudo journalctl -u openfortivpn@myvpn -f
```

## 🐛 Troubleshooting

### VPN Tidak Bisa Connect

1. **Cek kredensial di `.env.openfortivpn`**
   ```bash
   cat .env.openfortivpn
   ```

2. **Cek logs untuk error**
   ```bash
   vpn logs
   # atau
   sudo tail -f /var/log/openfortivpn.log
   ```

3. **Test koneksi ke server**
   ```bash
   ping vpn.example.com
   telnet vpn.example.com 10443
   ```

4. **Cek firewall**
   ```bash
   sudo firewall-cmd --list-ports
   ```
   Pastikan port `10443/tcp` dan `10443/udp` terbuka.

### Certificate Error

Jika muncul error certificate:

```bash
# Connect sekali untuk mendapatkan certificate hash
sudo openfortivpn vpn.example.com:10443 -u username

# Copy hash yang muncul ke .env.openfortivpn
VPN_CERT="hash_yang_didapat"
```

### Port Sudah Digunakan

```bash
# Cek process yang menggunakan port
sudo ss -tulpn | grep 10443

# Kill process jika diperlukan
sudo pkill openfortivpn
```

### DNS Tidak Bekerja

Jika DNS tidak resolve setelah connect:

```bash
# Cek resolv.conf
cat /etc/resolv.conf

# Manual restart DNS
sudo systemctl restart NetworkManager
```

### Force Disconnect

Jika VPN hang atau tidak bisa disconnect normal:

```bash
# Kill semua process openfortivpn
sudo pkill -9 openfortivpn

# Hapus PID file
sudo rm -f /var/run/openfortivpn.pid

# Hapus interface ppp0
sudo ip link delete ppp0 2>/dev/null
```

## 📊 Connection Info

### DTLS vs TLS

| Protocol | Transport | Performance | Use Case |
|----------|-----------|-------------|----------|
| **DTLS** | UDP | ⚡ High | Default, best performance |
| **TLS** | TCP | 🐢 Lower | Fallback jika DTLS gagal |

Script akan **otomatis menggunakan DTLS** untuk performa terbaik. Jika DTLS tidak tersedia atau gagal, akan fallback ke TLS.

### Ports

| Port | Protocol | Purpose |
|------|----------|---------|
| 10443 | TCP | TLS connection (fallback) |
| 10443 | UDP | DTLS connection (primary) |

## ❓ FAQ

### Q: Apa itu DTLS?

**A:** Datagram Transport Layer Security (DTLS) adalah protokol yang mirip TLS tapi menggunakan UDP. Lebih cepat dan efisien untuk VPN.

### Q: Apakah bisa digunakan untuk user lain?

**A:** Ya! Cukup edit file `.env.openfortivpn` dengan kredensial user masing-masing.

### Q: Bagaimana cara mengganti password?

**A:** Edit file `.env.openfortivpn` dan update nilai `VPN_PASS`, lalu jalankan ulang installer:
```bash
bash install-openfortivpn.sh
```

### Q: Apakah kredensial aman?

**A:** File `.env.openfortivpn` sudah masuk dalam `.gitignore` dan memiliki permission `600` (hanya owner yang bisa baca). Namun tetap jaga kerahasiaan file ini.

### Q: Bagaimana cara uninstall?

**A:** 
```bash
# Stop service
sudo systemctl stop openfortivpn@myvpn
sudo systemctl disable openfortivpn@myvpn

# Hapus files
sudo rm -f /etc/openfortivpn/myvpn.conf
sudo rm -f /usr/local/bin/vpn
sudo rm -f /etc/systemd/system/openfortivpn@.service

# Uninstall package (opsional)
sudo dnf remove openfortivpn
```

### Q: VPN sering disconnect?

**A:** Gunakan systemd service untuk auto-reconnect:
```bash
sudo systemctl enable openfortivpn@myvpn
sudo systemctl start openfortivpn@myvpn
```

Service akan otomatis reconnect jika koneksi terputus.

## 📝 Catatan Penting

> [!IMPORTANT]
> - Jangan share file `.env.openfortivpn` ke orang lain
> - Ganti password secara berkala untuk keamanan
> - Backup file konfigurasi Anda

> [!WARNING]
> - Script harus dijalankan sebagai **user biasa** (bukan root)
> - Pastikan user memiliki **sudo privileges**
> - Koneksi internet diperlukan saat instalasi

## 📞 Support

Untuk bantuan lebih lanjut:
- **Email**: support@example.com
- **Developer**: RezkyCoder
- **Issues**: Laporkan bug atau request fitur

## 📄 License

Script ini dibuat untuk penggunaan umum.

---

**Happy VPN-ing!** 🎉
```
