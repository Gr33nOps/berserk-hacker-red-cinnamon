#!/usr/bin/env python3
"""Validate public repository metadata without network access."""

from __future__ import annotations

import re
import struct
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
REQUIRED = (
    "README.md",
    "LICENSE",
    "CHANGELOG.md",
    "CREDITS.md",
    "THIRD_PARTY.md",
    "docs/GALLERY.md",
    "docs/TROUBLESHOOTING.md",
    "docs/COMPONENTS.md",
    "palette/berserk-red.conf",
)
SCREENSHOTS = (
    "desktop.png",
    "menu.png",
    "launcher.png",
    "nemo.png",
    "terminal.png",
)
TEXT_SUFFIXES = {
    ".css", ".desktop", ".ini", ".js", ".json", ".md", ".py",
    ".rasi", ".service", ".sh", ".theme", ".timer", ".toml",
    ".xml", ".yaml", ".yml",
}
LINK = re.compile(r"!?(?:\[[^]]*\])\(([^)]+)\)")
SECRET_PATTERNS = {
    "GitHub token": re.compile(r"(?:ghp|github_pat)_[A-Za-z0-9_]{20,}"),
    "private key": re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----"),
    "AWS access key": re.compile(r"\bAKIA[0-9A-Z]{16}\b"),
}


def fail(message: str, errors: list[str]) -> None:
    errors.append(message)


def png_size(path: Path) -> tuple[int, int]:
    with path.open("rb") as handle:
        header = handle.read(24)
    if len(header) != 24 or header[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("invalid PNG header")
    return struct.unpack(">II", header[16:24])


def check_links(path: Path, text: str, errors: list[str]) -> None:
    for match in LINK.finditer(text):
        destination = match.group(1).strip().split(maxsplit=1)[0].strip("<>")
        if not destination or destination.startswith(("#", "http://", "https://", "mailto:")):
            continue
        target = destination.split("#", 1)[0]
        if target and not (path.parent / target).resolve().exists():
            fail(f"{path.relative_to(ROOT)}: broken relative link: {destination}", errors)


def main() -> int:
    errors: list[str] = []

    installer = (ROOT / "install.sh").read_text(encoding="utf-8")
    if re.search(r"^\s*(?:run\s+)?(?:sudo|pkexec)\b", installer, re.MULTILINE):
        fail("install.sh must not run privileged commands", errors)

    for relative in REQUIRED:
        if not (ROOT / relative).is_file():
            fail(f"missing required public file: {relative}", errors)

    for name in SCREENSHOTS:
        path = ROOT / "screenshots" / name
        if not path.is_file():
            fail(f"missing gallery screenshot: screenshots/{name}", errors)
            continue
        try:
            width, height = png_size(path)
        except ValueError as error:
            fail(f"screenshots/{name}: {error}", errors)
            continue
        if width < 1200 or height < 675:
            fail(f"screenshots/{name}: too small for gallery ({width}x{height})", errors)

    for path in ROOT.rglob("*"):
        if not path.is_file() or ".git" in path.parts:
            continue
        if path.suffix.lower() not in TEXT_SUFFIXES and path.name not in {
            "LICENSE", ".editorconfig", ".gitignore", ".shellcheckrc"
        }:
            continue
        try:
            content = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue
        if path.suffix.lower() == ".md":
            check_links(path, content, errors)
        for label, pattern in SECRET_PATTERNS.items():
            if pattern.search(content):
                fail(f"{path.relative_to(ROOT)}: possible {label}", errors)

    if errors:
        print("Repository checks failed:", file=sys.stderr)
        for error in errors:
            print(f"  - {error}", file=sys.stderr)
        return 1

    print("Repository checks passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
