//
//  MapModel.swift
//  dogArea
//
//  Created by 김태훈 on 10/19/23.
//

import Foundation
import CoreLocation
import SwiftUI
import MapKit
import _MapKit_SwiftUI

struct Location: Identifiable, TimeCheckable {
    var createdAt: Double
    let id: UUID
    let coordinate: CLLocationCoordinate2D
    init(coordinate: CLLocationCoordinate2D, id: UUID, createdAt: Double) {
        self.id = id
        self.coordinate = coordinate
        self.createdAt = createdAt
    }
    init(coordinate: CLLocationCoordinate2D) {
        self.id = UUID()
        self.coordinate = coordinate
        self.createdAt = Date().timeIntervalSince1970
    }
}
extension Location : Equatable {
    static func == (lhs: Location, rhs: Location) -> Bool { lhs.id == rhs.id }
}
struct Polygon: Identifiable, TimeCheckable {
    var id: UUID
    var locations: [Location]
    var createdAt: Double
    var polygon: MKPolygon?
    var walkingArea: Double
    var walkingTime: Double
    var binaryImage: Data?
    var petId: String?
    init(
        locations: [Location] = [],
        walkingTime: Double,
        walkingArea: Double,
        petId: String? = nil
    ) {
        self.locations = locations
        self.id = UUID()
        self.polygon = MKPolygon(coordinates: locations.map{$0.coordinate}, count: locations.count)
        self.polygon?.title = "🐶"
        self.createdAt = Date().timeIntervalSince1970
        self.walkingArea = walkingArea
        self.walkingTime = walkingTime
        self.petId = petId
    }
    init(
        locations: [Location] = [],
        createdAt: Double,
        id: UUID,
        walkingTime: Double,
        walkingArea: Double,
        imgData: Data?,
        petId: String? = nil
    ) {
        self.locations = locations
        self.id = id
        self.polygon = MKPolygon(coordinates: locations.map{$0.coordinate}, count: locations.count)
        self.polygon?.title = "🐶"
        self.createdAt = createdAt
        self.walkingArea = walkingArea
        self.walkingTime = walkingTime
        self.binaryImage = imgData
        self.petId = petId
    }
    func center() -> CLLocationCoordinate2D? {
        guard !self.locations.isEmpty else {
            return nil
        }
        
        var minX = locations[0].coordinate.latitude
        var minY = locations[0].coordinate.longitude
        var maxX = locations[0].coordinate.latitude
        var maxY = locations[0].coordinate.longitude
        
        for location in locations {
            minX = min(minX, location.coordinate.latitude)
            minY = min(minY, location.coordinate.longitude)
            maxX = max(maxX, location.coordinate.latitude)
            maxY = max(maxY, location.coordinate.longitude)
        }
        
        let centerLatitude = (minX + maxX) / 2
        let centerLongitude = (minY + maxY) / 2
        
        return CLLocationCoordinate2D(latitude: centerLatitude, longitude: centerLongitude)
    }
}
extension Polygon {
    mutating func addPoint(_ loc : Location) {
        self.locations.append(loc)
    }
    mutating func makePolygon(walkArea: Double, walkTime: Double, img: UIImage? = nil) {
        self.walkingArea = walkArea
        self.walkingTime = walkTime
        self.binaryImage = img?.jpegData(compressionQuality: 1.0)
        refreshPolygon()
    }
    mutating func removeAt(_ loc : Location) {
        self.locations = self.locations.filter{$0 != loc}
        if polygon != nil && locations.count > 2{
            refreshPolygon()
        }
        else {
            polygon = nil
        }
    }
    mutating func removeAt(_ uid : UUID) {
        self.locations = self.locations.filter{$0.id != uid}
        if polygon != nil  && locations.count > 2{
            refreshPolygon()
        }
        else {
            polygon = nil
            self.locations = []
        }
    }
    mutating func clear() {
        self.locations = []
        if polygon != nil {
            refreshPolygon()
        }
    }
    
    private mutating func refreshPolygon() {
        self.createdAt = Date().timeIntervalSince1970
        self.id = UUID()
        let points = locations.map{MKMapPoint($0.coordinate)}
        self.polygon = MKPolygon(points: points, count: points.count)
        self.polygon?.title = "🐶"
        
    }
}

extension Array where Element == Polygon {
    func polygon(at id: UUID) -> Polygon? {
        self.first(where: {$0.id == id})
    }
}

struct HeatmapCellDTO: Identifiable, Equatable {
    let geohash: String
    let score: Double
    let centerCoordinate: CLLocationCoordinate2D

    var id: String { geohash }
    var intensityLevel: Int { Self.intensityLevel(for: score) }

    static func intensityLevel(for score: Double) -> Int {
        guard score > 0 else { return 0 }
        let level = Int(ceil(score * 5.0) - 1.0)
        return min(4, max(0, level))
    }

