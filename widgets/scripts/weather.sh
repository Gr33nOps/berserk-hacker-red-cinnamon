#!/bin/bash
# compact weather: temp + condition + humidity via wttr.in (auto location)
out="$(curl -sf --max-time 4 "https://wttr.in/?format=%t+%C+%h" 2>/dev/null)"
if [ -n "$out" ]; then
  echo "$out"
else
  echo "n/a"
fi