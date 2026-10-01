# The AI-Native SDLC Playbook 분석

> 원문: https://claude.com/blog/the-ai-native-sdlc-playbook
> 저자: Louis Claxton · 2026-08-21 · Enterprise AI / Claude Code

---

## 1. 핵심 전제

- **코드는 더 이상 병목이 아니다** — 에이전트가 Build 단계를 주/월 → 시간 단위로 압축
- 그 결과 세 가지 문제 발생
  1. 병목이 Build의 **좌측(Plan·Design)** 과 **우측(Test·Deploy·Maintain)** 으로 이동
  2. 기존 통제(control)가 실제 속도와 맞지 않아 운영 불가
  3. 예외 처리가 주/월 단위 회의·위원회를 거치므로 거버넌스 비용 증가
- 해법: 기존 **통제 목표는 유지**하되 **집행 메커니즘을 교체** (회의·서명 → 스킬·훅·리뷰·eval)

## 2. AI-Native SDLC 정의

| 구분 | 내용 |
|------|------|
| 구조 | 선형 핸드오프 → **루프** (각 단계에 AI 내장) |
| 단계 간 연결 | 버전 관리에 커밋된 **산출물(artifact)** 로 자동 핸드오프·트리거 |
| 사람의 역할 | 판단이 필요한 의사결정 지점에서 책임 유지 |
| 감사 추적 | "**커밋이 곧 감사 기록**" — 누가 요청했고, 에이전트가 무엇을 만들었고, 누가 승인했는지 |

### 단계별 비교

| 단계 | 기존 SDLC | AI-Native SDLC | 산출물 |
|------|-----------|----------------|--------|
| 1. Plan | 위원회·워크숍·수기 요구사항 | Claude가 문제를 `intent.md`로 합성 | `intent.md` |
| 2. Design | 분석가 명세 → 디자이너 해석 | 요구사항+설계를 1회 세션으로 압축 (스킬 가이드) | `spec.md` |
| 3. Build | 수기 코드·테스트, 문서는 사후 | AI가 코드·테스트 생성, 지식은 `CLAUDE.md`로 버전 관리 | `plan.md`, diff+tests |
| 4. Test | 단계 경계의 QA 게이트 | 구현 중 연속 eval | 테스트 출력, eval 결과 |
| 5. Deploy | 사람이 모든 라인 리뷰 | 다층 에이전트 리뷰, 사람은 규제·핵심 코드에 집중 | PR 리뷰 findings |
| 6. Maintain | 사람이 운영 감시 | 에이전트가 모니터링, 이탈 시 새 `intent.md` 작성 | 새 `intent.md` |

---

## 3. 단계별 상세

### Stage 1. Plan — `intent.md`로 의도 포착

- **목적**: 발의자(originator)의 의도를 핸드오프 손실 없이 원형 그대로 기록 (proto-spec)
- **절차**
  1. 발의자가 자기 말로 문제 설명
  2. Claude가 범위·사용자·제약·성공 기준 질문하며 구체화
  3. 조직 템플릿(**스킬로 인코딩**, 리드 승인)으로 `intent.md` 작성
  4. 발의자가 오해 교정
  5. 공유 저장소(예: 제품 repo의 `intent/`)에 커밋
- **인프라**: 비개발자용 Claude(claude.ai/Cowork), 합의된 템플릿, PO가 감시하는 버전 관리 디렉터리, 비개발자 커밋용 VCS 커넥터
- **템플릿 섹션**: `Problem` / `Proposed outcome` / `Affected users and systems` / `Constraints` / `Open questions` (+ Author, Status)
- **거버넌스**: 작성자·타임스탬프·이력 = git / PO가 승인(merge) 또는 반려(close)
- **지표**
  - 선행: 첫 대화 → `intent.md` 커밋 소요 시간 (주 → 시간)
  - 후행: Stage 2 진입 생존율, 첫 `spec.md` 커밋 이후 `intent.md` 변경 횟수

### Stage 2. Design — 요구사항 + 설계 통합

