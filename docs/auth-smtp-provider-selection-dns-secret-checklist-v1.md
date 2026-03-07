# Auth SMTP Provider Selection / DNS / Secret Checklist v1

Date: 2026-03-07  
Issue: #509

## 목적

DogArea는 당분간 이메일 인증 의존도가 높습니다.
따라서 Supabase Auth built-in SMTP rate limit을 벗어나기 위해 custom SMTP로 전환할 때,
단순 가격 비교가 아니라 아래를 한 번에 고정해야 합니다.

- provider 1안
- DNS 검증 체크리스트
- Supabase custom SMTP 입력값 체크리스트
- secret 보관/회전 가드레일
- rollout 직전 확인 순서

## 평가 원칙

- 기준일은 **2026-03-07** 입니다.
- 가격/플랜/제품 기능은 바뀔 수 있으므로, rollout 직전 공식 pricing 페이지를 다시 확인합니다.
- `deliverability` 평가는 통제된 A/B 측정이 아니라,
  각 provider의 공식 제품 포지셔닝과 운영 기능을 바탕으로 한 **운영 추정** 입니다.

## 비교 후보

- Resend
- Postmark
- Amazon SES

## 결론

DogArea의 **1안은 `Resend`** 로 고정합니다.

이유:

1. 초기 세팅과 Supabase 연결 설명이 가장 단순합니다.
2. 작은 팀 기준으로 DNS/도메인 인증과 운영 회전 부담이 낮습니다.
3. auth mail에 필요한 이벤트/로그/웹훅 표면이 충분합니다.
4. 현재 단계에서 `가장 싼 것`보다 `빨리 안정적으로 운영 가능한 것`이 더 중요합니다.

대안:

- `Postmark`: auth mail deliverability 우선 대안
- `SES`: 대량 발송/비용 최적화가 우선일 때의 대안

## 후보 비교표

| 항목 | Resend | Postmark | SES |
| --- | --- | --- | --- |
| 초기 세팅 난이도 | 낮음 | 중간 | 높음 |
| SPF/DKIM/DMARC 설정 난이도 | 낮음~중간 | 중간 | 중간~높음 |
| auth mail deliverability | 양호, developer-centric transactional mail에 적합 | 매우 강함으로 추정, transactional mail 특화 | 잠재력은 높지만 운영 품질 편차가 큼 |
| 로그/이벤트 확인 편의성 | 양호, dashboard + webhook 중심 | 매우 양호, transactional event 관측성이 강함 | 기본은 가능하지만 AWS 구성요소를 더 알아야 함 |
| 비용 / 무료 구간 | free 3,000 emails/mo, 100/day, Pro starts at $20/mo | 100 emails/mo free, then starts at $15/mo for 10,000 emails | $0.10 / 1,000 outbound emails pay-as-you-go |
| 장애 대응 / secret rotation 편의성 | 높음 | 중간~높음 | 중간 이하 |
| DogArea 적합도 | **1안** | 2안 | 3안 |

## 항목별 판단

### 1. 초기 세팅 난이도

#### Resend

- verified domain + DNS + API key/SMTP credential 구성으로 끝나는 편입니다.
- Supabase 연동 파트너 문서도 있어 onboarding friction이 낮습니다.

#### Postmark

- Sender Signature / Sender Domain / DKIM / Return-Path 개념을 함께 이해해야 합니다.
- 어려운 수준은 아니지만 Resend보다 용어와 운영 개념이 더 많습니다.

#### SES

- AWS 계정, SES identity, region, SMTP credential, 필요 시 SNS/config set까지 연결해야 합니다.
- 작은 팀 기준으로 가장 무겁습니다.

### 2. SPF / DKIM / DMARC 설정 난이도

공통:

- production auth mail은 SPF/DKIM/DMARC 중 하나만 맞춰서는 안 됩니다.
- 최소 기준은:
  - sender domain verification
  - DKIM pass
  - SPF alignment 확인
  - DMARC policy/aggregate report 준비

#### Resend

- verified domain 흐름이 단순하고 문서가 직관적입니다.
- baseline DNS 작업량이 가장 적습니다.

#### Postmark

- DKIM뿐 아니라 Return-Path 개념을 운영 관점에서 같이 챙기는 편이 좋습니다.
- DNS 항목을 정확히 맞추지 않으면 설정 완료 판단이 흐려질 수 있습니다.

#### SES

- Easy DKIM은 쉬운 편이지만, custom MAIL FROM / bounce handling까지 들어가면 운영 판단이 무거워집니다.
- AWS 지식이 적으면 실제 난이도가 올라갑니다.

