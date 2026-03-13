# Widget Family Real-Device Evidence Runbook v1

- Issue: #692
- Relates to: #692, #731, #408 (closed umbrella)

## 목적
- 위젯 family별 실기기 clipping / overflow / CTA 충돌 증적을 일관되게 남긴다.
- `#692`, `#731`이 요구하는 `small/medium zero-base QA`를 저장소 기준으로 재현 가능하게 만든다.

## 선행 문서
- 검증 매트릭스: `docs/widget-family-real-device-validation-matrix-v1.md`
- 복붙 템플릿: `docs/widget-family-real-device-evidence-template-v1.md`
- 공통 family budget: `docs/home-widget-family-layout-budget-v1.md`
- helper: `bash scripts/render_manual_evidence_pack.sh widget --write`
- helper prefill: `bash scripts/render_manual_evidence_pack.sh widget --write --prefill-from-env`
- 종료 체크리스트: `docs/widget-action-closure-checklist-v1.md`

## 최소 증적 세트
- 실제 기기 정보
  - 기기 모델
  - iOS 버전
  - 위젯 family
- surface 정보
  - widget surface 이름
  - 케이스 ID
  - covered states
- screenshot 증적
  - `step-1`: 위젯 홈 화면 캡처
  - `step-2`: 길이가 긴 상태 또는 fallback 상태 캡처
  - `step-fail`: 실패 시 추가 캡처
  - asset 경로는 bundle root 기준 `assets/layout/*.png`
- budget 판정
  - headline 정책
  - detail 정책
  - badge budget
  - CTA height rule
  - metric tile rule
  - compact formatting rule

## 실행 절차
1. `docs/widget-family-real-device-validation-matrix-v1.md`에서 대상 `WL-*` 케이스를 고른다.
2. 공통 메타를 먼저 채우고 시작하려면 `bash scripts/render_manual_evidence_pack.sh widget --write --prefill-from-env`를 사용한다.
   - 지원 env: `DOGAREA_WIDGET_EVIDENCE_DATE`, `DOGAREA_WIDGET_EVIDENCE_TESTER`, `DOGAREA_WIDGET_EVIDENCE_DEVICE_OS`, `DOGAREA_WIDGET_EVIDENCE_APP_BUILD`
3. 홈 화면에 대상 위젯과 family를 배치한다.
4. matrix에 적힌 covered states 중 가장 긴 문구가 나오는 상태를 우선 만든다.
5. 첫 화면을 `step-1`로 저장한다.
6. 상태 전환 또는 worst-case 문구를 만들어 `step-2`를 저장한다.
7. 위젯 프레임 경계, CTA, badge, metric strip이 깨지지 않는지 확인한다.
8. 캡처한 이미지를 `assets/layout/`에 같은 파일명으로 저장한다.
9. `docs/widget-family-real-device-evidence-template-v1.md` 형식으로 기록한다.
10. `bash scripts/validate_manual_evidence_pack.sh widget <widget-evidence-dir>`로 전체 bundle 완결성과 asset 존재를 검사한다.

## Pass 기준
- 상단/하단 clipping이 없다.
- CTA가 위젯 프레임 밖으로 나가지 않는다.
- badge와 CTA가 충돌하지 않는다.
- compact formatting rule이 실제 worst-case state에서 동작한다.
- metric tile / strip 높이가 family 내에서 일관된다.

## Fail 기준
- headline/detail이 위젯 경계를 침범한다.
- CTA가 잘리거나 badge를 덮는다.
- 상태가 바뀌면 lineLimit만으로 의미 없는 줄임표가 남는다.
- preview에서는 정상인데 홈 화면 실기기에서는 잘린다.

## 운영 규칙
- `WL-001` ... `WL-008`이 모두 채워져야 `#692`, `#731`의 실기기 layout evidence가 complete로 본다.
- 이 문서만으로는 충분하지 않고, action 수렴 evidence `WD-001` ... `WD-008`도 함께 complete여야 active blocker를 닫을 수 있다.