- **목적**: 분리된 요구사항/설계 단계를 **스킬로 제약된 단일 세션**으로 통합
- **절차**
  1. PO가 조직 스킬 로드 + `intent.md` 첨부하여 세션 시작
  2. 제약 명시·우려사항 플래그 요구 → 이후 **조직 슬래시 커맨드**로 코드화
  3. `intent.md` 승인 시 **비대화형 잡**이 자동 실행 → `spec.md`를 PR로 커밋
  4. PO가 intent 대비 spec 검토 (문제 해결 여부, Open questions 처리 여부)
  5. 플래그된 우려사항을 **정책 소유자**와 먼저 해결 (엔지니어링 전달 전)
  6. `spec.md`를 `intent.md` 옆에 커밋
  7. PO가 Build 진행 결정 (고위험은 테크 리드 자문)
- **핵심 프롬프트 요소**: intent 읽기 → 기존 코드베이스 통합 설계 → 브랜드·보안·UX 스킬 적용 → `spec.md` 작성 → 상충 정책 등 우려사항 명시
- **거버넌스**: 정책을 리뷰 시점이 아닌 **작성 시점에 적용** / spec·프롬프트·스킬 버전 기록
- **지표**
  - 선행: `intent.md` 커밋 → `spec.md` 커밋 경과 시간
  - 후행: 첫 `plan.md` 커밋 이후 `spec.md` 커밋 수 (요구사항 재작업)

### Stage 3. Build

#### 3-1. Plan Mode → `plan.md`

- 코드 작성 전 **plan mode**(읽기 전용)로 구현 계획 작성 → 엔지니어가 교정 → 승인본 커밋
- **절차**
  1. plan mode로 세션 시작, `intent.md` + `spec.md` 제공
  2. 요구 항목: 변경 파일, 작업 순서, 증명할 테스트
  3. 질의: 무엇이 깨질 수 있나, 가장 위험한 단계는, 대안은
  4. 대화 맥락 모르는 엔지니어도 구현 가능할 때까지 반복
  5. `plan.md` 커밋 → 구현 (대개 1-pass)
  6. 구현이 계획과 달라지면 **같은 커밋에서 `plan.md` 갱신** (훅으로 동기화 강제 고려)
- **템플릿 섹션**: `Files that change` / `Order of work` / `Risks` / `Proof`
- **거버넌스**: 코드 생성 전 설계 리뷰 — plan mode 자체가 승인 전 편집을 차단
- **지표**: 1차 구현 머지 비율, 계획 승인→머지 시간 / 변경당 재작업 횟수, 머지 diff와 `plan.md` 일치율

#### 3-2. Auto Mode

- 계획 승인 후 편집별 확인 없이 적용
- 가드레일(`CLAUDE.md` 튜닝, 정책 스킬, 차단 훅, 테스트 스위트) 성숙 시 루틴 작업의 **기본값**으로

#### 3-3. Source of Truth (레거시 시스템 공존)

| 방식 | 설명 |
|------|------|
| Repo 기준 | Markdown이 권위, 레거시는 사본/링크 |
| 레거시 기준 | Jira·ServiceNow가 원본, Markdown은 작업본 → MCP로 역기록 |
| 최소 요건 | 산출물엔 레코드 ID, 레거시 레코드엔 커밋 SHA 상호 연결 |

#### 3-4. `CLAUDE.md` — 팀 컨텍스트

- 신규 입사자 Day 1 컨텍스트: 명령어, 컨벤션, 아키텍처, 반복 실수
- **규칙**
  - `/init`으로 생성 후 필요한 것만 남김
  - repo 루트에 커밋
  - **같은 실수 2회 → `CLAUDE.md`에 교정 추가**
  - **1페이지 이내** (세션 시작 시 전체 로드)
- **섹션**: `Commands` / `Conventions` / `Architecture` / `Things Claude gets wrong`
- **지표**: `CLAUDE.md`가 막았어야 할 실수 반복 빈도 / 신규 멤버 첫 머지 PR까지 시간

#### 3-5. Skills — 제도적 지식

