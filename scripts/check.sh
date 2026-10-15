#!/usr/bin/env bash
# Checks the docs: provider names only in 09, links and anchors resolve, README lists every doc.
set -euo pipefail
cd "$(dirname "$0")/.."
export LC_ALL=C

fail=0
err() { echo "$*" >&2; fail=1; }

# GitHub heading anchors.
anchors() { grep -E '^#{1,6} ' "$1" | sed -E 's/^#+ //' | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9 _-]//g; s/ /-/g'; }

files=(README.md docs/*.md)

for f in "${files[@]}"; do
  if [ "$f" != docs/09-cloud.md ] && out=$(grep -nwE 'AWS|GCP|Azure|Yandex|Amz|Goog' "$f"); then
    err "$f: cloud provider name outside docs/09-cloud.md:"$'\n'"$out"
  fi

  dir=$(dirname "$f")
  while IFS= read -r link; do
    case $link in http*) continue ;; esac
    path=${link%%#*}
    anchor=
    [[ $link == *#* ]] && anchor=${link#*#}
    target=$f
    [ -n "$path" ] && target=$dir/$path
    if [ ! -e "$target" ]; then
      err "$f: broken link ($link)"
    elif [ -n "$anchor" ] && ! anchors "$target" | grep -qxF -- "$anchor"; then
      err "$f: no heading for ($link)"
    fi
  done < <(grep -oE '\]\([^)]+\)' "$f" | sed -E 's/^\]\(//; s/\)$//')
done

for f in docs/[0-9][0-9]-*.md; do
  grep -qF "]($f)" README.md || err "README.md: $f not in the doc table"
done

[ "$fail" = 0 ] && echo "ok"
exit "$fail"
