import Foundation
import CoreLocation

private func normalizedPetUUIDString(_ raw: String?) -> String? {
    guard let raw, raw.isEmpty == false, let parsed = UUID(uuidString: raw) else {
        return nil
    }
    return parsed.uuidString.lowercased()
}

struct WalkSessionDTO: Codable, Equatable, Identifiable {
    let id: String
    let userId: String?
    let petId: String?
    let startedAt: TimeInterval
    let endedAt: TimeInterval
    let durationSec: TimeInterval
    let areaM2: Double
    let hasImage: Bool
}

struct WalkSessionDetailDTO: Codable, Equatable {
    let session: WalkSessionDTO
    let points: [WalkPointBackfillDTO]
}

struct WalkSaveInput: Codable, Equatable {
    let session: WalkSessionDTO
    let points: [WalkPointBackfillDTO]
    let imageDataBase64: String?
}

struct WalkPointCacheRecord: Codable, Equatable {
    let id: String
    let lat: Double
    let lng: Double
    let createdAt: TimeInterval
    let pointRole: String?
}

struct WalkSessionCacheRecord: Codable, Equatable, Identifiable {
    let id: String
    var createdAt: TimeInterval
    var walkingTime: Double
    var walkingArea: Double
    var petId: String?
    var imageDataBase64: String?
    var points: [WalkPointCacheRecord]
}

struct WalkAreaCacheRecord: Codable, Equatable {
    let areaName: String
    let area: Double
    let createdAt: TimeInterval
}

struct WalkCacheSnapshot: Codable, Equatable {
    var version: Int
    var sessions: [WalkSessionCacheRecord]
    var areas: [WalkAreaCacheRecord]
    var updatedAt: TimeInterval

    static let empty = WalkCacheSnapshot(version: 1, sessions: [], areas: [], updatedAt: 0)
}

protocol WalkLocalCacheDataSourceProtocol {
    func loadSnapshot() -> WalkCacheSnapshot
    func saveSnapshot(_ snapshot: WalkCacheSnapshot)
}

final class WalkFileCacheDataSource: WalkLocalCacheDataSourceProtocol {
    private let fm: FileManager
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    private let stateQueue = DispatchQueue(label: "com.th.dogArea.walk-file-cache.state")
    private let fileURL: URL

    init(
        fileManager: FileManager = .default,
        baseDirectory: URL? = nil
    ) {
        self.fm = fileManager
        let root = baseDirectory ?? Self.defaultRootDirectory(fileManager: fileManager)
        self.fileURL = root
            .appendingPathComponent("walk-cache", isDirectory: true)
            .appendingPathComponent("v1", isDirectory: true)
            .appendingPathComponent("walk_snapshot.json", isDirectory: false)
        encoder.outputFormatting = [.sortedKeys]
        ensureDirectory()
    }

    func loadSnapshot() -> WalkCacheSnapshot {
        stateQueue.sync {
            do {
                guard fm.fileExists(atPath: fileURL.path) else { return .empty }
                let data = try Data(contentsOf: fileURL)
                let decoded = try decoder.decode(WalkCacheSnapshot.self, from: data)
                if decoded.version == 1 { return decoded }
                return WalkCacheSnapshot(version: 1, sessions: decoded.sessions, areas: decoded.areas, updatedAt: decoded.updatedAt)
            } catch {
                return .empty
            }
        }
    }

    func saveSnapshot(_ snapshot: WalkCacheSnapshot) {
        stateQueue.sync {
            do {
                ensureDirectory()
                var mutable = snapshot
                mutable.version = 1
                mutable.updatedAt = Date().timeIntervalSince1970
                let data = try encoder.encode(mutable)
                try data.write(to: fileURL, options: [.atomic])
            } catch {
                // ignore local cache write failures to avoid blocking walk flow
            }
        }
    }

