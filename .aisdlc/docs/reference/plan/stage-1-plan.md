# Stage 1. Plan 구축 계획

> 근거: `.aisdlc/docs/reference/blog-analysis.md` §3 Stage 1, §4
> 상태: 구축 완료 (v3 — 대상 프로젝트 전용 설정 분리)
>
> **전제**: 본 저장소는 **하네스 개발용**. 구축 결과물을 다른 프로젝트(대상 프로젝트)에 복사해 적용한다.
> 대상 프로젝트 전용 설정(GitHub 라벨·브랜치 보호·`.github/` 파일·`intent/` 폴더)은 본 저장소에 적용하지 않고 `README.md` 적용 가이드로 안내한다.

---

## 1. 목표

- 발의자(originator)가 Claude와 대화하여 **`intent.md`** 를 작성·제출하는 흐름 구축
- 블로그 Stage 1 요구사항 충족

| 블로그 요구사항 | 구현 |
|-----------------|------|
| 조직 템플릿을 **스킬로 인코딩** | `aisdlc-intent` 스킬 + 스킬 내 `templates/intent.md` |
| Claude가 범위·사용자·제약·성공 기준 질문 | 스킬 절차 2 (질문 체크리스트) |
| 발의자가 오해 교정 | 스킬 절차 4 (검토 루프) |
| 버전 관리되는 공유 저장소 (`intent/` 폴더) | `intent/<id>/intent.md` + git |
| PO 승인(merge) / 반려(close) 기록 | PR + `intent` 라벨 + CODEOWNERS + CI 승인 체크 |
| 지표 (리드타임, 생존율) | `intent-metrics.sh` |
| (분석 §4-4) 권고 + 결정 이중 통제 | 스킬(권고) + 훅·검증 스크립트·CI(결정) |
| (분석 §4-5) 직무 분리 | 에이전트의 `accepted`/`rejected` 설정을 훅으로 차단 |
| (블로그 Stage 6) 진단 결과를 Stage 1 포맷으로 | 스킬 **비대화형 모드** |

## 2. 범위

| 포함 | 제외 |
|------|------|
| intent 템플릿, 작성 스킬, 검증 스크립트, 훅, CI 워크플로(배포용), 지표 스크립트, 테스트 | spec.md 자동 생성 잡 (Stage 2) |
| 대상 프로젝트 적용 가이드 (`README.md`) | 비개발자용 커넥터 (claude.ai/Cowork) |
| | 레거시 트래커 연동 (Source of Truth = **repo**) |
| | **본 저장소의 GitHub 설정** (라벨, 브랜치 보호) → 대상 프로젝트에서 수행 |

## 3. 설계

### 3-1. 디렉터리 배치 원칙

| 경로 | 내용 | 대상 프로젝트 배포 |
|------|------|--------------------|
| `.claude/` | Claude Code가 로드하는 파일 (skills, commands, hooks, agents, settings) — **직접 배치** | 동일 경로로 복사 |
| `.aisdlc/scripts/` | 검증·지표 스크립트 | 동일 경로로 복사 |
| `.aisdlc/github/` | 대상 프로젝트 `.github/`에 넣을 파일 (본 저장소에서는 비활성) | `.github/`로 복사 |
| `.aisdlc/tests/`, `.aisdlc/docs/` | 하네스 테스트·문서 | 복사 안 함 (테스트는 선택) |
| `intent/<id>/` | 변경 단위 산출물 (`intent.md` → `spec.md` → `plan.md`) | 대상 프로젝트에서 스킬이 생성 |

### 3-2. 워크플로

```
발의자 설명 ─▶ [aisdlc-intent 스킬] 질문·구체화 ─▶ intent.md 작성 (status: draft)
                                                   │  PreToolUse 훅: accepted/rejected 차단
                                                   │  PostToolUse 훅: 구조 검증
                                                   ▼
                                  발의자 교정 루프 ─▶ status: proposed
                                                   ▼
                        branch intent/<id> → commit → PR (label: intent)
                                                   │  CI: 구조 검증 + PO 승인 체크
                                                   ▼
                    PO가 status: accepted 커밋 후 merge   |   PO가 PR close (반려)
                                                   ▼
                                          Stage 2 입력
```

### 3-3. 상태(status) 전이

| status | 설정 주체 | 의미 |
|--------|-----------|------|
| `draft` | Claude / 발의자 | 작성 중 |
| `proposed` | Claude / 발의자 | 발의자 확인 완료, PR 제출 |
| `accepted` | **PO만** | PO 승인 (PR에서 커밋 후 merge) |
| `rejected` | **PO만** | 반려 기록을 남길 때 (보통은 PR close) |

