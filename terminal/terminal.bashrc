# Load the user's normal interactive Bash environment first.
if [[ -f $HOME/.bashrc ]]; then
    # shellcheck disable=SC1090
    source "$HOME/.bashrc"
fi

if [[ -r ${XDG_CONFIG_HOME:-$HOME/.config}/berserk-hacker-red-cinnamon/shell-aliases.bash ]]; then
    # shellcheck disable=SC1090
    source "${XDG_CONFIG_HOME:-$HOME/.config}/berserk-hacker-red-cinnamon/shell-aliases.bash"
fi

# The launcher hides the underlying shell name from Ghostty's auto-detection,
# so load Ghostty's Bash integration explicitly when its resources are present.
if [[ -n ${GHOSTTY_RESOURCES_DIR:-} ]] &&
        [[ -r $GHOSTTY_RESOURCES_DIR/shell-integration/bash/ghostty.bash ]]; then
    export GHOSTTY_SHELL_FEATURES=${GHOSTTY_SHELL_FEATURES:-cursor:blink,path,title}
    # shellcheck disable=SC1090
    source "$GHOSTTY_RESOURCES_DIR/shell-integration/bash/ghostty.bash"
fi

# Ghostty starts this rcfile once for each new terminal surface. Neofetch is
# deliberately kept out of ~/.bashrc so subshells and scripts remain quiet.
if [[ $- == *i* ]] && command -v neofetch >/dev/null 2>&1; then
    command neofetch \
        --config "${XDG_CONFIG_HOME:-$HOME/.config}/neofetch/berserk-red.conf" \
        --source "${XDG_CONFIG_HOME:-$HOME/.config}/neofetch/berserk-logo.txt"
fi
