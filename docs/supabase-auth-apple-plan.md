# Apple Sign-In -> Supabase Auth 전환 계획

## 왜 필요한가
현재 Supabase 스키마의 `owner_user_id`는 `auth.users.id (uuid)`를 참조합니다.
즉, CoreData 백필/이중쓰기 전에 앱에서 Supabase 사용자 세션을 확보해야 합니다.

## 목표
- Apple 로그인 성공 시 Supabase 세션(access token)을 확보
- 앱의 사용자 식별을 `Supabase auth uid` 기준으로 전환
- 기존 `UserDefaults.userId`(Apple user identifier)는 보조 식별자로만 유지

## 제안 흐름
1. Apple 로그인 완료 후 `identityToken` 확보
2. Supabase Auth endpoint로 Apple 토큰 교환
3. 응답의 `access_token`, `user.id` 저장
4. 이후 PostgREST/Storage 호출은 Bearer access token 사용

## 앱 변경 포인트
- SignInView.swift
  - FirebaseAuth 경유 경로 제거/축소
  - Supabase 토큰 교환 호출 추가
- UserdefaultSetting.swift
  - `supabaseUserId`, `supabaseAccessToken`, `tokenExpiresAt` 저장 필드 추가
- CoreData -> Supabase 백필
  - owner_user_id = supabaseUserId 사용

## 보안
- service role 키는 앱에서 사용 금지
- 앱에는 anon key + 사용자 access token만 사용
- 토큰 만료 시 refresh 경로 구현 필요

## 단계별 적용
1. 로그인 성공 후 Supabase 토큰 저장
2. 읽기 API 일부를 Supabase로 연결
3. 쓰기 이중화 적용
4. 백필 실행
5. Firebase 의존 제거

## 검증
- 로그인 후 `auth.uid()`가 RLS 정책과 일치하는지 확인
- 동일 계정으로 재로그인 시 기존 데이터 조회 가능 여부 확인
