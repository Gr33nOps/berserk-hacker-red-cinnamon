# Third-party notices

This repository combines original integration work with redistributed free
software. Bundled components retain their upstream copyright, attribution,
and license terms. The table below distinguishes redistributed work from
visual inspiration and runtime integrations.

## Redistributed components

### Cinnamon Hacker

- **Upstream:** [linuxmint/cinnamon-spices-themes — Cinnamon Hacker](https://github.com/linuxmint/cinnamon-spices-themes/tree/master/cinnamon-Hacker)
- **Author:** dstakaroot; upstream artwork credits Tyr-jord as the baseline
- **License:** GPL-3.0
- **Local path:** `themes/cinnamon-Hacker-Red/`
- **Changes:** extensive crimson palette, contrast, GTK 2/3/4, Cinnamon shell,
  notification, calendar, OSD, menu, control-state, and asset modifications

The local theme is a heavily modified Cinnamon Hacker derivative. Its bundled
`COPYING` and upstream metadata remain with the component.

### Orchis

- **Upstream:** [vinceliuice/Orchis-theme](https://github.com/vinceliuice/Orchis-theme)
- **Author:** vinceliuice and contributors
- **Lineage:** based on [Materia](https://github.com/nana-4/materia-theme)
- **License:** GPL-3.0; individual artwork retains annotations embedded by its
  upstream authors, including CC BY-SA notices where present
- **Local path:** `themes/Orchis-Red-Dark/`
- **Changes:** focused-window palette, border, title-bar, and window-control
  integration for the project's design system

### Cinnamenu

- **Upstream:** [Cinnamenu on Cinnamon Spices](https://github.com/linuxmint/cinnamon-spices-applets/tree/master/Cinnamenu%40json)
- **Maintainer:** fredcw
- **Original author / lineage:** Jason Hicks (`jaszhix`), with earlier work and
  contributors listed in the bundled upstream `CREDITS` file
- **License:** GPL-3.0
- **Local path:** `cinnamon/applets/Cinnamenu@json/`
- **Changes:** packaged defaults, palette integration, sanitized settings, and
  optional user-supplied menu branding

Cinnamenu itself includes additional credits for Cinnamon/Mint menu code,
placesCenter, emojilib, search artwork and engines, and translators. Those
notices remain in its component directory.

### Oreo Spark Red cursors

- **Upstream:** [varlesh/oreo-cursors](https://github.com/varlesh/oreo-cursors)
- **Author:** Alexey Varfolomeev (`varlesh`) and contributors, including major
  contributions by Sourav Goswami
- **License:** GPL-2.0
- **Local path:** `cursors/oreo_spark_red_cursors/`
- **Changes:** packaged as the matching cursor selection; cursor artwork is
  otherwise retained from upstream

## Inspiration not redistributed

- [Dedicated-to-Hackerer](https://github.com/dstakaroot/Dedicated-to-Hackerer)
  by dstakaroot inspired the overall concept. Its repository does not declare
  a software license, so none of its files are redistributed here.
- [Hackerer](https://www.gnome-look.org/p/2010119/) by infinity64 informed the
  early visual direction. The current GTK bundle is derived from Cinnamon
  Hacker, not Hackerer, and Hackerer files are not redistributed here.

## Referenced terminal artwork

The Unicode Braille-style Brand emblem in `terminal/berserk-logo.txt` was
supplied by the project user through [Emoji Combos' Dot Art Editor](https://emojicombos.com/dot-art-editor).
The repository adds Neofetch terminal color markup but does not otherwise
change the clipboard artwork. The editor does not identify an original author
or explicit artwork license; downstream redistributors should review that
status for their own use.

## External runtimes and services

The installer configures or interoperates with the following projects but
does not redistribute their program source: Cinnamon, Linux Mint, Nemo,
Conky, Rofi, Ghostty, Starship, CAVA, btop, Plank, MPD/MPC, MPRIS-compatible
players, Hidamari, gnome-screenshot, xclip, Zenity, eza, bat, fzf, Inter,
JetBrains Mono Nerd Font, Pillow, xdotool, and wmctrl.

The quote widget can request a daily quote from
[ZenQuotes](https://zenquotes.io/). Its response is cached locally; the widget
has a bundled offline fallback and does not require that service.

## Original work in this repository

Unless a file or component states otherwise, the following is original
project work under GPL-3.0-or-later:

- backup-aware installer, uninstaller, manifest, and scoped dconf integration
- verification and palette normalization tools
- Conky configuration and matrix, music, quote, system, and weather widgets
- adaptive application-icon generator and reconciliation services
- background-application overflow applet integration
- Rofi, Plank, Ghostty, Starship, CAVA, and btop configs
- screenshot, clipboard, color-picker, and shell helper scripts
- small setup documentation

## Artwork and trademarks

Screenshots show reduced documentation views of user-supplied Berserk-inspired
wallpaper and branding solely to demonstrate the theme. The original wallpaper
and standalone branding files are not provided as installable assets. Berserk,
application logos, and other marks remain the property of their respective
rightsholders.

The icon generator transforms launchers on the end user's machine. The
project does not redistribute generated application icons or claim ownership
of their marks.
