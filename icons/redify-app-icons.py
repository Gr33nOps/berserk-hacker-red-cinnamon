#!/usr/bin/env python3
"""Maintain a future-proof red overlay for installed application icons."""

from __future__ import annotations

import fcntl
import json
import os
import re
import subprocess
from pathlib import Path

import gi
gi.require_version("GdkPixbuf", "2.0")
from gi.repository import GdkPixbuf
from PIL import Image, ImageDraw, ImageFont


HOME = Path.home()
THEME_NAME = os.environ.get("HACKER_RED_ICON_THEME", "Hacker-Red-Universal")
THEME = HOME / ".local/share/icons" / THEME_NAME
TARGET = THEME / "apps/256x256"
STATE_FILE = THEME / ".red-icon-overlay-state.json"
ORIGINAL_ICON_KEY = "X-Hacker-Red-Original-Icon"
IMAGE_SUFFIXES = {".png", ".svg", ".svgz", ".xpm", ".jpg", ".jpeg", ".webp"}
UI_OVERRIDES = {
    "categories": (
        "applications-accessories", "applications-development",
        "applications-games", "applications-graphics",
        "applications-internet", "applications-multimedia",
        "applications-office", "applications-system",
        "preferences-desktop", "preferences-system",
    ),
    "places": (
        "folder", "folder-documents", "folder-download", "folder-music",
        "folder-pictures", "folder-publicshare", "folder-templates",
        "folder-videos", "network-workgroup", "user-desktop", "user-home",
        "user-trash", "user-trash-full",
    ),
    "actions": (
        "document-open-recent", "folder-new", "folder-open",
        "system-lock-screen", "system-log-out", "system-shutdown",
    ),
    "devices": (
        "computer", "drive-harddisk", "drive-removable-media",
        "media-removable", "network-server",
    ),
    "mimetypes": (
        "application-json", "application-pdf", "application-x-archive",
        "application-x-executable", "application-x-generic",
        "application-x-shellscript", "application-x-zerosize",
        "audio-x-generic", "image-x-generic", "package-x-generic",
        "text-css", "text-html", "text-plain", "text-x-generic",
        "text-x-python", "video-x-generic",
    ),
}

# Highest precedence first, matching freedesktop desktop-file lookup.
LAUNCHER_DIRS = (
    HOME / ".local/share/applications",
    HOME / ".local/share/flatpak/exports/share/applications",
    Path("/var/lib/flatpak/exports/share/applications"),
    Path("/var/lib/snapd/desktop/applications"),
    Path("/usr/local/share/applications"),
    Path("/usr/share/applications"),
)
SOURCE_DIRS = (
    HOME / ".local/share/icons",
    HOME / ".icons",
    HOME / ".local/share/flatpak/exports/share/icons",
    Path("/var/lib/flatpak/exports/share/icons"),
    Path("/usr/local/share/icons"),
    Path("/usr/share/pixmaps"),
    Path("/usr/share/icons"),
)
EXCLUDED_THEME_ROOTS = {
    THEME.resolve(),
    Path("/usr/share/icons") / THEME_NAME,
}


def load_state() -> dict:
    try:
        data = json.loads(STATE_FILE.read_text())
        return data if data.get("version") == 3 else {"version": 3, "apps": {}}
    except (OSError, ValueError, TypeError):
        return {"version": 3, "apps": {}}


def save_state(state: dict) -> None:
    temporary = STATE_FILE.with_suffix(".tmp")
    temporary.write_text(json.dumps(state, indent=2, sort_keys=True) + "\n")
    temporary.replace(STATE_FILE)


def desktop_fields(desktop_file: Path) -> dict[str, str]:
    """Read only the primary [Desktop Entry] section."""
    fields: dict[str, str] = {}
    try:
        in_entry = False
        for raw_line in desktop_file.read_text(errors="ignore").splitlines():
            line = raw_line.strip()
            if line == "[Desktop Entry]":
                in_entry = True
                continue
            if in_entry and line.startswith("["):
                break
            if in_entry and "=" in line and not line.startswith("#"):
                key, value = line.split("=", 1)
                fields.setdefault(key.strip(), value.strip())
    except OSError:
        pass
    return fields


