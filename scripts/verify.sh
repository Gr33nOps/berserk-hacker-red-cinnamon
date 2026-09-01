#!/usr/bin/env bash
set -u

passed=0 failed=0 warnings=0
pass() { ((passed++)); printf '\033[32mPASS\033[0m  %s\n' "$1"; }
fail() { ((failed++)); printf '\033[31mFAIL\033[0m  %s\n' "$1"; }
warning() { ((warnings++)); printf '\033[33mWARN\033[0m  %s\n' "$1"; }

check_path() {
    if [[ -e $1 ]]; then pass "$2"; else fail "$2 ($1 missing)"; fi
}
check_command() {
    if command -v "$1" >/dev/null 2>&1; then pass "$2"; else warning "$2 ($1 missing)"; fi
}
check_setting() {
    local actual
    actual=$(gsettings get "$1" "$2" 2>/dev/null || printf unavailable)
    if [[ $actual == "$3" ]]; then pass "$4"; else fail "$4 (got $actual)"; fi
}
check_unit() {
    local enabled active
    enabled=$(systemctl --user is-enabled "$1" 2>/dev/null || true)
    active=$(systemctl --user is-active "$1" 2>/dev/null || true)
    if [[ $enabled:$active == enabled:active ]]; then
        pass "$2"
    else
        warning "$2 ($enabled/$active)"
    fi
}

check_setting org.cinnamon.theme name "'cinnamon-Hacker-Red'" 'Cinnamon shell theme'
check_setting org.cinnamon.desktop.interface gtk-theme "'cinnamon-Hacker-Red'" 'GTK theme'
check_setting org.cinnamon.desktop.interface icon-theme "'Hacker-Red-Universal'" 'Icon theme'
check_setting org.cinnamon.desktop.interface cursor-theme "'oreo_spark_red_cursors'" 'Cursor theme'
check_setting org.cinnamon.desktop.wm.preferences theme "'Orchis-Red-Dark'" 'Window borders'
check_path "$HOME/.themes/cinnamon-Hacker-Red/cinnamon/cinnamon.css" 'Cinnamon CSS'
check_path "$HOME/.themes/cinnamon-Hacker-Red/gtk-3.0/gtk.css" 'GTK 3 CSS'
check_path "$HOME/.themes/cinnamon-Hacker-Red/gtk-4.0/gtk.css" 'GTK 4 CSS'
check_path "$HOME/.themes/Orchis-Red-Dark/metacity-1/metacity-theme-3.xml" 'Metacity controls'
check_path "$HOME/.local/share/cinnamon/applets/Cinnamenu@json/metadata.json" 'Cinnamenu applet'
check_path "$HOME/.local/share/cinnamon/applets/red-status-overflow@berserk-hacker-red/metadata.json" 'Background-app tray applet'
check_command conky 'Conky runtime'
check_command rofi 'Rofi runtime'
check_command cava 'CAVA runtime'
check_command ghostty 'Ghostty terminal'
check_command starship 'Starship prompt'
check_command neofetch 'Neofetch runtime'
check_path "$HOME/.config/neofetch/berserk-red.conf" 'Berserk Neofetch config'
check_path "$HOME/.config/neofetch/berserk-logo.txt" 'Berserk ASCII logo'
check_path "$HOME/.config/berserk-hacker-red-cinnamon/terminal.bashrc" 'Terminal startup rcfile'
check_path "$HOME/.local/bin/berserk-terminal-shell" 'Terminal startup wrapper'
check_path "$HOME/.config/berserk-hacker-red-cinnamon/palette.conf" 'Shared red palette'
check_path "$HOME/.config/berserk-hacker-red-cinnamon/shell-aliases.bash" 'Shell helper aliases'
check_path "$HOME/.config/btop/themes/HackerRed.theme" 'btop red theme'
check_path "$HOME/.local/bin/hacker-screenshot" 'Screenshot helper'
check_path "$HOME/.local/bin/hacker-clipboard" 'Clipboard helper'
check_path "$HOME/.local/bin/hacker-color-picker" 'Color picker helper'
check_command btop 'btop runtime'
check_command gnome-screenshot 'Screenshot runtime'
check_command xclip 'Clipboard runtime'
check_command zenity 'Color picker runtime'
check_unit hacker-widgets.service 'Desktop widget persistence'
check_unit hacker-conky.service 'Conky crash recovery'
if pgrep -x conky >/dev/null 2>&1; then pass 'Conky process'; else fail 'Conky process (not running)'; fi
check_unit red-icon-overlay.path 'New-app icon watcher'
check_unit red-icon-overlay.timer 'Icon reconciliation timer'

printf '\n%d passed, %d failed, %d warnings\n' "$passed" "$failed" "$warnings"
((failed == 0))
