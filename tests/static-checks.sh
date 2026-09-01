#!/usr/bin/env bash
set -Eeuo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

while IFS= read -r -d '' script; do
    first_line=$(head -n 1 "$script")
    if [[ $first_line == *bash* ]]; then
        bash -n "$script"
    elif [[ $first_line == *'/sh'* ]]; then
        sh -n "$script"
    fi
done < <(find "$ROOT" -type f \( -name '*.sh' -o -perm /111 \) -print0)

python3 -m compileall -q "$ROOT/icons" "$ROOT/widgets" "$ROOT/scripts"
python3 "$ROOT/tests/repository-check.py"
"$ROOT/scripts/normalize-palette.py" --check

if command -v shellcheck >/dev/null 2>&1; then
    shell_files=("$ROOT/install.sh" "$ROOT/uninstall.sh")
    while IFS= read -r -d '' script; do
        [[ $script == "$ROOT/scripts/lib.sh" ]] && continue
        first_line=$(head -n 1 "$script")
        [[ $first_line == *bash* || $first_line == *'/sh'* ]] && shell_files+=("$script")
    done < <(find "$ROOT" -type f -name '*.sh' -print0)
    shellcheck "${shell_files[@]}"
fi

private_home="/home/$USER"
if grep -RIl --exclude-dir=.git --exclude='*.png' "$private_home" "$ROOT" | grep -q .; then
    printf 'Personal home path found in distributable files\n' >&2
    exit 1
fi

printf 'Static checks passed\n'
