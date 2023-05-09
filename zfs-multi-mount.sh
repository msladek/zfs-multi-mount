#!/usr/bin/env bash
set -euo pipefail

PATH=$PATH:/usr/bin:/sbin:/bin

help() {
    echo "Usage: $(basename "$0") [OPTION]... [SOURCE_POOL/DATASET]..."
    echo
    echo " -s, --systemd        use when within systemd context"
    echo " -m, --mount          mount datasets after loading keys"
    echo " -h, --help           show this help"
    exit 0
}

systemd=false
mount=false
for arg in "$@"; do
  case $arg in
    -s | --systemd) systemd=true; shift ;;
    -m | --mount) mount=true; shift ;;
    -h | --help) help ;;
    -?*) echo "Invalid option '$1' Try '$(basename "$0") --help' for more information."; exit 1 ;;
  esac
done

datasets=("$@")
[ ${#datasets[@]} -eq 0 ] && mapfile -t datasets < <(zfs list -H -o name)
attempt_limit=3

function exists_or_import {
  local pool=${1%%/*}
  ! zpool list -H -o name | grep -qx "$pool" \
    && echo "Pool '$pool' not found, trying import..." \
    && zpool import "$pool"
  ! zfs list -H -o name | grep -qx "$1" \
    && echo "ERROR: Dataset '$1' does not exist." \
    && return 1
  return 0
}

function ask_password {
  local key
  if $systemd; then
    key=$(systemd-ask-password "Enter $1 passphrase") # With systemd.
  else
    read -srp "Enter $1 passphrase: " key ; echo # Other places.
  fi
  echo "$key"
}

function load_key {
  local attempt=${2:-0}
  [ "$attempt" -ge "$attempt_limit" ] && echo "No more attempts left." && return 1
  [ "$(zfs get keystatus "$1" -H -o value)" = "unavailable" ] || return 0
  ask_password "$1" | zfs load-key "$1" && return 0
  load_key "$1" $((attempt + 1))
}

for dataset in "${datasets[@]}"; do
  exists_or_import "$dataset" && load_key "$dataset" || exit 1
  # Mounting as non-root user on Linux is not possible,
  # see https://github.com/openzfs/zfs/issues/10648.
  $mount && sudo zfs mount "$dataset" && echo "Dataset '$dataset' has been mounted."
done

exit 0