- 일관 적용이 필요한 지식을 명시화·버전 관리·중앙 갱신 (단, `CLAUDE.md`/프롬프트에 속할 내용은 제외)
- **구조**: `.claude/skills/<name>/SKILL.md` (frontmatter: `name`, `description`=트리거 조건 / body: 수행 지침) 또는 플러그인으로 조직 배포
- **절차**: 일관성 없는 지식 1개 선정 → 스킬화 → 다양한 표현으로 트리거 테스트 → 정책 변경 시 스킬 수정(정책 소유자 승인) → 다음 세션에 자동 반영
- **예시** `secure-api-review`: JWT 인증 필수, OpenAPI 스키마 검증, 상태변경 시 감사 이벤트, PII 로그 금지, 검사 스크립트 실행 결과 첨부
- **한계**: 스킬은 **권고형(advisory) 통제** — 반드시 지켜야 할 정책은 **결정적 레이어(훅/PR 리뷰)** 로 보강
- **지표**: 정책 승인→스킬 머지 시간 / 해당 정책 인용 PR 리뷰 findings (→ 0 수렴)

#### 3-6. Hooks — 빌드 타임 가드레일

- 스킬 = 권고, **훅 = 결정적**
- 용도: 보호 경로 편집 차단(생성 코드, 동결 패키지), 편집 후 포매터·린터, 자격증명 diff 유입 방지
- 원칙: **빠르고 범위 한정**. 무거운 검사(전체 테스트)는 커밋/PR 단계로
- 사람 승인을 묻는 훅은 **Stage 5**로 (병렬 세션 전체의 크리티컬 패스에 사람을 넣게 되므로)

#### 3-7. 병렬 세션 & 서브에이전트

| 구분 | 병렬 세션 | 서브에이전트 |
|------|-----------|--------------|
| 정의 | 별도 git worktree의 독립 Claude Code 인스턴스 | 세션 내부의 범위 한정 헬퍼 (별도 컨텍스트·도구 제한) |
| 용도 | 파일이 겹치지 않는 독립 작업 | 여러 작업에 반복되는 잡 (예: 앱 실행 검증) |
| 실행 | `claude --worktree <name>` | `.claude/agents/<name>.md` (name, description, tools) |

- 시작은 **2~3 세션**, 상한 = 한 사람이 제대로 리뷰 가능한 스트림 수
- 파일 공유 작업은 한 세션에서 순차 처리
- 예시 `verifier` 서브에이전트: `tools: Bash, Read`, `make run` 후 변경·인접 흐름 확인, **보고만 하고 수정 금지**
- **거버넌스**: 통제는 repo 설정(훅·권한)에서, 세션 행위는 실행 엔지니어에게 귀속
- **지표**: 리뷰 품질 유지 시 엔지니어당 동시 세션 수(OpenTelemetry) / 주당 머지 수 + 재작업률

### Stage 4. Test — 피드백 루프 제공

- **목적**: 사람이 보기 전에 에이전트가 **스스로 검증**하고 통과할 때까지 반복
- **절차**
  1. 검증을 단일 타깃으로 래핑 (`make test`, 실패 시 non-zero exit)
  2. `CLAUDE.md` Commands에 명령 + 정상 출력 예시
  3. 정량적 완료 기준 명시 ("test_status.py 전부 통과", "스크린샷이 목업과 일치")
  4. **버그 수정 = 실패 테스트 우선**: 재현 테스트 작성 → 올바른 이유로 실패 확인 → 커밋 → 테스트 수정 없이 통과시키기
  5. UI: 브라우저/스크린샷 도구 + 목업으로 시각 검증 (2~3 라운드 정상)
  6. 검증을 "완료" 정의에 포함 (출력 붙여넣기)
  7. 수정 작업 중 **테스트 파일 편집을 훅으로 차단** (또는 리뷰에서 거부)
- **거버넌스**: 증거는 툴체인의 실제 출력 / 세션 로그는 OpenTelemetry로 전송, PR check run에 기록 / 코드 오너는 의도·리스크에 집중
- **지표**: 에이전트 변경의 CI 1차 통과율 / PR당 리뷰 시간, 변경 실패율

#### 4-1. Continuous Evals in CI