def launcher_groups() -> dict[str, list[Path]]:
    """Collect desktop IDs and all lower-priority variants of each ID."""
    groups: dict[str, list[Path]] = {}
    for directory in LAUNCHER_DIRS:
        if directory.exists():
            for desktop_file in sorted(directory.glob("*.desktop")):
                groups.setdefault(desktop_file.name, []).append(desktop_file)
    for root in (Path("/var/lib/flatpak/app"), HOME / ".local/share/flatpak/app"):
        if not root.exists():
            continue
        pattern = "*/*/*/*/export/share/applications/*.desktop"
        for desktop_file in sorted(root.glob(pattern)):
            paths = groups.setdefault(desktop_file.name, [])
            if desktop_file not in paths:
                paths.append(desktop_file)
    return groups


def original_icon_for(paths: list[Path], primary_fields: dict[str, str]) -> str:
    remembered = primary_fields.get(ORIGINAL_ICON_KEY, "")
    if remembered:
        return remembered
    current = primary_fields.get("Icon", "")
    if current and not current.startswith("hacker-red-"):
        return current
    # Recover originals created by the previous implementation.
    for candidate in paths[1:]:
        icon = desktop_fields(candidate).get("Icon", "")
        if icon and not icon.startswith("hacker-red-"):
            return icon
    return current


def normalized_icon_key(icon: str, desktop_id: str) -> str:
    expanded = Path(os.path.expanduser(os.path.expandvars(icon)))
    if expanded.is_absolute() or "/" in icon:
        return f"hacker-red-{Path(desktop_id).stem}"
    suffix = Path(icon).suffix.lower()
    return Path(icon).stem if suffix in IMAGE_SUFFIXES else icon


def safe_icon_key(icon_key: str, desktop_id: str) -> str:
    clean = re.sub(r"[^A-Za-z0-9._+-]+", "-", icon_key).strip("-.")
    return clean or f"hacker-red-{Path(desktop_id).stem}"


def path_is_excluded(path: Path) -> bool:
    try:
        resolved = path.resolve()
    except OSError:
        resolved = path
    return any(resolved == root or root in resolved.parents
               for root in EXCLUDED_THEME_ROOTS)


def source_score(path: Path) -> tuple[int, int, int]:
    """Prefer scalable artwork, then large application icons."""
    suffix_score = 3000 if path.suffix.lower() in {".svg", ".svgz"} else 1000
    size = 0
    for part in reversed(path.parts):
        match = re.fullmatch(r"(\d+)[xX](\d+)", part)
        if match:
            size = min(int(match.group(1)), int(match.group(2)), 512)
            break
    app_score = 200 if any(part.lower() in {"apps", "applications"}
                           for part in path.parts) else 0
    return suffix_score, size, app_score


def source_index(needed_names: set[str]) -> tuple[dict[str, Path], dict[str, Path]]:
    """Index only names requested by current launchers.

    Walking directory entries is cheap; resolving and retaining every icon in
    every installed theme is not. This keeps periodic reconciliation fast.
    """
    exact: dict[str, Path] = {}
    folded: dict[str, Path] = {}
    needed_folded = {name.casefold() for name in needed_names}
    excluded = {str(root) for root in EXCLUDED_THEME_ROOTS}
    for directory in SOURCE_DIRS:
        if not directory.exists() or path_is_excluded(directory):
            continue
        try:
            for dirpath, dirnames, filenames in os.walk(directory):
                dirnames[:] = [name for name in dirnames
                               if str(Path(dirpath) / name) not in excluded]
                for filename in filenames:
                    path = Path(dirpath) / filename
                    if path.suffix.lower() not in IMAGE_SUFFIXES:
                        continue
                    names = {path.stem, path.name}
                    if not any(name in needed_names or name.casefold() in needed_folded
                               for name in names):
                        continue
                    score = source_score(path)
                    for name in names:
                        previous = exact.get(name)
                        if previous is None or score > source_score(previous):
                            exact[name] = path
                        lower = name.casefold()
                        previous_folded = folded.get(lower)
                        if previous_folded is None or score > source_score(previous_folded):
                            folded[lower] = path
        except OSError:
            continue
    return exact, folded


def flatpak_source(desktop_file: Path, icon: str) -> Path | None:
    parts = desktop_file.parts
    if "flatpak" not in parts or "export" not in parts:
        return None
    export_index = parts.index("export")
    icons = Path(*parts[:export_index]) / "files/share/icons"
    if not icons.exists():
        return None
    icon_name = Path(icon).stem
    matches = [path for path in icons.glob(f"**/{icon_name}.*")
               if path.suffix.lower() in IMAGE_SUFFIXES]
    return max(matches, key=source_score, default=None)


