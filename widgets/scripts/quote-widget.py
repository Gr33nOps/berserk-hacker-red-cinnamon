#!/usr/bin/env python3
"""A transparent local-day quote widget with a reliable offline rotation."""

import json
from datetime import date
from pathlib import Path
from urllib.request import Request, urlopen

import gi
gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
from gi.repository import Gdk, GLib, Gtk, Pango


CACHE = Path.home() / ".cache" / "hacker-widgets" / "daily-quote.json"
API = "https://zenquotes.io/api/random"
CACHE_VERSION = 2

# Original project copy: these keep the widget rotating at local midnight even
# when the network or the optional quote service is unavailable.
OFFLINE_QUOTES = (
    "Discipline is the bridge between intention and finished work.",
    "A quiet mind notices the path that noise conceals.",
    "Progress is built from the next deliberate step.",
    "Courage can be small and still move the whole day.",
    "Protect your focus; difficult things are built there.",
    "Rest is part of endurance, not its opposite.",
    "Make the system simple enough that tomorrow can trust it.",
    "Consistency turns effort into character.",
    "The strongest plan leaves room to adapt.",
    "Begin with what is clear, then earn the next answer.",
    "A sharp tool is useful; a steady hand is decisive.",
    "Darkness gives contrast, not direction.",
    "Keep the promise you made to your future self.",
    "Patience is action measured over a longer horizon.",
    "What you repeat quietly becomes reliable under pressure.",
    "Attention is a resource; spend it where the work matters.",
    "A difficult road becomes possible one honest step at a time.",
)


def offline_quote(day):
    return {
        "version": CACHE_VERSION,
        "date": day.isoformat(),
        "quote": OFFLINE_QUOTES[day.toordinal() % len(OFFLINE_QUOTES)],
        "author": "Berserk Hacker Red",
        "source": "Offline rotation",
    }


def save_quote(entry):
    CACHE.parent.mkdir(parents=True, exist_ok=True)
    temporary = CACHE.with_suffix(".tmp")
    temporary.write_text(json.dumps(entry, ensure_ascii=False) + "\n")
    temporary.replace(CACHE)


def load_quote():
    local_day = date.today()
    today = local_day.isoformat()
    try:
        cached = json.loads(CACHE.read_text())
        if cached.get("version") == CACHE_VERSION and cached.get("date") == today:
            return cached
    except (OSError, ValueError, AttributeError):
        pass
    try:
        request = Request(API, headers={"User-Agent": "red-desktop-widget/1.0"})
        with urlopen(request, timeout=6) as response:
            payload = json.load(response)
        data = payload[0]
        entry = {
            "version": CACHE_VERSION,
            "date": today,
            "quote": str(data["q"]).strip(),
            "author": str(data.get("a", "")).strip(),
            "source": "ZenQuotes",
        }
        if not entry["quote"]:
            raise ValueError("quote service returned an empty quote")
    except Exception:
        entry = offline_quote(local_day)
    save_quote(entry)
    return entry


class QuoteWidget(Gtk.Window):
    def __init__(self):
        super().__init__(type=Gtk.WindowType.TOPLEVEL)
        self.set_title("Daily quote")
        self.set_decorated(False)
        self.set_resizable(False)
        self.set_skip_taskbar_hint(True)
        self.set_skip_pager_hint(True)
        self.set_accept_focus(False)
        visual = self.get_screen().get_rgba_visual()
        if visual:
            self.set_visual(visual)
        self.set_app_paintable(True)
        self.set_size_request(320, 110)
        screen_height = self.get_screen().get_height()
        stack_top = 32 + (screen_height - 32 - 458) // 2
        self.move(14, stack_top + 348)

        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        box.set_margin_start(8)
        box.set_margin_end(8)
        box.set_margin_top(2)

        self.caption = Gtk.Label(label="DAILY QUOTE", xalign=0)
        self.caption.get_style_context().add_class("caption")
        box.pack_start(self.caption, False, False, 0)
        box.pack_start(Gtk.Box(), False, False, 7)

        self.quote = Gtk.Label(xalign=0, yalign=0)
        self.quote.set_line_wrap(True)
        self.quote.set_line_wrap_mode(Pango.WrapMode.WORD_CHAR)
        self.quote.set_max_width_chars(40)
        self.quote.get_style_context().add_class("quote")
        box.pack_start(self.quote, True, True, 0)

        self.author = Gtk.Label(xalign=0)
        self.author.get_style_context().add_class("author")
        box.pack_start(self.author, False, False, 0)
        self.add(box)

        provider = Gtk.CssProvider()
        provider.load_from_data(b"""
          window { background-color: rgba(0, 0, 0, 0); }
          label.caption { color: #ff3347; font: 8pt 'JetBrainsMono Nerd Font Mono'; font-weight: 700; letter-spacing: 1px; }
          label.quote { color: #eadfcf; font: 9pt 'JetBrainsMono Nerd Font Mono'; }
          label.author { color: #d78388; font: 8pt 'JetBrainsMono Nerd Font Mono'; }
        """)
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(), provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION + 1000)
        self.connect("realize", self._pin)
        self.shown_date = None
        self.refresh()
        # Check the local date frequently; the cache prevents network traffic
        # after the day's single quote has been chosen.
        GLib.timeout_add_seconds(60, self.refresh)

    def _pin(self, _widget):
        window = self.get_window()
        if window:
            window.stick()

    def refresh(self):
        today = date.today().isoformat()
        if self.shown_date == today:
            return True
        entry = load_quote()
        self.quote.set_text(f'“{entry["quote"]}”')
        source = entry.get("source", "Daily rotation")
        self.author.set_text(
            f'— {entry["author"]} · {source}' if entry["author"] else source)
        self.shown_date = entry["date"]
        return True


if __name__ == "__main__":
    window = QuoteWidget()
    window.show_all()
    Gtk.main()
