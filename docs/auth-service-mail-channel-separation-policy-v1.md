# Auth Service Mail Channel Separation Policy v1

Date: 2026-03-08  
Issue: #485

## 목적

DogArea는 인증 메일과 일반 서비스 메일을 같은 발송 경로에 섞지 않습니다.
이 문서는 아래를 고정합니다.

- 어떤 메일이 `Supabase Auth SMTP` 경로인지
- 어떤 메일이 `Edge Function + external mail API` 경로인지
- 발신 도메인 / 발신자 주소 분리 원칙
- secret / ownership / rate limit 분리 원칙
- 향후 설정 화면의 버그 리포트 / 지원 메일 연계 기준

## 결론

DogArea의 메일 채널은 아래 2개로 분리합니다.

1. `Auth SMTP`
   - 인증을 완료하거나 계정 보안을 유지하기 위해 꼭 필요한 메일만 허용합니다.
2. `Service Mail API`
   - 일반 서비스 커뮤니케이션, 운영 공지, 지원 응답, 버그 리포트, 마케팅 메일을 담당합니다.

핵심 원칙:

- `Supabase Auth` 경로는 인증 메일 전용입니다.
- 일반 서비스 메일은 Auth 경로를 공유하지 않습니다.
- "빨리 붙이려고 Auth SMTP를 재활용"하는 임시 운영을 금지합니다.

## 범위

포함:

- 메일 종류별 채널 분류
- sender domain / sender name / sender address 정책
- service mail path 초안
- secret / ownership / rate limit 분리 원칙

제외:

- 실제 bug report UI 구현
- CRM / 마케팅 자동화 도입
- 전체 알림 센터 구현

## 메일 종류 분류표

| 메일 종류 | 기본 채널 | 발신 주소 예시 | 발신 이름 예시 | 운영 owner | 비고 |
| --- | --- | --- | --- | --- | --- |
| 회원가입 확인 메일 | `Auth SMTP` | `auth@auth.dogarea.app` | `DogArea 인증` | backend operator | 계정 활성화용 |
| 비밀번호 재설정 메일 | `Auth SMTP` | `auth@auth.dogarea.app` | `DogArea 인증` | backend operator | 계정 보안용 |
| 이메일 변경 확인 메일 | `Auth SMTP` | `auth@auth.dogarea.app` | `DogArea 인증` | backend operator | 계정 보안용 |
| 초대 메일 | `Service Mail API` | `invite@notice.dogarea.app` | `DogArea 초대` | product/backend | 제품 커뮤니케이션으로 분류 |
| 고객지원 문의 회신 메일 | `Service Mail API` | `support@support.dogarea.app` | `DogArea 지원팀` | support/product | 티켓/문의 응답 |
| 버그리포트 접수 메일 | `Service Mail API` | `support@support.dogarea.app` | `DogArea 지원팀` | support/product | 접수 확인 |
| 버그리포트 회신 메일 | `Service Mail API` | `support@support.dogarea.app` | `DogArea 지원팀` | support/product | 추가 정보 요청 / 결과 회신 |
| 운영 공지 메일 | `Service Mail API` | `notice@notice.dogarea.app` | `DogArea 운영팀` | ops/product | 점검 / 정책 / 장애 공지 |
| 마케팅 / 리텐션 메일 | `Service Mail API` | `news@updates.dogarea.app` | `DogArea 소식` | growth/marketing | 향후 별도 opt-in 기준 필요 |

## Auth 메일 경로 제한

`Auth SMTP`는 아래 메일만 허용합니다.

- signup confirmation
- password reset
- email change

금지:

- 고객지원 회신
- 버그리포트 접수 / 회신
- 운영 공지
- 초대 메일
- 마케팅 / 리텐션 메일
- 기타 일반 서비스 커뮤니케이션

이유:

1. 인증 메일 deliverability를 일반 서비스 메일 볼륨에서 보호해야 합니다.
2. 인증 메일 rate limit과 평판을 일반 메일이 잠식하면 안 됩니다.
3. 사용자가 `auth@...` 발신 주소를 인증 용도로만 인식하도록 유지해야 합니다.

## Service Mail Path 초안

일반 서비스 메일은 아래 경로로 분리합니다.

`app / ops trigger -> Edge Function -> external mail API`

기본 초안:

1. 앱 또는 운영 surface가 service mail action을 발생시킵니다.
2. 전용 Edge Function이 action type, recipient, template payload를 검증합니다.
3. Edge Function이 `Resend` / `Postmark` / `SES API` 중 선택된 provider로 발송합니다.
4. provider webhook / event log는 auth mail observability와 분리된 service mail metric으로 수집합니다.

