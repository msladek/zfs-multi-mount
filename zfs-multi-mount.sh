#!/usr/bin/env bash

PATH=$PATH:/usr/bin:/sbin:/bin

help() {
    echo "Usage: $(basename "$0") [OPTION]... [SOURCE_POOL/DATASET]..."
    echo
    echo " -s, --systemd        use when within systemd context"
    echo " -n, --no-mount       only load keys, do not mount datasets"
    echo " -h, --help           show this help"
    exit 0
}

while getopts "snh" opt; do
  case $opt in
    s|--systemd) systemd=1 ;;
    n|--no-mount) no_mount=1 ;;
    h|--help) help ;;
    ?) echo "Invalid option '-$OPTARG'. Try '$(basename "$0") --help' for more information." && exit 1 ;;
  esac
done

datasets=("${@:$OPTIND}")
[ ${#datasets[@]} -eq 0 ] && mapfile -t datasets < <(zfs list -H -o name)
attempt=0
attempt_limit=3

function import_pool {
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
  if [ -v systemd ]; then
    key=$(systemd-ask-password "Enter $1 passphrase") # With systemd.
  else
    read -srp "Enter $1 passphrase: " key ; echo # Other places.
  fi
}

function load_key {
  [[ $attempt == "$attempt_limit" ]] && echo "No more attempts left." && exit 1
  [[ ! $(zfs get keystatus "$1" -H -o value) == "unavailable" ]] && return 0
  if [ ! -v key ]; then
    ((attempt++))
    ask_password $1
  fi
  if ! echo "$key" | zfs load-key "$1"; then
    unset key
    load_key "$1"
  fi
  attempt=0
  return 0
}

for dataset in "${datasets[@]}"; do
  import_pool $dataset && load_key "$dataset" || exit 1
  # Mounting as non-root user on Linux is not possible,
  # see https://github.com/openzfs/zfs/issues/10648.
  [ ! -v no_mount ] && sudo zfs mount "$dataset" && echo "Dataset '$dataset' has been mounted."
done

unset key

exit 0