    private func ensureDirectory() {
        let dir = fileURL.deletingLastPathComponent()
        if fm.fileExists(atPath: dir.path) == false {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    private static func defaultRootDirectory(fileManager: FileManager) -> URL {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    }
}

protocol WalkRemoteDataSourceProtocol {
    func fetchSessions(selectedPetId: String?) async throws -> [WalkSessionDTO]
    func fetchSessionDetail(sessionId: String) async throws -> WalkSessionDetailDTO
}

struct WalkSupabaseRemoteDataSource: WalkRemoteDataSourceProtocol {
    private let client: SupabaseHTTPClient

    init(client: SupabaseHTTPClient = .live) {
        self.client = client
    }

    private struct RemoteSessionDTO: Decodable {
        let id: String
        let ownerUserId: String?
        let petId: String?
        let startedAt: String?
        let endedAt: String?
        let durationSec: Double?
        let areaM2: Double?
        let hasImage: Bool?

        enum CodingKeys: String, CodingKey {
            case id
            case ownerUserId = "owner_user_id"
            case petId = "pet_id"
            case startedAt = "started_at"
            case endedAt = "ended_at"
            case durationSec = "duration_sec"
            case areaM2 = "area_m2"
            case hasImage = "has_image"
        }
    }

    private struct RemotePointDTO: Decodable {
        let seqNo: Int?
        let lat: Double
        let lng: Double
        let recordedAt: String?
        let pointRole: String?

        enum CodingKeys: String, CodingKey {
            case seqNo = "seq_no"
            case lat
            case lng
            case recordedAt = "recorded_at"
            case pointRole = "point_role"
        }
    }

    func fetchSessions(selectedPetId: String?) async throws -> [WalkSessionDTO] {
        var query = "select=id,owner_user_id,pet_id,started_at,ended_at,duration_sec,area_m2,has_image&order=ended_at.asc"
        if let selectedPetId, selectedPetId.isEmpty == false {
            query += "&pet_id=eq.\(selectedPetId.lowercased())"
        }
        let data = try await client.request(
            .rest(path: "walk_sessions", query: query),
            method: .get,
            body: Optional<String>.none
        )
        let rows = try JSONDecoder().decode([RemoteSessionDTO].self, from: data)
        return rows.map { row in
            WalkSessionDTO(
                id: row.id,
                userId: row.ownerUserId,
                petId: row.petId,
                startedAt: SupabaseISO8601.parseEpoch(row.startedAt) ?? 0,
                endedAt: SupabaseISO8601.parseEpoch(row.endedAt) ?? 0,
                durationSec: max(0, row.durationSec ?? 0),
                areaM2: max(0, row.areaM2 ?? 0),
                hasImage: row.hasImage ?? false
            )
        }
    }

    func fetchSessionDetail(sessionId: String) async throws -> WalkSessionDetailDTO {
        let sessionData = try await client.request(
            .rest(path: "walk_sessions", query: "select=id,owner_user_id,pet_id,started_at,ended_at,duration_sec,area_m2,has_image&id=eq.\(sessionId)&limit=1"),
            method: .get,
            body: Optional<String>.none
        )
        let sessions = try JSONDecoder().decode([RemoteSessionDTO].self, from: sessionData)
        guard let sessionRow = sessions.first else {
            throw SupabaseHTTPError.unexpectedStatusCode(404)
        }

        let pointData = try await client.request(
            .rest(path: "walk_points", query: "select=seq_no,lat,lng,recorded_at&walk_session_id=eq.\(sessionId)&order=seq_no.asc"),
            method: .get,
            body: Optional<String>.none
        )
        let points = try JSONDecoder().decode([RemotePointDTO].self, from: pointData).enumerated().map { index, row in
            WalkPointBackfillDTO(
                seqNo: row.seqNo ?? index,
                lat: row.lat,
                lng: row.lng,
                recordedAt: SupabaseISO8601.parseEpoch(row.recordedAt) ?? 0,
                pointRole: row.pointRole ?? WalkPointRole.mark.rawValue
            )
        }

        let session = WalkSessionDTO(
            id: sessionRow.id,
            userId: sessionRow.ownerUserId,
            petId: sessionRow.petId,
            startedAt: SupabaseISO8601.parseEpoch(sessionRow.startedAt) ?? 0,
            endedAt: SupabaseISO8601.parseEpoch(sessionRow.endedAt) ?? 0,
            durationSec: max(0, sessionRow.durationSec ?? 0),
            areaM2: max(0, sessionRow.areaM2 ?? 0),
            hasImage: sessionRow.hasImage ?? false
        )
        return WalkSessionDetailDTO(session: session, points: points)
    }
}

protocol WalkOutboxCoordinating {
    func enqueue(session: WalkSessionBackfillDTO)
    func flush(force: Bool) async
}

final class WalkOutboxCoordinator: WalkOutboxCoordinating {
    static let shared = WalkOutboxCoordinator()

    private let store: SyncOutboxStore
    private let transport: SyncOutboxTransporting

    init(
        store: SyncOutboxStore = .shared,
        transport: SyncOutboxTransporting = SupabaseSyncOutboxTransport()
    ) {
        self.store = store
        self.transport = transport
    }

    func enqueue(session: WalkSessionBackfillDTO) {
        store.enqueueWalkStages(sessionDTO: session)
    }

    func flush(force: Bool = false) async {
        _ = await store.flush(using: transport, now: Date())
    }
}

protocol WalkRepositoryProtocol {
    func fetchSessions(selectedPetId: String?) async throws -> [WalkSessionDTO]
    func fetchSessionDetail(sessionId: String) async throws -> WalkSessionDetailDTO
    func saveSession(_ input: WalkSaveInput) async throws
    func deleteSession(sessionId: String) async throws
    func syncPending() async

    func fetchPolygons() -> [Polygon]
    func savePolygon(_ polygon: Polygon) -> [Polygon]
    func deletePolygon(id: UUID) -> [Polygon]
    func saveArea(_ area: AreaMeterDTO) -> Bool
    func fetchAreas() -> [AreaMeterDTO]
}

final class WalkRepository: WalkRepositoryProtocol {
    private let local: WalkLocalCacheDataSourceProtocol
    private let remote: WalkRemoteDataSourceProtocol
    private let outbox: WalkOutboxCoordinating
    private let userDefaults: UserDefaults
    private let stateQueue = DispatchQueue(label: "com.th.dogArea.walk-repository.state")

    private let supabaseReadFlagKey = "ff_supabase_read_v1"
    private let backfillFlagKey = "walk.cache.petid.backfill.v1.completed"

    init(
        local: WalkLocalCacheDataSourceProtocol = WalkFileCacheDataSource(),
        remote: WalkRemoteDataSourceProtocol = WalkSupabaseRemoteDataSource(),
        outbox: WalkOutboxCoordinating = WalkOutboxCoordinator.shared,
        userDefaults: UserDefaults = .standard
    ) {
        self.local = local
        self.remote = remote
        self.outbox = outbox
        self.userDefaults = userDefaults
    }

    func fetchSessions(selectedPetId: String?) async throws -> [WalkSessionDTO] {
        if shouldUseSupabaseRead {
            do {
                let remoteSessions = try await remote.fetchSessions(selectedPetId: selectedPetId)
                if remoteSessions.isEmpty == false {
                    cache(remoteSessions: remoteSessions)
                    return remoteSessions
                }
            } catch {
                // fallback to cache
            }
        }

        let locals = fetchPolygons()
            .filter {
                guard let selectedPetId, selectedPetId.isEmpty == false else { return true }
                return $0.petId == selectedPetId
            }
            .map { polygon in
                let endedAt = max(0, polygon.createdAt)
                let duration = max(0, polygon.walkingTime)
                return WalkSessionDTO(
                    id: polygon.id.uuidString.lowercased(),
                    userId: nil,
                    petId: polygon.petId,
                    startedAt: max(0, endedAt - duration),
                    endedAt: endedAt,
                    durationSec: duration,
                    areaM2: max(0, polygon.walkingArea),
                    hasImage: polygon.binaryImage != nil
                )
            }
        return locals
    }

    func fetchSessionDetail(sessionId: String) async throws -> WalkSessionDetailDTO {
        if shouldUseSupabaseRead {
            if let remoteDetail = try? await remote.fetchSessionDetail(sessionId: sessionId) {
                return remoteDetail
            }
        }

        let polygons = fetchPolygons()
        guard let polygon = polygons.first(where: { $0.id.uuidString.lowercased() == sessionId.lowercased() }) else {
            throw SupabaseHTTPError.unexpectedStatusCode(404)
        }
        guard let dto = WalkBackfillDTOConverter.makeSessionDTO(
            from: polygon,
            ownerUserId: nil,
            petId: polygon.petId,
            sourceDevice: "ios"
        ) else {
            throw SupabaseHTTPError.invalidResponse
        }
        let session = WalkSessionDTO(
            id: dto.walkSessionId,
            userId: dto.ownerUserId,
            petId: dto.petId,
            startedAt: dto.startedAt,
            endedAt: dto.endedAt,
            durationSec: dto.durationSec,
            areaM2: dto.areaM2,
            hasImage: dto.hasImage
        )
        return WalkSessionDetailDTO(session: session, points: dto.points)
    }

    func saveSession(_ input: WalkSaveInput) async throws {
        let points = input.points.map {
            Location(
                coordinate: CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng),
                id: UUID(),
                createdAt: $0.recordedAt,
                pointRole: WalkPointRole(rawValue: $0.pointRole) ?? .mark
            )
        }
        let polygon = Polygon(
            locations: points,
            createdAt: input.session.endedAt,
            id: UUID(uuidString: input.session.id) ?? UUID(),
            walkingTime: input.session.durationSec,
            walkingArea: input.session.areaM2,
            imgData: input.imageDataBase64.flatMap { Data(base64Encoded: $0) },
            petId: input.session.petId
        )
        _ = savePolygon(polygon)
    }

    func deleteSession(sessionId: String) async throws {
        guard let uuid = UUID(uuidString: sessionId) else { return }
        _ = deletePolygon(id: uuid)
    }

    func syncPending() async {
        await outbox.flush(force: true)
    }

    func fetchPolygons() -> [Polygon] {
        stateQueue.sync {
            var snapshot = local.loadSnapshot()
            snapshot = backfillPetIdsIfNeeded(snapshot)
            return snapshot.sessions
                .sorted { $0.createdAt < $1.createdAt }
                .compactMap(Self.polygon(from:))
        }
    }

    func savePolygon(_ polygon: Polygon) -> [Polygon] {
        stateQueue.sync {
            var snapshot = local.loadSnapshot()
            let sessionId = polygon.id.uuidString.lowercased()
            let record = Self.sessionRecord(from: polygon)
            if let index = snapshot.sessions.firstIndex(where: { $0.id == sessionId }) {
                snapshot.sessions[index] = record
            } else {
                snapshot.sessions.append(record)
            }
            snapshot.sessions.sort { $0.createdAt < $1.createdAt }
            local.saveSnapshot(snapshot)
        }

        if let sessionDTO = WalkBackfillDTOConverter.makeSessionDTO(
            from: polygon,
            ownerUserId: UserdefaultSetting.shared.getValue()?.id,
            petId: polygon.petId,
            sourceDevice: "ios",
            hasImage: polygon.binaryImage != nil
        ) {
            outbox.enqueue(session: sessionDTO)
            Task { [outbox] in await outbox.flush(force: false) }
        }

        return fetchPolygons()
    }

    func deletePolygon(id: UUID) -> [Polygon] {
        stateQueue.sync {
            var snapshot = local.loadSnapshot()
            snapshot.sessions.removeAll { $0.id == id.uuidString.lowercased() }
            local.saveSnapshot(snapshot)
        }
        WalkSessionMetadataStore.shared.clear(sessionId: id)
        return fetchPolygons()
    }

    func saveArea(_ area: AreaMeterDTO) -> Bool {
        stateQueue.sync {
            var snapshot = local.loadSnapshot()
            snapshot.areas.append(
                WalkAreaCacheRecord(
                    areaName: area.areaName,
                    area: area.area,
                    createdAt: area.createdAt
                )
            )
            snapshot.areas.sort { $0.createdAt < $1.createdAt }
            local.saveSnapshot(snapshot)
        }
        return true
    }

    func fetchAreas() -> [AreaMeterDTO] {
        stateQueue.sync {
            local.loadSnapshot().areas
                .sorted { $0.createdAt < $1.createdAt }
                .map { AreaMeterDTO(areaName: $0.areaName, area: $0.area, createdAt: $0.createdAt) }
        }
    }

    private var shouldUseSupabaseRead: Bool {
        if FeatureFlagStore.shared.isEnabled(.repoLayerV2) == false { return false }
        if FeatureFlagStore.shared.isEnabled(.supabaseReadV1) == false { return false }
        let env = ProcessInfo.processInfo.environment
        if let raw = env["FF_SUPABASE_READ_V1"]?.lowercased() {
            return raw == "1" || raw == "true" || raw == "yes"
        }
        return userDefaults.object(forKey: supabaseReadFlagKey) as? Bool ?? true
    }

    private func backfillPetIdsIfNeeded(_ snapshot: WalkCacheSnapshot) -> WalkCacheSnapshot {
        guard userDefaults.bool(forKey: backfillFlagKey) == false else { return snapshot }

        var mutable = snapshot
        var didUpdate = false
        for index in mutable.sessions.indices {
            if normalizedPetUUIDString(mutable.sessions[index].petId) != nil { continue }
            guard let sessionUUID = UUID(uuidString: mutable.sessions[index].id),
                  let petId = normalizedPetUUIDString(WalkSessionMetadataStore.shared.petId(sessionId: sessionUUID)) else {
                continue
            }
            mutable.sessions[index].petId = petId
            didUpdate = true
        }

        if didUpdate {
            local.saveSnapshot(mutable)
        }
        userDefaults.set(true, forKey: backfillFlagKey)
        return mutable
    }

    private func cache(remoteSessions: [WalkSessionDTO]) {
        stateQueue.sync {
            var snapshot = local.loadSnapshot()
            for session in remoteSessions {
                let record = WalkSessionCacheRecord(
                    id: session.id.lowercased(),
                    createdAt: session.endedAt,
                    walkingTime: session.durationSec,
                    walkingArea: session.areaM2,
                    petId: normalizedPetUUIDString(session.petId),
                    imageDataBase64: nil,
                    points: []
                )
                if let idx = snapshot.sessions.firstIndex(where: { $0.id == record.id }) {
                    snapshot.sessions[idx] = record
                } else {
                    snapshot.sessions.append(record)
                }
            }
            snapshot.sessions.sort { $0.createdAt < $1.createdAt }
            local.saveSnapshot(snapshot)
        }
    }

    private static func sessionRecord(from polygon: Polygon) -> WalkSessionCacheRecord {
        WalkSessionCacheRecord(
            id: polygon.id.uuidString.lowercased(),
            createdAt: polygon.createdAt,
            walkingTime: polygon.walkingTime,
            walkingArea: polygon.walkingArea,
            petId: normalizedPetUUIDString(polygon.petId),
            imageDataBase64: polygon.binaryImage?.base64EncodedString(),
            points: polygon.locations.map { location in
                WalkPointCacheRecord(
                    id: location.id.uuidString.lowercased(),
                    lat: location.coordinate.latitude,
                    lng: location.coordinate.longitude,
                    createdAt: location.createdAt,
                    pointRole: location.pointRole.rawValue
                )
            }
        )
    }

    private static func polygon(from record: WalkSessionCacheRecord) -> Polygon? {
        guard let uuid = UUID(uuidString: record.id) else { return nil }
        let points = record.points.compactMap { point -> Location? in
            guard let pointId = UUID(uuidString: point.id) else { return nil }
            return Location(
                coordinate: CLLocationCoordinate2D(latitude: point.lat, longitude: point.lng),
                id: pointId,
                createdAt: point.createdAt,
                pointRole: WalkPointRole(rawValue: point.pointRole ?? WalkPointRole.mark.rawValue) ?? .mark
            )
        }

        return Polygon(
            locations: points,
            createdAt: record.createdAt,
            id: uuid,
            walkingTime: record.walkingTime,
            walkingArea: record.walkingArea,
            imgData: record.imageDataBase64.flatMap { Data(base64Encoded: $0) },
            petId: normalizedPetUUIDString(record.petId)
        )
    }
}

enum WalkRepositoryContainer {
    static let shared: WalkRepositoryProtocol = WalkRepository()
}