권장 구조:

- function name 예시: `service-mail-dispatch`
- provider class: API 기반 provider 우선
- template ownership: product/support/ops가 분리된 템플릿 집합 사용
- rate limit: auth mail과 완전히 별도 버킷 사용
- suppression / bounce 처리: service mail 전용 정책 사용

## 발신 도메인 / 발신자 정책

최소 기준:

- 인증 메일과 일반 서비스 메일은 발신 주소를 분리합니다.
- sender name도 용도별로 분리합니다.

권장 예시:

### Auth Mail

- sender domain: `auth.dogarea.app`
- from address: `auth@auth.dogarea.app`
- sender name: `DogArea 인증`

### Support / Bug Report

- sender domain: `support.dogarea.app`
- from address: `support@support.dogarea.app`
- sender name: `DogArea 지원팀`

### Notice / Invite

- sender domain: `notice.dogarea.app`
- from address: `notice@notice.dogarea.app`
- sender name: `DogArea 운영팀`
- invite 전용 주소가 필요하면 `invite@notice.dogarea.app` 사용

### Marketing / Retention

- sender domain: `updates.dogarea.app`
- from address: `news@updates.dogarea.app`
- sender name: `DogArea 소식`

## Secret / Ownership 분리 원칙

### Auth SMTP

- secret class: `platform_secret`
- storage location: `Supabase Dashboard > Auth > Emails > SMTP Settings`
- owner: backend operator
- template owner: backend/operator + auth owner
- rollout gate: auth deliverability smoke / auth mail observability 확인

### Service Mail API

- secret class: `edge_runtime_secret`
- storage location: Edge Function runtime secret
- owner: backend operator + service-mail owner
- template owner: support / product / ops 각 surface owner
- rollout gate: service mail smoke / provider event / webhook 확인

금지:

- auth SMTP credential을 service mail function에서 재사용
- service mail provider API key를 Supabase Auth SMTP credential로 겸용
- auth template와 service template를 같은 owner와 같은 배포 절차로 묶기

## 운영 위험 분리

목표는 service mail 볼륨 증가가 auth mail deliverability를 건드리지 못하게 하는 것입니다.

분리 수준은 아래 우선순위를 따릅니다.

1. **반드시 분리**
   - 발신 주소
   - sender name
   - rate limit
   - template ownership
2. **강하게 권장**
   - sender subdomain
   - provider dashboard / metric board
3. **볼륨 증가 시 검토**
   - provider account 분리
   - dedicated IP / account reputation 분리

## 설정 화면 연계 기준

향후 설정 화면에 아래가 추가될 수 있습니다.

- 버그 리포트 메일 보내기
- 지원 문의 메일 보내기
- 운영 공지 구독 / 수신 관련 surface

이 경우에도 메일 채널은 아래로 고정합니다.

- bug report 접수 / 회신: `Service Mail API`
- support contact 회신: `Service Mail API`
- auth 관련 안내: `Auth SMTP`가 아니라 앱 내 안내 또는 별도 service surface에서 설명

즉, 설정 화면 기능이 필요하더라도 `Supabase Auth SMTP`를 일반 메일 전송용으로 확장하지 않습니다.

## Service Mail 도입 체크리스트

1. service mail provider를 auth SMTP provider와 독립적으로 선택했는가
2. Edge Function runtime secret이 auth SMTP credential과 분리되어 있는가
3. sender domain / sender address / sender name이 auth 메일과 겹치지 않는가
4. template owner와 review 절차가 auth mail과 분리되어 있는가
5. provider event / bounce / suppression metric을 service mail 전용으로 볼 수 있는가
6. 버그리포트 / 지원 / 공지 / 마케팅 액션이 Auth 경로를 전혀 통과하지 않는가

## DoD

아래를 모두 만족하면 이 정책이 충족된 것으로 봅니다.

- 어떤 메일이 `Auth SMTP`인지 명확합니다.
- 어떤 메일이 `Service Mail API`인지 명확합니다.
- auth mail과 service mail이 발신 주소 / sender name / secret / ownership 기준으로 분리됩니다.
- 향후 버그리포트 / 공지 메일이 auth mail 한도와 충돌하지 않습니다.

## 관련 문서

- `docs/auth-smtp-provider-selection-dns-secret-checklist-v1.md`
- `docs/auth-mail-observability-metric-alert-request-key-v1.md`
- `docs/backend-edge-secret-inventory-rotation-runbook-v1.md`
