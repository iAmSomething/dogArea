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

    var pointsJSONString: String {
        guard let data = try? JSONEncoder().encode(points),
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
                    recordedAt: max(0, point.createdAt)
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
