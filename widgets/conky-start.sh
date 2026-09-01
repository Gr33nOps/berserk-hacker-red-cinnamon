#!/usr/bin/env bash
set -Eeuo pipefail

export DISPLAY="${DISPLAY:-:0}"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/berserk-hacker-red-cinnamon/conky.conf"
LOG_DIR="${XDG_RUNTIME_DIR:-/tmp}/hacker-widgets"
mkdir -p "$LOG_DIR"

screen_width=$(xrandr --query 2>/dev/null | awk '/^Screen 0:/{print $8; exit}')
screen_height=$(xrandr --query 2>/dev/null | awk '/^Screen 0:/{gsub(/,/, "", $10); print $10; exit}')
screen_width=${screen_width:-1366}
screen_height=${screen_height:-768}
panel_height=36
conky_width=330
conky_height=486
conky_x=$((screen_width - conky_width - 24))
conky_y=$((panel_height + (screen_height - panel_height - conky_height) / 2))

conky -c "$CONFIG" >"$LOG_DIR/wd-conky.log" 2>&1 &
conky_pid=$!
trap 'kill "$conky_pid" 2>/dev/null || true' EXIT INT TERM

conky_id=""
for _ in $(seq 1 60); do
    kill -0 "$conky_pid" 2>/dev/null || wait "$conky_pid"
    conky_id=$(wmctrl -lpx 2>/dev/null | awk '$4 == "Conky.Conky" {print $1; exit}')
    [[ -n $conky_id ]] && break
    sleep 0.2
done

if [[ -n $conky_id ]]; then
    sleep 1
    xdotool set_window --name WD_CONKY --class WD_CONKY "$conky_id"
    xdotool windowsize "$conky_id" "$conky_width" "$conky_height"
    wmctrl -i -r "$conky_id" -b add,sticky,skip_taskbar,skip_pager
    for _ in 1 2 3; do
        xdotool windowmove "$conky_id" "$conky_x" "$conky_y"
        sleep 0.5
    done
else
    printf 'Conky window was not found for placement\n' >&2
fi

wait "$conky_pid"
