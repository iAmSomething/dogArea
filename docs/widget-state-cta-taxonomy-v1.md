# Widget state CTA taxonomy v1

## Scope
- Territory widget
- Hotspot widget
- Quest/Rival widget
- 대상 상태: `guest`, `empty`, `offline`, `syncDelayed`

## Taxonomy
- `guest`
  - 의미: 인증이 없어 위젯 핵심 데이터를 보여줄 수 없음
  - 역할: 로그인 유도
- `empty`
  - 의미: 계정/표면은 유효하지만 아직 첫 행동 데이터가 없음
  - 역할: 첫 행동 유도
- `offline`
  - 의미: 마지막 성공 스냅샷을 보여주고 있음
  - 역할: 복구 대기 안내
- `syncDelayed`
  - 의미: 최신 상태 반영이 늦어지고 있음
  - 역할: 앱 재진입 최신화 유도

## CTA rules
- `guest`
  - badge: `로그인 필요`
  - CTA: `앱에서 로그인`
- `empty`
  - badge: `첫 행동`
  - CTA pattern: `앱에서 ... 시작`
- `offline`
  - badge: `오프라인`
  - CTA: `연결 복구 대기 중`
- `syncDelayed`
  - badge: `지연`
  - CTA: `앱에서 최신 상태 확인`

## Copy rules
- badge는 짧게 2~4음절 수준으로 유지
- headline은 현재 상태를 바로 이해시키는 한 문장으로 제한
- detail은 왜 이 상태인지와 다음 행동을 함께 설명
- CTA는 명령형 한 줄로 유지
- 접근성 라벨/힌트는 CTA title과 분리해 상태 이유를 보강

## Surface specializations
- Territory empty: `앱에서 첫 산책 시작`
- Hotspot empty: `앱에서 익명 공유 시작`
- Quest/Rival empty: `앱에서 퀘스트 시작`
- Hotspot은 반경 preset 문맥을 detail에 유지
- Quest/Rival은 `offline` / `syncDelayed`에서 보상/순위 CTA보다 복구 CTA를 우선

## Accessibility
- CTA label은 짧은 사용자 문구를 그대로 읽음
- CTA hint는 왜 앱으로 가야 하는지 설명
- 상태 badge와 CTA는 서로 다른 의미를 갖도록 중복 단어를 줄임
