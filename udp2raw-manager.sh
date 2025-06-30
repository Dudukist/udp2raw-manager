#!/bin/bash

set -e

SERVICE_NAME="udp2raw"
BIN_NAME="udp2raw"
INSTALL_DIR="/usr/local/bin"
SERVICE_PATH="/etc/systemd/system/${SERVICE_NAME}.service"
DOWNLOAD_URL="https://github.com/wangyu-/udp2raw-tunnel/releases/download/20200715.0/udp2raw_binaries.tar.gz"

function install_udp2raw() {
  echo "⏬ Downloading udp2raw..."
  cd /tmp
  wget -O udp2raw.tar.gz "$DOWNLOAD_URL"
  tar -xzf udp2raw.tar.gz

  mv udp2raw_amd64 "$INSTALL_DIR/$BIN_NAME"
  chmod +x "$INSTALL_DIR/$BIN_NAME"
  echo "✅ Binary installed at $INSTALL_DIR/$BIN_NAME"

  read -p "Mode? (server/client): " MODE
  if [[ "$MODE" != "server" && "$MODE" != "client" ]]; then
    echo "❌ Invalid mode. Choose 'server' or 'client'."
    exit 1
  fi

  read -p "Local port (e.g. 4096): " LOCAL_PORT
  read -p "Remote port (e.g. 22 for SSH): " REMOTE_PORT
  read -p "Password: " PASSWORD

  if [[ "$MODE" == "client" ]]; then
    read -p "Server IP: " SERVER_IP
  fi

  echo "🛠 Creating systemd service..."

  if [[ "$MODE" == "server" ]]; then
    cat <<EOF | sudo tee "$SERVICE_PATH"
[Unit]
Description=udp2raw Server
After=network.target

[Service]
ExecStart=$INSTALL_DIR/$BIN_NAME -s -l0.0.0.0:$LOCAL_PORT -r127.0.0.1:$REMOTE_PORT -k "$PASSWORD" --raw-mode faketcp
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

  else
    cat <<EOF | sudo tee "$SERVICE_PATH"
[Unit]
Description=udp2raw Client
After=network.target

[Service]
ExecStart=$INSTALL_DIR/$BIN_NAME -c -l127.0.0.1:$LOCAL_PORT -r$SERVER_IP:$LOCAL_PORT -k "$PASSWORD" --raw-mode faketcp
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
  fi

  echo "✅ Enabling and starting service..."
  sudo systemctl daemon-reexec
  sudo systemctl daemon-reload
  sudo systemctl enable $SERVICE_NAME
  sudo systemctl restart $SERVICE_NAME
  sudo systemctl status $SERVICE_NAME --no-pager
  echo "🎉 Installation and setup completed."
}

function uninstall_udp2raw() {
  echo "🗑 Removing service and binary..."

  sudo systemctl stop $SERVICE_NAME || true
  sudo systemctl disable $SERVICE_NAME || true
  sudo rm -f "$SERVICE_PATH"
  sudo rm -f "$INSTALL_DIR/$BIN_NAME"

  sudo systemctl daemon-reexec
  sudo systemctl daemon-reload
  echo "✅ udp2raw successfully removed."
}

echo "----- udp2raw Install or Uninstall -----"
read -p "Choose action (install/uninstall): " ACTION

case "$ACTION" in
  install)
    install_udp2raw
    ;;
  uninstall)
    uninstall_udp2raw
    ;;
  *)
    echo "❌ Invalid option. Use 'install' or 'uninstall'."
    exit 1
    ;;
esac
