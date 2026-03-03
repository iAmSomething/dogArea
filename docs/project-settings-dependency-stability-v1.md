# Project Settings & Dependency Stability v1

## 1. 목적
기능 이슈 수행 전, 빌드 실패의 비기능 원인(툴체인/타깃/의존성/워크플로 drift)을 고정한다.

연결 이슈:
- 본 문서: #62 (프로젝트 설정/의존성 안정화)

## 2. 기준 툴체인/타깃
- Xcode 기준: `LastUpgradeCheck = 1500` (Xcode 15 계열 기준)
- Swift 언어 버전: `SWIFT_VERSION = 5.0`
- iOS 최소 버전: `IPHONEOS_DEPLOYMENT_TARGET = 18.0`
- watchOS 최소 버전: `WATCHOS_DEPLOYMENT_TARGET = 10.2`

## 3. 공통 빌드 스킴 기준
- iOS: `dogArea`
- watchOS: `dogAreaWatch Watch App`
- 로컬/CI 모두 동일 명령으로 검증한다.

## 4. 로컬/CI 공통 체크 명령
- 실행 스크립트: `bash scripts/ios_pr_check.sh`
- 빠른 문서/유닛 체크만 수행: `DOGAREA_SKIP_BUILD=1 bash scripts/ios_pr_check.sh`

실행 순서:
1. 문서/유닛 스크립트 검증
2. iOS build
3. watchOS build

## 5. CI PR 체크 기준
- 워크플로 파일: `.github/workflows/ios-pr-check.yml`
- 트리거:
  - `pull_request` to `main`
  - `workflow_dispatch`
- 머지 게이트:
  - iOS/watchOS 빌드 실패 시 머지 차단
  - 문서/계약 스크립트 실패 시 머지 차단

## 6. Drift 방지 규칙
- `project.pbxproj`의 deployment target/Swift 버전 변경은 별도 이슈에서만 수행한다.
- SPM 변경(`Package.resolved`)은 기능 변경과 분리해 원인 추적성을 유지한다.
- PR 템플릿/워크플로에서 요구한 체크를 우회하지 않는다.

## 7. 재현 체크리스트
1. 클린 체크아웃 후 `bash scripts/ios_pr_check.sh` 실행 가능
2. 동일 브랜치 PR에서 `iOS PR Check` 통과
3. 문서(`README`, 본 문서) 기준으로 신규 환경에서도 동일 절차 재현 가능
