#!/usr/bin/env python3
"""Keep Hidamari's full-screen wallpaper window transparent to mouse input."""

import time

from Xlib import X, display
from Xlib.ext import shape


def apply_clickthrough():
    dpy = display.Display()
    root = dpy.screen().root
    screen = dpy.screen()

    def visit(window):
        try:
            klass = window.get_wm_class() or ()
            geometry = window.get_geometry()
            if ("hidamari" in [part.lower() for part in klass]
                    and geometry.width >= screen.width_in_pixels
                    and geometry.height >= screen.height_in_pixels):
                shape.rectangles(window, shape.SO.Set, shape.SK.Input,
                                 X.YXBanded, 0, 0, [])
            for child in window.query_tree().children:
                visit(child)
        except Exception:
            pass

    visit(root)
    dpy.sync()
    dpy.close()


while True:
    apply_clickthrough()
    time.sleep(3)
