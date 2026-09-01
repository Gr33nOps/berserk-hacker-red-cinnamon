#!/bin/sh
set -eu

battery=""
for candidate in /sys/class/power_supply/BAT*; do
    if [ -d "$candidate" ]; then
        battery=$candidate
        break
    fi
done

case "${1:-}" in
    battery-percent)
        if [ -n "$battery" ] && [ -r "$battery/capacity" ]; then
            cat "$battery/capacity"
        else
            printf '100\n'
        fi
        ;;
    battery-label)
        if [ -n "$battery" ] && [ -r "$battery/capacity" ]; then
            percent=$(cat "$battery/capacity")
            status=$(cat "$battery/status" 2>/dev/null || printf unknown)
            printf '%s%% %s\n' "$percent" "$status"
        else
            printf 'desktop power\n'
        fi
        ;;
    temp)
        for input in /sys/class/thermal/thermal_zone*/temp; do
            if [ -r "$input" ]; then
                value=$(cat "$input")
                [ "$value" -gt 0 ] 2>/dev/null || continue
                printf '%s°C\n' "$((value / 1000))"
                exit 0
            fi
        done
        printf 'n/a\n'
        ;;
    *)
        printf 'usage: %s {battery-percent|battery-label|temp}\n' "$0" >&2
        exit 2
        ;;
esac
