# Cycle 206 - Game Layer Observability/QA Baseline (2026-03-03)

## 1. 개요
- Branch: `codex/game-layer-observability-qa`
- Issue: `#206`
- 목적: 게임 레이어 공통 관측 지표/QA 게이트를 단일 문서로 표준화하고 PR 체크에 편입.

## 2. 반영 내용
1. 공통 운영 기준 문서 신설
- `docs/game-layer-observability-qa-v1.md`
- 시즌/퀘스트/라이벌/날씨 도메인 공통 이벤트 키 정의
- KPI/경보 임계치/릴리즈 블로킹 규칙 정리

2. PR 체크 정합성 강화
- `scripts/game_layer_observability_qa_unit_check.swift` 추가
- `scripts/ios_pr_check.sh`에 신규 체크 연결

3. 문서 인덱스 업데이트
- `README.md` 문서 목록에 본 명세/사이클 리포트 링크 추가

## 3. 수용 기준 대응
- 공통 관측 지표 문서화: 완료
- QA 시나리오/릴리즈 게이트 명세: 완료
- 자동 검증 파이프라인 연결: 완료

## 4. 실행 검증
- `swift scripts/game_layer_observability_qa_unit_check.swift` -> PASS
- `DOGAREA_SKIP_BUILD=1 bash scripts/ios_pr_check.sh` -> PASS

## 5. 다음 단계
- #123 에픽 본문에서 `공통 QA/관측 지표 정의` 항목의 추적 이슈를 `#206`으로 동기화
- 운영 대시보드(7d/24h KPI) 실제 쿼리 뷰 연결 여부를 후속 사이클에서 점검