def resolve_source(desktop_file: Path, icon: str,
                   exact: dict[str, Path], folded: dict[str, Path]) -> Path | None:
    expanded = Path(os.path.expanduser(os.path.expandvars(icon)))
    direct_candidates = [expanded]
    if not expanded.is_absolute() and "/" in icon:
        direct_candidates.append(desktop_file.parent / expanded)
    for candidate in direct_candidates:
        if candidate.is_file() and not path_is_excluded(candidate):
            return candidate
    flatpak = flatpak_source(desktop_file, icon)
    if flatpak:
        return flatpak
    for name in (icon, Path(icon).name, Path(icon).stem):
        if name in exact:
            return exact[name]
        if name.casefold() in folded:
            return folded[name.casefold()]
    return None


def tint(source: Path, destination: Path) -> bool:
    """Map source luminance onto the shared crimson palette."""
    temporary = destination.with_suffix(".tmp.png")
    try:
        pixbuf = GdkPixbuf.Pixbuf.new_from_file_at_scale(str(source), 256, 256, True)
        pixbuf.savev(str(temporary), "png", [], [])
        image = Image.open(temporary).convert("RGBA")
        output = []
        for red, green, blue, alpha in image.getdata():
            luminance = (red * .2126 + green * .7152 + blue * .0722) / 255
            # surface-3 (#2b0e15) → focus crimson (#ff3347)
            output.append((int(43 + 212 * luminance),
                           int(14 + 37 * luminance),
                           int(21 + 50 * luminance), alpha))
        image.putdata(output)
        image.save(temporary)
        temporary.replace(destination)
        return True
    except Exception as error:
        temporary.unlink(missing_ok=True)
        print(f"warning: could not tint {source}: {error}")
        return False


def generic_red_icon(name: str, destination: Path) -> bool:
    """Use a consistent monogram only when an app supplies no artwork."""
    words = [word for word in re.split(r"[._+-]+", name)
             if word and word.casefold() not in
             {"org", "com", "io", "github", "hacker", "red"}]
    monogram = "".join(word[0].upper() for word in words[-2:])[:2] or "A"
    temporary = destination.with_suffix(".tmp.png")
    try:
        canvas = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
        draw = ImageDraw.Draw(canvas)
        draw.rounded_rectangle((14, 14, 242, 242), radius=54,
                               fill=(29, 11, 16, 245),
                               outline=(177, 18, 38, 255), width=5)
        draw.rounded_rectangle((25, 25, 231, 231), radius=44,
                               outline=(255, 51, 71, 210), width=2)
        font_path = Path("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf")
        font = ImageFont.truetype(str(font_path), 92) if font_path.exists() else ImageFont.load_default()
        box = draw.textbbox((0, 0), monogram, font=font)
        draw.text(((256 - (box[2] - box[0])) / 2,
                   (256 - (box[3] - box[1])) / 2 - 10),
                  monogram, font=font, fill=(215, 131, 136, 255))
        canvas.save(temporary)
        temporary.replace(destination)
        return True
    except Exception as error:
        temporary.unlink(missing_ok=True)
        print(f"warning: could not create fallback for {name}: {error}")
        return False


def source_signature(source: Path | None) -> dict:
    if source is None:
        return {"source": None, "source_mtime_ns": None, "source_size": None}
    try:
        stat = source.stat()
        return {"source": str(source), "source_mtime_ns": stat.st_mtime_ns,
                "source_size": stat.st_size}
    except OSError:
        return {"source": str(source), "source_mtime_ns": None,
                "source_size": None}