- **stage-gate QA의 AI-native 대체** — 에이전트 **설정**(모델, 프롬프트, `CLAUDE.md`, 스킬, 훅)이 바뀔 때 품질 유지 여부 검증
- 살아있는 스위트: 모델 향상으로 변별력 잃은 케이스 교체, 모니터링에서 신규 추가
- **절차**
  1. 최근 실제 작업 **20~50개** + 기대 결과 수집
  2. eval = 프롬프트 + 수용 기준 체크 (테스트 통과, 린트, 동작 불변, 정책 준수)
  3. CI에서 **스케줄 + `CLAUDE.md`/`.claude/**` 변경 시** 비대화형 실행
  4. 결과로 설정 변경 게이트 (통과율 하락 시 리뷰)
  5. **모든 운영 장애 → eval**로 영구 회귀 테스트화
- **구현**: `.github/workflows/agent-evals.yml` — `claude -p "<prompt>" --allowedTools "..." --output-format json` → `evals/check.sh`
- **지표**: eval 통과율 추이, 장애→eval 전환 시간 / CI vs 운영에서 발견된 회귀 비율

### Stage 5. Deploy — 리뷰와 게이팅

#### 5-1. AI PR 리뷰 루프

- 모든 PR에 동일한 리뷰 패스 적용, 심각도순 정렬 → 사람은 **계획 부합 여부·리스크 수용성**에 집중
- **구현 옵션**: 관리형 Code Review 서비스 (빠른 시작) / `claude-code-action`으로 자체 CI (통제·자체 클라우드 계약)
- **`REVIEW.md`** (repo 루트, 테크 리드 작성)
  - Passes: **Bugs / Security / Compliance**(`spec.md`·`plan.md`·설계 원칙 대비)
  - Important 정의: 동작 파괴·데이터 유출·정책 위반만. 스타일은 Nit
  - Nit 최대 5개, 나머지는 개수만
  - 제외: 생성 파일, CI가 이미 강제하는 것
- **운영 규칙**
  - findings는 단독으로 승인/차단하지 않음 — **브랜치 보호의 코드 오너 승인 필수**
  - 심각도 집계를 머신리더블로 발행 → 머지 게이트 가능
  - `@claude` 태그 → 수정 푸시 / Claude가 연 PR은 머지까지 **babysit** (코멘트·실패 체크 해결 반복)
  - 리뷰에서 2회 지적된 실수 → `CLAUDE.md` 반영, `CLAUDE.md` 노후화도 지적
  - 월 1회 finding 평가·Nit 상한 튜닝
- **거버넌스**: **직무 분리** — 코드를 쓴 에이전트는 승인 불가 / PR이 감사 기록
- **지표**: 첫 리뷰까지 시간(분 단위), 사람 개입 없이 해결된 코멘트 비율 / 머지 전 vs 운영 유출 결함

#### 5-2. Hooks as Approval Gates

- 빌드 훅 = allow/block, 배포 훅 = **ask**(특정인 승인까지 정지) 추가
- **절차**: 리더십+변경관리+컴플라이언스가 승인 게이트 목록화 → 플랫폼 엔지니어가 훅으로 구현 → 팀 훅은 `.claude/settings.json`, 필수 훅은 **managed settings**(엔지니어 비활성화 불가) → 차단 시 **사유와 승인 경로 출력**
- **구현**: `PreToolUse` + `matcher: Bash` → `production-gate.sh` (`deploy`+`production` 명령에 `RELEASE_APPROVAL` 없으면 `exit 2`로 차단, stderr 메시지가 Claude에 전달)
- **지표**: 게이트별 대기 시간(OTel) / 훅 도입 전후 운영 도달 게이트 위반

#### 5-3. Managed Settings (규제 기업 예시)

MDM/관리 콘솔 배포, 엔지니어 수정 불가.

| 설정 | 통제 목적 |
|------|-----------|
| `permissions.deny` (`.env*`, `secrets/**`, WebFetch, curl, wget) | 비밀 정보 차단, 임의 네트워크 반출 차단 |
| `permissions.allow` (git, make build/test/lint) | 안전한 inner loop 사전 승인 |
| `disableBypassPermissionsMode` + `allowManagedPermissionRulesOnly` | 누구도 규칙 확장 불가 |
| `sandbox` (`allowedDomains`) | OS 레벨 도메인 허용목록 |
| `failIfUnavailable` + `allowUnsandboxedCommands: false` | 샌드박스 실패 시 실행 거부 |
| `sandbox.credentials` (`~/.ssh`, `~/.aws/credentials`, `GITHUB_TOKEN`) | 자격증명 파일·환경변수 차단 |
| `allowManagedHooksOnly` | 관리 훅만 허용 |
| `disableSideloadFlags` + `strictKnownMarketplaces` | 스킬·에이전트·훅·MCP는 승인 마켓플레이스 경유만 |
| `allowManagedMcpServersOnly` | MCP 도구 표면을 플랫폼팀 허용목록으로 |
| `requiredMinimumVersion` | 최소 버전 미만 실행 거부 |

