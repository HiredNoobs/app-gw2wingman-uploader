#!/usr/bin/env bash
#
# Wingman API docs: https://gw2wingman.nevermindcreations.de/api

ARCDPS_LOG_DIR="/var/lib/gw2logs/arcdps.cbtlogs"

WINGMAN_BASE="https://gw2wingman.nevermindcreations.de"
WINGMAN_UPLOADED_DIR="/var/lib/gw2logs/.wingmanUploaded/arcdps.cbtlogs"

# -----------------------------------------------------
# Preflight checks
# -----------------------------------------------------

function check_env {
  if [ -z "${ACCOUNT_NAME:-}" ]; then
    echo "Account name not set." >&2
    return 1
  fi

  if [ ! -d "$WINGMAN_UPLOADED_DIR" ]; then
    return 1
  fi
}

function check_connection {
  local resp http_code content
  resp=$(curl -s -w "%{http_code}" "$WINGMAN_BASE/testConnection")
  http_code="${resp: -3}"
  content="${resp::-3}"

  if [[ "$http_code" != "200" || "$content" != "True" ]]; then
    echo "Error: Connection to wingman unsuccessful." >&2
    return 1
  fi
}

# -----------------------------------------------------
# File handlers
# -----------------------------------------------------

function process_file {
  local file relpath uploaded_mem
  
  file="$1"

  case "$file" in
    *.evtc|*.evtc.zip|*.zevtc) ;;
    *) return 0 ;;
  esac

  relpath="${file#"$ARCDPS_LOG_DIR/"}"
  uploaded_mem="$WINGMAN_UPLOADED_DIR/${relpath%.*}.mem"

  [[ -f "$uploaded_mem" ]] && return 0

  echo "Uploading: $file" >&2
  if upload_file "$file"; then
    echo "File successfully uploaded." >&2
    mkdir -p "$(dirname "$uploaded_mem")"
    touch "$uploaded_mem"
  fi
}

function upload_file {
  local file filename filesize resp http_code content

  file="$1"
  filename=$(basename "$file")
  filesize=$(stat --printf="%s" "$file")

  resp=$(curl -s -X POST "$WINGMAN_BASE/checkUpload" -H "Content-Type: application/x-www-form-urlencoded" --data "file=$filename&filesize=$filesize&account=$ACCOUNT_NAME")
  http_code="${resp: -3}"
  content="${resp::-3}"

  if [ "$content" == "Error" ]; then
    echo "Error: Wingman not accepting uploads currently." >&2
    return 1
  elif [ "$content" == "False" ]; then
    echo "Log already uploaded or 'file'/'filesize' is incorrect or missing." >&2
    return 1
  fi

  /opt/GW2EIParser/GuildWars2EliteInsights-CLI -c "/etc/GW2EIParser/parser.conf" "$file"

  # Is it safe to assume GW2EI-CLI returns a sensible value?
  # If not will need to upload separately...
  return $?
}

# Go through all files in ARCDPS_LOG_DIR and upload those that don't
# already have a WINGMAN_IGNORE/UPLOADED_DIR entry.
function initial_upload {
  local file

  echo "Checking for old files..." >&2
  find "$ARCDPS_LOG_DIR" -type f \( -name "*.evtc" -o -name "*.evtc.zip" -o -name "*.zevtc" \) -print0 |
  while IFS= read -r -d '' file; do
    process_file "$file"
  done
}

# Wait for new files in ARCDPS_LOG_DIR and upload them.
function upload_new {
  local file

  echo "Waiting for new files..." >&2
  inotifywait -m -r -e create,moved_to,close_write --format '%w%f' "$ARCDPS_LOG_DIR" |
  while read -r file; do
    process_file "$file"
  done
}

# -----------------------------------------------------
# Main
# -----------------------------------------------------

if ! check_env; then exit $?; fi
if ! check_connection; then exit $?; fi
initial_upload
upload_new
