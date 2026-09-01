# Small quality-of-life aliases. Each one only activates when its tool exists.
command -v eza >/dev/null 2>&1 && alias ls='eza --icons=auto --group-directories-first'
command -v eza >/dev/null 2>&1 && alias ll='eza -lah --icons=auto --group-directories-first'
command -v batcat >/dev/null 2>&1 && alias cat='batcat --theme=ansi'
command -v rg >/dev/null 2>&1 && alias grep='rg'