### 3. auth mail deliverability

이 항목은 공식 문서만으로 절대값을 증명할 수 없으므로 아래는 운영 추정입니다.

#### Resend

- transactional/developer use case에 초점이 맞고,
- domain verification, events, suppression, webhooks를 갖춰 baseline은 충분합니다.

#### Postmark

- transactional email 특화 provider라 auth mail 성공률 우선 조직에서 강한 대안입니다.
- DogArea가 나중에 가입 전환율 하락을 메일 deliverability 문제로 확정하면 2안에서 1안으로 승격할 수 있습니다.

#### SES

- 인프라 여지는 크지만, 실제 deliverability 품질은 세팅/운영 수준에 더 크게 의존합니다.
- 현재 DogArea 운영 역량 기준으로는 "가장 안전한 기본값"은 아닙니다.

### 4. 로그 / 이벤트 확인 편의성

#### Resend

- dashboard와 webhook 중심으로 운영자 경험이 단순합니다.
- 작은 팀이 빠르게 원인 파악하기 좋습니다.

#### Postmark

- message activity와 이벤트 표면이 매우 강합니다.
- auth mail 실패 추적에는 가장 보기 좋은 축에 가깝습니다.

#### SES

- 가능하지만 AWS 콘솔, SNS, event destination 등 조합을 더 알아야 합니다.
- 단순 auth mail 운영만 놓고 보면 관측성 체감이 가장 무겁습니다.

### 5. 비용 / 무료 구간

#### Resend

- free 3,000 emails/mo
- free 100 emails/day
- Pro starts at $20/mo

#### Postmark

- free 100 emails/mo
- paid starts at $15/mo for 10,000 emails

#### SES

- $0.10 / 1,000 outbound emails pay-as-you-go

정리:

- 비용만 보면 SES가 가장 유리합니다.
- 그러나 DogArea 현재 단계에서는 **운영 복잡도 절감이 비용 차이보다 중요** 합니다.

### 6. 장애 대응 / secret rotation 편의성

#### Resend

- API key / SMTP credential / domain verification 축이 단순합니다.
- rotation, rollback, ownership handoff가 쉽습니다.

#### Postmark

- provider 자체는 안정적이지만, sender/return-path/DNS 개념을 같이 알아야 해 운영 문맥이 더 필요합니다.

#### SES

- IAM, SMTP credential, region, event destination까지 엮이면 사람 교체나 장애 대응 난도가 가장 큽니다.

## 최종 1안: Resend

### 선택 사유

1. DogArea 현재 운영 규모에 가장 잘 맞습니다.
2. Supabase custom SMTP 전환을 가장 빠르게 안정화할 수 있습니다.
3. 도메인 검증, 발송 이벤트 확인, secret rotation 문서화가 가장 단순합니다.
4. 추후 auth mail metric을 붙였을 때 운영자가 해석하기 쉬운 구조입니다.

### 비선정 사유

#### Postmark 미선정 사유

- transactional mail 품질 관점에서는 매우 매력적이지만,
  지금 DogArea 단계에서는 Resend보다 onboarding/운영 단순성이 떨어집니다.
- auth mail 실패율이 실제 KPI 문제로 확인되기 전까지는 2안으로 두는 것이 합리적입니다.

#### SES 미선정 사유

- 비용은 가장 좋지만, AWS 운영 표면이 너무 넓습니다.
- 현재 팀 역량/속도 기준으로 rollout risk가 가장 큽니다.

## DNS 체크리스트

production rollout 전에 아래를 모두 만족해야 합니다.

### 1. sender domain 결정

- auth mail 전용 발신 도메인을 정합니다.
- 예:
  - `auth.dogarea.app`
  - `mail.dogarea.app`

권장:

- 마케팅 메일과 auth mail 도메인을 분리
- `From` 주소도 auth 전용으로 고정

예:

- `noreply@auth.dogarea.app`

### 2. SPF

- provider가 요구하는 SPF 레코드를 domain에 반영
- 기존 SPF가 있으면 **merge** 해야 하며, 중복 `v=spf1` 생성 금지

확인:

- SPF pass
- envelope sender / return-path alignment 확인

### 3. DKIM

- provider가 요구하는 DKIM CNAME/TXT를 모두 반영
- `verified` 상태가 될 때까지 rollout 금지

확인:

- DKIM pass
- provider dashboard 상 verified

### 4. DMARC

