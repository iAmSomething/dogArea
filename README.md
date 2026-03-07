# dogArea : 우리 댕댕이 영역 표시하기

**TestFlight**
> [체험하기](https://testflight.apple.com/join/61E3OBmk)
<div align="left">
	<img src="https://img.shields.io/badge/Swift-F05138?style=flat&logo=swift&logoColor=white"/>
  <img src="https://img.shields.io/badge/Firebase-FFCA28?style=flat&logo=firebase&logoColor=white"/>
  <img src="https://img.shields.io/badge/OpenAI-412991?style=flat&logo=openai&logoColor=white"/>

## Idea : 강아지들이 산책 할 때 영역 표시를 하는데, 이걸 실제 지도 위에 표현해보자!

## 문서

- Supabase 스키마/마이그레이션 v1 명세: `docs/supabase-schema-v1.md`
- 데이터 레이어 전환 설계 v1: `docs/data-layer-transition-v1.md`
- 다견가정 도메인/UX 명세 v1: `docs/multi-dog-domain-v1.md`
- 명소 넓이 데이터 거버넌스 v1: `docs/area-references-data-governance.md`
- 비교군 UI DB 전환 v1: `docs/area-reference-db-ui-transition-v1.md`
- 이미지 생성 공급자 라우터 명세 v1: `docs/image-provider-router-v1.md`
- 시계열 Heatmap 명세 v1: `docs/heatmap-timeseries-v1.md`
- Watch 액션 신뢰성 명세 v1: `docs/watch-connectivity-reliability-v1.md`
- 캐리커처 비동기 파이프라인 명세 v1: `docs/caricature-async-pipeline-v1.md`
- 근처 사용자 익명 핫스팟 명세 v1: `docs/nearby-anonymous-hotspot-v1.md`
- 핫스팟 위젯 프라이버시 매핑 v1: `docs/hotspot-widget-privacy-mapping-v1.md`
- 라이벌 프라이버시 하드 가드 v1: `docs/rival-privacy-hard-guard-v1.md`
- 라이벌 프라이버시 정책 Stage1 v1: `docs/rival-privacy-policy-stage1-v1.md`
- 라이벌 공정 리그 매칭 v1: `docs/rival-fair-league-v1.md`
- 라이벌 Stage2 백엔드(리더보드/권리경로) v1: `docs/rival-stage2-backend-v1.md`
- 라이벌 Stage3 클라이언트 UX v1: `docs/rival-stage3-client-ux-v1.md`
- 시즌 안티 농사 규칙 v1: `docs/season-anti-farming-v1.md`
- 시즌 복귀 캐치업 버프 v1: `docs/season-comeback-catchup-buff-v1.md`
- 시즌 주간 정책 Stage1 v1: `docs/season-weekly-policy-stage1-v1.md`
- 시즌 집계/정산 파이프라인 Stage2 v1: `docs/season-stage2-pipeline-v1.md`
- 체감 날씨 피드백 루프 v1: `docs/weather-feedback-loop-v1.md`
- 날씨 리스크 모델/Provider 정책 v1: `docs/weather-risk-provider-policy-v1.md`
- 날씨 치환/스트릭 보호 서버 엔진 v1: `docs/weather-replacement-shield-engine-v1.md`
- 날씨 연동 UX/fallback/접근성 v1: `docs/weather-ux-fallback-accessibility-v1.md`
- 퀘스트 Stage1 템플릿/난이도 정책 v1: `docs/quest-stage1-template-difficulty-policy-v1.md`
- 퀘스트 Stage2 진행/클레임 백엔드 엔진 v1: `docs/quest-stage2-progress-claim-engine-v1.md`
- 퀘스트 실패 완충(자동 연장 슬롯) v1: `docs/quest-failure-buffer-v1.md`
- 퀘스트 Stage3 UX/리마인드 v1: `docs/quest-stage3-ux-reminder-v1.md`
- 반려견 맞춤 난이도/쉬운 날 모드 v1: `docs/pet-adaptive-quest-difficulty-v1.md`
- Feature Flag/롤아웃 모니터링 명세 v1: `docs/feature-flag-rollout-monitoring-v1.md`
- ViewModel 현대화 리팩토링 명세 v1: `docs/viewmodel-modernization-v1.md`
- CoreData 반환 계약 정리 v1: `docs/coredata-return-contract-v1.md`
- Swift 안정화(강제 언래핑/타이머 수명) v1: `docs/swift-stability-hardening-v1.md`
- 프로젝트 설정/의존성 안정화 v1: `docs/project-settings-dependency-stability-v1.md`
- Supabase 마이그레이션/운영 검증 v1: `docs/supabase-migration.md`
- Supabase integration smoke matrix v1: `docs/supabase-integration-smoke-matrix-v1.md`
- Backend 계약 버저닝 정책 v1: `docs/backend-contract-versioning-policy-v1.md`
- Backend 고위험 계약 매트릭스 v1: `docs/backend-high-risk-contract-matrix-v1.md`
- Backend request correlation/idempotency 정책 v1: `docs/backend-request-correlation-idempotency-policy-v1.md`
- Backend migration drift / RPC CI 체크 v1: `docs/backend-migration-drift-rpc-ci-check-v1.md`
- Backend scheduler 운영 기준 v1: `docs/backend-scheduler-ops-standard-v1.md`
- Backend realtime/moderation retention policy v1: `docs/backend-realtime-moderation-retention-policy-v1.md`
- Widget summary RPC 공통 응답 모델 v1: `docs/widget-summary-rpc-common-response-model-v1.md`
- Backend Edge auth policy v1: `docs/backend-edge-auth-policy-v1.md`
- Backend Edge auth mode inventory v1: `docs/backend-edge-auth-mode-inventory-v1.md`
- Backend Edge observability 표준 v1: `docs/backend-edge-observability-standard-v1.md`
- Backend Edge error taxonomy v1: `docs/backend-edge-error-taxonomy-v1.md`
- Backend Edge incident runbook v1: `docs/backend-edge-incident-runbook-v1.md`
- Backend Edge observability adoption matrix v1: `docs/backend-edge-observability-adoption-matrix-v1.md`
- Backend Edge failure dashboard view v1: `docs/backend-edge-failure-dashboard-view-v1.md`
- 릴리즈 회귀 체크리스트 v1: `docs/release-regression-checklist-v1.md`
- 릴리즈 회귀 실행 리포트(2026-02-26): `docs/release-regression-report-2026-02-26.md`
- 게임 레이어 공통 관측/QA 기준 v1: `docs/game-layer-observability-qa-v1.md`
- 다중 반려견 산책 N:M 2차 설계 v2: `docs/multi-pet-session-nm-v2.md`
- 다견 1차 선택 반려견 UX v1: `docs/multi-dog-selection-ux-v1.md`
- 선택 반려견 컨텍스트 배지/빈 상태 UX v1: `docs/pet-context-badge-empty-state-v1.md`
- 산책 시작/종료 UX 단순화 v1: `docs/walk-start-stop-ux-v1.md`
- 영역 포인트 자동 기록 모드 v1: `docs/walk-point-auto-record-v1.md`
- 산책 세션 자동 복구/자동 종료 정책 v1: `docs/walk-session-recovery-auto-end-v1.md`
- 산책 런타임 예외 방어 가드레일 v1: `docs/walk-runtime-guardrails-v1.md`
- 산책 저장/동기화 정합성 아웃박스 v1: `docs/walk-sync-consistency-outbox-v1.md`
- Cycle #80 결과 보고서(2026-02-26): `docs/cycle-80-sync-consistency-report-2026-02-26.md`
- 예외처리 장애주입 매트릭스 v1: `docs/fault-injection-matrix-v1.md`
- 예외처리 장애주입 런북 v1: `docs/fault-injection-runbook-v1.md`
- 예외처리 결과 템플릿 v1: `docs/fault-injection-result-template-v1.md`
- 시즌 인터랙션 모션팩 v1: `docs/season-motion-pack-v1.md`
- Cycle #81 결과 보고서(2026-02-26): `docs/cycle-81-fault-injection-report-2026-02-26.md`
- Cycle #78 결과 보고서(2026-02-26): `docs/cycle-78-auto-end-policy-report-2026-02-26.md`
- Cycle #148 결과 보고서(2026-02-27): `docs/cycle-148-quest-failure-buffer-report-2026-02-27.md`
- Cycle #170 결과 보고서(2026-03-01): `docs/cycle-170-quest-stage3-ux-reminder-report-2026-03-01.md`
- Cycle #127 결과 보고서(2026-03-01): `docs/cycle-127-quest-stage1-policy-report-2026-03-01.md`
- Cycle #205 결과 보고서(2026-03-03): `docs/cycle-205-quest-stage2-engine-report-2026-03-03.md`
- Cycle #206 결과 보고서(2026-03-03): `docs/cycle-206-game-layer-observability-qa-report-2026-03-03.md`
- Cycle #214 결과 보고서(2026-03-03): `docs/cycle-214-widget-epic-closure-report-2026-03-03.md`
- Cycle #218 결과 보고서(2026-03-03): `docs/cycle-218-hotspot-widget-privacy-report-2026-03-03.md`
- Cycle #232 결과 보고서(2026-03-03): `docs/cycle-232-map-camera-jump-fix-report-2026-03-03.md`
- Cycle #147 결과 보고서(2026-02-27): `docs/cycle-147-pet-adaptive-quest-report-2026-02-27.md`
- Cycle #145 결과 보고서(2026-02-27): `docs/cycle-145-season-catchup-buff-report-2026-02-27.md`
- Cycle #124 결과 보고서(2026-02-27): `docs/cycle-124-season-policy-report-2026-02-27.md`
- Cycle #135 결과 보고서(2026-02-27): `docs/cycle-135-weather-ux-fallback-report-2026-02-27.md`
- Cycle #133 결과 보고서(2026-02-27): `docs/cycle-133-weather-risk-policy-report-2026-02-27.md`
- Cycle #134 결과 보고서(2026-02-27): `docs/cycle-134-weather-stage2-engine-report-2026-02-27.md`
- Cycle #138 결과 보고서(2026-02-27): `docs/cycle-138-pet-context-badge-report-2026-02-27.md`
- Cycle #139 결과 보고서(2026-02-27): `docs/cycle-139-area-reference-db-ui-report-2026-02-27.md`

## 로컬 PR 체크

- 전체 체크(iOS/watchOS build 포함): `bash scripts/ios_pr_check.sh`
- 문서/유닛만 빠르게 체크: `DOGAREA_SKIP_BUILD=1 bash scripts/ios_pr_check.sh`
- Backend drift / RPC contract 전용 체크: `bash scripts/backend_migration_drift_check.sh`
- Backend smoke entrypoint: `bash scripts/backend_pr_check.sh`
- Live Supabase smoke matrix: `DOGAREA_RUN_SUPABASE_SMOKE=1 DOGAREA_TEST_EMAIL=... DOGAREA_TEST_PASSWORD=... bash scripts/backend_pr_check.sh`

## 강아지들의 영역 표시

산책하다 보면 강아지들이 영역 표시를 하는 것을 아실 수 있습니다.

그런데 이 영역을 시각적으로 보고 기록할 수 있으면 재미있지 않겠습니까?

그래서 간단한 토이 프로젝트의 의미로 프로젝트를 시작하게 되었습니다.

### 사용하는 기능

1. Map > location의 배열을 가지고 영역 폴리곤을 만들어야 함!
   1. Mapkit 활용
   2. Location의 입력을 받아 버튼 눌렀을 때 annotation을 추가하고 완성된 annotatione들의 coordinate를 기반으로 폴리곤 제작
   3. 완성된 폴리곤을 토대로 image화 하여 저장, 사진 저장 기능 추가
2. Data storage
   1. CoreData로 활용
      1. Polygon 데이터 저장 : 역대 산책한 영역들을 저장
      2. 유저 정보 저장 : 유저의 identity와 강아지 관련 정보 저장
3. User에 대한 고민 : 프로필 이미지를 캐릭터화 하고 싶다..
   1. OpenAI로 image generate하기 < 바라는 이미지로는 안나옴,, 그냥 이미지 입력 받아야 할듯
   2. Apple 로그인을 통해 User 정보 확보하기
      1. 처음 사용자의 경우 프로필을 만드는 기능을 추가 > 완료
      2. 필요한 정보는 Identifiable한 랜덤 정보면 된다.
         1. 이메일, 이름으로 결정
      3. 사용자의 프로필 이미지의 필요 여부를 결정해야 한다.
         1. 없을 경우 empty image넣어주기로 결정
      4. 강아지의 정보를 필수값으로 저장해야 한다. 이름은 필수 이미지는 옵셔널
   3. 입력받은 UIImage를 URL화 하기
      1. Firebase storage를 활용해서 해결하였다.

## 화면

### 스플래시

- 로티 애니메이션을 추가

  <img src="https://p.ipic.vip/2pwx2f.gif" alt="스플래시"  width="200" height="432" />

### 홈

1. 메인 화면
   1. <img src="https://p.ipic.vip/47rvyp.png" alt="IMG_0357"  width="200" height="432" /><img src="https://p.ipic.vip/9cm520.png" alt="IMG_0358"  width="200" height="432" />
   2. 산책한 날에 강아지 아이콘을 추가하였습니다.
   3. 주별로(해당 주 일요일부터 토요일까지) 산책한 영역의 넓이와 산책 횟수를 산출하여 보여주었습니다.
   4. 누적된 산책 영역을 합산하여 대한민국 지자체 및 기타 유명한 지역의 넓이와 비교하여 보았습니다.
   5. 점차 넓은 영역을 넘어서도록 동기 부여용으로 제작하였습니다.
2. 더보기 눌렀을 때 뷰
   1. <img src="https://p.ipic.vip/ccc70a.png" alt="IMG_0359"  width="200" height="432" />
   2. 여태까지 정복한 영역을 최신순으로 정렬하여 보여줍니다.

#### Todo

-  막 산책을 마치고 다음 목표를 넘어섰을 때 Event를 추가하고 싶습니다.

### 산책 목록

1. 메인 뷰
   1. <img src="https://p.ipic.vip/md9o07.png" alt="IMG_0360"  width="200" height="432" /><img src="https://p.ipic.vip/3ttd2o.png" alt="IMG_0361"  width="200" height="432" />
      1. 산책 기록을 리스트로 보여줍니다.
      2. 셀 눌렀을 때는 영역을 지도에서 폴리곤으로 보여주고, 산책 정보를 보여주며, 사진으로 저장하는 기능을 추가하였습니다.

### 지도

<img src="https://p.ipic.vip/0co6bk.png" alt="IMG_0362"  width="200" height="432" /><img src="https://p.ipic.vip/ovfa5s.png" alt="IMG_0364"  width="200" height="432" /><img src="https://p.ipic.vip/sad2io.png" alt="IMG_0365"  width="200" height="432" /><img src="https://p.ipic.vip/q5dscv.png" alt="IMG_0366"  width="200" height="432" />


1. 메인 뷰입니다. 앱을 켜면 바로 등장합니다.
2. 산책을 시작하면 실시간으로 산책 시간과 영역 넓이를 계산하여 보여줍니다.
3. 영역 추가 버튼을 통해 영역을 추가할 수 있고, 추가된 영역을 클릭하여 삭제할 수 있습니다.
4. 산책이 완료되면 영역의 폴리곤을 오버레이한 사진을 코어데이터에 저장하고 관련 정보를 보여줍니다.
   1. 공유하기 기능은 아직 미구현입니다.
5. 저장하기 버튼을 통해 완성된 이미지를 사진첩에 저장할 수 있습니다.
6. 확인 버튼을 통해 뷰를 내릴 수 있습니다.

### 미정

### 설정

유저 정보와 설정값, 회원 탈퇴 등의 기능이 필요
