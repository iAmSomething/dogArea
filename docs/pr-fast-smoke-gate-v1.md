# PR Fast Smoke Gate v1

- Issue: #705
- Relates to: #270, #266

## 목적
- PR 직전에 빠르게 돌려서 main 유입을 막아야 하는 핵심 회귀만 잡는다.
- 실패 시 어떤 축이 깨졌는지 한눈에 보이는 요약 형식을 고정한다.
- nightly full gate와 역할이 겹치지 않도록 fast smoke의 경계를 문서로 확정한다.

## 역할 경계
- `fast smoke`: 15분 안쪽으로 끝나는 핵심 진입/상태 수렴 확인
- `nightly full gate`: 장시간 세션, 오프라인 복구, 실기기 증적, flaky 재시도 판단
- fast smoke에 넣지 않는 것
  - 20분 이상 장시간 산책
  - watch 실기기 장시간 큐 복구
  - 실기기 증적 수집이 필요한 항목 전체

## 실행 진입점
- iOS 정적/문서 게이트: `DOGAREA_SKIP_BUILD=1 bash scripts/ios_pr_check.sh`
- map UI 회귀: `bash scripts/run_feature_regression_ui_tests.sh`
- widget action 회귀: `bash scripts/run_widget_action_regression_ui_tests.sh`
- backend/sync smoke: `bash scripts/backend_pr_check.sh`
- member auth + nearby smoke: `DOGAREA_AUTH_SMOKE_ITERATIONS=1 bash scripts/auth_member_401_smoke_check.sh`

## 대상 축

| Axis ID | 축 | 자동화 | 대표 진입점 | 포함 이유 |
| --- | --- | --- | --- | --- |
| `FS-001` | map root UI 회귀 | 자동 | `FeatureRegressionUITests` 중 지도 핵심 케이스 | 탭바/상단 chrome/primary action 가림은 바로 사용자 차단으로 이어진다. |
| `FS-002` | widget family / clipping | 자동 | 위젯 layout 관련 unit check + widget regression | 홈 화면 clipping/overflow는 PR 단계에서 빨리 잡아야 한다. |
| `FS-003` | widget start/end action smoke | 자동 | `run_widget_action_regression_ui_tests.sh` | 앱/위젯/Live Activity 수렴 실패는 높은 빈도로 회귀한다. |
| `FS-004` | watch start / addPoint / end 기본 smoke | 수동 최소 확인 | watch simulator 또는 실기기 기본 3액션 | watch 표면은 완전 자동화가 약해서 PR에서 최소 경로라도 본다. |
| `FS-005` | sync / outbox / nearby-presence 복구 smoke | 자동 | `backend_pr_check.sh`, `auth_member_401_smoke_check.sh` | 401/500/404 회귀가 앱 전체 신뢰성을 무너뜨린다. |

## 시나리오 정의

### FS-001 map root UI 회귀
- 최소 확인
  - 지도 탭 진입 가능
  - primary action이 탭바에 가려지지 않음
  - top chrome이 safe area 아래에서 안정적으로 보임
- pass 기준
  - `testFeatureRegression_MapPrimaryActionIsNotObscuredByTabBar` 통과
  - 지도 루트 진입 실패나 overlay 충돌 실패가 없음
- fail bucket
  - `map_root_ui`

### FS-002 widget family / clipping
- 최소 확인
  - `systemSmall`, `systemMedium`, lock-screen accessory 주요 레이아웃이 clipping 없이 렌더됨
  - CTA/핵심 수치가 family별로 잘리지 않음
- pass 기준
  - widget family layout 관련 정적 체크 통과
  - widget regression pack에서 family 레이아웃 실패가 없음
- fail bucket
  - `widget_layout`

### FS-003 widget start/end action smoke
- 최소 확인
  - start 액션 후 앱/위젯/Live Activity가 같은 상태로 수렴
  - end 액션 후 종료 상태가 일관되게 반영
- pass 기준
  - widget action regression UI 케이스 통과
  - `widget_intent_openapp_unit_check.swift`가 깨지지 않음
- fail bucket
  - `widget_action`

### FS-004 watch start / addPoint / end 기본 smoke
- 최소 확인
  - start
  - addPoint
  - end
- 자동화/수동 구분
  - 기본 계약/unit check는 자동
  - 최종 버튼 체감/상태 수렴은 PR 영향 범위가 watch에 걸릴 때만 수동 확인
- pass 기준
  - 관련 watch contract/unit check 전부 통과
  - watch 영향 PR이면 start/addPoint/end 결과를 수동으로 1회 기록
- fail bucket
  - `watch_basic_action`

### FS-005 sync / outbox / nearby-presence 복구 smoke
- 최소 확인
  - member auth 경로에서 401 downgrade 없음
  - nearby-presence member/app smoke 성공
  - outbox/sync 핵심 route 404/500 없음
- pass 기준
  - `backend_pr_check.sh` 통과
  - `auth_member_401_smoke_check.sh`에서 member 경로 200 유지
- fail bucket
  - `sync_recovery`

## 자동화 vs 수동 판단 규칙
- 기본값은 자동화 우선
- 아래 조건 중 하나면 수동 확인 1세트 추가
  - watch 화면/액션을 직접 건드림
  - widget deep link / action route를 건드림
  - map root overlay hierarchy를 건드림
- 실기기만 가능한 증적은 fast smoke가 아니라 `nightly full gate` 문서로 넘긴다.

## 결과 리포트 형식
- summary는 1 screen 안에 들어와야 한다.
- 축별 상태는 `PASS | FAIL | BLOCKED | SKIPPED`만 사용한다.
- 실패 행에는 반드시 `bucket`, `first failing step`, `next owner`가 포함돼야 한다.

### 상단 요약 표
| Axis | Status | Auto/Manual | Evidence | Bucket |
| --- | --- | --- | --- | --- |
| `FS-001 map_root_ui` | PASS | Auto | `FeatureRegressionUITests` | - |

### 상세 표
| Scenario ID | Command / Surface | Expected | Actual | Evidence Link / Log | Owner | Next Action |
| --- | --- | --- | --- | --- | --- | --- |
| `FS-003` | `run_widget_action_regression_ui_tests.sh` | start/end 상태 수렴 | 실제 결과 | xcresult / console log | `@owner` | rerun / fix |

## 종합 판단 규칙
- 아래 중 하나면 `NO-GO`
  - `FS-001`, `FS-003`, `FS-005` 중 하나라도 `FAIL`
  - 자동화 필수 축이 `BLOCKED`
- 아래면 조건부 `GO`
  - `FS-004`만 `SKIPPED`이고 watch 비영향 PR
- manual only 이슈는 summary에 이유를 남기고 nightly queue에 연결한다.

## 후속 이슈가 바로 사용할 입력값
- 축 식별자: `FS-001` ~ `FS-005`
- failure bucket: `map_root_ui`, `widget_layout`, `widget_action`, `watch_basic_action`, `sync_recovery`
- 결과 상태: `PASS | FAIL | BLOCKED | SKIPPED`
- 리포트 템플릿: `docs/pr-fast-smoke-gate-report-template-v1.md`
