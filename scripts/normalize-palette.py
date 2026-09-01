#!/usr/bin/env python3
"""Normalize custom surface colors to the documented semantic palette."""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TARGETS = (
    ROOT / "themes/cinnamon-Hacker-Red",
    ROOT / "rofi",
    ROOT / "widgets",
    ROOT / "terminal/cava.conf",
    ROOT / "cinnamon/applets/Cinnamenu@json",
    ROOT / "cinnamon/applets/red-status-overflow@berserk-hacker-red/stylesheet.css",
)

REPLACEMENTS = {
    "#030000": "#070405",
    "#0f0f0f": "#070405",
    "#0a0000": "#070405",
    "#070000": "#070405",
    "#100000": "#11070a",
    "#110000": "#11070a",
    "#0b0001": "#11070a",
    "#150000": "#11070a",
    "#171717": "#11070a",
    "#160f0f": "#11070a",
    "#100002": "#11070a",
    "#190003": "#1d0b10",
    "#1a0003": "#1d0b10",
    "#200000": "#1d0b10",
    "#1a1a1a": "#1d0b10",
    "#1b1b1b": "#1d0b10",
    "#220000": "#1d0b10",
    "#250000": "#1d0b10",
    "#261616": "#1d0b10",
    "#260004": "#2b0e15",
    "#300000": "#2b0e15",
    "#330000": "#2b0e15",
    "#353537": "#2b0e15",
    "#352525": "#2b0e15",
    "#3b2b2b": "#2b0e15",
    "#300006": "#2b0e15",
    "#3c0008": "#2b0e15",
    "#400000": "#2b0e15",
    "#440000": "#2b0e15",
    "#4a0000": "#2b0e15",
    "#410007": "#2b0e15",
    "#54070c": "#64101d",
    "#500000": "#64101d",
    "#3b3c3e": "#64101d",
    "#3e3e3e": "#64101d",
    "#434343": "#64101d",
    "#453535": "#64101d",
    "#493c3c": "#64101d",
    "#4d0000": "#64101d",
    "#4d4f52": "#64101d",
    "#505050": "#64101d",
    "#525252": "#64101d",
    "#640000": "#64101d",
    "#64070e": "#64101d",
    "#670505": "#64101d",
    "#660000": "#64101d",
    "#666666": "#9e8587",
    "#681010": "#64101d",
    "#6d070e": "#64101d",
    "#7f0000": "#64101d",
    "#800000": "#64101d",
    "#808080": "#9e8587",
    "#838383": "#9e8587",
    "#880000": "#64101d",
    "#84050d": "#64101d",
    "#8f0a12": "#64101d",
    "#8c121c": "#b11226",
    "#9d0000": "#64101d",
    "#990000": "#b11226",
    "#9c0303": "#b11226",
    "#9f2f2f": "#b11226",
    "#a53531": "#b11226",
    "#a83535": "#b11226",
    "#aa4400": "#b11226",
    "#b20000": "#b11226",
    "#b30000": "#b11226",
    "#a50912": "#64101d",
    "#a70913": "#64101d",
    "#b3131b": "#b11226",
    "#b80d18": "#b11226",
    "#c00303": "#b11226",
    "#c01c28": "#d62238",
    "#cc0000": "#d62238",
    "#c41420": "#b11226",
    "#c60000": "#d62238",
    "#c7c7c7": "#eadfcf",
    "#c60101": "#d62238",
    "#cf0a0a": "#d62238",
    "#d61f2d": "#d62238",
    "#d45500": "#d62238",
    "#dd0000": "#d62238",
    "#df1621": "#d62238",
    "#e50000": "#d62238",
    "#e60000": "#d62238",
    "#e25252": "#d78388",
    "#ef2929": "#ff3347",
    "#ec1b22": "#d62238",
    "#f04a50": "#d62238",
    "#f23535": "#d62238",
    "#f50000": "#ff3347",
    "#f70505": "#ff3347",
    "#fb4040": "#ff3347",
    "#fc4138": "#ff3347",
    "#ff0000": "#ff3347",
    "#ff0b00": "#ff3347",
    "#ff1a1a": "#ff3347",
    "#ff1e1e": "#ff3347",
    "#ff1744": "#ff3347",
    "#ff222b": "#ff3347",
    "#ff3038": "#ff3347",
    "#ff3434": "#ff3347",
    "#ff3535": "#ff3347",
    "#ff3838": "#ff3347",
    "#ff4444": "#ff3347",
    "#ff4d4d": "#ff3347",
    "#ff4f5e": "#ff3347",
    "#ff5058": "#ff3347",
    "#ff7070": "#d78388",
    "#ff6600": "#d62238",
    "#ff7f2a": "#ff3347",
    "#ff5961": "#d78388",
    "#ff7077": "#d78388",
    "#ff9090": "#d78388",
    "#ff9b9b": "#d78388",
    "#ff9ca1": "#d78388",
    "#ffb0b0": "#eadfcf",
    "#e8d8d8": "#eadfcf",
    "#f2eaea": "#eadfcf",
    "#ffe6e6": "#eadfcf",
    "#ffe8e8": "#eadfcf",
    "#ffffff": "#fff4e8",
    "#fff0f0": "#fff4e8",
    "#fff4f4": "#fff4e8",
    "#fff7f7": "#fff4e8",
    "#a99c9c": "#9e8587",
    "#b99da0": "#9e8587",
    "#c7a8aa": "#9e8587",
    "#e3a7aa": "#9e8587",
    "#ca6a6a": "#d78388",
    "#c95d65": "#d78388",
    "#ddaaaa": "#d78388",
    "#bebebe": "#9e8587",
}

