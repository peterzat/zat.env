#!/usr/bin/env bash
set -euo pipefail

# Apply a BACKLOG sweep manifest (read from stdin) to BACKLOG.md.
#
# Deterministic counterpart to /spec backlog mode (Step 3f), its
# proposal-consume step (Step 3g), and ACTIVE adoption (Step 4), and to
# /tester design mode. Keeps BACKLOG.md mutations out of LLM-executed
# file edits.
#
# Invocation:
#   spec-backlog-apply.sh <<'MANIFEST'
#   delete: <heading as it appears or appeared in BACKLOG.md>
#   adopt: <heading> | <YYYY-MM-DD>
#   purge-origin: <origin prefix>
#   append: <heading>
#   <entry body lines, verbatim>
#   end-append
#   clear
#   MANIFEST
#
# Heading matching strips any trailing "(ACTIVE in spec YYYY-MM-DD)" on
# both sides, so the manifest may name a heading with or without annotation.
#
# purge-origin removes every entry whose Origin field starts with the
# given prefix (backticks stripped), except entries whose heading carries
# an (ACTIVE in spec ...) annotation. Zero matches is a success; one
# PURGED line is reported per removed entry.
#
# append writes a new entry "### <heading>\n<body>" to BACKLOG.md. The
# body spans every manifest line between "append: <heading>" and the
# next "end-append" line (exact match, no leading whitespace). An
# already-present heading (with or without an ACTIVE annotation) emits
# SKIPPED and no write; otherwise APPENDED and the entry is added. If
# BACKLOG.md does not exist and the manifest has append ops, the file is
# created with the standard `# Backlog` header.
#
# clear (a line on its own, no argument) removes every entry, and any
# `## ` theme subhead left with nothing under it, while keeping every line
# above the first entry: the `# Backlog` header and any notes a project
# put there. A `### ` line inside a fenced code block is not an entry. If
# nothing is left above the first entry, the standard header is written.
#
# Ops run in parse order where independent; across op types the order is
# clear, delete, adopt, purge, append.
#
# Fences are tracked only in the header, above the first `### ` line
# outside a fence: there, a `### ` or `## ` line inside a fenced code block
# is header text, not a heading. From the first entry on, fence lines are
# plain entry text, so an unclosed fence in an entry body cannot hide the
# entries after it.
#
# BACKLOG.md must be a regular file. A symlink (live or dangling) or any
# other non-regular file is refused before any read or write, so a cloned
# repo cannot point the script at a file outside the working tree.

BACKLOG=BACKLOG.md

manifest=$(cat)
[[ -n "$manifest" ]] || exit 0

strip_annot() {
  sed -E 's/ \(ACTIVE in spec [0-9]{4}-[0-9]{2}-[0-9]{2}\)$//'
}

