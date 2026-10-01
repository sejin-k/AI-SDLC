#!/usr/bin/env bash
# Stage 1 지표: intent별 리드타임(created → 첫 커밋), status 분포, PR 생존율
# usage: intent-metrics.sh
set -uo pipefail
root=$(git rev-parse --show-toplevel)
cd "$root"

to_epoch() {  # ISO 8601 (+0900 형식) → epoch
  date -j -f "%Y-%m-%dT%H:%M:%S%z" "$1" +%s 2>/dev/null || date -d "$1" +%s 2>/dev/null
}

printf '%-40s %-10s %-26s %s\n' "ID" "STATUS" "CREATED" "LEAD(h)"
for f in intent/*/intent.md; do
  [ -f "$f" ] || continue
  id=$(basename "$(dirname "$f")")
  status=$(sed -n 's/^status:[[:space:]]*//p' "$f" | head -n1)
  created=$(sed -n 's/^created:[[:space:]]*//p' "$f" | head -n1)
  first=$(git log --diff-filter=A --format=%at -- "$f" | tail -n1)
  lead="-"
  c=$(to_epoch "$created")
  if [ -n "$first" ] && [ -n "$c" ]; then lead=$(awk -v a="$first" -v b="$c" 'BEGIN{printf "%.1f", (a-b)/3600}'); fi
  printf '%-40s %-10s %-26s %s\n' "$id" "$status" "$created" "$lead"
done

if command -v gh >/dev/null 2>&1; then
  echo
  echo "PR (label: intent)"
  gh pr list --label intent --state all --limit 500 --json state \
    --jq 'group_by(.state) | map("  \(.[0].state): \(length)") | .[]' 2>/dev/null || echo "  (gh 조회 실패)"
  echo "  생존율 = MERGED / (MERGED + CLOSED)"
fi
