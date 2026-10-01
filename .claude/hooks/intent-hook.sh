#!/usr/bin/env bash
# Stage 1 intent.md 가드레일
#   pre : 에이전트가 status를 accepted/rejected로 설정하는 것 차단 (PO 전용)
#   post: 저장된 intent.md 구조 검증
# usage: intent-hook.sh pre|post   (stdin: Claude Code hook JSON)
set -uo pipefail
mode="${1:-}"
input=$(cat)
path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')

case "$path" in
  intent/*/intent.md|*/intent/*/intent.md) ;;
  *) exit 0 ;;
esac

root="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"

case "$mode" in
  pre)
    new=$(printf '%s' "$input" | jq -r '.tool_input.content // .tool_input.new_string // empty')
    if printf '%s\n' "$new" | grep -qE '^status:[[:space:]]*"?(accepted|rejected)'; then
      echo "차단: intent status를 accepted/rejected로 설정하는 것은 Product Owner만 할 수 있습니다. status는 draft 또는 proposed로 두고 PR로 승인을 요청하세요." >&2
      exit 2
    fi
    ;;
  post)
    if ! out=$("$root/.aisdlc/scripts/validate-intent.sh" "$path" 2>&1); then
      printf '%s\n템플릿(.claude/skills/aisdlc-intent/templates/intent.md)에 맞게 수정 후 다시 저장하세요.\n' "$out" >&2
      exit 2
    fi
    ;;
esac
exit 0
