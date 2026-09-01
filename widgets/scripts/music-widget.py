#!/usr/bin/env python3
"""A compact, artwork-backed desktop player widget for Cinnamon."""

import subprocess
from pathlib import Path

import gi
gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
gi.require_version("GdkPixbuf", "2.0")
from gi.repository import Gdk, GLib, Gtk, Pango


PLAYER = str(Path.home() / ".local/lib/berserk-hacker-red-cinnamon/widgets/scripts/nowplaying.sh")


def field(name):
    try:
        return subprocess.check_output([PLAYER, name], text=True,
                                       timeout=1).strip()
    except (subprocess.SubprocessError, OSError):
        return ""


class MusicWidget(Gtk.Window):
    def __init__(self):
        super().__init__(type=Gtk.WindowType.TOPLEVEL)
        self.set_title("Music widget")
        self.set_decorated(False)
        self.set_resizable(False)
        self.set_skip_taskbar_hint(True)
        self.set_skip_pager_hint(True)
        self.set_accept_focus(False)
        # Keep it on every workspace, but let normal apps cover it.
        visual = self.get_screen().get_rgba_visual()
        if visual:
            self.set_visual(visual)
        self.set_app_paintable(True)
        self.set_size_request(320, 132)
        screen_height = self.get_screen().get_height()
        # Align beneath the matrix panel inside the full centered left stack.
        stack_top = 32 + (screen_height - 32 - 458) // 2
        self.move(14, stack_top + 192)

        content = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        content.set_margin_start(8)
        content.set_margin_end(8)
        content.set_margin_top(4)
        content.set_margin_bottom(4)

        self.status = Gtk.Label(xalign=0)
        self.status.get_style_context().add_class("status")
        content.pack_start(self.status, False, False, 0)

        content.pack_start(Gtk.Box(), False, False, 8)
        self.title_label = Gtk.Label(xalign=0)
        self.title_label.set_ellipsize(Pango.EllipsizeMode.END)
        self.title_label.set_max_width_chars(27)
        self.title_label.get_style_context().add_class("title")
        content.pack_start(self.title_label, False, False, 0)

        content.pack_start(Gtk.Box(), False, False, 3)
        self.artist = Gtk.Label(xalign=0)
        self.artist.set_ellipsize(Pango.EllipsizeMode.END)
        self.artist.set_max_width_chars(31)
        self.artist.get_style_context().add_class("artist")
        content.pack_start(self.artist, False, False, 0)

        content.pack_start(Gtk.Box(), True, True, 0)
        self.progress = Gtk.ProgressBar()
        self.progress.set_show_text(False)
        self.progress.get_style_context().add_class("track-progress")
        content.pack_start(self.progress, False, False, 0)

        content.pack_start(Gtk.Box(), False, False, 6)
        footer = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        self.source = Gtk.Label(xalign=0)
        self.source.get_style_context().add_class("source")
        self.time = Gtk.Label(xalign=1)
        self.time.get_style_context().add_class("time")
        footer.pack_start(self.source, True, True, 0)
        footer.pack_end(self.time, False, False, 0)
        content.pack_start(footer, False, False, 0)

        self.add(content)
        self._style()
        self.connect("realize", self._pin)
        GLib.timeout_add_seconds(1, self.refresh)
        self.refresh()

    def _style(self):
        css = b"""
          window { background-color: rgba(0, 0, 0, 0); }
          label.status { color: #d78388; font: 8pt 'JetBrainsMono Nerd Font Mono'; letter-spacing: 1px; }
          label.title { color: #eadfcf; font: 16pt 'JetBrainsMono Nerd Font Mono'; font-weight: 700; }
          label.artist { color: #d78388; font: 10pt 'JetBrainsMono Nerd Font Mono'; }
          label.source { color: #ff3347; font: 9pt 'JetBrainsMono Nerd Font Mono'; font-weight: 700; }
          label.time { color: #d78388; font: 9pt 'JetBrainsMono Nerd Font Mono'; }
          progressbar.track-progress trough { min-height: 3px; border-radius: 2px; background-color: rgba(100, 16, 29, 0.52); border: none; }
          progressbar.track-progress progress { min-height: 3px; border-radius: 2px; background-image: linear-gradient(90deg, #64101d, #ff3347); }
        """
        provider = Gtk.CssProvider()
        provider.load_from_data(css)
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(), provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION + 1000)

    def _pin(self, _widget):
        window = self.get_window()
        if window:
            window.stick()

    def refresh(self):
        status = field("status") or "standby"
        self.status.set_text(f"PLAYBACK  /  {status.upper()}")
        self.title_label.set_text(field("title") or "nothing playing")
        self.artist.set_text(field("artist") or "open a music app to begin")
        self.source.set_text("● " + (field("src") or "player").upper())
        self.time.set_text(field("progress") or "0:00 / 0:00")
        try:
            self.progress.set_fraction(max(0, min(100, int(field("pct") or 0))) / 100)
        except ValueError:
            self.progress.set_fraction(0)
        return True


window = MusicWidget()
window.show_all()
Gtk.main()