CANONICAL = {
    "#000000",  # true black remains valid for shadows and transparent assets
    "#070405", "#11070a", "#1d0b10", "#2b0e15", "#64101d",
    "#b11226", "#d62238", "#ff3347", "#d78388", "#eadfcf",
    "#fff4e8", "#9e8587",
}
HEX_TOKEN = re.compile(r"#[0-9a-fA-F]{3,8}(?![0-9a-fA-F])")


def canonical_hex(token):
    """Return whether a CSS/SVG RGB(A) hex token belongs to the palette."""
    token = token.lower()
    if len(token) in {4, 5}:
        rgb = "#" + "".join(char * 2 for char in token[1:4])
    elif len(token) in {7, 9}:
        rgb = token[:7]
    else:
        return False
    return rgb in CANONICAL


def candidates():
    for target in TARGETS:
        if target.is_file():
            yield target
        elif target.is_dir():
            for path in target.rglob("*"):
                if path.is_file() and path.suffix.lower() in {
                    ".css", ".rasi", ".conf", ".py", ".sh", ".js",
                    ".in", ".theme", ".svg", ".rc"
                }:
                    yield path


check_only = "--check" in sys.argv[1:]
unknown = [arg for arg in sys.argv[1:] if arg != "--check"]
if unknown:
    raise SystemExit(f"unknown option: {unknown[0]}")

changed = 0
violations = []
for path in candidates():
    original = path.read_text(errors="strict")
    normalized = original
    for old, new in REPLACEMENTS.items():
        normalized = normalized.replace(old, new).replace(old.upper(), new)
    if check_only:
        unexpected = sorted({
            token.lower() for token in HEX_TOKEN.findall(normalized)
            if not canonical_hex(token)
        })
        if unexpected:
            violations.append((path, unexpected))
    if normalized != original:
        if not check_only:
            path.write_text(normalized)
        changed += 1

if check_only and (changed or violations):
    if changed:
        print(f"palette normalization required in {changed} files", file=sys.stderr)
    for path, colors in violations:
        print(f"off-palette color in {path.relative_to(ROOT)}: {', '.join(colors)}", file=sys.stderr)
    raise SystemExit(1)
print(f"normalized palette in {changed} files")
