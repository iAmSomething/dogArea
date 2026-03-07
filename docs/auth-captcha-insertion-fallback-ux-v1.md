# Auth CAPTCHA Insertion & Fallback UX v1

## 목적

DogArea iOS 인증 플로우에서 CAPTCHA를 어디에 삽입하고,
어떤 경우에만 step-up 하며,
실패/취소/네트워크 오류 시 사용자를 어떻게 복귀시킬지 고정합니다.

이번 문서는 **provider 미확정 상태에서도 합의 가능한 앱 UX 계약**만 다룹니다.

관련 후속 이슈:

- `#509` Auth SMTP / provider / DNS / secret checklist
- `#510` Auth mail metric / alert / request key observability

## 전제

- CAPTCHA는 abuse 방어 수단이지, 정상 사용자 흐름의 기본 단계가 아닙니다.
- DogArea는 이메일 기반 가입/복구 의존도가 높으므로, 모든 액션에 항상 CAPTCHA를 노출하지 않습니다.
- 최종 판단은 서버 risk signal이 하며, iOS는 **step-up 표면과 복귀 UX**를 책임집니다.

## 액션별 적용 기준

| 액션 | 기본 정책 | CAPTCHA 기본 노출 여부 | step-up 조건 | 비고 |
| --- | --- | --- | --- | --- |
| 회원가입 | low-friction 우선 | 항상 노출하지 않음 | 서버가 의심 패턴으로 판정했을 때만 | 정상 신규 유저 전환율 보호가 우선 |
| 비밀번호 재설정 | abuse 방어 우선 | 항상 노출하지 않음 | 서버가 reset abuse / enumeration 패턴을 감지했을 때 | signup보다 더 보수적인 threshold 허용 |
| 이메일 변경 | 세션 신뢰 우선 | 항상 노출하지 않음 | 재인증 완료 후에도 서버가 위험하다고 판정했을 때만 | 로그인 세션이 있으므로 기본 friction을 가장 낮게 유지 |

정리:

- 세 액션 모두 **always-on CAPTCHA 금지**
- 세 액션 모두 **서버 판정 기반 step-up 허용**
- 액션별 threshold는 다를 수 있으나, iOS UX 패턴은 하나로 통일

## 삽입 지점 결정

### 선택한 전략

DogArea iOS는 아래 순서로 동작합니다.

1. 사용자가 액션 버튼을 탭합니다.
2. 앱은 원래 인증 요청을 서버에 보냅니다.
3. 서버가 정상 요청으로 판단하면 그대로 완료합니다.
4. 서버가 `captcha_required` 계열 응답을 반환하면,
   앱은 **native explainer sheet**를 먼저 보여준 뒤 challenge를 엽니다.
5. 사용자가 challenge를 통과하면 앱이 원래 액션을 자동 재시도합니다.

즉, 기본 전략은 **버튼 탭 직전 선노출이 아니라 서버 판정 기반 step-up** 입니다.

### 선택 이유

- 정상 사용자 대부분은 CAPTCHA를 보지 않음
- abuse가 의심되는 요청만 추가 friction 부여 가능
- provider가 바뀌어도 서버 응답 계약만 유지하면 앱 UX는 재사용 가능
- 회원가입/재설정/이메일 변경을 하나의 공통 state machine으로 묶기 쉬움

## 노출 방식 비교

### 1. 폼 하단에 항상 inline 노출

장점:

- 사용자는 액션 전에 challenge 존재를 미리 인지 가능

단점:

- 정상 사용자 모두에게 마찰이 생김
- Dynamic Type / VoiceOver / small screen에서 폼 높이가 급격히 커짐
- provider 교체 시 레이아웃 영향이 큼

판단:

- **DogArea에서는 채택하지 않음**

### 2. 앱 내부 `WKWebView` / 임베디드 웹뷰

장점:

- 앱 시각 언어를 유지하기 쉬움
- 전환 감각은 자연스러움

단점:

- anti-bot / cookie / storage / provider SDK 호환성 리스크가 큼
- VoiceOver focus 이동과 dismiss 복귀를 앱이 직접 책임져야 함
- 실패 시 디버깅 난도가 높음

판단:

- **1차 채택안에서 제외**

### 3. native explainer sheet + `ASWebAuthenticationSession`

장점:

- provider 호환성과 보안성 균형이 가장 좋음
- 시스템 레벨 웹 인증 세션이라 복귀와 세션 경계가 명확함
- 접근성 측면에서도 OS가 제공하는 표면을 활용 가능

단점:

- 앱 바깥 표면으로 넘어가는 느낌이 있음
- 사용자에게 왜 외부 인증 화면이 뜨는지 설명이 필요함

판단:

- **DogArea 기본 채택안**

### 4. 외부 Safari 완전 전환

장점:

- provider 호환성은 가장 높음

단점:

- 앱 이탈감이 가장 큼
- 복귀 실패 / 탭 중단 / 세션 손실 위험이 큼
- 정상 사용자 전환율 손실이 큼

판단:

- `ASWebAuthenticationSession` 실행 실패 시에만 fallback 용도로 허용

## 최종 UX 계약

### 기본 흐름

1. 사용자가 인증 액션 버튼을 탭합니다.
2. 서버가 challenge 없이 허용하면 원래 성공 UX로 진행합니다.
3. 서버가 CAPTCHA를 요구하면 아래 native sheet를 보여줍니다.

sheet 구성:

- 제목: `보안 확인이 필요해요`
- 본문: 현재 요청이 평소보다 민감하게 보여 간단한 확인이 필요하다는 설명
- 기본 액션: `보안 확인 계속`
- 보조 액션: `나중에 할게요`

