#!/usr/bin/env bash

set -e

THIS=$(realpath "$0")
HERE=$(dirname "$THIS")
ROOT=$(realpath "$HERE/..")

source "$ROOT/conf/installer.env"

sudo systemctl stop wingman-uploader.service >/dev/null 2>&1 || true

# -----------------------------------------------------
# Detect distro
# -----------------------------------------------------

if command -v apt-get >/dev/null 2>&1; then
  DISTRO="debian"
elif command -v pacman >/dev/null 2>&1; then
  DISTRO="arch"
else
  echo "Unsupported distro. Requires Debian/Ubuntu or Arch-based." >&2
  exit 1
fi

# -----------------------------------------------------
# Install dependencies
# -----------------------------------------------------

echo "Installing dependencies..." >&2

if [[ "$DISTRO" == "debian" ]]; then
  wget https://packages.microsoft.com/config/debian/13/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
  sudo dpkg -i packages-microsoft-prod.deb
  rm packages-microsoft-prod.deb

  sudo apt-get update
  sudo apt-get install -y \
    curl \
    unzip \
    inotify-tools \
    dotnet-sdk-8.0 \
    libicu72
elif [[ "$DISTRO" == "arch" ]]; then
  sudo pacman -S --noconfirm \
    curl \
    unzip \
    inotify-tools \
    icu \
    dotnet-sdk
fi

# -----------------------------------------------------
# Build Elite Insights CLI
# -----------------------------------------------------

echo "Building Elite Insights CLI..." >&2

LATEST_TAG=$(curl -fsSL https://api.github.com/repos/baaron4/GW2-Elite-Insights-Parser/releases/latest | grep '"tag_name":' | cut -d'"' -f4)

cd /tmp
curl -fsSL -o EI.zip "https://github.com/baaron4/GW2-Elite-Insights-Parser/archive/refs/tags/$LATEST_TAG.zip"

unzip -o -q EI.zip
cd GW2-Elite-Insights-Parser-3.20.0.0/GW2EIParserCLI

dotnet build -c Release --self-contained --runtime linux-x64 -o out

sudo mkdir -p /opt/gw2-ei-parser
sudo rm -rf /opt/gw2-ei-parser/*  # Delete any old files...
sudo cp -r out/* /opt/gw2-ei-parser/

# -----------------------------------------------------
# Install uploader
# -----------------------------------------------------

echo "Installing wingman uploader..." >&2

sudo mkdir -p /opt/scripts /etc/gw2-ei-parser

sudo cp "$HERE/wingman_uploader.sh" /opt/scripts/
sudo cp "$ROOT/conf/parser.conf" /etc/gw2-ei-parser/

# -----------------------------------------------------
# Systemd service
# -----------------------------------------------------

if [[ "${CREATE_SYSTEMD_SERVICE:-}" == "false" ]]; then
  echo "Skipping creation of Systemd service." >&2
  return 0
fi

sudo tee /etc/systemd/system/wingman-uploader.service >/dev/null <<EOF
[Unit]
Description=GW2 Wingman Uploader
StartLimitIntervalSec=300
StartLimitBurst=5
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/opt/scripts/wingman_uploader.sh
Environment=ACCOUNT_NAME=$ACCOUNT_NAME
Environment=ARCDPS_LOG_DIR=$ARCDPS_LOG_DIR
Environment=WINGMAN_UPLOADED_DIR=$WINGMAN_UPLOADED_DIR
Environment=IGNORE_OLD_LOGS=$IGNORE_OLD_LOGS
Environment=RETRY_FAILED_UPLOADS=$RETRY_FAILED_UPLOADS
Environment=RETRY_FREQUENCY=$RETRY_FREQUENCY
Environment=MAX_RETRIES=$MAX_RETRIES
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

SERVICE_EXISTS=false
if systemctl list-unit-files | grep -q '^wingman-uploader.service'; then
  SERVICE_EXISTS=true
fi

sudo systemctl daemon-reload

if $SERVICE_EXISTS; then
  echo "Restarting existing service..." >&2
  sudo systemctl restart wingman-uploader.service
else
  if [ "${WINGMAN_SERVICE_ENABLED:-}" == "true" ]; then
    echo "Enabling and starting service for the first time..." >&2
    sudo systemctl enable --now wingman-uploader.service
  else
    echo "Uploader not enabled by default. Uploader service ready to start." >&2
  fi
fi