#### 5-4. CI/CD 통합 및 배포

- **원칙: 에이전트는 운영 게이트까지 행동할 수 있으나 통과할 수 없다**
- **단계적 도입**
  1. 읽기 전용 판단 (`claude -p`로 빌드 실패 triage, flaky 요약, changelog 초안)
  2. 기존 게이트 뒤의 쓰기 작업 (린트 수정, 문서 갱신, `@claude` 대응) — 모두 PR로
  3. 샌드박스 실행: 컨테이너 + 네트워크 정책 + 단기 범위 토큰, 운영 자격증명 없음
  4. 배포를 **MCP 도구**로 노출 (deploy/status/rollback, 환경별 범위)
  5. **환경별 자율성 계층**: dev 자유 배포 / staging 중간 / prod는 준비만, 릴리스 매니저 승인 (훅 강제)
  6. **롤백 리허설 최우선** — Stage 6 루프가 호출
- **지표**: 사람 호출 없이 triage된 파이프라인 실패 비율 / DORA 지표

### Stage 6. Maintain — 루프 닫기

#### 6-1. 모니터링 & Control Band

- 트리거(control band 이탈, 티켓, 채널 메시지, 스케줄)가 **사람 없이 Claude 호출** → 진단 → 게이트된 경로로만 행동 → 결과를 `intent.md`로 작성 → Stage 1 재진입
- **절차**
  1. 안정적 rolling baseline 지표 1개 선정 (CI 실패율, 배포 후 5xx, PR 사이클 타임)
  2. **결정적 탐지 스크립트** (rolling 평균·표준편차 + Western Electric 규칙, 모델 미사용, 버전 관리·단위 테스트)
  3. `bands.yaml`에 대응 계층 정의
  4. 트리거: GitHub/GitLab 스케줄, 모니터링 웹훅, 사내 Cron / 실행: CI 러너 비대화형 또는 샌드박스 Agent SDK 서비스 (stateless)
  5. 진단을 Stage 1 포맷 `intent.md`로 작성
  6. 서비스 오너/온콜이 triage (지금 수정 / 일정화 / 기각 → 기각은 밴드 튜닝)
  7. 수정 배포 시 해당 장애를 eval로 추가

| 계층 | 행동 | 권한 |
|------|------|------|
| 1σ | log | 없음 |
| 2σ | diagnose | 읽기 전용 (`Read,Grep,Bash(gh run view *)`) |
| 3σ | propose | PR 생성 또는 사전 승인된 runbook (`rollback-deploy`) |

- **예시**: CI 실패율 3σ → flaky 격리/revert PR / 배포 직후 5xx 3σ → 롤백 파이프라인 / PR 사이클 타임 drift → 리더십 보고서
- **지표**: 이탈→`intent.md` 시간 / 머지된 수정 비율, 동종 장애 재발

#### 6-2. Claude Security 정기 스캔

- 스캔 = 특정 시점·특정 모델 기준 → 코드와 모델 모두 노후화 → **스케줄 실행**
- 호스티드 서비스, GitHub 연결, Claude Mythos 5로 스캔, finding마다 검증 + 신뢰도
- **절차**: repo 연결·소유권 정리 → 첫 전체 스캔(baseline) → 프로젝트별 스케줄(주간 기본) → 신뢰도 기반 triage, **기각 시 사유 기록** → 국소 finding은 Claude Code on the Web에서 패치 → PR 게이트 / 광범위 finding은 `intent.md`로 Stage 1 → 수정 후 eval 추가 → CSV/Markdown/웹훅으로 기존 트래커에 연동
- 기존 정적 분석을 **보완** (결정적 검사는 CI 유지, 모델 스캔은 맥락 의존 취약점)

