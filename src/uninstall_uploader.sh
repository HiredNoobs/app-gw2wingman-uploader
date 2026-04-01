#!/usr/bin/env bash

set -e

# -----------------------------------------------------
# Systemd service
# -----------------------------------------------------

echo "Stopping and removing service..." >&2

sudo systemctl stop wingman-uploader.service 2>/dev/null || true
sudo systemctl disable wingman-uploader.service 2>/dev/null || true
sudo rm -f /etc/systemd/system/wingman-uploader.service
sudo systemctl daemon-reload

# -----------------------------------------------------
# Remove installed files
# -----------------------------------------------------

echo "Removing Elite Insights parser and uploader..." >&2

sudo rm -rf /opt/GW2EIParser 2>/dev/null || true
sudo rm -f /opt/scripts/wingman_uploader.sh 2>/dev/null || true

if [ -d /opt/scripts ] && [ -z "$(ls -A /opt/scripts)" ]; then
  echo "/opt/scripts is empty, removing directory..." >&2
  sudo rmdir /opt/scripts
fi

sudo rm -f /etc/GW2EIParser/parser.conf 2>/dev/null || true

if [ -d /etc/GW2EIParser ] && [ -z "$(ls -A /etc/GW2EIParser)" ]; then
  echo "/etc/GW2EIParser is empty, removing directory..." >&2
  sudo rmdir /etc/GW2EIParser
fi

echo "Wingman uploader removed."
echo "Dependencies were NOT removed."
echo "Please remove any unwanted dependencies manually."
