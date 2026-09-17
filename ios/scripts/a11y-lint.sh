#!/usr/bin/env bash
# a11y-lint.sh — accessibility lint for CuantoSocials SwiftUI views.
#
# Flags (file:line list, exit 1 on any hit):
#   1. Image(systemName:) with no nearby accessibilityLabel(...) — icon-only
#      labels (bare icons, or the icon inside an icon-only Button) are
#      unreadable by VoiceOver without one.
#   2. Text(...) immediately followed by a fixed .frame(height: <number>) —
#      clips at larger Dynamic Type sizes.
#   3. .font(.system(size: ...)) without relativeTo: — doesn't scale with
#      Dynamic Type.
#
# Allowlist a specific line by ending it with `// a11y-ok`.
#
# Usage: a11y-lint.sh [dir-or-file ...]
#   Defaults to $A11Y_SCOPE (default: ios/App/Features) when no args given.
set -euo pipefail

# Paths (args or $A11Y_SCOPE) are resolved relative to the caller's cwd — the
# acceptance command and gate.sh both invoke this from the repo root with
# repo-relative paths like `ios/App/Features/AI`. No `cd` here.
TARGETS=("$@")
if [ "${#TARGETS[@]}" -eq 0 ]; then
  TARGETS=("${A11Y_SCOPE:-ios/App/Features}")
fi

FILES="$(find "${TARGETS[@]}" -type f -name '*.swift' 2>/dev/null | sort)"

VIOLATIONS=0

report() {
  local file="$1" line="$2" rule="$3" text="$4"
  printf '%s:%s: %s: %s\n' "$file" "$line" "$rule" "$text"
  VIOLATIONS=$((VIOLATIONS + 1))
}

while IFS= read -r file; do
  [ -z "$file" ] && continue

  awk -v file="$file" '
    function trimmed(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }

    { lines[NR] = $0 }

    # Rule 1: Image(systemName:) lacking a nearby accessibilityLabel(...)
    /Image\(systemName:/ && !/\/\/ *a11y-ok/ {
      found = 0
      for (j = NR; j <= NR + 5; j++) {
        if (lines[j] ~ /accessibilityLabel\(/) { found = 1; break }
      }
      if (!found) print NR ":RULE1:" trimmed($0)
    }

    # Rule 3: .font(.system(size:)) without relativeTo:
    /\.font\(\.system\(size:/ && !/relativeTo:/ && !/\/\/ *a11y-ok/ {
      print NR ":RULE3:" trimmed($0)
    }

    END {
      # Rule 2: Text(...) immediately (within 2 lines) followed by a fixed
      # .frame(height: <numeric literal>)
      for (i = 1; i <= NR; i++) {
        if (lines[i] ~ /Text\(/) {
          for (k = i; k <= i + 2 && k <= NR; k++) {
            if (lines[k] ~ /\.frame\(height: *[0-9]/ && lines[k] !~ /\/\/ *a11y-ok/) {
              print k ":RULE2:" trimmed(lines[k])
            }
          }
        }
      }
    }
  ' "$file" > /tmp/a11y-lint-hits.$$ || true
  sort -t: -k1,1n /tmp/a11y-lint-hits.$$ -o /tmp/a11y-lint-hits.$$
  while IFS=: read -r ln rule text; do
    [ -z "$ln" ] && continue
    case "$rule" in
      RULE1) report "$file" "$ln" "icon missing accessibilityLabel" "$text" ;;
      RULE2) report "$file" "$ln" "fixed frame(height:) on a text row" "$text" ;;
      RULE3) report "$file" "$ln" "font(.system(size:)) without relativeTo" "$text" ;;
    esac
  done < /tmp/a11y-lint-hits.$$
  trash /tmp/a11y-lint-hits.$$ 2>/dev/null || rm -f /tmp/a11y-lint-hits.$$
done <<<"$FILES"

if [ "$VIOLATIONS" -gt 0 ]; then
  echo "[a11y-lint] $VIOLATIONS violation(s)" >&2
  exit 1
fi

echo "[a11y-lint] clean"
exit 0
