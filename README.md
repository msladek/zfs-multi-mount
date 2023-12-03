# zfs-multi-unlock
Imports, unlocks and optionally mounts several ZFS datasets while asking for the encryption passphrase as rarely as possible. If the same encryption passphrase is used on several datasets, it will ask once.

This script can be used in a systemd service to unlock encrypted datasets during boot. Practical if using several datasets with the same passphrase.

## Fork
Originally created by Pawel Ginalski https://github.com/gbytedev/zfs-multi-mount.
This fork brings several improvements/changes to the upstream repo:
- tries to import the referenced pools first
- swaps the default mounting behaviour by replacing `-n/--no-mount` with `-m/--mount`
- improved script robustness

## Installation
Just drop the script in any of your `$PATH` directories, e.g. `/usr/local/sbin`:
```
sudo wget -O /usr/local/sbin/zfs-multi-unlock https://raw.githubusercontent.com/msladek/zfs-multi-unlock/master/zfs-multi-unlock.sh
sudo chmod +x /usr/local/sbin/zfs-multi-unlock
```

## Usage
### Unlock all already imported datasets
`zfs-multi-unlock`

### Import and unlock specific datasets
`zfs-multi-unlock poolA/dataset1 poolA/dataset2 poolB/dataset3`

### Unlock all already imported datasets and mount them
`zfs-multi-unlock --mount`

### Use within systemd context (in a systemd service)
`zfs-multi-unlock --systemd`

#### Example of a systemd service file using this script to unlock ZFS datasets
/etc/systemd/system/zfs-multi-unlock.service
```
[Unit]
Description=Unlock all datasets
DefaultDependencies=no
Before=zfs-mount.service
Before=systemd-user-sessions.service
After=zfs-import.target
OnFailure=emergency.target

[Service]
Type=oneshot
RemainAfterExit=yes

ExecStart=/usr/local/sbin/zfs-multi-unlock --systemd

[Install]
WantedBy=zfs-mount.service
```