- 최소한 DMARC record를 명시적으로 둡니다.

권장 시작값:

- `p=none` 으로 aggregate report부터 수집

운영 안정화 후 검토:

- `p=quarantine`
- `p=reject`

권장:

- aggregate report 수신 메일함 운영
- auth mail 전용 도메인별 report 분리

### 5. bounce / return-path / custom MAIL FROM 확인

provider별로 요구 수준이 다릅니다.

- Resend:
  - baseline send는 비교적 단순
- Postmark:
  - return-path 운영을 같이 보는 편이 안전
- SES:
  - custom MAIL FROM은 optional이지만 DMARC/SPF alignment 운영을 명확히 하려면 적극 검토

따라서 rollout checklist에는 아래 질문을 반드시 포함합니다.

- bounce domain이 필요한가?
- return-path를 별도 domain/subdomain으로 운영할 것인가?
- provider 기본 경로로 둘 것인가, branded path로 둘 것인가?

### 6. DNS 완료 판정 기준

아래를 다 만족해야 `DNS 완료`로 봅니다.

- sender domain verified
- DKIM verified
- SPF pass 확인
- DMARC record 반영
- test inbox에서 auth mail 실제 수신 확인
- spam/junk 분류 여부 확인

## Supabase Custom SMTP 설정 체크리스트

위치:

- `Supabase Dashboard > Auth > Emails > SMTP Settings`

입력 전 준비물:

- verified sender domain
- 발신 이메일 주소
- provider SMTP host / port
- SMTP username
- SMTP password 또는 provider API key 기반 SMTP credential
- sender name

입력값 체크:

- `SMTP Host`
- `SMTP Port`
- `SMTP User`
- `SMTP Pass`
- `Sender Name`
- `Sender Email / From Address`

운영 기준:

- staging project와 production project를 분리
- 같은 credential을 staging/prod에 재사용하지 않음
- 테스트 완료 전 built-in SMTP를 끄지 않음

## Secret / 설정값 체크리스트

저장소 commit 금지 대상:

- SMTP username
- SMTP password
- provider API key

운영 문서에만 남길 값:

- provider name
- auth sender domain
- sender email
- SMTP host / port
- rotation owner
- rotation 절차 링크

DogArea 분류 기준:

- custom SMTP credential은 `platform_secret`
- 관련 원칙은 [backend-edge-secret-inventory-rotation-runbook-v1.md](/Users/gimtaehun/멋사/dogArea/docs/backend-edge-secret-inventory-rotation-runbook-v1.md)와 같이 유지

권장 보관 위치:

- Supabase hosted SMTP settings
- 팀 secret manager / 1Password / CI secret store

금지:

- `xcconfig`
- `.env`를 저장소에 commit
- 이슈/PR 본문에 실제 secret 값 기록

## Rollout 직전 체크리스트

1. provider account 준비 완료
2. sender domain verified
3. SPF pass
4. DKIM pass
5. DMARC record 존재
6. auth 전용 `From` 주소 확정
7. staging Supabase project에서 test mail 수신 확인
8. spam/junk 분류 확인
9. secret rotation owner 지정
10. rollback 시 built-in SMTP 또는 대체 provider 복귀 경로 정리

## Rollout 후 확인 항목

1. signup confirmation 수신율
2. password reset 수신율
3. average delivery latency
4. bounce / block / deferred 비율
5. sender reputation 이상 징후

세부 metric/alert는 `#510`에서 닫습니다.

## DogArea 실행 순서

1. `Resend` 계정/도메인 준비
2. auth sender domain DNS 반영
3. staging Supabase project에 custom SMTP 적용
4. signup / reset / email change 흐름 smoke
5. observability 문서(`#510`) 반영 후 production 전환

## 공식 소스

기준일: 2026-03-07

- Resend Pricing: https://resend.com/pricing
- Resend Domains: https://resend.com/docs/dashboard/domains/introduction
- Resend x Supabase: https://resend.com/supabase
- Postmark Pricing: https://postmarkapp.com/pricing
- Postmark Sender Signatures: https://postmarkapp.com/developer/user-guide/sender-signatures
- Amazon SES Pricing: https://aws.amazon.com/ses/pricing/
- Amazon SES Verified identities / domain verification: https://docs.aws.amazon.com/ses/latest/dg/creating-identities.html
- Amazon SES Custom MAIL FROM: https://docs.aws.amazon.com/ses/latest/dg/mail-from.html
- Supabase Custom SMTP: https://supabase.com/docs/guides/auth/auth-smtp
