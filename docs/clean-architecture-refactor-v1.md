# DogArea Clean Architecture Refactor v1

## Goal
- Remove ViewModel-level storage coupling.
- Standardize Supabase access through infrastructure services.
- Keep current UX while replacing internals with repository/use-case boundaries.

## Layering
- Presentation: `Views/*ViewModel.swift`
- Repository: `Source/Data/Walk/WalkRepository.swift`
- Local cache: `WalkFileCacheDataSource` (`Application Support/walk-cache/v1`)
- Remote: `WalkSupabaseRemoteDataSource`, `Supabase*Transport`
- Infrastructure: `Source/Infrastructure/Supabase/SupabaseInfrastructure.swift`

## Migration notes
- ViewModels now depend on `WalkRepositoryProtocol` instead of `CoreDataProtocol`.
- Supabase inline clients were extracted from `UserdefaultSetting`, `MapViewModel`, `AreaMeters`, and `ProfileSyncOutboxStore`.
- Feature flags added:
  - `ff_repo_layer_v2`
  - `ff_supabase_read_v1`
  - `ff_coredata_deprecation_v1`

## Operational policy
- Write path: local cache first, then outbox enqueue/flush.
- Read path: Supabase read when flags allow; fallback to local cache.
- Offline: local cache always available.
