#!/usr/bin/env bash
# Stage 1 테스트. usage: run.sh   (E2E=1 run.sh → Claude 비대화형 스모크 테스트 포함)
set -uo pipefail
root=$(cd "$(dirname "$0")/../../.." && pwd)
V="$root/.aisdlc/scripts/validate-intent.sh"
H="$root/.claude/hooks/intent-hook.sh"
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
pass=0; fail=0

check() {  # check <이름> <기대 exit> <명령...>
  local name=$1 want=$2; shift 2
  "$@" >/dev/null 2>&1; local got=$?
  if [ "$got" -eq "$want" ]; then pass=$((pass+1)); echo "  PASS $name"
  else fail=$((fail+1)); echo "  FAIL $name (want $want, got $got)"; fi
}

mk() {  # mk <id> → 유효한 intent 경로 출력
  local d="$tmp/intent/$1"; mkdir -p "$d"
  cat > "$d/intent.md" <<EOF
---
id: $1
title: 테스트 intent
author: 테스터 (QA)
status: draft
created: 2026-09-29T10:00:00+0900
---

# Intent: 테스트 intent

## Problem
문제 설명.

## Proposed outcome
기대 결과.

## Affected users and systems
사용자 A, 시스템 B.

## Constraints
제약 없음.

## Success criteria
기준 1.

## Open questions
없음.
EOF
  echo "$d/intent.md"
}

run_hook() {  # run_hook <pre|post> <file_path> <content>
  jq -n --arg p "$2" --arg c "$3" '{tool_name:"Write", tool_input:{file_path:$p, content:$c}}' \
    | CLAUDE_PROJECT_DIR="$root" "$H" "$1"
}

echo "[validate-intent.sh]"
f=$(mk 20260929-valid);            check "유효한 intent 통과" 0 "$V" "$f"
f=$(mk 20260929-no-author);        sed -i '' '/^author:/d' "$f";                        check "author 누락 실패" 1 "$V" "$f"
f=$(mk 20260929-bad-status);       sed -i '' 's/^status: draft/status: done/' "$f";     check "status 값 오류 실패" 1 "$V" "$f"
f=$(mk 20260929-no-section);       sed -i '' '/^## Constraints/,/^제약 없음/d' "$f";     check "섹션 누락 실패" 1 "$V" "$f"
f=$(mk 20260929-empty-section);    sed -i '' '/^기준 1\./d' "$f";                        check "빈 섹션 실패" 1 "$V" "$f"
f=$(mk 20260929-placeholder);      sed -i '' 's/^문제 설명\./{{문제}}/' "$f";            check "플레이스홀더 잔존 실패" 1 "$V" "$f"
f=$(mk 20260929-id-mismatch);      sed -i '' 's/^id: .*/id: 20260929-other/' "$f";      check "id-디렉터리 불일치 실패" 1 "$V" "$f"
f=$(mk 20260929-order);            sed -i '' 's/^## Problem$/## Tmp/; s/^## Open questions$/## Problem/; s/^## Tmp$/## Open questions/' "$f"
                                                                                         check "섹션 순서 오류 실패" 1 "$V" "$f"
f=$(mk 20260929-proposed);         sed -i '' 's/^status: draft/status: proposed/' "$f"; check "require accepted: proposed 실패" 1 "$V" --require-status accepted "$f"
f=$(mk 20260929-accepted);         sed -i '' 's/^status: draft/status: accepted/' "$f"; check "require accepted: accepted 통과" 0 "$V" --require-status accepted "$f"
check "템플릿 원본은 실패 (플레이스홀더)" 1 "$V" "$root/.claude/skills/aisdlc-intent/templates/intent.md"

echo "[intent-hook.sh]"
ip="$tmp/intent/20260929-hook/intent.md"
check "pre: accepted 설정 차단"   2 run_hook pre "$ip" $'---\nstatus: accepted\n---'
check "pre: rejected 설정 차단"   2 run_hook pre "$ip" $'---\nstatus: rejected\n---'
check "pre: proposed 허용"        0 run_hook pre "$ip" $'---\nstatus: proposed\n---'
check "pre: intent 외 파일 무시"   0 run_hook pre "$tmp/other.md" 'status: accepted'
f=$(mk 20260929-post-ok);         check "post: 유효 파일 통과"   0 run_hook post "$f" x
f=$(mk 20260929-post-bad);        sed -i '' '/^title:/d' "$f"
                                  check "post: 무효 파일 exit 2" 2 run_hook post "$f" x

echo "[wiring]"
check "settings.json 유효 JSON + 훅 등록" 0 jq -e '[.hooks.PreToolUse[].hooks[].command, .hooks.PostToolUse[].hooks[].command] | map(test("intent-hook.sh")) | all' "$root/.claude/settings.json"
check "스킬 파일 존재"                    0 test -f "$root/.claude/skills/aisdlc-intent/SKILL.md"
check "스크립트 실행 권한"                0 test -x "$V" -a -x "$H" -a -x "$root/.aisdlc/scripts/intent-metrics.sh"

if [ "${E2E:-0}" = "1" ]; then
  echo "[e2e: claude -p]"
  had_dir=0; [ -d "$root/intent" ] && had_dir=1
  before=$(ls "$root/intent" 2>/dev/null | sort)
  (cd "$root" && claude -p "/aisdlc-intent 비대화형 모드로 질문 없이 작성하세요. 발의자: E2E 테스터 (QA). 문제: 팀원들이 주간 회의록을 각자 다른 형식으로 작성해 검색이 어렵다. 원하는 결과: 표준 형식으로 저장되고 키워드로 검색된다. 제약: 사내 위키만 사용. 성공 기준: 회의록 검색 시간 1분 이내." \
      --permission-mode acceptEdits \
      --allowedTools "Read,Write,Edit,Bash(date:*),Bash(ls:*),Bash(.aisdlc/scripts/validate-intent.sh:*)" >/dev/null 2>&1)
  new=$(comm -13 <(echo "$before") <(ls "$root/intent" 2>/dev/null | sort) | head -n1)
  check "e2e: intent 생성됨" 0 test -n "$new"
  if [ -n "$new" ]; then
    check "e2e: 생성된 intent 검증 통과" 0 "$V" "$root/intent/$new/intent.md"
    rm -rf "${root:?}/intent/$new"
  fi
  [ "$had_dir" -eq 0 ] && rmdir "$root/intent" 2>/dev/null   # 하네스 저장소에는 intent/를 남기지 않음
fi

echo
echo "결과: PASS $pass / FAIL $fail"
[ "$fail" -eq 0 ]
