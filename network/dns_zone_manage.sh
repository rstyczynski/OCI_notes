#!/bin/bash

export LOG_LEVEL=info

rm -rf "$HOME"/tmp/process_record-temp*/*

#
# logging support
#

# Set default log level
: "${LOG_LEVEL:=info}"

log_level_num() {
  case "$1" in
    error) echo 0 ;;
    warning) echo 1 ;;
    info) echo 2 ;;
    debug) echo 3 ;;
    *) echo 99 ;; # Unknown level
  esac
}
export -f log_level_num

log() {
  local level=$1
  shift

  local level_num 
  local current_level_num 
  local timestamp 
  local color 
  local reset

  level_num=$(log_level_num "$level")
  current_level_num=$(log_level_num "$LOG_LEVEL")

  if (( level_num <= current_level_num )); then
    timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    reset="\033[0m"

    case "$level" in
      error)   color="\033[1;31m" ;; # bright red
      warning) color="\033[1;33m" ;; # yellow
      info)    color="\033[1;32m" ;; # green
      debug)   color="\033[0;37m" ;; # gray
      *)       color="" ;;
    esac

    echo -e "${color}[$timestamp] [$level] $*${reset}"
  fi
}
export -f log


info()    { log info "$@"; }; export -f info
warning() { log warning "$@"; }; export -f warning
debug()   { log debug "$@"; }; export -f debug
error()   { log error "$@"; }; export -f error

#
# initialize
#

initialize() {
    export base_domain=$1
    export zone_ocid=$2
    export max_retries="${3:-10}" # take $3, and set 10 when not provided

    initial_etag=$(oci dns record zone get \
    --zone-name-or-id "${zone_ocid}" \
    --all \
    --query "etag" \
    --raw-output)
}

#
# Generate records with test data
#
generate_data() {
    export record_count=$1

    test_dataset="test_rrset_dataset.tsv"
    echo -e "domain_name\trdata\trtype\tttl" > "$test_dataset"
    for i in $(seq 1 "$record_count"); do
    domain="instance_${i}.${base_domain}"
    rdata="instance-${i}.subnet.vcn.oraclevcn.com."
    rtype="CNAME"
    ttl=$RANDOM 
    echo -e "${domain}\t${rdata}\t${rtype}\t${ttl}" >> "$test_dataset"
    done 
}

generate_json_data() {
    export record_count=$1

    json_file="test_rrset_dataset.json"
    base_domain=${base_domain:-"example.com"}  # fallback if not exported

    echo "[" > "$json_file"

    for i in $(seq 1 "$record_count"); do
        domain="instance_${i}.${base_domain}"
        rdata="instance-${i}.subnet.vcn.oraclevcn.com."
        rtype="CNAME"
        ttl=$RANDOM

        # Emit valid JSON entry
        cat <<EOF >> "$json_file"
  {
    "domain": "$domain",
    "rdata": "$rdata",
    "rtype": "$rtype",
    "ttl": $ttl
  }$( [ "$i" -lt "$record_count" ] && echo "," )
EOF
    done

    echo "]" >> "$json_file"
}

#
# log error 
#
log_error() {
    local where="$1"
    local what="$2"
    local reported_status_code="$3"

    if [ "$reported_status_code" -ne 0 ]; then
      # Peek at the first line to detect error type
      error_type=$(head -n1 "$tmp_process_record/error.info" | cut -d: -f1)

      case "$error_type" in
        TransientServiceError)
          error_json=$(sed '1s/^TransientServiceError: *//' "$tmp_process_record/error.info")
          err_status=$(jq -r '.status' <<< "$error_json")
          err_msg=$(jq -rc '.message' <<< "$error_json")

          case "$err_status" in
            429)
              warning "[$where] [$what] $err_msg, code: $err_status"
              ;;
            *)
              warning "[$where] [$what] $err_msg, code: $err_status"
              ;;
          esac
          ;;

        RequestException)
          error_json=$(sed '1s/^RequestException: *//' "$tmp_process_record/error.info")
          err_msg=$(jq -r '.message' <<< "$error_json")
          warning "[$where] [$what] System error: $err_msg"
          ;;

        ServiceError)
          error_json=$(sed '1s/^ServiceError: *//' "$tmp_process_record/error.info")
          err_status=$(jq -r '.status' <<< "$error_json")
          err_msg=$(jq -rc '.message' <<< "$error_json")

          warning "[$where] [$what] Service error: $err_msg, $err_status"
          ;;

        *)
          # Unknown or malformed error
          error "[$where] [$what] Unknown error format:"
          cat "$tmp_process_record/success.info"
          cat "$tmp_process_record/error.info"
          ;;
      esac
    fi
}
export -f log_error

