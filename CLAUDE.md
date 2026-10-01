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