4. 사용자가 `보안 확인 계속`을 누르면 `ASWebAuthenticationSession`을 엽니다.
5. 완료 callback을 받으면 앱이 원래 액션을 **자동 1회 재시도** 합니다.
6. 재시도 성공 시, 사용자는 중간 복구 단계를 의식하지 않고 원래 성공 UX를 봅니다.

### 액션별 성공 후 복귀

- 회원가입:
  - 인증 메일 발송 성공 카드 또는 프로필 입력 계속 플로우로 복귀
- 비밀번호 재설정:
  - `재설정 메일을 보냈어요` 상태로 복귀
- 이메일 변경:
  - `새 이메일 확인 메일을 보냈어요` 상태로 복귀

## 실패 / 취소 / 네트워크 오류 UX

### 1. CAPTCHA 실패

조건:

- provider challenge 실패
- 서버 verification 실패

UX:

- 현재 입력값은 유지
- 원래 액션은 자동 진행하지 않음
- 배너/인라인 메시지:
  - `보안 확인을 완료하지 못했어요. 다시 시도해주세요.`
- CTA:
  - `다시 시도`
  - `취소`

### 2. 사용자가 취소

조건:

- explainer sheet에서 `나중에 할게요`
- `ASWebAuthenticationSession`을 사용자가 닫음

UX:

- 에러 취급하지 않음
- 현재 폼 상태 유지
- 안내 문구:
  - `보안 확인을 취소했어요. 계속하려면 다시 시도해주세요.`
- 메인 CTA는 원래 액션 버튼 상태로 복귀

### 3. 네트워크 실패

조건:

- challenge URL 발급 실패
- callback 검증 요청 실패
- challenge 후 원래 액션 재시도 실패

UX:

- 현재 입력값 유지
- 액션별로 기존 resend / retry state machine과 충돌하지 않게 분리
- 안내 문구:
  - `연결이 불안정해 보안 확인을 완료하지 못했어요. 잠시 후 다시 시도해주세요.`
- CTA:
  - `다시 시도`

### 4. 반복 실패 / 과도한 요청

조건:

- CAPTCHA 이후에도 서버가 `429` 또는 추가 abuse signal을 반환

UX:

- 메일 resend cooldown / rate-limited UX를 우선 재사용
- 추가 문구:
  - `요청이 많아 잠시 기다린 뒤 다시 시도할 수 있어요.`
- CAPTCHA를 무한 반복 노출하지 않고,
  일정 시간 동안은 버튼 자체를 disabled 상태로 둠

## 접근성 기준

### native explainer sheet

- Dynamic Type `AX5`까지 줄바꿈 유지
- VoiceOver 읽기 순서:
  - 제목 -> 설명 -> 기본 액션 -> 보조 액션
- `취소`와 `계속`의 역할 차이를 레이블만으로 이해 가능해야 함

### challenge transport

- 기본은 `ASWebAuthenticationSession`
- 시스템 제공 표면이라 VoiceOver / 확대 / 포커스 복귀 안정성이 가장 높음

### 금지

- CAPTCHA 이미지를 앱이 직접 렌더링하는 커스텀 뷰
- 설명 없이 바로 외부 브라우저를 띄우는 흐름
- 실패 사유에 `bot`, `abuse`, `risk score` 같은 내부 보안 용어 노출

## 정상 사용자 전환율 영향과 완화책

예상 영향:

- signup 전환율 저하 가능성
- password reset 완료율 저하 가능성
- email change 도중 이탈 가능성

완화책:

1. always-on 금지, step-up only 유지
2. explainer sheet에서 왜 필요한지 짧고 중립적으로 설명
3. 입력값 유지, 원래 폼으로 즉시 복귀 가능
4. challenge 성공 후 원래 액션 자동 재시도
5. 동일 세션에서 중복 challenge를 남발하지 않도록 서버 cooldown 적용
6. metric으로 액션별 drop-off를 추적

최소 metric 제안:

- `auth_captcha_step_up_presented`
- `auth_captcha_step_up_completed`
- `auth_captcha_step_up_cancelled`
- `auth_captcha_step_up_failed`
- `auth_captcha_step_up_retry_succeeded`

상세 observability는 `#510`에서 닫습니다.

## QA 시나리오

1. 회원가입 정상 경로
- CAPTCHA 없이 메일 발송 성공

2. 회원가입 step-up 경로
- sheet 노출
- challenge 완료
- 자동 재시도 후 성공

3. 비밀번호 재설정 step-up 취소
- 취소 후 폼 유지
- 재시도 가능

4. 이메일 변경 step-up 네트워크 실패
- 현재 입력값 유지
- 재시도 문구 노출

5. CAPTCHA 성공 후에도 서버 `429`
- rate-limited 문구와 남은 시간 노출

6. VoiceOver 환경
- sheet 제목/설명/버튼 순서가 올바르게 읽힘

## 구현 전 가드레일

- provider 확정 전에는 실제 challenge UI를 앱에 먼저 붙이지 않음
- iOS는 아래 추상 계약만 먼저 가질 수 있음
  - `captcha_required`
  - `challenge_url`
  - `callback_token`
  - `retry_after`
- provider-specific 파라미터와 SDK는 별도 adapter로 감춤

## 최종 결정 요약

- CAPTCHA는 세 액션 모두 **항상 노출하지 않음**
- 기본 전략은 **서버 판정 기반 step-up**
- 표면은 **native explainer sheet + ASWebAuthenticationSession**
- `WKWebView`는 1차 채택안에서 제외
- 실패/취소/네트워크 오류 시 사용자는 원래 폼으로 안전하게 복귀