### 3-4. 저장 규칙

- 경로: `intent/<id>/intent.md` — 이후 `spec.md`, `plan.md`도 같은 디렉터리
- id: `YYYYMMDD-<slug>` (created 날짜 + 영문 kebab-case), 디렉터리명과 일치
- 브랜치: `intent/<id>` / 커밋: `intent: <title>` / PR 라벨: `intent`

### 3-5. 통제 구성

| 통제 | 유형 | 시점 | 구현 |
|------|------|------|------|
| 작성 절차·질문 | 권고 | 작성 중 | `aisdlc-intent` 스킬 |
| 에이전트 자기 승인 차단 | 결정 | Write/Edit 전 | `intent-hook.sh pre` |
| 구조 검증 | 결정 | Write/Edit 후 | `intent-hook.sh post` → `validate-intent.sh` |
| PR 구조 검증 | 결정 | PR | `intent-check.yml` / `validate` job |
| PO 승인 체크 | 결정 | PR | `intent-check.yml` / `po-acceptance` job |
| 리뷰어 지정 | 결정 | PR | `CODEOWNERS` |

### 3-6. 검증 규칙 (`validate-intent.sh`)

1. 첫 줄 `---` frontmatter 존재
2. 필수 키: `id`, `title`, `author`, `status`, `created`
3. `status` ∈ `draft|proposed|accepted|rejected`
4. `id` 형식 `^[0-9]{8}-[a-z0-9-]+$`, 디렉터리명과 일치
5. `created` 형식 `YYYY-MM-DDTHH:MM:SS` 로 시작
6. `# Intent: ` H1 존재
7. 필수 H2 섹션 존재 + 순서 + 내용 비어있지 않음:
   `Problem` → `Proposed outcome` → `Affected users and systems` → `Constraints` → `Success criteria` → `Open questions`
8. 템플릿 플레이스홀더 `{{` 잔존 금지
9. 옵션 `--require-status <s>`: status가 `<s>`가 아니면 실패 (CI 승인 체크용)

> 블로그 템플릿 대비 `Success criteria` 추가 — 브레인스토밍에서 성공 기준을 묻고, Stage 4 검증 목표로 이어지므로

---

## 4. 파일 목록

| # | 작업 | 경로 | 역할 |
|---|------|------|------|
| 1 | 생성 | `.claude/skills/aisdlc-intent/SKILL.md` | 작성 스킬 |
| 2 | 생성 | `.claude/skills/aisdlc-intent/templates/intent.md` | intent 템플릿 (스킬 동봉) |
| 3 | 생성 | `.claude/hooks/intent-hook.sh` | pre/post 훅 |
| 4 | 생성 | `.claude/settings.json` | 훅 등록 |
| 5 | 생성 | `.aisdlc/scripts/validate-intent.sh` | 구조 검증 (훅·CI·사람 공용) |
| 6 | 생성 | `.aisdlc/scripts/intent-metrics.sh` | 지표 |
| 7 | 생성 | `.aisdlc/tests/stage-1/run.sh` | 테스트 |
| 8 | 생성 | `.aisdlc/github/workflows/intent-check.yml` | PR 검증 (배포용) |
| 9 | 생성 | `.aisdlc/github/CODEOWNERS` | PO 리뷰 지정 (배포용, `@<po-github-id>` 플레이스홀더) |
| 10 | 생성 | `CLAUDE.md` | 하네스 구조·규칙 안내 |
| 11 | 수정 | `README.md` | 구조 + **대상 프로젝트 적용 가이드** |
| 12 | 수정 | `.aisdlc/docs/reference/plan/stage-1-plan.md` | 본 문서 (상태 갱신) |
| — | 삭제 | 없음 | |

- 본 저장소에 **생성하지 않는 것**: `intent/` 폴더, `.github/` 파일, GitHub 라벨·브랜치 보호 → README 적용 가이드로 이관

---

## 5. 파일 내용

### 5-1. `.claude/skills/aisdlc-intent/SKILL.md`

````markdown
---
name: aisdlc-intent
description: AI-SDLC Stage 1(Plan). 새 기능·개선 아이디어, 요구사항, 불편, 문제 제기를 intent.md로 작성하고 제출한다. 사용자가 무언가를 만들거나 바꾸고 싶다고 설명할 때, "intent 작성"을 요청할 때, 운영 진단 결과를 intent로 기록할 때 사용.
---

