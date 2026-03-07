# Backend Upload Profile Image Owner Binding Policy v1

## 목적

`upload-profile-image`의 member/anon 업로드 경계를 문서와 구현 기준으로 고정합니다.

## canonical policy

### 1. member bearer

- `ownerId`는 optional입니다.
- `ownerId`를 보내는 경우 `auth.user.id`와 같아야 합니다.
- mismatch는 `403 UNAUTHORIZED_USER_MISMATCH`로 처리합니다.
- 실제 storage path는 항상 `<auth.user.id>/userProfile.<ext>` 또는 `<auth.user.id>/petProfile.<ext>`입니다.

### 2. anon bearer

- `ownerId`는 required입니다.
- `anon-onboarding-*` prefix를 가진 temporary namespace만 허용합니다.
- 허용 경로는 `anon-onboarding/<ownerId>/userProfile.<ext>` 또는 `anon-onboarding/<ownerId>/petProfile.<ext>`입니다.
- prefix가 맞지 않으면 `403 ANON_OWNER_NAMESPACE_REQUIRED`로 처리합니다.

## non-goals

- 전체 bucket policy 재설계
- 앱 프로필 편집 UX 변경
- anon onboarding object cleanup scheduler 추가

## rationale

- member path는 caller supplied `ownerId`를 신뢰하면 안 됩니다.
- anon path는 완전 차단보다 temporary namespace 격리가 더 현실적입니다.
- path를 물리적으로 분리해야 운영 중 object ownership drift를 빨리 찾을 수 있습니다.

## validation

- 구현: `supabase/functions/upload-profile-image/index.ts`
- shared helper: `supabase/functions/_shared/storage_upload.ts`
- static: `swift scripts/upload_profile_image_owner_binding_policy_unit_check.swift`
- live smoke: `DOGAREA_AUTH_SMOKE_ITERATIONS=1 DOGAREA_TEST_EMAIL=... DOGAREA_TEST_PASSWORD=... bash scripts/auth_member_401_smoke_check.sh`

## expected smoke signals

- `upload_profile member=200`
- `upload_profile app=200`
- `upload_profile member_mismatch=403`

## related

- `docs/backend-edge-auth-policy-v1.md`
- `docs/backend-edge-auth-mode-inventory-v1.md`
- `docs/backend-edge-rpc-deployment-matrix-post-deploy-v1.md`
- `supabase/functions/upload-profile-image/README.md`
- `#466`
