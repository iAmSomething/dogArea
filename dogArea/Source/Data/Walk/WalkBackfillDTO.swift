import Foundation

private func normalizedUUIDStringOrNil(_ raw: String?) -> String? {
    guard let raw, raw.isEmpty == false,
          let parsed = UUID(uuidString: raw) else {
        return nil
    }
    return parsed.uuidString.lowercased()
}

struct WalkPointBackfillDTO: Codable, Equatable {
    let seqNo: Int
    let lat: Double
    let lng: Double
    let recordedAt: TimeInterval
    let pointRole: String

    /// 산책 포인트 백필 DTO를 생성합니다.
    /// - Parameters:
    ///   - seqNo: 세션 내 포인트 순번입니다.
    ///   - lat: 포인트 위도입니다.
    ///   - lng: 포인트 경도입니다.
    ///   - recordedAt: 포인트 기록 시각(UNIX epoch)입니다.
    ///   - pointRole: 포인트 역할(`mark`/`route`) 문자열입니다.
    init(
        seqNo: Int,
        lat: Double,
        lng: Double,
        recordedAt: TimeInterval,
        pointRole: String
    ) {
        self.seqNo = seqNo
        self.lat = lat
        self.lng = lng
        self.recordedAt = recordedAt
        self.pointRole = pointRole
    }

    /// 직렬화된 산책 포인트 데이터를 디코딩합니다.
    /// - Parameter decoder: DTO 복원에 사용할 디코더입니다.
    /// - Throws: 필수 필드가 없거나 타입이 맞지 않으면 디코딩 에러를 던집니다.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        seqNo = try container.decode(Int.self, forKey: .seqNo)
        lat = try container.decode(Double.self, forKey: .lat)
        lng = try container.decode(Double.self, forKey: .lng)
        recordedAt = try container.decode(TimeInterval.self, forKey: .recordedAt)
        pointRole = try container.decodeIfPresent(String.self, forKey: .pointRole) ?? WalkPointRole.mark.rawValue
    }
}

struct WalkSessionBackfillDTO: Codable, Equatable {
    let walkSessionId: String
    let ownerUserId: String?
    let petId: String?
    let createdAt: TimeInterval
    let startedAt: TimeInterval
    let endedAt: TimeInterval
    let durationSec: TimeInterval
    let areaM2: Double
    let sourceDevice: String
    let hasImage: Bool
    let mapImageURL: String?
    let points: [WalkPointBackfillDTO]

    var pointCount: Int { points.count }

    var routePoints: [WalkPointBackfillDTO] {
        points.filter { $0.pointRole == WalkPointRole.route.rawValue }
    }

    var markPoints: [WalkPointBackfillDTO] {
        points.filter { $0.pointRole == WalkPointRole.mark.rawValue }
    }

    var pointsJSONString: String {
        guard let data = try? JSONEncoder().encode(points),
              let string = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return string
    }

    var routePointsJSONString: String {
        guard let data = try? JSONEncoder().encode(routePoints),
              let string = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return string
    }

    var markPointsJSONString: String {
        guard let data = try? JSONEncoder().encode(markPoints),
              let string = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return string
    }
}

enum WalkBackfillDTOConverter {
    static func makeSessionDTO(
        from polygon: Polygon,
        ownerUserId: String?,
        petId: String?,
        sourceDevice: String = "ios",
        hasImage: Bool? = nil
    ) -> WalkSessionBackfillDTO? {
        let walkSessionId = polygon.id.uuidString.lowercased()
        guard walkSessionId.isEmpty == false else { return nil }

        let endedAt = max(0, polygon.createdAt)
        let durationSec = max(0, polygon.walkingTime)
        let startedAt = max(0, endedAt - durationSec)

        let points = polygon.locations
            .enumerated()
            .map { index, point in
                WalkPointBackfillDTO(
                    seqNo: index,
                    lat: point.coordinate.latitude,
                    lng: point.coordinate.longitude,
                    recordedAt: max(0, point.createdAt),
                    pointRole: point.pointRole.rawValue
                )
            }

        return WalkSessionBackfillDTO(
            walkSessionId: walkSessionId,
            ownerUserId: ownerUserId,
            petId: normalizedUUIDString(petId) ?? normalizedUUIDString(polygon.petId),
            createdAt: endedAt,
            startedAt: startedAt,
            endedAt: endedAt,
            durationSec: durationSec,
            areaM2: max(0, polygon.walkingArea),
            sourceDevice: sourceDevice,
            hasImage: hasImage ?? (polygon.binaryImage != nil),
            mapImageURL: nil,
            points: points
        )
    }

    private static func normalizedUUIDString(_ raw: String?) -> String? {
        guard let raw, raw.isEmpty == false,
              let parsed = UUID(uuidString: raw) else {
            return nil
        }
        return parsed.uuidString.lowercased()
    }
}

extension Polygon {
    var canonicalPetId: String? {
        normalizedUUIDStringOrNil(self.petId)
    }
}
