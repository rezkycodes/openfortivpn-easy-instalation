#!/bin/bash

#############################################
# OpenFortiVPN Auto Installer & Configurator
# Untuk: Universal Usage
# Author: RezkyCoder
# Date: $(date +%Y-%m-%d)
#############################################

set -e

# Warna untuk output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fungsi helper
print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_header() {
    echo -e "${BLUE}"
    echo "=================================================="
    echo "$1"
    echo "=================================================="
    echo -e "${NC}"
}

# Cek apakah dijalankan sebagai root
if [[ $EUID -eq 0 ]]; then
   print_error "Script ini TIDAK boleh dijalankan sebagai root"
   echo "Jalankan sebagai user biasa: bash $0"
   exit 1
fi

# Load konfigurasi VPN dari file .env
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env.openfortivpn"

if [[ ! -f "$ENV_FILE" ]]; then
    print_error "File konfigurasi tidak ditemukan: $ENV_FILE"
    echo ""
    echo "Buat file .env.openfortivpn dengan format:"
    echo "VPN_HOST=\"vpn.example.com\""
    echo "VPN_PORT=\"10443\""
    echo "VPN_USER=\"username\""
    echo "VPN_PASS=\"password\""
    echo "VPN_CERT=\"certificate_hash\""
    echo "PROFILE_NAME=\"myvpn\""
    exit 1
fi

print_info "Loading konfigurasi dari: $ENV_FILE"
source "$ENV_FILE"

# Validasi konfigurasi yang diperlukan
REQUIRED_VARS=("VPN_HOST" "VPN_PORT" "VPN_USER" "VPN_PASS" "VPN_CERT" "PROFILE_NAME")
for var in "${REQUIRED_VARS[@]}"; do
    if [[ -z "${!var}" ]]; then
        print_error "Variabel $var tidak ditemukan di $ENV_FILE"
        exit 1
    fi
done

CONFIG_DIR="/etc/openfortivpn"
CONFIG_FILE="$CONFIG_DIR/$PROFILE_NAME.conf"
LOG_FILE="/var/log/openfortivpn.log"
SCRIPT_PATH="/usr/local/bin/vpn"
SERVICE_NAME="openfortivpn@$PROFILE_NAME"

# Banner
clear
print_header "OpenFortiVPN Auto Installer"
echo ""
print_info "Konfigurasi VPN:"
echo "  Gateway: $VPN_HOST:$VPN_PORT"
echo "  User: $VPN_USER"
echo "  DTLS: Enabled (Auto)"
echo ""

read -p "Lanjutkan instalasi? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_warning "Instalasi dibatalkan"
    exit 0
fi

# 1. Update sistem dan install dependencies
print_header "Step 1: Install OpenFortiVPN"

if command -v openfortivpn &> /dev/null; then
    print_success "OpenFortiVPN sudah terinstall"
    openfortivpn --version
else
    print_info "Installing OpenFortiVPN..."
    sudo dnf install -y openfortivpn ppp
    print_success "OpenFortiVPN berhasil diinstall"
fi

# 2. Buat direktori konfigurasi
print_header "Step 2: Setup Konfigurasi"

sudo mkdir -p "$CONFIG_DIR"
print_success "Direktori config dibuat: $CONFIG_DIR"

# 3. Buat file konfigurasi
print_info "Membuat file konfigurasi VPN..."

sudo tee "$CONFIG_FILE" > /dev/null <<EOF
# ============================================================
# OpenFortiVPN Configuration File
# Generated: $(date)
# ============================================================

# Gateway Settings
host = $VPN_HOST
port = $VPN_PORT

# Authentication Credentials
username = $VPN_USER
password = $VPN_PASS

# Certificate Validation (SHA256 Fingerprint)
trusted-cert = $VPN_CERT

# DNS Configuration
set-dns = 1
pppd-use-peerdns = 1

# Logging Configuration
pppd-log = $LOG_FILE
use-syslog = 1

# Connection Settings
persistent = 0
half-internet-routes = 0

# PPP Settings
pppd-accept-remote = 1

# ============================================================
# Performance Notes:
# - DTLS (UDP) is used automatically for best performance
# - Automatic fallback to TLS (TCP) if DTLS unavailable
# - No manual DTLS configuration needed
# ============================================================
EOF

# Set permission agar aman
sudo chmod 600 "$CONFIG_FILE"
print_success "File konfigurasi dibuat: $CONFIG_FILE"

# 4. Setup log file
sudo touch "$LOG_FILE"
sudo chmod 644 "$LOG_FILE"
print_success "Log file dibuat: $LOG_FILE"

# 5. Buat helper script
print_header "Step 3: Setup Helper Script"

# Buat header script dengan variabel yang diexpand
sudo tee "$SCRIPT_PATH" > /dev/null <<EOF
#!/bin/bash

CONFIG_FILE="/etc/openfortivpn/${PROFILE_NAME}.conf"
LOG_FILE="/var/log/openfortivpn.log"
PID_FILE="/var/run/openfortivpn.pid"
EOF

