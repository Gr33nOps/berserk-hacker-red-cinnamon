# Small fixes

## Cinnamon did not refresh

Log out and back in. The installer only changes your user session.

## Widgets are missing

```bash
systemctl --user restart hacker-widgets.service
systemctl --user status hacker-widgets.service
```

## Conky is missing

Conky normally restarts itself. To restore it immediately and check its log:

```bash
systemctl --user restart hacker-conky.service
systemctl --user status hacker-conky.service
journalctl --user -u hacker-conky.service -n 30 --no-pager
```

## New app icon is not red

```bash
systemctl --user start red-icon-overlay.service
```

Then reopen the menu. Conky may briefly restart while Cinnamon refreshes; its
separate service brings it back automatically.

## Plank is missing

```bash
plank &
```

## Check everything

```bash
./scripts/verify.sh
```

## Go back

```bash
./uninstall.sh
```

The first install backup is kept under
`~/.local/state/berserk-hacker-red-cinnamon/backups/`.
