//
//  CoreDataDTO.swift
//  dogArea
//
//  Created by 김태훈 on 10/20/23.
//

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

enum CoreDataSupabaseBackfillDTOConverter {
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

    static func makeSessionDTO(
        from entity: PolygonEntity,
        ownerUserId: String?,
        petId: String?,
        sourceDevice: String = "ios"
    ) -> WalkSessionBackfillDTO? {
        let canonicalPetId = normalizedUUIDString(petId) ?? normalizedUUIDString(entity.petId)
        guard let polygon = entity.toPolygon() else { return nil }
        return makeSessionDTO(
            from: polygon,
            ownerUserId: ownerUserId,
            petId: canonicalPetId,
            sourceDevice: sourceDevice,
            hasImage: entity.mapImage != nil
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

extension PolygonEntity {
  func toPolygon() -> Polygon? {
    var locations = [Location]()
      let walkingTime = self.walkingTime
      let walkingArea = self.walkingArea
    guard
      let id = self.uuid,
      let locationEntities = self.locations?.array as? [LocationEntity]
    else {
      return nil
    }
      let data = self.mapImage
      let petId = normalizedUUIDStringOrNil(self.petId)
    for entity in locationEntities {
      if let location = entity.toLocation() {
        locations.append(location)
      }
    }
      return Polygon(locations: locations,
                     createdAt: Double(self.createdAt),
                     id:id,
                     walkingTime: walkingTime,
                     walkingArea: walkingArea,
                     imgData: data,
                     petId: petId)
  }
}

extension LocationEntity {
  func toLocation() -> Location? {
    guard
      let id = self.uuid,
      let x = self.x,
      let y = self.y,
      let createdAt = self.createdAt
    else {
      return nil
    }
    return Location.init(coordinate: .init(latitude: Double(truncating: x), longitude: Double(truncating: y)), id: id, createdAt: Double(truncating: createdAt))
  }
}
extension AreaEntity {
    func toArea() -> AreaMeterDTO? {
        guard
            let areaName = self.areaName
        else {return nil}
        return AreaMeterDTO(areaName: areaName, area: self.areaSize, createdAt: self.createdAt)
    }
}