# AI-SDLC Stage 1: Intent 작성

발의자의 의도를 **발의자의 언어로** `intent.md`에 담는다. 설계·구현 방법은 쓰지 않는다 (Stage 2 몫).

## 모드

- **대화형** (기본): 절차 1~6
- **비대화형**: 사람이 응답할 수 없거나(`claude -p`, 자동화) "질문 없이" 요청 시
  - 질문 생략, 확인 불가 항목은 `Open questions`에 기록
  - 절차 1·3·5만 수행, status는 `draft`, 커밋·PR 하지 않음

## 절차

1. **시작 시각 기록**: `date +%Y-%m-%dT%H:%M:%S%z` → `created`
2. **경청 → 질문**: 발의자 설명을 먼저 듣고, 빈 항목만 **한 번에 최대 3개** 질문
   | 항목 | 확인할 것 |
   |------|-----------|
   | Problem | 누가, 언제, 얼마나 자주, 현재 우회 방법, 비용 |
   | Proposed outcome | 해결 후 무엇이 달라지나 |
   | Affected users and systems | 사용자 그룹, 관련 시스템 |
   | Constraints | 보안·규정·기술·일정, 범위 밖 항목 |
   | Success criteria | 성공을 무엇으로 측정하나 |
   - 모든 섹션을 구체적으로 채울 수 있거나 발의자가 충분하다고 하면 종료
   - 금지: 해결책 주도, 기술 스택 결정, 발의자 용어를 전문 용어로 치환
3. **작성**
   - 템플릿 [templates/intent.md](templates/intent.md)를 읽고 모든 `{{...}}`를 채운다
   - `id` = `YYYYMMDD-<영문 kebab-case slug>` (created 날짜), 동일 id 존재 시 slug 변경
   - 저장: `intent/<id>/intent.md`, `status: draft`
   - `author` = 발의자 (Claude 아님)
4. **검토**: 전문을 보여주고 오해·누락 교정 요청 → 반영 반복
5. **검증**: `.aisdlc/scripts/validate-intent.sh intent/<id>/intent.md` 통과 확인
6. **제출** (발의자 확인 후)
   - `status: proposed`로 변경
   - `git switch -c intent/<id>` → `git add intent/<id>/intent.md` → `git commit -m "intent: <title>"`
   - **push·PR 생성 전 발의자 동의 확인**
   - `git push -u origin intent/<id>`
   - `gh pr create --base main --label intent --title "intent: <title>" --body "<Problem 요약 1~2줄>\n\nPO 승인: status를 accepted로 커밋 후 merge / 반려: PR close"`
   - PR 링크 전달

## 규칙

- `status`를 `accepted`/`rejected`로 설정 금지 — PO 전용 (훅이 차단)
- 짧은 문장, 추측 금지 → 불확실하면 `Open questions`
- 한 intent = 한 문제. 여러 문제면 intent 분리 제안
````

### 5-2. `.claude/skills/aisdlc-intent/templates/intent.md`

```markdown
---
id: {{YYYYMMDD-slug}}
title: {{한 줄 제목}}
author: {{발의자 이름 (역할/소속)}}
status: draft
created: {{YYYY-MM-DDTHH:MM:SS+0900}}
---

# Intent: {{title}}

## Problem
{{누가, 어떤 상황에서, 무엇이 불편한가. 빈도·비용 등 수치가 있으면 포함}}

## Proposed outcome
{{해결되면 사용자가 겪는 결과. 구현 방법이 아닌 결과로 기술}}

## Affected users and systems
{{영향받는 사용자 그룹, 시스템·서비스}}

## Constraints
{{반드시 지킬 제약: 보안, 규정, 기술, 일정, 비용, 범위 밖 항목}}

## Success criteria
{{성공 여부를 판단할 측정 가능한 기준}}

## Open questions
{{미해결 질문. 없으면 "없음"}}
```

### 5-3. `.claude/hooks/intent-hook.sh`

```bash
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
```

### 5-4. `.claude/settings.json`

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          { "type": "command", "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/intent-hook.sh pre" }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          { "type": "command", "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/intent-hook.sh post" }
        ]
      }
    ]
  }
}
```

### 5-5. `.aisdlc/scripts/validate-intent.sh`

```bash
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
```

### 5-6. `.aisdlc/scripts/intent-metrics.sh`

```bash
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
```

### 5-7. `.aisdlc/tests/stage-1/run.sh`

```bash
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
```

> macOS 기준 (`sed -i ''`). CI(Linux)에서는 이 테스트를 실행하지 않음.

### 5-8. `.aisdlc/github/workflows/intent-check.yml` (배포용 → 대상 `.github/workflows/`)

```yaml
name: Intent check
on:
  pull_request:
    paths: ['intent/**/intent.md']
jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with: { fetch-depth: 0 }
      - name: Validate changed intents
        run: |
          files=$(git diff --name-only --diff-filter=AM "origin/${{ github.base_ref }}...HEAD" | grep -E '^intent/[^/]+/intent\.md$' || true)
          rc=0
          for f in $files; do .aisdlc/scripts/validate-intent.sh "$f" || rc=1; done
          exit $rc
  po-acceptance:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with: { fetch-depth: 0 }
      - name: Require status accepted
        run: |
          files=$(git diff --name-only --diff-filter=AM "origin/${{ github.base_ref }}...HEAD" | grep -E '^intent/[^/]+/intent\.md$' || true)
          rc=0
          for f in $files; do .aisdlc/scripts/validate-intent.sh --require-status accepted "$f" || rc=1; done
          [ $rc -eq 0 ] || echo "::error::PO 승인 대기 — PO가 status: accepted로 커밋해야 merge 가능"
          exit $rc
```

### 5-9. `.aisdlc/github/CODEOWNERS` (배포용 → 대상 `.github/CODEOWNERS`)

```
# Stage 1: intent 승인자 (Product Owner) — 적용 시 @<po-github-id>를 실제 계정/팀으로 교체
/intent/ @<po-github-id>
```

### 5-10. `CLAUDE.md`

```markdown
# AI-SDLC

AI-native SDLC **하네스 개발** 프로젝트. 결과물은 다른 프로젝트(대상 프로젝트)에 복사해 적용한다 (README 적용 가이드).

## 구조
- `.claude/` Claude Code 파일 (skills, commands, hooks, agents, settings.json) — 심볼릭 링크 없이 직접 배치
- `.aisdlc/scripts/` 검증·지표 스크립트
- `.aisdlc/github/` 대상 프로젝트 `.github/`용 배포 파일 (본 저장소에서는 비활성)
- `.aisdlc/tests/` 스테이지별 테스트
- `.aisdlc/docs/` 참고·계획 문서
- `intent/<id>/` 변경 단위 산출물 — 대상 프로젝트에서 생성 (본 저장소에는 커밋하지 않음)

## 명령
- Stage 1 테스트: `.aisdlc/tests/stage-1/run.sh` (E2E 포함: `E2E=1 .aisdlc/tests/stage-1/run.sh`)
- intent 검증: `.aisdlc/scripts/validate-intent.sh <intent.md>`
- intent 지표: `.aisdlc/scripts/intent-metrics.sh`

