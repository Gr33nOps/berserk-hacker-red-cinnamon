#!/bin/bash
# Start the red-hacker desktop widgets: cmatrix rain (top-left)
# and the red conky monitor (full right column).
export DISPLAY="${DISPLAY:-:0}"
LOG_DIR="${XDG_RUNTIME_DIR:-/tmp}/hacker-widgets"
WIDGET_ROOT="$HOME/.local/lib/berserk-hacker-red-cinnamon/widgets/scripts"
mkdir -p "$LOG_DIR"

# Center the left widget stack and right monitor vertically beneath Cinnamon's
# 32px top panel, while keeping each widget anchored to its side.
SCREEN_H="$(DISPLAY=:0 xrandr --query 2>/dev/null | awk '/^Screen 0:/{gsub(/,/, "", $10); print $10; exit}')"
SCREEN_H="${SCREEN_H:-768}"
TOP_PANEL_H=36
LEFT_STACK_H=458  # 176px matrix + 16px gap + 132px music + 24px gap + 110px quote
LEFT_TOP=$((TOP_PANEL_H + (SCREEN_H - TOP_PANEL_H - LEFT_STACK_H) / 2))

# 1) Desktop-only matrix rain.  This replaces the old Ghostty/cm​atrix
# terminal so there is no terminal window to minimise, close, or manage.
pkill -f 'ghostty.*run-cmatrix.sh' 2>/dev/null || true
# Match both the canonical path and pre-publication ~/bin/widgets installs so
# an upgrade cannot leave duplicate desktop layers running.
pkill -f '^python3 .*/matrix-widget.py$' 2>/dev/null || true
DISPLAY=:0 MATRIX_TOP="$LEFT_TOP" nohup "$WIDGET_ROOT/matrix-widget.py" \
  >"$LOG_DIR/wd-matrix.log" 2>&1 &

# 2) Conky is managed separately by hacker-conky.service so it can recover
# automatically if Cinnamon or XRender closes it during a theme refresh.

# 3) Dedicated GTK music card beneath the matrix panel.
pkill -f '^python3 .*/music-widget.py$' 2>/dev/null || true
sleep 1
DISPLAY=:0 nohup "$WIDGET_ROOT/music-widget.py" >"$LOG_DIR/wd-music.log" 2>&1 &

# 4) Daily quote, beneath the music widget.
pkill -f '^python3 .*/quote-widget.py$' 2>/dev/null || true
sleep 1
DISPLAY=:0 nohup "$WIDGET_ROOT/quote-widget.py" >"$LOG_DIR/wd-quote.log" 2>&1 &

echo "widgets started"
