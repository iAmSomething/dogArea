# Backend Gemini API Key Canonicalization v1

Date: 2026-03-08  
Issue: #479

## 목적

`caricature` provider path에서 Gemini secret 이름을 `GEMINI_API_KEY` 하나로 고정합니다.

이 변경의 목적은 다음 3가지입니다.

- secret inventory를 단일 canonical 이름으로 유지
- rotation / incident 대응 시 혼선 제거
- 문서/스크립트/env 표준 이름을 하나로 정리

## 결정

- canonical Gemini provider secret은 `GEMINI_API_KEY`
- legacy Gemini alias는 저장소와 runtime 코드에서 제거
- 신규 문서, 스크립트, local setup, hosted Edge secret 설정은 모두 `GEMINI_API_KEY`만 사용

## 적용 범위

- `supabase/functions/caricature/index.ts`
- `supabase/functions/caricature/README.md`
- secret inventory / fallback sunset 문서
- backend / iOS 정적 체크

## 비범위

- production key rotation 자체 수행
- Gemini provider routing 정책 변경
- `OPENAI_API_KEY` fallback 전략 변경

## 저장소 기준 완료 조건

1. `caricature` 함수가 `GEMINI_API_KEY`만 읽는다.
2. 저장소 grep 기준 legacy Gemini alias가 남아 있지 않다.
3. secret inventory와 fallback sunset 문서가 alias 제거 상태를 반영한다.
4. backend / iOS PR 체크에 canonicalization 검증이 포함된다.

## Rollout 전 검증

### Secret 상태 확인
- hosted Edge secrets에 `GEMINI_API_KEY`가 존재해야 합니다.
- 더 이상 legacy Gemini alias를 운영 기준 이름으로 보지 않습니다.

### 저장소 검증
- 저장소 기준으로 legacy Gemini alias 문자열 결과가 `0건`이어야 합니다.

### 정적 검증
```bash
swift scripts/backend_gemini_api_key_canonical_unit_check.swift
bash scripts/backend_pr_check.sh
DOGAREA_SKIP_BUILD=1 bash scripts/ios_pr_check.sh
```

## 운영 메모

- 이 이슈는 alias 제거와 표준 이름 단일화만 다룹니다.
- 만약 hosted secret store에 아직 예전 Gemini alias 이름만 남아 있다면, 먼저 동일 값으로 `GEMINI_API_KEY`를 추가한 뒤 함수 배포/검증을 거쳐 예전 alias를 삭제해야 합니다.
- canonical name은 앞으로 `GEMINI_API_KEY`만 사용합니다.
