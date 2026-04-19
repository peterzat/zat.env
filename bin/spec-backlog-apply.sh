#!/usr/bin/env bash
set -euo pipefail

# Apply a BACKLOG sweep manifest (read from stdin) to BACKLOG.md.
#
# Deterministic counterpart to the /spec skill's proposal-consume step
# (Step 3g). Keeps BACKLOG.md mutations out of LLM-executed file edits.
#
# Invocation:
#   spec-backlog-apply.sh <<'MANIFEST'
#   delete: <heading as it appears or appeared in BACKLOG.md>
#   adopt: <heading> | <YYYY-MM-DD>
#   MANIFEST
#
# Heading matching strips any trailing "(ACTIVE in spec YYYY-MM-DD)" on
# both sides, so the manifest may name a heading with or without annotation.

BACKLOG=BACKLOG.md

manifest=$(cat)
[[ -n "$manifest" ]] || exit 0

strip_annot() {
  sed -E 's/ \(ACTIVE in spec [0-9]{4}-[0-9]{2}-[0-9]{2}\)$//'
}

deletes=()
adopt_headers=()
adopt_dates=()
while IFS= read -r line; do
  line="${line# }"
  case "$line" in
    delete:*)
      hdr="${line#delete:}"
      hdr="${hdr# }"
      hdr=$(printf '%s' "$hdr" | strip_annot)
      [[ -n "$hdr" ]] && deletes+=("$hdr")
      ;;
    adopt:*)
      spec_line="${line#adopt:}"
      spec_line="${spec_line# }"
      hdr="${spec_line% | *}"
      date="${spec_line##* | }"
      hdr=$(printf '%s' "$hdr" | strip_annot)
      if [[ -n "$hdr" && -n "$date" && "$hdr" != "$date" ]]; then
        adopt_headers+=("$hdr")
        adopt_dates+=("$date")
      fi
      ;;
  esac
done <<< "$manifest"

total_ops=$((${#deletes[@]} + ${#adopt_headers[@]}))
[[ "$total_ops" -gt 0 ]] || exit 0

if [[ ! -f "$BACKLOG" ]]; then
  printf 'BACKLOG.md not found; skipping %d op(s)\n' "$total_ops" >&2
  exit 0
fi

miss=0

for target in "${deletes[@]}"; do
  tmp=$(mktemp)
  if awk -v t="$target" '
    BEGIN { done=0 }
    {
      if (!done && /^### /) {
        hdr=$0
        sub(/^### /, "", hdr)
        sub(/ \(ACTIVE in spec [0-9]{4}-[0-9]{2}-[0-9]{2}\)$/, "", hdr)
        if (hdr == t) { deleting=1; done=1; next }
      }
      if (deleting && (/^### / || /^## /)) { deleting=0 }
      if (!deleting) print
    }
    END { exit !done }
  ' "$BACKLOG" > "$tmp"; then
    mv "$tmp" "$BACKLOG"
    printf 'DELETED: %s\n' "$target"
  else
    rm -f "$tmp"
    printf 'MISS: delete: %s (heading not found)\n' "$target" >&2
    miss=1
  fi
done

for i in "${!adopt_headers[@]}"; do
  target="${adopt_headers[$i]}"
  date="${adopt_dates[$i]}"
  tmp=$(mktemp)
  if awk -v t="$target" -v d="$date" '
    BEGIN { done=0 }
    {
      if (!done && /^### /) {
        hdr=$0
        sub(/^### /, "", hdr)
        sub(/ \(ACTIVE in spec [0-9]{4}-[0-9]{2}-[0-9]{2}\)$/, "", hdr)
        if (hdr == t) {
          print "### " t " (ACTIVE in spec " d ")"
          done=1
          next
        }
      }
      print
    }
    END { exit !done }
  ' "$BACKLOG" > "$tmp"; then
    mv "$tmp" "$BACKLOG"
    printf 'ANNOTATED: %s (ACTIVE in spec %s)\n' "$target" "$date"
  else
    rm -f "$tmp"
    printf 'MISS: adopt: %s (heading not found)\n' "$target" >&2
    miss=1
  fi
done

count=$(awk '/^```/{f=!f; next} !f && /^### /{n++} END{print n+0}' "$BACKLOG")
printf 'BACKLOG.md: %s entries\n' "$count"

exit "$miss"