#### 6-3. Claude Tag (Slack 온콜)

- Claude가 자체 ID로 채널 멤버 → 새 장애의 1차 대응자
- MCP로 지표 baseline 복귀 확인 → 스레드에 확인 → post-mortem을 버전 관리 lessons 파일에 기록
- 티켓·채널 요청 triage: 작은 수정 → PR / 큰 작업 → `intent.md` → Stage 1

---

## 4. 하네스 아키텍처 분석

### 4-1. 전체 루프 구조

```
 ┌──────────────────────────────────────────────────────────────────────┐
 │                                                                      │
 ▼                                                                      │
[1 Plan]──intent.md──▶[2 Design]──spec.md──▶[3 Build]──plan.md+diff──▶[4 Test]
  ▲  PO 승인            ▲ PO+정책소유자 승인    ▲ 엔지니어 승인          │ 테스트/eval
  │                                                                      ▼
  │                                                              [5 Deploy]──PR findings
  │                                                                │ 코드오너 승인 + 릴리스 승인
  │                                                                ▼
  └──────────── intent.md (진단) ◀──────────────────────────── [6 Maintain]
                                  control band / 보안 스캔 / Slack / 티켓
```

### 4-2. 하네스 구성 요소 (레이어별)

| 레이어 | 구성 요소 | 성격 | 위치 |
|--------|-----------|------|------|
| **컨텍스트** | `CLAUDE.md` | 팀 지식, 매 세션 로드 | repo 루트 |
| **지식/정책** | Skills (`SKILL.md`) | 권고형 | `.claude/skills/<name>/` 또는 플러그인 |
| **워크플로** | Slash commands | 반복 프롬프트 코드화 | 조직 커맨드 |
| **위임** | Subagents | 범위 한정 헬퍼 | `.claude/agents/<name>.md` |
| **결정적 통제** | Hooks (allow/block/ask) | 강제형 | `.claude/settings.json` / managed |
| **권한·격리** | Permissions, Sandbox | 강제형 | managed settings |
| **리뷰 정책** | `REVIEW.md` | 리뷰 기준 | repo 루트 |
| **품질 게이트** | Evals | 설정 변경 회귀 검증 | `evals/`, CI workflow |
| **자동화 실행** | `claude -p`, Agent SDK, `claude-code-action` | 비대화형 | CI/CD, 컨테이너 |
| **외부 연동** | MCP (VCS, 배포, 트래커, 모니터링) | 도구 표면 | managed MCP |
| **관측** | OpenTelemetry | 감사·지표 | 관측 스택 |
| **탐지** | 결정적 스크립트 + `bands.yaml` | 모델 미사용 트리거 | repo |

### 4-3. 산출물 체인 (Artifact Contract)

| 산출물 | 생성 | 입력 | 승인자 | 저장 |
|--------|------|------|--------|------|
| `intent.md` | Stage 1, Stage 6 | 발의자 대화 / 진단 결과 | PO (또는 서비스 오너) | `intent/` |
| `spec.md` | Stage 2 (비대화형 잡) | `intent.md` + 조직 스킬 | PO + 정책 소유자 | intent 옆 |
| `plan.md` | Stage 3 (plan mode) | `intent.md` + `spec.md` | 엔지니어 | intent 옆 |
| diff + tests | Stage 3~4 | `plan.md` | — | 브랜치 |
| PR findings | Stage 5 | diff + `REVIEW.md` + spec/plan | 코드 오너 | PR |
| eval 케이스 | Stage 4, 6 | 실제 작업 / 장애 | 설정 소유 팀 | `evals/` |

### 4-4. 통제 모델: 권고 vs 결정

| 권고형 (Advisory) | 결정형 (Deterministic) |
|-------------------|------------------------|
| `CLAUDE.md`, Skills, `REVIEW.md`, 프롬프트 | Hooks, Permissions, Sandbox, Branch protection, Eval 게이트, 탐지 스크립트 |
| 작성 시점에 정책 적용 → 리뷰 부담 감소 | 반드시 지켜야 할 정책 보장 |
| 우회 가능 | 우회 불가 (managed일 경우) |

→ **설계 원칙**: 모든 필수 정책은 "스킬(권고) + 훅/리뷰(결정)"의 **이중 레이어**로 구성

