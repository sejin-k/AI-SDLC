#!/usr/bin/env bash
# intent.md 구조 검증
# usage: validate-intent.sh [--require-status <status>] <intent.md>
set -uo pipefail

require_status=""
if [ "${1:-}" = "--require-status" ]; then require_status="${2:-}"; shift 2; fi
file="${1:-}"
[ -f "$file" ] || { echo "파일 없음: $file" >&2; exit 1; }

errors=()
err() { errors+=("$1"); }

# frontmatter
[ "$(head -n1 "$file")" = "---" ] || err "frontmatter 누락 (첫 줄 '---')"
fm=$(awk 'NR==1 && /^---$/ {f=1; next} f && /^---$/ {exit} f' "$file")
get() { printf '%s\n' "$fm" | sed -n "s/^$1:[[:space:]]*//p" | head -n1 | sed 's/^"\(.*\)"$/\1/'; }

for k in id title author status created; do
  [ -n "$(get "$k")" ] || err "frontmatter '$k' 누락"
done

status=$(get status)
case "$status" in
  draft|proposed|accepted|rejected|"") ;;
  *) err "status 값 오류: '$status' (draft|proposed|accepted|rejected)" ;;
esac
if [ -n "$require_status" ] && [ "$status" != "$require_status" ]; then
  err "status가 '$require_status'가 아님 (현재: '$status')"
fi

id=$(get id)
dir=$(basename "$(dirname "$file")")
if [ -n "$id" ]; then
  [[ "$id" =~ ^[0-9]{8}-[a-z0-9-]+$ ]] || err "id 형식 오류: '$id' (YYYYMMDD-slug)"
  [ "$id" = "$dir" ] || err "id('$id')와 디렉터리명('$dir') 불일치"
fi

created=$(get created)
if [ -n "$created" ]; then
  [[ "$created" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2} ]] || err "created 형식 오류: '$created'"
fi

# body
body=$(awk 'NR==1 && /^---$/ {f=1; next} f==1 && /^---$/ {f=2; next} f!=1' "$file")
printf '%s\n' "$body" | grep -q '^# Intent: ' || err "'# Intent: <title>' 제목 누락"

prev=0
for s in "Problem" "Proposed outcome" "Affected users and systems" "Constraints" "Success criteria" "Open questions"; do
  line=$(printf '%s\n' "$body" | grep -n -x "## $s" | head -n1 | cut -d: -f1)
  if [ -z "$line" ]; then err "섹션 누락: ## $s"; continue; fi
  [ "$line" -gt "$prev" ] || err "섹션 순서 오류: ## $s"
  prev=$line
  content=$(printf '%s\n' "$body" | awk -v h="## $s" '$0==h {f=1; next} f && /^## / {exit} f' | grep -v '^[[:space:]]*$')
  [ -n "$content" ] || err "섹션 내용 비어있음: ## $s"
done

grep -q '{{' "$file" && err "템플릿 플레이스홀더 '{{...}}' 잔존"

if [ ${#errors[@]} -gt 0 ]; then
  echo "intent 검증 실패: $file" >&2
  for e in "${errors[@]}"; do echo "  - $e" >&2; done
  exit 1
fi
echo "OK: $file"
