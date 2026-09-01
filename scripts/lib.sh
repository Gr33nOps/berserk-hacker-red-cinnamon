#!/usr/bin/env bash

PROJECT_ID="berserk-hacker-red-cinnamon"
STATE_ROOT="${XDG_STATE_HOME:-$HOME/.local/state}/$PROJECT_ID"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

info() { printf '\033[1;31m==>\033[0m %s\n' "$*"; }
ok() { printf '\033[1;32m  ✓\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m  !\033[0m %s\n' "$*" >&2; }
die() { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

run() {
    if [[ ${DRY_RUN:-false} == true ]]; then
        printf '  [dry-run]'
        printf ' %q' "$@"
        printf '\n'
    else
        "$@"
    fi
}

safe_user_target() {
    case "$1" in
        "$HOME"/.themes/*|"$HOME"/.icons/*|"$HOME"/.local/bin/*|"$HOME"/.local/lib/*|"$DATA_HOME"/*|"$CONFIG_HOME"/*)
            return 0 ;;
        *) die "refusing unsafe target: $1" ;;
    esac
}

remove_target() {
    safe_user_target "$1"
    if [[ -d $1 && ! -L $1 ]]; then
        run find "$1" -depth -mindepth 1 -delete
        run rmdir "$1"
    elif [[ -e $1 || -L $1 ]]; then
        run unlink "$1"
    fi
}

backup_target() {
    local target=$1 label=$2 metadata="$BACKUP_DIR/metadata.tsv"
    [[ ${DRY_RUN:-false} == true ]] && return 0
    grep -q "^${label}"$'\t' "$metadata" 2>/dev/null && return 0
    mkdir -p "$BACKUP_DIR/files"
    if [[ -e $target || -L $target ]]; then
        cp -a "$target" "$BACKUP_DIR/files/$label"
        printf '%s\t%s\tpresent\n' "$label" "$target" >> "$metadata"
    else
        printf '%s\t%s\tabsent\n' "$label" "$target" >> "$metadata"
    fi
}

install_tree() {
    local source=$1 target=$2 label=$3
    backup_target "$target" "$label"
    remove_target "$target"
    run install -d "$(dirname "$target")"
    run cp -a "$source" "$target"
}

install_file() {
    local source=$1 target=$2 mode=$3 label=$4
    backup_target "$target" "$label"
    run install -D -m "$mode" "$source" "$target"
}

setting() {
    local schema=$1 key=$2 value=$3
    if [[ ${DRY_RUN:-false} == true ]]; then
        printf '  [dry-run] gsettings set %q %q %q\n' "$schema" "$key" "$value"
    else
        gsettings set "$schema" "$key" "$value"
    fi
}
