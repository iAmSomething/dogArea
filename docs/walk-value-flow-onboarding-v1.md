# Walk Value Flow Onboarding v1

## 목표
산책 시작 전, 진행 중, 저장 직후에 사용자가 `무엇이 기록되는지`, `왜 중요한지`, `다음에 어디를 보면 되는지`를 같은 용어로 이해하게 만든다.

## 정책
- 시작 전: 지도 시작 덱 안에서 CTA 옆에 붙는 compact helper 카드
- 첫 사용자: 지도 첫 진입 시 1회 자동 가이드 시트
- 진행 중: safe area 바로 아래 top chrome band의 slim HUD
- 저장 직후: 지도 상단에 후속 행동 카드
- 종료 확인 시트: 저장 직전 결과 연결 카드를 항상 노출

## 용어 통일
- 기록되는 것: `경로`, `영역`, `시간`, `포인트`
- 저장 후 이어지는 곳: `목록`, `상세`, `목표`, `미션`
- 미션 위치: `산책 위에 얹힌 보조 시스템`

## 화면별 적용
- 지도 시작 전: `map.walk.startMeaning.card`
- 지도 가이드 시트: `map.walk.guide.sheet`
- 지도 진행 중 slim HUD: `map.walk.activeValue.card`
- 지도 저장 직후: `map.walk.savedOutcome.card`
- 종료 확인 시트: `walk.detail.valueFlow.card`
- 목록/상세: 기존 산책 기본 루프 요약 문구 유지 + 저장 후 후속 의미 문구 통일

## 회귀 포인트
- 첫 지도 진입에서 가이드가 강제 arg 기준으로 자동 표시되는가
- 산책 중 slim HUD가 safe area 아래에서 1~2줄 정보로 유지되는가
- 저장 직후 목록 이동 CTA가 노출되는가
- 종료 확인 시트가 `저장될 기록 / 다시 볼 곳 / 이어지는 결과`를 설명하는가
