# Auth SMTP Rollout Evidence Runbook v1

- Issue: #664
- Relates to: #482

## 목적
- Supabase Auth custom SMTP rollout의 운영 증적을 같은 형식으로 남긴다.
- `설정했다` 수준이 아니라 DNS, hosted auth 설정, 실수신, provider event, rollback readiness까지 한 번에 검증한다.
- `#482`를 닫을 수 있는 증거를 issue/PR 코멘트에 재현 가능한 형태로 남긴다.

## 선행 문서
- provider / DNS / secret 체크리스트: `docs/auth-smtp-provider-selection-dns-secret-checklist-v1.md`
- auth abuse guard 정책: `docs/auth-abuse-guard-policy-v1.md`
- auth observability 기준: `docs/auth-mail-observability-metric-alert-request-key-v1.md`
- live-send validation matrix: `docs/auth-smtp-live-send-validation-matrix-v1.md`
- bundle 템플릿: `docs/auth-smtp-rollout-evidence-template-v1.md`
- 종료 체크리스트: `docs/auth-smtp-closure-checklist-v1.md`
- helper: `bash scripts/render_manual_evidence_pack.sh auth-smtp --write`
  - 기본 출력: `.codex_tmp/auth-smtp-evidence/`

## 최소 증적 세트
- provider 선택 정보
  - provider 이름
  - sender domain
  - rollout 대상 Supabase project
- DNS 인증 증적
  - SPF pass
  - DKIM verified
  - DMARC record 존재
  - provider dashboard verified 상태
- Supabase Auth 설정 증적
  - SMTP Host
  - SMTP Port
  - SMTP User
  - Sender Name
  - Sender Email
  - `email_sent` 운영값
  - `auth.email.max_frequency` 운영값
- 실수신 증적
  - signup confirmation
  - password reset
  - email change
- provider delivery/event 증적
  - `provider_message_id`
  - 가능하면 `provider_event_id`
  - bounce/reject/deferred 확인 결과
- 운영 안전장치 증적
  - rollback 경로
  - secret rotation 확인 시점
  - 테스트 계정/받는 주소

## 비밀값 가림 규칙
- `SMTP Pass`, API key, provider secret은 저장소/이슈/PR에 그대로 남기지 않는다.
- 아래만 남긴다.
  - host
  - port
  - username prefix 또는 masked username
  - sender email
  - verified timestamp
- 스크린샷에도 secret이 보이면 마스킹 후 첨부한다.

## 증적 수집 순서
1. sender domain과 provider를 확정한다.
2. `docs/auth-smtp-live-send-validation-matrix-v1.md`에서 대상 케이스를 고른다.
3. provider dashboard에서 domain verification 상태를 캡처한다.
4. DNS 검사 결과를 정리한다.
   - SPF pass
   - DKIM verified
   - DMARC record 존재
5. `Supabase Dashboard > Auth > Emails > SMTP Settings` 반영 상태를 캡처한다.
6. 운영값을 템플릿에 기록한다.
   - `email_sent`
   - `auth.email.max_frequency`
7. 아래 3개 실수신 시나리오를 실제로 실행한다.
   - signup confirmation
   - password reset
   - email change
8. 각 시나리오마다 아래를 남긴다.
   - request time
   - recipient mask/hash
   - provider accepted 여부
   - provider_message_id
   - mailbox 수신 여부
9. bounce/reject/deferred가 있으면 provider event 캡처를 남긴다.
10. rollback readiness와 secret rotation 담당자를 기록한다.
11. `.codex_tmp/auth-smtp-evidence/` bundle 파일을 모두 채운다.
    - `01-dns-verification.md`
    - `02-supabase-smtp-settings.md`
    - `03-live-send-results.md`
    - `04-negative-evidence.md`
    - `05-rollback-rotation.md`
    - `06-final-decision.md`
12. 코멘트로 올리기 전 `bash scripts/validate_manual_evidence_pack.sh auth-smtp <bundle-dir>` 으로 완결성을 검사한다.
13. closure comment를 바로 게시하려면 `bash scripts/post_closure_comment_from_evidence.sh auth-smtp --issue 482 <bundle-dir> --post`를 사용한다.

## 실수신 시나리오 규칙
### Signup confirmation
- 신규 이메일 기준으로 실행한다.
- confirmation mail subject와 redirect가 기대값과 일치해야 한다.
- `auth_mail_send_accepted`와 provider accepted 흔적을 함께 남긴다.

### Password reset
- 실제 가입된 이메일 기준으로 실행한다.
- reset mail subject와 reset link가 기대값과 일치해야 한다.
- duplicate suppression 또는 cooldown이 있으면 그 상태도 함께 적는다.

### Email change
- signed-in session에서 실행한다.
- 기존/변경 대상 이메일 문맥이 혼동되지 않도록 recipient를 명확히 적는다.
- 실제로 기능을 쓰는 surface가 없다면 `not enabled in product`로 명시하고 blocker로 남긴다.

## 로그/이벤트 규칙
- 가능하면 아래 키를 함께 남긴다.
  - `request_id`
  - `mail_action_key`
  - `provider_message_id`
  - `provider_event_id`
- provider event가 없다면 `accepted only / no downstream event`라고 명시한다.
- bounce/reject/deferred가 발생했다면 reason과 retry 여부를 적는다.

## 스크린샷 규칙
- 최소 3장
  - provider domain verification
  - Supabase SMTP settings
  - mailbox 수신 화면
- 파일명 예시
  - `SMTP-001-provider-domain.png`
  - `SMTP-001-supabase-settings.png`
  - `SMTP-001-signup-mailbox.png`

## Pass 기준
- custom SMTP provider가 production 또는 rollout 대상 project에 실제로 연결돼 있다.
- sender domain이 verified 상태다.
- SPF pass / DKIM verified / DMARC record 존재가 확인된다.
- signup/reset/email change 시나리오가 실제 수신까지 검증된다.
- rollback 경로와 secret rotation 경로가 기록돼 있다.

## Fail 기준
- built-in SMTP인지 custom SMTP인지 구분되는 증거가 없다.
- sender domain verification이 끝나지 않았다.
- 실수신 결과가 없거나, provider accepted만 있고 mailbox proof가 없다.
- secret이 평문으로 남았다.
- rollback 또는 rotation 소유자가 비어 있다.

## 운영 규칙
- `#482`는 이 런북 형식의 운영 증거가 들어오기 전까지 닫지 않는다.
- staging 증거는 production 증거의 대체물이 아니다.
- provider 변경 또는 sender domain 변경 시 이 런북과 템플릿을 다시 채운다.
