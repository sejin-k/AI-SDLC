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