# Append sisa script (tanpa expand variabel)
sudo tee -a "$SCRIPT_PATH" > /dev/null <<'SCRIPT_EOF'

# Warna
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

start_vpn() {
    if [ -f "$PID_FILE" ]; then
        echo -e "${RED}❌ VPN sudah running (PID: $(cat $PID_FILE))${NC}"
        echo "Gunakan: vpn stop"
        exit 1
    fi
    
    echo -e "${BLUE}🔐 Connecting to VPN...${NC}"
    sudo openfortivpn -c "$CONFIG_FILE" > /dev/null 2>&1 &
    echo $! | sudo tee "$PID_FILE" > /dev/null
    
    # Tunggu koneksi establish
    sleep 5
    
    if ip addr show ppp0 &>/dev/null; then
        echo -e "${GREEN}✅ VPN Connected!${NC}"
        echo ""
        echo "Interface Info:"
        ip addr show ppp0 | grep "inet " | awk '{print "  IP: " $2}'
        echo ""
        
        # Cek tipe koneksi
        echo "Connection Type:"
        if sudo ss -anup 2>/dev/null | grep -q "openfortivpn"; then
            echo -e "  ${GREEN}✅ DTLS (UDP) - High Performance Mode${NC}"
        elif sudo ss -antp 2>/dev/null | grep -q "openfortivpn"; then
            echo -e "  ${YELLOW}⚠️  TLS (TCP) - Fallback Mode${NC}"
        fi
    else
        echo -e "${RED}❌ VPN Connection Failed${NC}"
        echo "Check logs: sudo tail -f $LOG_FILE"
        [ -f "$PID_FILE" ] && sudo rm -f "$PID_FILE"
        exit 1
    fi
}

stop_vpn() {
    if [ ! -f "$PID_FILE" ]; then
        echo -e "${RED}❌ VPN tidak running${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}🔌 Disconnecting VPN...${NC}"
    PID=$(cat "$PID_FILE")
    sudo kill "$PID" 2>/dev/null || sudo pkill openfortivpn
    sudo rm -f "$PID_FILE"
    
    # Tunggu sebentar
    sleep 2
    
    if ! ip addr show ppp0 &>/dev/null; then
        echo -e "${GREEN}✅ VPN Disconnected${NC}"
    else
        echo -e "${YELLOW}⚠️  Interface masih ada, mencoba force disconnect...${NC}"
        sudo pkill -9 openfortivpn
        sleep 1
        echo -e "${GREEN}✅ VPN Disconnected (forced)${NC}"
    fi
}

status_vpn() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}        VPN Status${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    if [ -f "$PID_FILE" ] && ps -p $(cat "$PID_FILE") > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Status: Connected${NC}"
        echo "   PID: $(cat $PID_FILE)"
        echo ""
        
        # Connection Type
        echo "📡 Connection Type:"
        if sudo ss -anup 2>/dev/null | grep -q "openfortivpn"; then
            echo -e "   ${GREEN}✅ DTLS (UDP) - High Performance${NC}"
            echo "   Protocol: User Datagram Protocol"
            sudo ss -anup | grep openfortivpn | awk '{print "   Remote: " $6}' | head -1
        elif sudo ss -antp 2>/dev/null | grep -q "openfortivpn"; then
            echo -e "   ${YELLOW}⚠️  TLS (TCP) - Fallback Mode${NC}"
            echo "   Protocol: Transmission Control Protocol"
            sudo ss -antp | grep openfortivpn | awk '{print "   Remote: " $5}' | head -1
        else
            echo -e "   ${RED}❓ Cannot determine${NC}"
        fi
        
        # Interface Info
        if ip addr show ppp0 &>/dev/null; then
            echo ""
            echo "🔗 Interface ppp0:"
            ip addr show ppp0 | grep "inet " | awk '{print "   IP Address: " $2}'
            ip addr show ppp0 | grep "peer" | awk '{print "   Peer: " $4}'
            
            # Routes
            echo ""
            echo "🛣️  Active Routes (showing first 5):"
            ip route | grep ppp0 | head -5 | while read line; do
                echo "   → $line"
            done
            
            # Gateway test
            GATEWAY=$(ip route | grep ppp0 | grep default | awk '{print $3}')
            if [ -n "$GATEWAY" ]; then
                echo ""
                echo "🏓 Gateway Latency:"
                ping -c 3 -W 2 "$GATEWAY" 2>/dev/null | tail -1 | awk '{print "   " $0}' || echo "   Cannot reach gateway"
            fi
        fi
    else
        echo -e "${RED}❌ Status: Disconnected${NC}"
        [ -f "$PID_FILE" ] && sudo rm -f "$PID_FILE"
    fi
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

logs_vpn() {
    if [ -f "$LOG_FILE" ]; then
        echo -e "${BLUE}📋 VPN Logs (Ctrl+C to exit):${NC}"
        echo ""
        sudo tail -f "$LOG_FILE"
    else
        echo -e "${RED}❌ Log file not found: $LOG_FILE${NC}"
    fi
}

test_vpn() {
    echo -e "${BLUE}🧪 Testing VPN Connection...${NC}"
    echo ""
    
    if ! ip addr show ppp0 &>/dev/null; then
        echo -e "${RED}❌ VPN not connected${NC}"
        exit 1
    fi
    
    # Protocol test
    echo "1. Protocol Check:"
    if sudo ss -anup 2>/dev/null | grep -q "openfortivpn"; then
        echo -e "   ${GREEN}✅ DTLS (UDP) Active${NC}"
    elif sudo ss -antp 2>/dev/null | grep -q "openfortivpn"; then
        echo -e "   ${YELLOW}⚠️  TLS (TCP) Active${NC}"
    fi
    
    # Latency test
    echo ""
    echo "2. Latency Test:"
    GATEWAY=$(ip route | grep ppp0 | grep default | awk '{print $3}')
    if [ -n "$GATEWAY" ]; then
        ping -c 5 "$GATEWAY" 2>/dev/null | tail -2
    else
        echo "   Gateway not found"
    fi
    
    # DNS test
    echo ""
    echo "3. DNS Resolution:"
    if nslookup google.com &>/dev/null; then
        echo -e "   ${GREEN}✅ DNS Working${NC}"
    else
        echo -e "   ${RED}❌ DNS Failed${NC}"
    fi
    
    echo ""
    echo -e "${GREEN}Test completed${NC}"
}

case "$1" in
    start|connect)
        start_vpn
        ;;
    stop|disconnect)
        stop_vpn
        ;;
    status)
        status_vpn
        ;;
    restart)
        echo "Restarting VPN..."
        stop_vpn
        sleep 2
        start_vpn
        ;;
    logs|log)
        logs_vpn
        ;;
    test)
        test_vpn
        ;;
    *)
        echo "Usage: vpn {start|stop|status|restart|logs|test}"
        echo ""
        echo "Commands:"
        echo "  start/connect    - Connect to VPN"
        echo "  stop/disconnect  - Disconnect from VPN"
        echo "  status          - Show detailed VPN status"
        echo "  restart         - Restart VPN connection"
        echo "  logs/log        - Show live logs"
        echo "  test            - Test VPN connection"
        exit 1
        ;;
