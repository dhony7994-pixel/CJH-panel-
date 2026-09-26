#!/bin/bash

# Ensure script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run as root (sudo)."
  exit 1
fi

echo "=========================================="
echo "      Installing CJH Control Panel        "
echo "=========================================="

# 1. System packages install
apt update && apt upgrade -y
apt install -y python3 python3-pip python3-venv qemu-system-x86 qemu-utils libvirt-daemon-system libvirt-clients virtinst bridge-utils curl iptables-persistent

# 2. Directory & Virtual Environment setup
mkdir -p /opt/cjh-panel/templates
cd /opt/cjh-panel

python3 -m venv venv
source venv/bin/activate
pip install flask werkzeug requests

# 3. Download panel files from your GitHub repository
# (Yahan [YOUR-GITHUB-USERNAME] ki jagah apna username dalein)
REPO_URL="https://raw.githubusercontent.com/[YOUR-GITHUB-USERNAME]/cjh-panel/main"

curl -fsSL "$REPO_URL/app.py" -o /opt/cjh-panel/app.py
curl -fsSL "$REPO_URL/templates/index.html" -o /opt/cjh-panel/templates/index.html

# 4. Open Port 5000 in Firewall
iptables -A INPUT -p tcp --dport 5000 -j ACCEPT
iptables -A INPUT -p tcp --dport 22 -j ACCEPT
netfilter-persistent save

# 5. Create Systemd Service for CJH Panel
cat <<EOF > /etc/systemd/system/cjh-panel.service
[Unit]
Description=CJH Bot & VPS Panel Service
After=network.target libvirtd.service

[Service]
User=root
WorkingDirectory=/opt/cjh-panel
ExecStart=/opt/cjh-panel/venv/bin/python3 /opt/cjh-panel/app.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# 6. Start Services
systemctl daemon-reload
systemctl enable libvirtd
systemctl start libvirtd
systemctl enable cjh-panel
systemctl start cjh-panel

SERVER_IP=$(curl -s ifconfig.me)

echo "=========================================="
echo "    CJH PANEL INSTALLED SUCCESSFULLY!     "
echo "=========================================="
echo "Access Panel at: http://${SERVER_IP}:5000"
echo "First launch par Admin Account banane ka option aayega."