clear=0
deletes=()
adopt_headers=()
adopt_dates=()
purge_prefixes=()
append_headers=()
append_bodies=()
in_append=0
current_header=""
current_body=""
while IFS= read -r line; do
  if [[ "$in_append" -eq 1 ]]; then
    if [[ "$line" == "end-append" ]]; then
      append_headers+=("$current_header")
      append_bodies+=("$current_body")
      in_append=0
      current_header=""
      current_body=""
      continue
    fi
    if [[ -z "$current_body" ]]; then
      current_body="$line"
    else
      current_body+=$'\n'"$line"
    fi
    continue
  fi
  line="${line# }"
  if [[ "${line%"${line##*[![:space:]]}"}" == "clear" ]]; then
    clear=1
    continue
  fi
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
    purge-origin:*)
      prefix="${line#purge-origin:}"
      prefix="${prefix# }"
      prefix="${prefix%"${prefix##*[![:space:]]}"}"
      [[ -n "$prefix" ]] && purge_prefixes+=("$prefix")
      ;;
    append:*)
      hdr="${line#append:}"
      hdr="${hdr# }"
      hdr=$(printf '%s' "$hdr" | strip_annot)
      if [[ -n "$hdr" ]]; then
        in_append=1
        current_header="$hdr"
        current_body=""
      fi
      ;;
  esac
done <<< "$manifest"

if [[ "$in_append" -eq 1 ]]; then
  printf 'ERROR: append block for %s missing end-append delimiter\n' \
    "$current_header" >&2
  exit 1
fi

total_ops=$((clear + ${#deletes[@]} + ${#adopt_headers[@]} + ${#purge_prefixes[@]} + ${#append_headers[@]}))
[[ "$total_ops" -gt 0 ]] || exit 0

if [[ -L "$BACKLOG" ]] || { [[ -e "$BACKLOG" ]] && [[ ! -f "$BACKLOG" ]]; }; then
  printf 'ERROR: %s is a symlink or not a regular file; refusing to touch it\n' \
    "$BACKLOG" >&2
  exit 1
fi

write_header() {
  cat > "$1" <<'HEADER'
# Backlog

Durable register of considered proposals that were deferred, scoped out, or
rejected. Read before drafting a new SPEC.md; swept at turn close.
HEADER
}

count_entries() {
  awk '!body && /^```/{f=!f; next} !f && /^### /{body=1; n++} END{print n+0}' "$BACKLOG"
}

if [[ ! -f "$BACKLOG" ]] && [[ "${#append_headers[@]}" -gt 0 ]]; then
  write_header "$BACKLOG"
fi

if [[ ! -f "$BACKLOG" ]]; then
  printf 'BACKLOG.md not found; skipping %d op(s)\n' "$total_ops" >&2
  exit 0
fi

miss=0

if [[ "$clear" -eq 1 ]]; then
  cleared=$(count_entries)
  tmp=$(mktemp)
  awk '
    /^```/ { fence = !fence }
    !fence && /^### / { exit }
    { pre[++n] = $0 }
    END {
      while (n > 0 && (pre[n] ~ /^[[:space:]]*$/ || pre[n] ~ /^## /)) n--
      for (i = 1; i <= n; i++) print pre[i]
    }
  ' "$BACKLOG" > "$tmp"
  if [[ -s "$tmp" ]]; then
    mv "$tmp" "$BACKLOG"
  else
    rm -f "$tmp"
    write_header "$BACKLOG"
  fi
  printf 'CLEARED: %s entries\n' "$cleared"
fi

# Loop guards use the ${arr[@]+"${arr[@]}"} idiom: bash 3.2 (stock macOS
# /bin/bash) treats an empty array expansion as unset under `set -u`, so an
# unguarded loop crashes whenever a manifest omits that op type. On bash 4.4+
# (every Linux target) the guarded and unguarded forms expand identically.
for target in ${deletes[@]+"${deletes[@]}"}; do
  tmp=$(mktemp)
  if awk -v t="$target" '
    BEGIN { done=0 }
    {
      if (!body && /^```/) fence = !fence
      if (!fence && /^### /) body = 1
      if (!done && !fence && /^### /) {
        hdr=$0
        sub(/^### /, "", hdr)
        sub(/\r$/, "", hdr)
        sub(/ \(ACTIVE in spec [0-9]{4}-[0-9]{2}-[0-9]{2}\)$/, "", hdr)
        if (hdr == t) { deleting=1; done=1; next }
      }
      if (deleting && !fence && (/^### / || /^## /)) { deleting=0 }
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

for i in ${adopt_headers[@]+"${!adopt_headers[@]}"}; do
  target="${adopt_headers[$i]}"
  date="${adopt_dates[$i]}"
  tmp=$(mktemp)
  if awk -v t="$target" -v d="$date" '
    BEGIN { done=0 }
    {
      if (!body && /^```/) fence = !fence
      if (!fence && /^### /) body = 1
      if (!done && !fence && /^### /) {
        hdr=$0
        sub(/^### /, "", hdr)
        sub(/\r$/, "", hdr)
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

for prefix in ${purge_prefixes[@]+"${purge_prefixes[@]}"}; do
  tmp=$(mktemp)
  purged_list=$(mktemp)
  awk -v prefix="$prefix" -v purged_file="$purged_list" '
    function flush_entry() {
      if (!in_entry) return
      should_purge = 0
      if (!has_active) {
        for (i = 1; i <= buf_len; i++) {
          if (buf[i] ~ /\*\*Origin:\*\*/) {
            origin = buf[i]
            sub(/^.*\*\*Origin:\*\*[[:space:]]*/, "", origin)
            gsub(/`/, "", origin)
            sub(/[[:space:]]+$/, "", origin)
            if (index(origin, prefix) == 1) {
              should_purge = 1
              break
            }
          }
        }
      }
      if (should_purge) {
        print entry_heading >> purged_file
      } else {
        for (i = 1; i <= buf_len; i++) print buf[i]
      }
      in_entry = 0
      buf_len = 0
      has_active = 0
      entry_heading = ""
    }
    !body && /^```/ { fence = !fence }
    !fence && /^### / {
      body = 1
      flush_entry()
      in_entry = 1
      entry_heading = $0
      sub(/^### /, "", entry_heading)
      sub(/\r$/, "", entry_heading)
      if (entry_heading ~ / \(ACTIVE in spec [0-9]{4}-[0-9]{2}-[0-9]{2}\)$/) {
        has_active = 1
      }
      buf[++buf_len] = $0
      next
    }
    !fence && /^## / {
      flush_entry()
      print
      next
    }
    in_entry {
      buf[++buf_len] = $0
      next
    }
    { print }
    END { flush_entry() }
  ' "$BACKLOG" > "$tmp"
  mv "$tmp" "$BACKLOG"
  while IFS= read -r purged_heading; do
    printf 'PURGED: %s (origin prefix: %s)\n' "$purged_heading" "$prefix"
  done < "$purged_list"
  rm -f "$purged_list"
done

for i in ${append_headers[@]+"${!append_headers[@]}"}; do
  hdr="${append_headers[$i]}"
  body="${append_bodies[$i]}"
  if awk -v t="$hdr" '
    !body && /^```/ { fence = !fence }
    !fence && /^### / {
      body = 1
      h=$0
      sub(/^### /, "", h)
      sub(/\r$/, "", h)
      sub(/ \(ACTIVE in spec [0-9]{4}-[0-9]{2}-[0-9]{2}\)$/, "", h)
      if (h == t) { found=1; exit }
    }
    END { exit !found }
  ' "$BACKLOG"; then
    printf 'SKIPPED: %s (heading already present)\n' "$hdr"
    continue
  fi
  printf '\n### %s\n%s\n' "$hdr" "$body" >> "$BACKLOG"
  printf 'APPENDED: %s\n' "$hdr"
done

printf 'BACKLOG.md: %s entries\n' "$(count_entries)"

exit "$miss"