def override_absolute_icon(desktop_file: Path, original_icon: str,
                           icon_key: str) -> bool:
    expanded = Path(os.path.expanduser(os.path.expandvars(original_icon)))
    if not (expanded.is_absolute() or "/" in original_icon):
        return False
    override = HOME / ".local/share/applications" / desktop_file.name
    try:
        contents = desktop_file.read_text(errors="ignore")
        if ORIGINAL_ICON_KEY in contents:
            contents = re.sub(rf"^{re.escape(ORIGINAL_ICON_KEY)}=.*$",
                              f"{ORIGINAL_ICON_KEY}={original_icon}", contents,
                              count=1, flags=re.MULTILINE)
        else:
            contents = contents.replace(
                "[Desktop Entry]",
                f"[Desktop Entry]\n{ORIGINAL_ICON_KEY}={original_icon}", 1)
        contents = re.sub(r"^Icon=.*$", f"Icon={icon_key}", contents,
                          count=1, flags=re.MULTILINE)
        override.parent.mkdir(parents=True, exist_ok=True)
        if not override.exists() or override.read_text(errors="ignore") != contents:
            override.write_text(contents)
        return True
    except OSError as error:
        print(f"warning: could not create launcher override for {desktop_file}: {error}")
        return False


def refresh_cache() -> None:
    updater = Path("/usr/bin/gtk-update-icon-cache")
    if updater.exists():
        subprocess.run([str(updater), "-f", "-t", str(THEME)],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                       check=False)


def main() -> int:
    TARGET.mkdir(parents=True, exist_ok=True)
    for context in UI_OVERRIDES:
        (THEME / context / "256x256").mkdir(parents=True, exist_ok=True)
    state = load_state()
    previous_apps = state.get("apps", {})
    next_apps: dict[str, dict] = {}
    groups = launcher_groups()
    prepared: list[tuple[str, list[Path], dict[str, str], str]] = []
    needed_names: set[str] = {
        name for names in UI_OVERRIDES.values() for name in names
    }
    for desktop_id, paths in sorted(groups.items()):
        fields = desktop_fields(paths[0])
        if fields.get("Type", "Application") != "Application" or not fields.get("Icon"):
            continue
        original_icon = original_icon_for(paths, fields)
        prepared.append((desktop_id, paths, fields, original_icon))
        needed_names.update({original_icon, Path(original_icon).name,
                             Path(original_icon).stem})
    exact, folded = source_index(needed_names)
    total = generated = reused = generic = failed = overrides = 0

    for context, names in UI_OVERRIDES.items():
        for name in names:
            source = exact.get(name) or folded.get(name.casefold())
            destination = THEME / context / "256x256" / f"{name}.png"
            success = tint(source, destination) if source else generic_red_icon(name, destination)
            if not success:
                failed += 1

    for desktop_id, paths, fields, original_icon in prepared:
        primary = paths[0]
        total += 1
        icon_key = safe_icon_key(normalized_icon_key(original_icon, desktop_id), desktop_id)
        destination = TARGET / f"{icon_key}.png"
        source = resolve_source(primary, original_icon, exact, folded)
        signature = {
            "desktop": str(primary),
            "desktop_mtime_ns": primary.stat().st_mtime_ns,
            "original_icon": original_icon,
            "icon_key": icon_key,
            "destination": str(destination),
            **source_signature(source),
        }
        previous = previous_apps.get(desktop_id)

        if previous == signature and destination.is_file():
            reused += 1
            success = True
        elif source is not None:
            success = tint(source, destination)
            generated += int(success)
        elif original_icon.startswith("hacker-red-") and destination.is_file():
            # Preserve valid output from releases that did not record sources.
            success = True
            reused += 1
        else:
            success = generic_red_icon(icon_key, destination)
            generic += int(success)

        if not success:
            failed += 1
            continue
        next_apps[desktop_id] = signature
        overrides += int(override_absolute_icon(primary, original_icon, icon_key))

    live_destinations = {entry["destination"] for entry in next_apps.values()}
    for old_entry in previous_apps.values():
        old_destination = old_entry.get("destination")
        if old_destination and old_destination not in live_destinations:
            Path(old_destination).unlink(missing_ok=True)

    save_state({"version": 3, "theme": THEME_NAME, "apps": next_apps})
    refresh_cache()
    print("red icon overlay: "
          f"{total} launchers, {generated} regenerated, {reused} reused, "
          f"{generic} fallbacks, {overrides} path overrides, {failed} failed")
    return 1 if failed else 0


if __name__ == "__main__":
    lock_path = HOME / ".cache/hacker-red/red-icon-overlay.lock"
    lock_path.parent.mkdir(parents=True, exist_ok=True)
    with lock_path.open("w") as lock_file:
        try:
            fcntl.flock(lock_file, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            print("red icon overlay: another refresh is already running")
        else:
            raise SystemExit(main())
