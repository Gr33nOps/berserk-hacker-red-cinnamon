#!/usr/bin/env python3
"""A desktop-only red matrix rain widget; no terminal emulator involved."""

import os
import random

import gi
gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
from gi.repository import Gdk, GLib, Gtk


WIDTH, HEIGHT = 340, 176
CHARS = "0123456789abcdef<>[]{}+-*/#$%&@!?"


class MatrixCanvas(Gtk.DrawingArea):
    def __init__(self):
        super().__init__()
        self.columns = [self._column(index) for index in range(0, WIDTH, 18)]
        self.connect("draw", self.draw_matrix)
        GLib.timeout_add(65, self.advance)

    def _column(self, x):
        return {"x": x, "y": random.randint(-HEIGHT, HEIGHT),
                "speed": random.uniform(1.3, 4.1),
                "length": random.randint(4, 12),
                "chars": [random.choice(CHARS) for _ in range(14)]}

    def advance(self):
        for column in self.columns:
            column["y"] += column["speed"]
            if column["y"] - column["length"] * 13 > HEIGHT:
                column.update(self._column(column["x"]))
        self.queue_draw()
        return True

    def draw_matrix(self, _widget, cr):
        cr.set_source_rgba(0.027, 0.016, 0.020, 0.72)
        cr.rectangle(0, 0, WIDTH, HEIGHT)
        cr.fill()
        cr.select_font_face("JetBrains Mono", 0, 0)
        cr.set_font_size(12)
        for column in self.columns:
            for offset in range(column["length"]):
                y = column["y"] - offset * 13
                if not 0 <= y <= HEIGHT:
                    continue
                strength = 1 - offset / (column["length"] + 1)
                if offset == 0:
                    # Warm-white leading glyph with a fading crimson trail.
                    cr.set_source_rgba(1.0, 0.957, 0.91, 0.98)
                else:
                    cr.set_source_rgba(1, 0.2, 0.278, 0.16 + strength * 0.78)
                cr.move_to(column["x"], y)
                cr.show_text(column["chars"][offset % len(column["chars"])])
        return False


class MatrixWidget(Gtk.Window):
    def __init__(self):
        super().__init__(type=Gtk.WindowType.TOPLEVEL)
        self.set_title("Matrix rain")
        self.set_wmclass("WD_MATRIX", "WD_MATRIX")
        self.set_decorated(False)
        self.set_resizable(False)
        self.set_skip_taskbar_hint(True)
        self.set_skip_pager_hint(True)
        self.set_accept_focus(False)
        self.set_type_hint(Gdk.WindowTypeHint.UTILITY)
        visual = self.get_screen().get_rgba_visual()
        if visual:
            self.set_visual(visual)
        self.set_app_paintable(True)
        self.set_size_request(WIDTH, HEIGHT)
        self.move(14, int(os.environ.get("MATRIX_TOP", "238")))
        self.add(MatrixCanvas())
        self.connect("realize", self.pin)

    def pin(self, _widget):
        window = self.get_window()
        if window:
            window.stick()
            window.set_keep_below(True)


window = MatrixWidget()
window.show_all()
Gtk.main()
