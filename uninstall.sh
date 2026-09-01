#!/usr/bin/env bash
set -Eeuo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=scripts/lib.sh
source "$ROOT/scripts/lib.sh"
DRY_RUN=false

case "${1:-}" in
    "") ;;
    --dry-run) DRY_RUN=true ;;
    -h|--help)
        printf '%s\n' 'Usage: ./uninstall.sh [--dry-run]'
        exit 0 ;;
    *) die "unknown option: $1" ;;
esac

[[ -f $STATE_ROOT/current-backup ]] || die "no installation rollback snapshot found"
BACKUP_DIR=$(cat "$STATE_ROOT/current-backup")
[[ -d $BACKUP_DIR ]] || die "rollback directory is missing: $BACKUP_DIR"

info "Stopping Hacker Red services"
for unit in hacker-widgets.service hacker-conky.service hidamari-clickthrough.service red-icon-overlay.path red-icon-overlay.timer red-icon-overlay.service; do
    if $DRY_RUN; then
        printf '  [dry-run] systemctl --user disable --now %s\n' "$unit"
    else
        systemctl --user disable --now "$unit" >/dev/null 2>&1 || true
    fi
done

info "Restoring files from $BACKUP_DIR"
if [[ -f $BACKUP_DIR/metadata.tsv ]]; then
    while IFS=$'\t' read -r label target previous; do
        [[ -n $label && -n $target ]] || continue
        remove_target "$target"
        if [[ $previous == present ]]; then
            run install -d "$(dirname "$target")"
            run cp -a "$BACKUP_DIR/files/$label" "$target"
            ok "restored $target"
        else
            ok "removed $target"
        fi
    done < "$BACKUP_DIR/metadata.tsv"
fi

info "Restoring Cinnamon and Nemo settings"
if $DRY_RUN; then
    printf '  [dry-run] restore dconf snapshots\n'
else
    [[ -f $BACKUP_DIR/cinnamon.dconf ]] && dconf load /org/cinnamon/ < "$BACKUP_DIR/cinnamon.dconf"
    [[ -f $BACKUP_DIR/nemo.dconf ]] && dconf load /org/nemo/ < "$BACKUP_DIR/nemo.dconf"
    [[ -f $BACKUP_DIR/gnome.dconf ]] && dconf load /org/gnome/ < "$BACKUP_DIR/gnome.dconf"
    [[ -f $BACKUP_DIR/plank.dconf ]] && dconf load /net/launchpad/plank/ < "$BACKUP_DIR/plank.dconf"
    [[ -f $BACKUP_DIR/ibus.dconf ]] && dconf load /desktop/ibus/ < "$BACKUP_DIR/ibus.dconf"
    systemctl --user daemon-reload
    unlink "$STATE_ROOT/current-backup"
fi

ok "Previous desktop configuration restored"
printf 'Backup retained at %s\n' "$BACKUP_DIR"