esac
SCRIPT_EOF

sudo chmod +x "$SCRIPT_PATH"
print_success "Helper script dibuat: $SCRIPT_PATH"

# 6. Setup systemd service
print_header "Step 4: Setup Systemd Service"

sudo tee "/etc/systemd/system/openfortivpn@.service" > /dev/null <<EOF
[Unit]
Description=OpenFortiVPN - %i
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/bin/openfortivpn -c /etc/openfortivpn/%i.conf
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
print_success "Systemd service dibuat"

# 7. Setup firewall
print_header "Step 5: Configure Firewall"

if command -v firewall-cmd &> /dev/null; then
    print_info "Membuka port UDP 10443 untuk DTLS..."
    sudo firewall-cmd --permanent --add-port=10443/udp
    sudo firewall-cmd --permanent --add-port=10443/tcp
    sudo firewall-cmd --reload
    print_success "Firewall dikonfigurasi"
else
    print_warning "firewalld tidak aktif, skip firewall config"
fi

# 8. Test koneksi
print_header "Step 6: Test Connection"

read -p "Test koneksi VPN sekarang? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_info "Testing VPN connection..."
    echo ""
    
    # Test connect
    sudo -u $SUDO_USER $SCRIPT_PATH start
    
    sleep 3
    
    # Show status
    echo ""
    sudo -u $SUDO_USER $SCRIPT_PATH status
    
    echo ""
    read -p "Disconnect sekarang? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo -u $SUDO_USER $SCRIPT_PATH stop
    fi
fi

# 9. Summary
print_header "Installation Complete!"

echo ""
print_success "OpenFortiVPN berhasil diinstall dan dikonfigurasi!"
echo ""
echo "📝 Informasi Konfigurasi:"
echo "  Config File: $CONFIG_FILE"
echo "  Log File: $LOG_FILE"
echo "  Helper Script: $SCRIPT_PATH"
echo ""
echo "🚀 Cara Menggunakan:"
echo "  vpn start      - Connect ke VPN"
echo "  vpn stop       - Disconnect dari VPN"
echo "  vpn status     - Lihat status VPN"
echo "  vpn restart    - Restart VPN"
echo "  vpn logs       - Lihat logs real-time"
echo "  vpn test       - Test koneksi VPN"
echo ""
echo "🔄 Auto-start saat boot (opsional):"
echo "  sudo systemctl enable $SERVICE_NAME"
echo "  sudo systemctl start $SERVICE_NAME"
echo ""
echo "📊 Monitor service:"
echo "  sudo systemctl status $SERVICE_NAME"
echo "  sudo journalctl -u $SERVICE_NAME -f"
echo ""
print_info "DTLS (UDP) akan digunakan secara otomatis untuk performa optimal"
print_info "Jika DTLS gagal, akan otomatis fallback ke TLS (TCP)"
echo ""
print_success "Happy VPN-ing! 🎉"
echo ""