## 규칙
- 새 아이디어·요구사항·문제 제기 → `aisdlc-intent` 스킬로 intent.md 작성
- intent status `accepted`/`rejected`는 PO만 변경
- 셸 스크립트는 macOS bash 3.2 호환
- 대상 프로젝트 전용 설정(GitHub 라벨·브랜치 보호·`.github/`)은 본 저장소에 적용하지 않고 README 적용 가이드에 기록
```

### 5-11. `README.md` (수정 — 기존 내용 아래에 추가)

````markdown

## 구조
- `.claude/` Claude Code 스킬·훅·설정
- `.aisdlc/scripts/` 검증·지표 스크립트
- `.aisdlc/github/` 대상 프로젝트 `.github/`용 배포 파일
- `.aisdlc/tests/`, `.aisdlc/docs/` 하네스 테스트·문서

상세: `CLAUDE.md`

## 대상 프로젝트 적용 가이드

### 사전 요구사항
- `jq`, `git`, `gh` (`gh auth login` 완료)
- GitHub 원격 저장소 (`origin`), 기본 브랜치 `main` (다르면 `SKILL.md`의 `--base main` 수정)

### Stage 1. Plan

**1) 파일 복사**

| 하네스 경로 | 대상 프로젝트 경로 | 비고 |
|-------------|--------------------|------|
| `.claude/skills/aisdlc-intent/` | `.claude/skills/aisdlc-intent/` | |
| `.claude/hooks/intent-hook.sh` | `.claude/hooks/intent-hook.sh` | 실행 권한 유지 |
| `.claude/settings.json` | `.claude/settings.json` | 기존 파일 있으면 `hooks` 항목 **병합** |
| `.aisdlc/scripts/validate-intent.sh`, `intent-metrics.sh` | `.aisdlc/scripts/` | 실행 권한 유지 |
| `.aisdlc/github/workflows/intent-check.yml` | `.github/workflows/intent-check.yml` | |
| `.aisdlc/github/CODEOWNERS` | `.github/CODEOWNERS` | `@<po-github-id>` 교체, 기존 파일 있으면 병합 |
| `.aisdlc/tests/stage-1/` (선택) | `.aisdlc/tests/stage-1/` | 적용 확인용 |

```bash
H=<하네스 경로>; T=<대상 프로젝트 경로>
mkdir -p "$T/.claude/skills" "$T/.claude/hooks" "$T/.aisdlc/scripts" "$T/.github/workflows"
cp -R "$H/.claude/skills/aisdlc-intent" "$T/.claude/skills/"
cp -p "$H/.claude/hooks/intent-hook.sh" "$T/.claude/hooks/"
cp -p "$H/.aisdlc/scripts/validate-intent.sh" "$H/.aisdlc/scripts/intent-metrics.sh" "$T/.aisdlc/scripts/"
cp "$H/.aisdlc/github/workflows/intent-check.yml" "$T/.github/workflows/"
[ -f "$T/.claude/settings.json" ] || cp "$H/.claude/settings.json" "$T/.claude/"   # 있으면 수동 병합
[ -f "$T/.github/CODEOWNERS" ]   || cp "$H/.aisdlc/github/CODEOWNERS" "$T/.github/" # 있으면 수동 병합
```

**2) GitHub 설정 (대상 저장소에서)**

| 작업 | 방법 | 필수 |
|------|------|------|
| `intent` 라벨 생성 | `gh label create intent --color 0E8A16 --description "Stage 1 intent"` | 필수 (스킬이 PR에 부착) |
| CODEOWNERS PO 지정 | `.github/CODEOWNERS`의 `@<po-github-id>` 교체 | 필수 |
| 브랜치 보호 (`main`) | Settings → Branches: required checks `validate`, `po-acceptance` + Require review from Code Owners | 권장 |

**3) `CLAUDE.md`에 규칙 추가**

```markdown
## AI-SDLC
- 새 아이디어·요구사항·문제 제기 → `aisdlc-intent` 스킬로 `intent/<id>/intent.md` 작성
- intent status `accepted`/`rejected`는 PO만 변경
```

**4) 확인**
- (선택) `.aisdlc/tests/stage-1/run.sh` → `FAIL 0`
- 새 Claude Code 세션에서 `/aisdlc-intent` 실행 → 질문·작성·PR 생성 확인

### Stage 1 사용 흐름
1. Claude Code에서 아이디어·문제를 설명하거나 `/aisdlc-intent` 실행
2. Claude의 질문에 답하며 `intent.md` 구체화 → 교정
3. Claude가 `intent/<id>` 브랜치로 PR 생성 (label: `intent`)
4. PO 승인: PR에서 `status: accepted` 커밋 후 merge / 반려: PR close
````

---

## 6. 구축 순서

1. 파일 1, 2, 3, 5, 6 생성
2. `chmod +x .claude/hooks/*.sh .aisdlc/scripts/*.sh .aisdlc/tests/stage-1/run.sh`
3. 파일 4 (settings.json) 생성
4. 파일 7, 8, 9, 10 생성, 11 수정
5. 본 문서 상태 → `구축 완료`

> GitHub 라벨·브랜치 보호 등 대상 프로젝트 설정은 수행하지 않음 (README 가이드)

## 7. 테스트

| 단계 | 명령 | 통과 기준 |
|------|------|-----------|
| 단위·훅·연결 | `.aisdlc/tests/stage-1/run.sh` | `FAIL 0` (20건) |
| E2E 스모크 | `E2E=1 .aisdlc/tests/stage-1/run.sh` | Claude가 비대화형으로 intent 생성 + 검증 통과 (생성물은 자동 삭제) |
| 지표 | `.aisdlc/scripts/intent-metrics.sh` | 오류 없이 실행 (intent 없음 → 헤더만 출력) |

- 대화형 흐름(질문 → 교정 → PR)은 대상 프로젝트 적용 후 수동 확인
- E2E 생성물과 `intent/` 폴더는 테스트 후 자동 삭제 (하네스 저장소에 남기지 않음)

## 8. 완료 기준

- [x] 11개 파일 생성·수정 완료, 실행 권한 부여
- [x] 단위·훅·연결 테스트 전부 통과
- [x] E2E 스모크 통과
- [x] 본 문서 상태 갱신