process_record() {
  # must be local to keep thread safe

  local domain_name="$1"
  local rdata="$2"
  local rtype="$3"
  local ttl="$4"

  items=$(cat <<EOF
[{
  "domain": "$domain_name",
  "rdata": "$rdata",
  "rtype": "$rtype",
  "ttl": $ttl
}]
EOF
)

  echo "$items"
}
export -f process_record

#
# update DNS
#
update_rrset() {
  # must be local to keep thread safe

  local domain_name="$1"
  local rtype="$2"
  local items="$3"

  debug "$domain_name" "$rtype"
  debug "$domain_name" "$items"

  local tmp_process_record
  tmp_process_record=$(mktemp -d "$HOME/tmp/process_record-temp-$domain_name-XXXXXX")
  chmod 700 "$tmp_process_record"

  local retry_count=0 
  local current_etag  

  local status_code
  local items
  local sleep_seconds

  while true; do
    info "[${domain_name}] Fetching ETag from Zone..."
    rm -f "$tmp_process_record"/error.info

    oci dns record zone get \
    --zone-name-or-id "${zone_ocid}" \
    --all \
    --query "etag" \
    --raw-output > "$tmp_process_record"/success.info 2> "$tmp_process_record"/error.info
    status_code=$?
    log_error "$domain_name" " " "$status_code"

    current_etag=$(<"$tmp_process_record/success.info")
    clean_current_etag=${current_etag//\"/}
    current_etag_num=$(echo "$clean_current_etag" | grep -oE '^[0-9]+')
    info "[$domain_name] [$current_etag_num] Fetched ETag from Zone"

    if [ $retry_count -eq 0 ]; then
      info "[$domain_name] [$current_etag_num] Attempting to update"
    else
      warning "[$domain_name] [$current_etag_num] Attempting to update (retry #$((retry_count)))"
    fi

    # Run the OCI command
    # rrset is the most atomic patch operation
    # domain may patch whole domain in one operation
    # zone may patch whole zone with multiple domains/rrsets in one operation

    case $items in
      delete)
        oci dns record rrset delete \
          --zone-name-or-id "$zone_ocid" \
          --domain "$domain_name" \
          --rtype "$rtype" \
          --force \
          --raw-output \
          --if-match "$current_etag" > "$tmp_process_record"/success.info 2> "$tmp_process_record"/error.info
        status_code=$?
        ;;
      *)
        oci dns record rrset patch \
          --zone-name-or-id "$zone_ocid" \
          --domain "$domain_name" \
          --rtype "$rtype" \
          --items "$items" \
          --raw-output \
          --if-match "$current_etag" > "$tmp_process_record"/success.info 2> "$tmp_process_record"/error.info
        status_code=$?
        ;;
    esac
    
    log_error "$domain_name" "$current_etag_num" "$status_code"
    if [ $status_code -eq 0 ]; then
      info "[$domain_name] [$current_etag_num] Success"
      break
    else
      warning "[$domain_name] [$current_etag_num] Update error"
      retry_count=$((retry_count + 1))
      if [ "$retry_count" -ge "$max_retries" ]; then
        error "[$domain_name] [$current_etag_num]Failed after $max_retries attempts"
        break
      fi
      sleep_seconds=$(python3 -c "import random; print(round(random.uniform(0.1, 5.0), 2))")
      info "[$domain_name] [$current_etag_num] Retry in ${sleep_seconds}s..."
      sleep "$sleep_seconds"
    fi
  done
}
export -f update_rrset

