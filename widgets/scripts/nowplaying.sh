#!/usr/bin/env python3
import re
import subprocess
import sys
import time
from pathlib import Path
from urllib.parse import unquote, urlparse

import gi
gi.require_version("Gio", "2.0")
from gi.repository import Gio, GLib

IFACE = "org.mpris.MediaPlayer2.Player"
PROPS = "org.freedesktop.DBus.Properties"
ROOT = "/org/mpris/MediaPlayer2"


def fmt(us):
    if not us or us <= 0:
        return "0:00"
    us = int(us)
    s = us // 1000000
    m, s = divmod(s, 60)
    parts = [m, s]
    return f"{parts[0]}:{parts[1]:02d}"


def clip(value, width=28):
    value = value.strip()
    return value if len(value) <= width else value[:width - 1] + "…"


def get(conn, owner, iface, prop):
    r = conn.call_sync(owner, ROOT, PROPS, "Get",
                       GLib.Variant("(ss)", (iface, prop)),
                       GLib.VariantType("(v)"), Gio.DBusCallFlags.NONE,
                       300, None)
    v = r.unpack()
    # PyGObject already unwraps the D-Bus variant on current Mint/Ubuntu;
    # older builds return a Variant object. Support both forms.
    if not v:
        return None
    return v[0].unpack() if hasattr(v[0], "unpack") else v[0]


def mpris():
    try:
        conn = Gio.bus_get_sync(Gio.BusType.SESSION, None)
        r = conn.call_sync("org.freedesktop.DBus", "/org/freedesktop/DBus",
                           "org.freedesktop.DBus", "ListNames", None,
                           GLib.VariantType("(as)"), Gio.DBusCallFlags.NONE,
                           300, None)
    except Exception:
        return None
    for name in r.unpack()[0]:
        if not name.startswith("org.mpris.MediaPlayer2."):
            continue
        try:
            status = get(conn, name, IFACE, "PlaybackStatus")
            if not status or status == "Stopped":
                continue
            meta = get(conn, name, IFACE, "Metadata") or {}
            art = meta.get("xesam:artist")
            pos = get(conn, name, IFACE, "Position")
            title = str(meta.get("xesam:title") or "")
            if not title and meta.get("xesam:url"):
                title = Path(unquote(urlparse(str(meta["xesam:url"])).path)).name
            player = {
                "src": name.rsplit(".", 1)[-1],
                "status": status,
                "title": title,
                "artist": ", ".join(str(a) for a in art)
                if isinstance(art, list) else str(art or ""),
                "album": str(meta.get("xesam:album") or ""),
                "len": meta.get("mpris:length"),
                "pos": pos,
            }
            # Only active playback belongs in the desktop widget. This avoids
            # a paused player leaving an old song displayed after startup.
            if status == "Playing":
                return player
        except Exception:
            continue
    return None


def mpd():
    try:
        cur = subprocess.run(["mpc", "current", "-f",
                              "%title%\n%artist%\n%album%"],
                             capture_output=True, text=True, timeout=2)
        if cur.returncode != 0 or not cur.stdout.strip():
            return None
        st = subprocess.run(["mpc", "status"], capture_output=True,
                            text=True, timeout=2)
        if "[playing]" not in st.stdout:
            return None
        lines = cur.stdout.splitlines()
        p = {
            "src": "mpd",
            "status": "Playing",
            "title": lines[0] if lines else "",
            "artist": lines[1] if len(lines) > 1 else "",
            "album": lines[2] if len(lines) > 2 else "",
            "len": None,
            "pos": None,
        }
        m = re.search(r"([\d:]{1,2}:\d{2}(?::\d{2})?)/([\d:]{1,2}:\d{2}(?::\d{2})?)",
                      st.stdout)
        if m:
            def secs(t):
                parts = [float(x) for x in t.split(":")]
                return parts[0] * 3600 + parts[1] * 60 + parts[2] if len(parts) == 3 \
                    else parts[0] * 60 + parts[1]
            p["pos"] = int(secs(m.group(1))) * 1000000
            p["len"] = int(secs(m.group(2))) * 1000000
        return p
    except Exception:
        return None


def main():
    field = sys.argv[1] if len(sys.argv) > 1 else "title"
    p = mpris() or mpd()
    if p is None:
        if field == "status":
            print("standby")
        elif field in ("title", "song"):
            print("nothing playing")
        elif field == "artist":
            print("open a music app to begin")
        elif field == "src":
            print("player")
        elif field == "progress":
            print("0:00 / 0:00")
        elif field == "state":
            print("[]")
        elif field == "pct":
            print("0")
        elif field == "viz":
            print("▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁")
        return
    if field in ("title", "song"):
        print(clip(p["title"]) or "no track info")
    elif field == "artist":
        print(clip(p["artist"]) or "unknown artist")
    elif field == "album":
        print(p["album"].strip())
    elif field == "status":
        print(p["status"])
    elif field == "state":
        print("||" if p["status"] == "Paused" else ">>")
    elif field == "progress":
        print(f"{fmt(p['pos'])} / {fmt(p['len'])}")
    elif field == "pct":
        if p["len"] and p["pos"] is not None and p["len"] > 0:
            print(int(100 * p["pos"] / p["len"]))
        else:
            print("0")
    elif field == "src":
        print(p["src"])
    elif field == "viz":
        # A compact animated playback indicator; it intentionally reflects
        # playback state rather than claiming to be an audio spectrum.
        if p["status"] != "Playing":
            print("▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁")
        else:
            phase = int(time.time() * 4)
            position = int((p["pos"] or 0) / 1000000)
            levels = "▁▂▃▄▅▆▇█"
            print("".join(levels[(phase * (i % 5 + 1) + position + i * i) % len(levels)]
                          for i in range(24)))


if __name__ == "__main__":
    main()
