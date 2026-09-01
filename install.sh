#!/usr/bin/env bash
set -Eeuo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=scripts/lib.sh
source "$ROOT/scripts/lib.sh"

DRY_RUN=false
WITH_WIDGETS=true
WITH_ROFI=true
WITH_PLANK=true
WITH_TERMINAL=true
WITH_ICONS=true
WITH_CURSOR=true
WALLPAPER=""
BRAND_LOGO=""

usage() {
    cat <<'EOF'
Usage: ./install.sh [options]

Options:
  --dry-run             Print every action without changing the system
  --no-widgets          Skip Conky, music, matrix and quote widgets
  --no-rofi             Skip Rofi launcher and power menu
  --no-plank            Skip Plank theme and autostart
  --no-terminal         Skip Ghostty, Starship and CAVA configuration
  --no-icons            Skip the automatic red icon overlay
  --no-cursor           Skip the Oreo Spark Red cursor
  --wallpaper PATH      Install and select a legally obtained wallpaper
  --brand-logo PATH     Use a legally obtained panel-menu logo
  -h, --help            Show this help

This installer only changes files and settings in your user account.
It never uses sudo, pkexec, GRUB, Plymouth, LightDM, or Firefox profiles.
EOF
}

while (($#)); do
    case "$1" in
        --dry-run) DRY_RUN=true ;;
        --no-widgets) WITH_WIDGETS=false ;;
        --no-rofi) WITH_ROFI=false ;;
        --no-plank) WITH_PLANK=false ;;
        --no-terminal) WITH_TERMINAL=false ;;
        --no-icons) WITH_ICONS=false ;;
        --no-cursor) WITH_CURSOR=false ;;
        --wallpaper)
            shift; (($#)) || die "--wallpaper requires a path"; WALLPAPER=$1 ;;
        --brand-logo)
            shift; (($#)) || die "--brand-logo requires a path"; BRAND_LOGO=$1 ;;
        -h|--help) usage; exit 0 ;;
        *) die "unknown option: $1" ;;
    esac
    shift
done

[[ -z $WALLPAPER || -f $WALLPAPER ]] || die "wallpaper not found: $WALLPAPER"
[[ -z $BRAND_LOGO || -f $BRAND_LOGO ]] || die "brand logo not found: $BRAND_LOGO"
command -v gsettings >/dev/null || die "gsettings is required"
command -v dconf >/dev/null || die "dconf is required"

desktop=${XDG_CURRENT_DESKTOP:-}
[[ $desktop == *Cinnamon* || $desktop == *X-Cinnamon* ]] || \
    warn "Cinnamon is not the current desktop; settings will apply at next Cinnamon login"

declare -A package_for=(
    [conky]=conky-all [rofi]=rofi [cava]=cava
    [xdotool]=xdotool [wmctrl]=wmctrl [plank]=plank [neofetch]=neofetch
    [btop]=btop [gnome-screenshot]=gnome-screenshot [xclip]=xclip [zenity]=zenity
)
required=()
$WITH_WIDGETS && required+=(conky xdotool wmctrl)
$WITH_ROFI && required+=(rofi)
$WITH_PLANK && required+=(plank)
$WITH_TERMINAL && required+=(cava neofetch btop)
required+=(gnome-screenshot xclip zenity)

missing_packages=()
for command_name in "${required[@]}"; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        missing_packages+=("${package_for[$command_name]}")
    fi
done
if ((${#missing_packages[@]})); then
    die "missing packages: ${missing_packages[*]} (install them first, then run this again)"
fi

if $WITH_ICONS && ! python3 -c 'import gi; from PIL import Image' >/dev/null 2>&1; then
    die "red icons need python3-gi and python3-pil"
fi

timestamp=$(date +%Y%m%d-%H%M%S)
if [[ -f $STATE_ROOT/current-backup ]]; then
    BACKUP_DIR=$(cat "$STATE_ROOT/current-backup")
fi
if [[ -z ${BACKUP_DIR:-} || ! -d $BACKUP_DIR ]]; then
    BACKUP_DIR="$STATE_ROOT/backups/$timestamp"
    if ! $DRY_RUN; then
        mkdir -p "$BACKUP_DIR"
        printf '%s\n' "$BACKUP_DIR" > "$STATE_ROOT/current-backup"
        dconf dump /org/cinnamon/ > "$BACKUP_DIR/cinnamon.dconf"
        dconf dump /org/nemo/ > "$BACKUP_DIR/nemo.dconf"
        dconf dump /org/gnome/ > "$BACKUP_DIR/gnome.dconf"
        dconf dump /net/launchpad/plank/ > "$BACKUP_DIR/plank.dconf"
        dconf dump /desktop/ibus/ > "$BACKUP_DIR/ibus.dconf"
    fi
fi
info "Rollback snapshot: $BACKUP_DIR"

info "Installing Cinnamon, GTK and window themes"
install_tree "$ROOT/themes/cinnamon-Hacker-Red" "$HOME/.themes/cinnamon-Hacker-Red" theme-cinnamon-hacker-red
install_tree "$ROOT/themes/Orchis-Red-Dark" "$HOME/.themes/Orchis-Red-Dark" theme-orchis-red-dark

if $WITH_CURSOR; then
    info "Installing Oreo Spark Red cursor"
    install_tree "$ROOT/cursors/oreo_spark_red_cursors" "$HOME/.icons/oreo_spark_red_cursors" cursor-oreo-spark-red
    default_cursor="$HOME/.icons/default"
    backup_target "$default_cursor" cursor-default
    remove_target "$default_cursor"
    run install -d "$default_cursor"
    if ! $DRY_RUN; then
        printf '%s\n' '[Icon Theme]' 'Inherits=oreo_spark_red_cursors' > "$default_cursor/index.theme"
    fi
fi

info "Installing Cinnamon applets"
install_tree "$ROOT/cinnamon/applets/Cinnamenu@json" "$DATA_HOME/cinnamon/applets/Cinnamenu@json" applet-cinnamenu
install_tree "$ROOT/cinnamon/applets/red-status-overflow@berserk-hacker-red" "$DATA_HOME/cinnamon/applets/red-status-overflow@berserk-hacker-red" applet-red-status

brand_value=start-here
if [[ -n $BRAND_LOGO ]]; then
    brand_target="$DATA_HOME/icons/berserk-red/brand-of-sacrifice.${BRAND_LOGO##*.}"
    install_file "$BRAND_LOGO" "$brand_target" 0644 brand-logo
    brand_value=$brand_target
fi
cinnamenu_target="$CONFIG_HOME/cinnamon/spices/Cinnamenu@json/3.json"
backup_target "$cinnamenu_target" cinnamenu-settings
run install -d "$(dirname "$cinnamenu_target")"
if $DRY_RUN; then
    printf '  [dry-run] install sanitized Cinnamenu settings\n'
else
    sed "s|__BRAND_ICON__|$brand_value|g" "$ROOT/cinnamon/cinnamenu-settings.json" > "$cinnamenu_target"
fi

if $WITH_ICONS; then
    info "Installing future-proof application icon overlay"
    icon_theme="$DATA_HOME/icons/Hacker-Red-Universal"
    backup_target "$icon_theme" icon-theme
    remove_target "$icon_theme"
    run install -d "$icon_theme/apps/256x256"
    run install -m 0644 "$ROOT/icons/index.theme" "$icon_theme/index.theme"
    install_file "$ROOT/icons/redify-app-icons.py" "$HOME/.local/bin/hacker-red-icon-overlay" 0755 icon-generator
    for unit in service path timer; do
        install_file "$ROOT/icons/systemd/red-icon-overlay.$unit" "$CONFIG_HOME/systemd/user/red-icon-overlay.$unit" 0644 "icon-unit-$unit"
    done
fi

if $WITH_WIDGETS; then
    info "Installing adaptive desktop widgets"
    widget_root="$HOME/.local/lib/$PROJECT_ID/widgets"
    install_tree "$ROOT/widgets/scripts" "$widget_root/scripts" widget-scripts
    install_file "$ROOT/widgets/widgets-start.sh" "$widget_root/widgets-start.sh" 0755 widget-launcher
    install_file "$ROOT/widgets/conky-start.sh" "$widget_root/conky-start.sh" 0755 conky-launcher
    net_iface=$(ip route show default 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}')
    if [[ -z $net_iface ]]; then
        net_iface=$(find /sys/class/net -mindepth 1 -maxdepth 1 -printf '%f\n' | grep -v '^lo$' | head -n 1)
    fi
    [[ -n $net_iface ]] || net_iface=lo
    conky_target="$CONFIG_HOME/$PROJECT_ID/conky.conf"
    backup_target "$conky_target" conky-config
    run install -d "$(dirname "$conky_target")"
    if $DRY_RUN; then
        printf '  [dry-run] render Conky for interface %s\n' "$net_iface"
    else
        sed "s/__NET_IFACE__/$net_iface/g" "$ROOT/widgets/conky.conf.in" > "$conky_target"
    fi
    for unit in hacker-widgets.service hacker-conky.service hidamari-clickthrough.service; do
        install_file "$ROOT/widgets/systemd/$unit" "$CONFIG_HOME/systemd/user/$unit" 0644 "widget-unit-${unit%.service}"
    done
fi

if $WITH_ROFI; then
    info "Installing Rofi launcher and power menu"
    install_file "$ROOT/rofi/config.rasi" "$CONFIG_HOME/rofi/config.rasi" 0644 rofi-config
    install_file "$ROOT/rofi/hacker-red.rasi" "$CONFIG_HOME/rofi/hacker-red.rasi" 0644 rofi-theme
    install_file "$ROOT/rofi/hacker-launcher" "$HOME/.local/bin/hacker-launcher" 0755 rofi-launcher
    install_file "$ROOT/rofi/hacker-power-menu" "$HOME/.local/bin/hacker-power-menu" 0755 rofi-power
fi

info "Installing desktop utilities and shared palette"
install_file "$ROOT/palette/berserk-red.conf" "$CONFIG_HOME/$PROJECT_ID/palette.conf" 0644 shared-palette
install_file "$ROOT/utilities/hacker-screenshot" "$HOME/.local/bin/hacker-screenshot" 0755 utility-screenshot
install_file "$ROOT/utilities/hacker-color-picker" "$HOME/.local/bin/hacker-color-picker" 0755 utility-color-picker
$WITH_ROFI && install_file "$ROOT/utilities/hacker-clipboard" "$HOME/.local/bin/hacker-clipboard" 0755 utility-clipboard

if $WITH_TERMINAL; then
    info "Installing terminal, prompt, Neofetch and visualizer configuration"
    if command -v ghostty >/dev/null 2>&1; then
        install_file "$ROOT/terminal/ghostty.conf" "$CONFIG_HOME/ghostty/config" 0644 ghostty-config
    else
        warn "Ghostty is not installed; its config was skipped"
    fi
    if command -v starship >/dev/null 2>&1; then
        install_file "$ROOT/terminal/starship.toml" "$CONFIG_HOME/starship.toml" 0644 starship-config
    else
        warn "Starship is not installed; its config was skipped"
    fi
    install_file "$ROOT/terminal/cava.conf" "$CONFIG_HOME/cava/config" 0644 cava-config
    install_file "$ROOT/terminal/hacker-cava" "$HOME/.local/bin/hacker-cava" 0755 cava-launcher
    install_file "$ROOT/terminal/neofetch.conf" "$CONFIG_HOME/neofetch/berserk-red.conf" 0644 neofetch-config
    install_file "$ROOT/terminal/berserk-logo.txt" "$CONFIG_HOME/neofetch/berserk-logo.txt" 0644 neofetch-logo
    install_file "$ROOT/terminal/terminal.bashrc" "$CONFIG_HOME/$PROJECT_ID/terminal.bashrc" 0644 terminal-bashrc
    install_file "$ROOT/terminal/shell-aliases.bash" "$CONFIG_HOME/$PROJECT_ID/shell-aliases.bash" 0644 shell-aliases
    install_file "$ROOT/terminal/berserk-terminal-shell" "$HOME/.local/bin/berserk-terminal-shell" 0755 terminal-shell
    install_file "$ROOT/terminal/btop/HackerRed.theme" "$CONFIG_HOME/btop/themes/HackerRed.theme" 0644 btop-theme
    btop_config="$CONFIG_HOME/btop/btop.conf"
    backup_target "$btop_config" btop-config
    run install -d "$(dirname "$btop_config")"
    if $DRY_RUN; then
        printf '  [dry-run] select HackerRed in %s\n' "$btop_config"
    elif [[ -f $btop_config ]]; then
        if grep -qE '^(color_theme|theme)[[:space:]]*=' "$btop_config"; then
            sed -Ei 's/^(color_theme|theme)[[:space:]]*=.*/color_theme = "HackerRed"/' "$btop_config"
        else
            printf '\ncolor_theme = "HackerRed"\n' >> "$btop_config"
        fi
    else
        printf 'color_theme = "HackerRed"\n' > "$btop_config"
    fi
fi

if $WITH_PLANK; then
    info "Installing Plank theme"
    install_tree "$ROOT/plank/themes/Cinnamon-Hacker-Red" "$DATA_HOME/plank/themes/Cinnamon-Hacker-Red" plank-theme
    install_file "$ROOT/plank/plank.desktop" "$CONFIG_HOME/autostart/plank.desktop" 0644 plank-autostart
fi

info "Installing sound profile"
install_tree "$ROOT/sounds/HackerRed" "$DATA_HOME/sounds/HackerRed" sound-theme
if [[ -f /usr/share/mint-artwork/sounds/volume.oga ]] && ! $DRY_RUN; then
    mkdir -p "$DATA_HOME/sounds/HackerRed/stereo"
    ln -sfn /usr/share/mint-artwork/sounds/volume.oga "$DATA_HOME/sounds/HackerRed/stereo/audio-volume-change.oga"
fi

info "Applying scoped Cinnamon and Nemo settings"
if $DRY_RUN; then
    printf '  [dry-run] dconf load /org/cinnamon/ and /org/nemo/\n'
else
    dconf load /org/cinnamon/ < "$ROOT/settings/cinnamon.dconf"
    dconf load /org/nemo/ < "$ROOT/settings/nemo.dconf"
fi
setting org.gnome.desktop.interface color-scheme "'prefer-dark'"
setting org.gnome.desktop.interface gtk-theme "'cinnamon-Hacker-Red'"
$WITH_ICONS && setting org.gnome.desktop.interface icon-theme "'Hacker-Red-Universal'"
$WITH_CURSOR && setting org.gnome.desktop.interface cursor-theme "'oreo_spark_red_cursors'"
setting org.gnome.desktop.interface font-name "'Inter 10'"
setting org.gnome.desktop.interface document-font-name "'Inter 10'"
setting org.gnome.desktop.interface monospace-font-name "'JetBrainsMono Nerd Font 10'"

if [[ -n $WALLPAPER ]]; then
    extension=${WALLPAPER##*.}
    wallpaper_target="$DATA_HOME/backgrounds/$PROJECT_ID/wallpaper.$extension"
    install_file "$WALLPAPER" "$wallpaper_target" 0644 wallpaper
    wallpaper_uri=$(python3 -c 'import pathlib,sys; print(pathlib.Path(sys.argv[1]).resolve().as_uri())' "$wallpaper_target")
    setting org.cinnamon.desktop.background picture-uri "'$wallpaper_uri'"
    setting org.cinnamon.desktop.background picture-options "'zoom'"
else
    warn "No wallpaper supplied; keeping the current wallpaper"
fi

custom_shortcuts=()
if $WITH_ROFI; then
    custom_shortcuts+=(custom0 custom1)
    for tuple in \
        "custom0|Hacker Red launcher|$HOME/.local/bin/hacker-launcher|['<Super>space']" \
        "custom1|Hacker Red power menu|$HOME/.local/bin/hacker-power-menu|['<Super>Escape']"; do
        IFS='|' read -r id name command binding <<< "$tuple"
        schema="org.cinnamon.desktop.keybindings.custom-keybinding:/org/cinnamon/desktop/keybindings/custom-keybindings/$id/"
        setting "$schema" name "'$name'"; setting "$schema" command "'$command'"; setting "$schema" binding "$binding"
    done
    setting org.cinnamon.desktop.keybindings.wm switch-input-source "['XF86Keyboard']"
    setting org.cinnamon.desktop.keybindings.wm switch-input-source-backward "['<Shift>XF86Keyboard']"
    if gsettings list-schemas | grep -qx org.freedesktop.ibus.general.hotkey; then
        setting org.freedesktop.ibus.general.hotkey triggers "[]"
    fi
fi
if $WITH_TERMINAL; then
    custom_shortcuts+=(custom2 custom3)
    terminal_command=ghostty
    command -v ghostty >/dev/null 2>&1 || terminal_command=x-terminal-emulator
    for tuple in \
        "custom2|Terminal|$terminal_command|['<Super>Return']" \
        "custom3|Hacker Red visualizer|$HOME/.local/bin/hacker-cava|['<Super><Alt>m']"; do
        IFS='|' read -r id name command binding <<< "$tuple"
        schema="org.cinnamon.desktop.keybindings.custom-keybinding:/org/cinnamon/desktop/keybindings/custom-keybindings/$id/"
        setting "$schema" name "'$name'"; setting "$schema" command "'$command'"; setting "$schema" binding "$binding"
    done
fi
custom_shortcuts+=(custom4)
schema="org.cinnamon.desktop.keybindings.custom-keybinding:/org/cinnamon/desktop/keybindings/custom-keybindings/custom4/"
setting "$schema" name "'Area screenshot'"
setting "$schema" command "'$HOME/.local/bin/hacker-screenshot'"
setting "$schema" binding "['<Super><Shift>s']"
if $WITH_ROFI; then
    custom_shortcuts+=(custom5)
    schema="org.cinnamon.desktop.keybindings.custom-keybinding:/org/cinnamon/desktop/keybindings/custom-keybindings/custom5/"
    setting "$schema" name "'Clipboard editor'"
    setting "$schema" command "'$HOME/.local/bin/hacker-clipboard'"
    setting "$schema" binding "['<Super><Shift>v']"
fi
custom_shortcuts+=(custom6)
schema="org.cinnamon.desktop.keybindings.custom-keybinding:/org/cinnamon/desktop/keybindings/custom-keybindings/custom6/"
setting "$schema" name "'Color picker'"
setting "$schema" command "'$HOME/.local/bin/hacker-color-picker'"
setting "$schema" binding "['<Super><Shift>c']"
shortcut_value="[]"
if ((${#custom_shortcuts[@]})); then
    printf -v shortcut_value "'%s', " "${custom_shortcuts[@]}"
    shortcut_value="[${shortcut_value%, }]"
fi
setting org.cinnamon.desktop.keybindings custom-list "$shortcut_value"

if $WITH_PLANK && gsettings list-schemas | grep -qx net.launchpad.plank.dock.settings; then
    setting 'net.launchpad.plank.dock.settings:/net/launchpad/plank/docks/dock1/' theme "'Cinnamon-Hacker-Red'"
    setting 'net.launchpad.plank.dock.settings:/net/launchpad/plank/docks/dock1/' icon-size 48
fi

if ! $DRY_RUN; then
    systemctl --user daemon-reload
    if $WITH_ICONS; then
        systemctl --user enable --now red-icon-overlay.path red-icon-overlay.timer
        systemctl --user start red-icon-overlay.service
    fi
    if $WITH_WIDGETS; then
        systemctl --user enable hacker-widgets.service hacker-conky.service
        systemctl --user restart hacker-widgets.service hacker-conky.service
        if pgrep -f '(^|/)hidamari($| )' >/dev/null || \
            { command -v flatpak >/dev/null 2>&1 && flatpak info io.github.jeffshee.Hidamari >/dev/null 2>&1; }; then
            systemctl --user enable --now hidamari-clickthrough.service
        fi
    fi
    printf '%s\n' "$ROOT" > "$STATE_ROOT/installed-from"
fi

ok "Installation complete"
printf '%s\n' "Run ./scripts/verify.sh, then log out and back in if any running app has not refreshed."