update_zone() {
  # must be local to keep thread safe
  local items="$1"

  local domain_name=zone

  local tmp_process_record
  tmp_process_record=$(mktemp -d "$HOME/tmp/process_record-temp-$domain_name-XXXXXX")
  chmod 700 "$tmp_process_record"

  local retry_count=0 
  local current_etag  

  local status_code
  local items
  local sleep_seconds

  while true; do
    info "[${domain_name}] Fetching ETag from Zone..."
    rm -f "$tmp_process_record"/error.info

    oci dns record zone get \
    --zone-name-or-id "${zone_ocid}" \
    --all \
    --query "etag" \
    --raw-output > "$tmp_process_record"/success.info 2> "$tmp_process_record"/error.info
    status_code=$?
    log_error $domain_name " " $status_code

    current_etag=$(<"$tmp_process_record/success.info")
    clean_current_etag=${current_etag//\"/}
    current_etag_num=$(echo "$clean_current_etag" | grep -oE '^[0-9]+')
    info "[${domain_name}] [$current_etag_num] Fetched ETag from Zone"

    if [ $retry_count -eq 0 ]; then
      info "[${domain_name}] [$current_etag_num] Attempting to update"
    else
      warning "[${domain_name}] [$current_etag_num] Attempting to update (retry #$((retry_count)))"
    fi

    # Run the OCI command
    # rrset is the most atomic patch operation
    # domain may patch whole domain in one operation
    # zone may patch whole zone with multiple domains/rrsets in one operation
    oci dns record zone patch \
      --zone-name-or-id "$zone_ocid" \
      --items "$items" \
      --raw-output \
      --if-match "$current_etag" > "$tmp_process_record"/success.info 2> "$tmp_process_record"/error.info
    status_code=$?
    log_error "$domain_name" "$current_etag_num" "$status_code"
    if [ $status_code -eq 0 ]; then
      info "[$domain_name] [$current_etag_num] Success"
      break
    else
      warning "[$domain_name] [$current_etag_num] Update error"
      retry_count=$((retry_count + 1))
      if [ "$retry_count" -ge "$max_retries" ]; then
        error "[$domain_name] [$current_etag_num] Failed after $max_retries attempts"
        break
      fi
      sleep_seconds=$(python3 -c "import random; print(round(random.uniform(0.1, 5.0), 2))")
      info "[$domain_name] [$current_etag_num] Retry in ${sleep_seconds}s..."
      sleep "$sleep_seconds"
    fi
  done
}
export -f update_zone

#
# run parallel updates
#
update_rrset_parallel() {
  parallelization="${1:-1}"

  tail -n +2 test_rrset_dataset.tsv | while IFS=$'\t' read -r domain_name rdata rtype ttl; do
  echo "$domain_name"$'\t'"$rdata"$'\t'"$rtype"$'\t'"$ttl"
  done | xargs -P "$parallelization" -n 4 bash -c 'items=$(process_record "$0" "$1" "$2" "$3"); update_rrset "$0" "$2" "$items"'

  # used verbatim name to avoid issues
  rm -rf ~/tmp/process_record-temp-*
}

delete_rrset_parallel() {
  parallelization="${1:-1}"

  tail -n +2 test_rrset_dataset.tsv | while IFS=$'\t' read -r domain_name rdata rtype ttl; do
  echo "$domain_name"$'\t'"$rdata"$'\t'"$rtype"$'\t'"$ttl"
  done | xargs -P "$parallelization" -n 4 bash -c 'update_rrset "$0" "$2" "delete"'

  # used verbatim name to avoid issues
  rm -rf ~/tmp/process_record-temp-*
}

#
# summarize
#
summarize() {
  # Get the final etag from OCI
  final_etag=$(oci dns record zone get \
    --zone-name-or-id "${zone_ocid}" \
    --all \
    --query "etag" \
    --raw-output)

  # Strip quotes and extract numeric prefixes
  clean_initial_etag=${initial_etag//\"/}
  clean_final_etag=${final_etag//\"/}

  initial_num=$(echo "$clean_initial_etag" | grep -oE '^[0-9]+')
  final_num=$(echo "$clean_final_etag" | grep -oE '^[0-9]+')

  debug "Initial etag: $initial_etag"
  debug "Final etag:   $final_etag"

  # Validate extracted numbers
  if [[ -z "$initial_num" || -z "$final_num" ]]; then
    error "ERROR: Could not extract numeric part of etag."
    return 1
  fi

  # Zones serial no get incremented after each update,
  # so final serial should reflect updated records
  zone_update_count=$((final_num - initial_num))
  
  debug "Change count: $zone_update_count"

  if [[ "$zone_update_count" -eq "$record_count" ]]; then
    info "SUCCESS: $zone_update_count changes applied (as expected)"
  else
    error "ERROR: Expected $record_count changes, but got $zone_update_count"
    return 1
  fi
}

#
# test run
#
mode="${1:-rrset}" # default to rrset if not provided
records="${2:-1}"
parallel="${3:-1}"
operation="${4:-patch}"

# Constants
ZONE_NAME="zrh.demo.com"
ZONE_OCID="ocid1.dns-zone.oc1.eu-zurich-1.aaaaaaaa77dwosh6t2jigqmxqin2nzkov62wetmwkn23y33pg4emcdkh5ryq"

# Initialize zone
initialize "$ZONE_NAME" "$ZONE_OCID"

# Branch by modeAttempting to update
case "$mode" in
  zone)
    generate_json_data "$records"
    json_data=$(cat test_rrset_dataset.json)
    update_zone "$json_data"
    ;;
  rrset)
    generate_data "$records"
    case $operation in
      patch)
        update_rrset_parallel "$parallel"
        summarize
        ;;
      delete)
        delete_rrset_parallel "$parallel" 
        summarize
        ;;
    esac
    ;;
  *)
    echo "Invalid mode: $mode"
    echo "Usage: $0 [zone|rrset] records threads [patch|delete]"
    exit 1
    ;;
esac

# Ask if the user wants to show final zone records
read -rp "Do you want to show the final DNS zone records? [y/N]: " confirm
if [[ "$confirm" =~ ^[Yy]$ ]]; then
  oci dns record zone get --zone-name-or-id "$ZONE_OCID" --all | jq .
fi