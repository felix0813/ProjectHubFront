#!/usr/bin/env bash
set -euo pipefail

PORT=8001
APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_NAME="projecthub-front"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

if ! command -v node >/dev/null 2>&1; then
  echo "Error: node is required." >&2
  exit 1
fi

if ! command -v npm >/dev/null 2>&1; then
  echo "Error: npm is required." >&2
  exit 1
fi

cd "$APP_DIR"

npm install
npm run build

if [[ ! -x "$APP_DIR/node_modules/.bin/serve" ]]; then
  npm install --save-dev serve
fi

CURRENT_USER="$(id -un)"
if [[ $EUID -ne 0 ]]; then
  SUDO="sudo"
else
  SUDO=""
fi

$SUDO tee "$SERVICE_FILE" >/dev/null <<SERVICE_EOF
[Unit]
Description=ProjectHub Frontend (static)
After=network.target

[Service]
Type=simple
User=$CURRENT_USER
WorkingDirectory=$APP_DIR
ExecStart=$APP_DIR/node_modules/.bin/serve -s dist -l $PORT
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
SERVICE_EOF

$SUDO systemctl daemon-reload
$SUDO systemctl enable "$SERVICE_NAME"
$SUDO systemctl restart "$SERVICE_NAME"

echo "ProjectHub frontend installed and started."
echo "Service name: $SERVICE_NAME"
echo "Port: $PORT"
