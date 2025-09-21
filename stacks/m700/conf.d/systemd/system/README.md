# Systemd configuration

## Install

copy files to `/etc/systemd/system/`

## Enable / Disable

```
systemctl daemon-reload
systemctl enable --now wake.timer suspend.timer powertop.automount hdparm-spindown.service mnt-data.automount
systemctl disable wake.timer suspend.timer
```

## Start / Stop

```
systemctl start wake.timer suspend.timer
systemctl stop wake.timer suspend.timer
```
