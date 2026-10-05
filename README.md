# AI-SDLC

AI를 활용한 SDLC 시스템을 구축하는 프로젝트.


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

&lt;TEST TEXT&gt;
