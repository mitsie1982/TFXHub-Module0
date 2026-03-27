#!/bin/bash
# pre-push-check.sh - simple local check to warn about large files before push
THRESHOLD_BYTES=5242880  # 5 MB

# Find files staged for push
FILES=$(git diff --cached --name-only)
OFFENDERS=()

for f in $FILES; do
  if [ -f "$f" ]; then
    size=$(wc -c < "$f" | tr -d ' ')
    if [ "$size" -ge "$THRESHOLD_BYTES" ]; then
      OFFENDERS+=("$f:$size")
    fi
  fi
done

if [ ${#OFFENDERS[@]} -gt 0 ]; then
  echo "Warning: files staged exceed $((THRESHOLD_BYTES/1024/1024)) MB:"
  for o in "${OFFENDERS[@]}"; do
    echo "  - $o"
  done
  echo "Consider using Git LFS: https://git-lfs.github.com/"
  # Do not block push by default; exit 0. To block, exit 1.
  exit 0
fi
exit 0
