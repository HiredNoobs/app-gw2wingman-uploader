#!/usr/bin/env bash
#
# Wingman API docs: https://gw2wingman.nevermindcreations.de/api

ARCDPS_BASE=$(basename "$ARCDPS_LOG_DIR")
WINGMAN_BASE="https://gw2wingman.nevermindcreations.de"

# -----------------------------------------------------
# Preflight checks
# -----------------------------------------------------

function check_env {
  if [[ -z "${ACCOUNT_NAME:-}" ]]; then
    echo "Account name not set." >&2
    return 1
  fi

  if [[ ! -d "$WINGMAN_UPLOADED_DIR" ]]; then
    return 1
  fi

  if [[ ! -d "$ARCDPS_LOG_DIR" ]]; then
    return 1
  fi

  mkdir -p "$WINGMAN_UPLOADED_DIR/$ARCDPS_BASE"
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
# Helper functions
# -----------------------------------------------------

# Returns:
#   0: Log not already uploaded
#   1: Log already uploaded OR file/filesize are wrong/missing
#   10: Wingman isn't accepting uploads
function check_upload {
  local file filename filesize resp http_code content

  file="$1"
  filename=$(basename "$file")
  filesize=$(stat --printf="%s" "$file")

  resp=$(curl -s -X POST -w "%{http_code}" "$WINGMAN_BASE/checkUpload" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    --data "file=$filename&filesize=$filesize&account=$ACCOUNT_NAME")

  http_code="${resp: -3}"
  content="${resp::-3}"

  if [[ "$content" == "Error" ]]; then
    echo "Error: Wingman not currently accepting uploads." >&2
    return 10
  elif [[ "$content" == "False" ]]; then
    echo "Log already uploaded or 'file'/'filesize' is incorrect or missing." >&2
    return 1
  fi

  return 0
}

# -----------------------------------------------------
# Parsing and uploading
# -----------------------------------------------------

function process_file {
  local file relpath uploaded_mem status

  file="$1"

  case "$file" in
    *.evtc|*.evtc.zip|*.zevtc) ;;
    *) return 0 ;;
  esac

  relpath="${file#"$ARCDPS_LOG_DIR/"}"
  uploaded_mem="$WINGMAN_UPLOADED_DIR/$ARCDPS_BASE/${relpath%.*}"

  [[ -f "$uploaded_mem.mem" || -f "$uploaded_mem.err" ]] && return 0

  echo "Uploading: $file" >&2
  if upload_file "$file"; then
    echo "File successfully uploaded." >&2

    mkdir -p "$(dirname "$uploaded_mem")"
    touch "$uploaded_mem.mem"
    rm -f "$uploaded_mem.retry"

    return 0
  else
    status=$?
    if [[ $status == 1 ]]; then
      echo "Failed to parse $file." >&2

      mkdir -p "$(dirname "$uploaded_mem")"
      touch "$uploaded_mem.err"
      rm -f "$uploaded_mem.retry"
    elif [[ $status == 2 ]]; then
      echo "Failed to upload $file."

      mkdir -p "$(dirname "$uploaded_mem")"
      touch "$uploaded_mem.retry"
    fi
    return $status
  fi
}

# Returns:
#   0: File uploaded or already uploaded
#   1: Failed to parse log
#   2: Failed to upload log
#   10: Wingman not accepting logs
function upload_file {
  local log_file resp status parser_out
  
  log_file="$1"

  if ! check_upload "$log_file"; then
    status=$?
    [[ $status == 1 ]] && return 0
    return $status
  fi

  parser_out=$(/opt/gw2-ei-parser/GuildWars2EliteInsights-CLI -c "/etc/gw2-ei-parser/parser.conf" "$log_file")
  [[ "$parser_out" =~ ^Parsing[[:space:]]+Failure ]] && return 1

  check_upload "$log_file"
  status=$?
  [[ $status == 0 ]] && return 2
  [[ $status == 1 ]] && return 0
  return $status
}

# -----------------------------------------------------
# File handlers
# -----------------------------------------------------

function initial_upload {
  echo "Checking for old logs." >&2

  local file lastscan_file status

  if [[ "$IGNORE_OLD_LOGS" == "true" ]]; then
    lastscan_file="$WINGMAN_UPLOADED_DIR/.lastscan"

    if [[ ! -f "$lastscan_file" ]]; then
      echo "No previous scan timestamp found; scanning all logs." >&2
      touch -d "2012-08-28" "$lastscan_file"
    fi

    while IFS= read -r -d '' file; do
      process_file "$file"
      status=$?
      if [[ $status == 10 ]]; then
        return $status
      fi
    done < <(
      find "$ARCDPS_LOG_DIR" -type f -newer "$lastscan_file" \
        \( -name "*.evtc" -o -name "*.evtc.zip" -o -name "*.zevtc" \) -print0)

    touch "$lastscan_file"
  else
    while IFS= read -r -d '' file; do
      process_file "$file"
      status=$?
      if [[ $status == 10 ]]; then
        return $status
      fi
    done < <(
      find "$ARCDPS_LOG_DIR" -type f \
        \( -name "*.evtc" -o -name "*.evtc.zip" -o -name "*.zevtc" \) -print0)
  fi

  return 0
}

function retry_uploads {
  local retry_file log_file status base relpath freq

  freq="${RETRY_FREQUENCY:-60}"

  echo "Starting retry loop." >&2
  while true; do
    find "$WINGMAN_UPLOADED_DIR/$ARCDPS_BASE" -type f -name "*.retry" -mmin +5 | while read -r retry_file; do
      base="${retry_file%.retry}"
      relpath="${base#"$WINGMAN_UPLOADED_DIR/$ARCDPS_BASE/"}"
      log_file="$ARCDPS_LOG_DIR/$relpath"

      if [[ -f "$log_file.evtc" ]]; then
        log_file="$log_file.evtc"
      elif [[ -f "$log_file.evtc.zip" ]]; then
        log_file="$log_file.evtc.zip"
      elif [[ -f "$log_file.zevtc" ]]; then
        log_file="$log_file.zevtc"
      else
        echo "Couldn't find original file for $retry_file." >&2
        rm -f "$retry_file"
        continue
      fi

      echo "Retrying upload of $log_file." >&2
      if process_file "$log_file"; then
        rm -f "$retry_file"
        touch "$base.mem"
      fi
    done
    sleep "$freq"
  done
}

function upload_new {
  local file status

  echo "Starting main loop." >&2
  inotifywait -m -r -e create,moved_to,close_write --format '%w%f' "$ARCDPS_LOG_DIR" |
  while read -r file; do
    process_file "$file"
    status=$?
    if [[ $status == 10 ]]; then
      return $status
    fi
  done
}

# -----------------------------------------------------
# Main
# -----------------------------------------------------

if ! check_env; then exit $?; fi
if ! check_connection; then exit $?; fi
if ! initial_upload; then exit $?; fi

if [[ "$RETRY_FAILED_UPLOADS" == "true" ]]; then
  retry_uploads &
  RETRY_PID=$!
  if ! upload_new; then
    STATUS=$?
    kill "$RETRY_PID"
    exit $STATUS
  fi
else
  if ! upload_new; then exit $?; fi
fi