### 4-5. Human-in-the-Loop 지점

| 지점 | 책임자 | 판단 내용 |
|------|--------|-----------|
| intent 수용 | Product Owner | 문제 가치, Stage 2 진입 |
| spec 우려사항 | 정책 소유자 | 상충 정책 해소 |
| Build 진행 | PO (+테크 리드) | 고위험 여부 |
| plan 승인 | 엔지니어 | 구현 방법·리스크 |
| PR 승인 | 코드 오너 | 의도 부합·리스크 수용 |
| 운영 배포 | 릴리스 매니저 | 릴리스 승인 |
| 진단 triage | 서비스 오너/온콜 | 수정/일정/기각 |

→ **"루프는 계속 돌고, 사람의 판단은 그 위에 있다"**

### 4-6. 핵심 설계 원칙

1. **Artifact-driven handoff** — 단계 간 연결은 커밋된 Markdown, git이 감사 기록
2. **Shift-left governance** — 정책은 리뷰가 아닌 작성 시점에 적용 (스킬)
3. **Advisory + Deterministic 이중 통제** — 스킬로 유도, 훅으로 강제
4. **Self-verification** — 에이전트가 사람에게 넘기기 전 스스로 검증
5. **Separation of duties** — 작성 에이전트 ≠ 승인자
6. **Gate, not pass** — 에이전트는 운영 게이트까지만
7. **Tiered autonomy** — 환경(dev/staging/prod)·심각도(1σ/2σ/3σ)별 권한 차등
8. **Learning loop** — 실수 2회 → `CLAUDE.md`, 장애 → eval, 진단 → `intent.md`
9. **Deterministic triggers** — 탐지는 모델 없이, 판단·진단만 모델
10. **Configuration as code** — 에이전트 설정 변경도 eval로 게이트

### 4-7. 지표 체계 요약

| 단계 | 선행 지표 | 후행 지표 |
|------|-----------|-----------|
| Plan | 대화→intent 커밋 시간 | intent 생존율, spec 이후 intent 변경 수 |
| Design | intent→spec 시간 | plan 이후 spec 변경 수 |
| Build | 1차 머지 비율, 승인→머지 시간 | 재작업 횟수, diff-plan 일치율 |
| Test | CI 1차 통과율, eval 통과율 | 리뷰 시간, 변경 실패율, CI vs 운영 회귀 |
| Deploy | 첫 리뷰 시간, 게이트 대기 시간 | 머지 전 vs 유출 결함, DORA |
| Maintain | 이탈→intent 시간 | 수정 전환율, 동종 장애 재발 |

---

## 5. 하네스 구축 시 시사점

- **구축 우선순위** (의존 관계 기준)
  1. 산출물 템플릿 (`intent.md` / `spec.md` / `plan.md`) + 저장 구조
  2. `CLAUDE.md` + 검증 명령 단일화 (`make test` 등)
  3. 단계별 스킬 (intent 작성, spec 설계, 정책)
  4. 빌드 훅 (보호 경로, 테스트 파일 보호, 포맷·린트)
  5. 서브에이전트 (`verifier` 등) + 슬래시 커맨드
  6. `REVIEW.md` + PR 리뷰 자동화
  7. 승인 게이트 훅 + 권한/샌드박스 설정
  8. Eval 스위트 + CI workflow
  9. 모니터링 탐지 스크립트 + `bands.yaml` → `intent.md` 자동 생성
- **단계 간 자동 트리거** 구현 필요: intent 승인 → spec 생성 잡 (비대화형 `claude -p`)
- **Source of Truth 결정** 선행: repo 기준 vs 레거시 기준 vs 링크
- **개인/소규모 환경 적용 시** managed settings·Claude Security·Claude Tag는 선택 요소, 프로젝트 레벨 `.claude/settings.json`으로 대체 가능

## 6. 참고 문서 (도입 순서)

Admin setup → Settings → Server-managed settings → Permissions → Sandboxing → Hooks guide/reference → Skills → Plugins & marketplaces → Managed MCP → Enterprise deployment → Network config → Monitoring(OTel) → Analytics → Compliance API → Security model
(https://code.claude.com/docs/en/)
