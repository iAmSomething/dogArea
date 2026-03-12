# Widget Action Bridge Observability v1

Issues: #617, #731  
Related: #408

## Goal

위젯 액션이 `무반응`처럼 보였을 때, 최소 DEBUG 로그만으로 아래 4단계를 구분합니다.

1. AppIntent 진입
2. App Group pending request 저장
3. 앱의 pending request 복원/삭제
4. walk snapshot 저장/WidgetKit reload

## Canonical prefix

- 모든 bridge 로그 prefix는 `[WidgetAction]`로 고정합니다.

## Required logs

### AppIntent
- `intent preparePendingRoute kind=... actionId=... contextId=...`
- `intent prepared openURL kind=... url=...`

### Pending request store
- `action request store ready storage=...`
- `setPending success storage=...`
- `setPending encode_failed ...`
- `pendingRequest loaded storage=...`
- `pendingRequest decode_failed storage=...`
- `discardPending removed storage=...`
- `discardPending skipped storage=...`

### Snapshot store
- `walk snapshot store ready storage=...`
- `walk snapshot save storage=... status=... walking=...`
- `walk snapshot encode_failed storage=...`
- `walk snapshot decode_failed storage=...`
- `walk snapshot reloadTimelines kind=...`

## Storage mode taxonomy

- `app_group_suite`
  - App Group shared suite를 실제로 사용 중인 상태
- `standard_fallback`
  - App Group container 또는 suite 생성 실패로 `.standard`에 fallback 된 상태

`standard_fallback`는 DEBUG에서 바로 식별 가능해야 하며, 실기기 QA에서는 실패로 간주합니다.

## Guardrail

- no-op 실패를 허용하지 않습니다.
- encode/decode 실패는 반드시 prefix 로그를 남깁니다.
- 저장소 선택 결과(`app_group_suite` / `standard_fallback`)는 store init 시점에 한 번 이상 남깁니다.