    /// Compares two heatmap cells by geohash, normalized score, and center coordinate values.
    /// - Parameters:
    ///   - lhs: The left-hand heatmap cell to compare.
    ///   - rhs: The right-hand heatmap cell to compare.
    /// - Returns: `true` when all semantic fields represent the same heatmap cell.
    static func == (lhs: HeatmapCellDTO, rhs: HeatmapCellDTO) -> Bool {
        lhs.geohash == rhs.geohash &&
        lhs.score == rhs.score &&
        lhs.centerCoordinate.latitude == rhs.centerCoordinate.latitude &&
        lhs.centerCoordinate.longitude == rhs.centerCoordinate.longitude
    }
}

struct NearbyHotspotDTO: Identifiable, Equatable {
    let geohash: String
    let count: Int
    let intensity: Double
    let centerCoordinate: CLLocationCoordinate2D

    var id: String { geohash }

    /// Compares two nearby hotspots by bucket identity, metrics, and center coordinate values.
    /// - Parameters:
    ///   - lhs: The left-hand hotspot to compare.
    ///   - rhs: The right-hand hotspot to compare.
    /// - Returns: `true` when both hotspots describe the same aggregated result.
    static func == (lhs: NearbyHotspotDTO, rhs: NearbyHotspotDTO) -> Bool {
        lhs.geohash == rhs.geohash &&
        lhs.count == rhs.count &&
        lhs.intensity == rhs.intensity &&
        lhs.centerCoordinate.latitude == rhs.centerCoordinate.latitude &&
        lhs.centerCoordinate.longitude == rhs.centerCoordinate.longitude
    }
}

enum HeatmapEngine {
    private static let halfLifeDays = 21.0
    private static let lambda = log(2.0) / halfLifeDays

    static func decayWeight(recordedAt: TimeInterval, now: Date = Date()) -> Double {
        let ageDays = max(0.0, (now.timeIntervalSince1970 - recordedAt) / 86_400.0)
        return exp(-lambda * ageDays)
    }

    static func aggregate(points: [Location], now: Date = Date(), precision: Int = 7) -> [HeatmapCellDTO] {
        guard !points.isEmpty else { return [] }

        var bucketWeights: [String: Double] = [:]
        var bucketCenters: [String: CLLocationCoordinate2D] = [:]

        for point in points {
            let geohash = GeohashCoder.encode(
                latitude: point.coordinate.latitude,
                longitude: point.coordinate.longitude,
                precision: precision
            )
            let weight = decayWeight(recordedAt: point.createdAt, now: now)
            bucketWeights[geohash, default: 0.0] += weight

            if bucketCenters[geohash] == nil {
                bucketCenters[geohash] = GeohashCoder.decodeCenter(geohash: geohash)
            }
        }

        guard let maxWeight = bucketWeights.values.max(), maxWeight > 0 else {
            return []
        }

        return bucketWeights.keys.sorted().compactMap { geohash in
            guard let weight = bucketWeights[geohash],
                  let center = bucketCenters[geohash] else {
                return nil
            }

            let normalized = min(1.0, max(0.0, weight / maxWeight))
            return HeatmapCellDTO(
                geohash: geohash,
                score: normalized,
                centerCoordinate: center
            )
        }
    }
}

private enum GeohashCoder {
    private static let base32 = Array("0123456789bcdefghjkmnpqrstuvwxyz")
    private static let bitMasks = [16, 8, 4, 2, 1]

    static func encode(latitude: Double, longitude: Double, precision: Int) -> String {
        var latRange = (-90.0, 90.0)
        var lonRange = (-180.0, 180.0)
        var isEvenBit = true
        var bitIndex = 0
        var currentChar = 0
        var output = ""

        while output.count < max(1, precision) {
            if isEvenBit {
                let mid = (lonRange.0 + lonRange.1) / 2.0
                if longitude >= mid {
                    currentChar |= bitMasks[bitIndex]
                    lonRange.0 = mid
                } else {
                    lonRange.1 = mid
                }
            } else {
                let mid = (latRange.0 + latRange.1) / 2.0
                if latitude >= mid {
                    currentChar |= bitMasks[bitIndex]
                    latRange.0 = mid
                } else {
                    latRange.1 = mid
                }
            }

            isEvenBit.toggle()
            if bitIndex < 4 {
                bitIndex += 1
            } else {
                output.append(base32[currentChar])
                bitIndex = 0
                currentChar = 0
            }
        }
        return output
    }

    static func decodeCenter(geohash: String) -> CLLocationCoordinate2D? {
        guard !geohash.isEmpty else { return nil }

        var latRange = (-90.0, 90.0)
        var lonRange = (-180.0, 180.0)
        var isEvenBit = true

        for char in geohash.lowercased() {
            guard let index = base32.firstIndex(of: char) else { return nil }

            for bit in bitMasks {
                let bitSet = (index & bit) != 0
                if isEvenBit {
                    let mid = (lonRange.0 + lonRange.1) / 2.0
                    if bitSet { lonRange.0 = mid } else { lonRange.1 = mid }
                } else {
                    let mid = (latRange.0 + latRange.1) / 2.0
                    if bitSet { latRange.0 = mid } else { latRange.1 = mid }
                }
                isEvenBit.toggle()
            }
        }

        return CLLocationCoordinate2D(
            latitude: (latRange.0 + latRange.1) / 2.0,
            longitude: (lonRange.0 + lonRange.1) / 2.0
        )
    }
}
