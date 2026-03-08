//
//  MapHeatmapAggregationService.swift
//  dogArea
//
//  Created by Codex on 3/8/26.
//

import Foundation

/// 지도 heatmap 집계 재사용과 비동기 계산을 담당하는 계약입니다.
protocol MapHeatmapAggregationServicing {
    /// 현재 polygon 목록의 heatmap 입력 변경 여부를 추적할 fingerprint를 생성합니다.
    /// - Parameter polygons: heatmap 집계에 반영할 polygon 목록입니다.
    /// - Returns: 동일한 입력이면 같은 값을 갖는 heatmap dataset fingerprint입니다.
    func makeDatasetFingerprint(from polygons: [Polygon]) -> MapHeatmapDatasetFingerprint

    /// 저장된 heatmap snapshot을 그대로 재사용할 수 있는지 판단합니다.
    /// - Parameters:
    ///   - snapshot: 이전 계산 결과로 보관 중인 snapshot입니다.
    ///   - datasetFingerprint: 현재 polygon 목록의 fingerprint입니다.
    ///   - reference: 이번 판단 기준 시각입니다.
    /// - Returns: 입력과 시간 버킷이 모두 유효하면 `true`입니다.
    func canReuseSnapshot(
        _ snapshot: MapHeatmapAggregationSnapshot?,
        datasetFingerprint: MapHeatmapDatasetFingerprint,
        reference: Date
    ) -> Bool

    /// 현재 polygon 목록의 heatmap 셀을 background task에서 집계합니다.
    /// - Parameters:
    ///   - polygons: heatmap 집계에 사용할 polygon 목록입니다.
    ///   - datasetFingerprint: 현재 polygon 목록의 fingerprint입니다.
    ///   - reference: decay weight와 snapshot 유효 구간 계산에 사용할 기준 시각입니다.
    /// - Returns: 재사용 가능한 heatmap 집계 snapshot입니다.
    func makeAggregationSnapshot(
        polygons: [Polygon],
        datasetFingerprint: MapHeatmapDatasetFingerprint,
        reference: Date
    ) async -> MapHeatmapAggregationSnapshot
}

final class MapHeatmapAggregationService: MapHeatmapAggregationServicing {
    private let refreshBucketInterval: TimeInterval
    private let geohashPrecision: Int

    /// heatmap 집계 서비스의 시간 버킷/정밀도 정책을 생성합니다.
    /// - Parameters:
    ///   - refreshBucketInterval: 동일 입력 재사용을 허용할 시간 버킷 길이(초)입니다.
    ///   - geohashPrecision: heatmap bucket geohash 정밀도입니다.
    init(
        refreshBucketInterval: TimeInterval = 900,
        geohashPrecision: Int = 7
    ) {
        self.refreshBucketInterval = refreshBucketInterval
        self.geohashPrecision = geohashPrecision
    }

    /// 현재 polygon 목록의 heatmap 입력 변경 여부를 추적할 fingerprint를 생성합니다.
    /// - Parameter polygons: heatmap 집계에 반영할 polygon 목록입니다.
    /// - Returns: 동일한 입력이면 같은 값을 갖는 heatmap dataset fingerprint입니다.
    func makeDatasetFingerprint(from polygons: [Polygon]) -> MapHeatmapDatasetFingerprint {
        var hash: UInt64 = 0xcbf29ce484222325
        let sortedPolygons = polygons.sorted { lhs, rhs in
            lhs.id.uuidString < rhs.id.uuidString
        }
        var pointCount = 0

        for polygon in sortedPolygons {
            mix(value: polygon.id.uuidString.utf8, into: &hash)
            mix(value: polygon.createdAt.bitPattern, into: &hash)
            mix(value: UInt64(polygon.locations.count), into: &hash)

            for point in polygon.locations {
                pointCount += 1
                mix(value: point.id.uuidString.utf8, into: &hash)
                mix(value: point.createdAt.bitPattern, into: &hash)
                mix(value: point.coordinate.latitude.bitPattern, into: &hash)
                mix(value: point.coordinate.longitude.bitPattern, into: &hash)
            }
        }

        return MapHeatmapDatasetFingerprint(
            digestHex: String(format: "%016llx", hash),
            polygonCount: polygons.count,
            pointCount: pointCount
        )
    }

    /// 저장된 heatmap snapshot을 그대로 재사용할 수 있는지 판단합니다.
    /// - Parameters:
    ///   - snapshot: 이전 계산 결과로 보관 중인 snapshot입니다.
    ///   - datasetFingerprint: 현재 polygon 목록의 fingerprint입니다.
    ///   - reference: 이번 판단 기준 시각입니다.
    /// - Returns: 입력과 시간 버킷이 모두 유효하면 `true`입니다.
    func canReuseSnapshot(
        _ snapshot: MapHeatmapAggregationSnapshot?,
        datasetFingerprint: MapHeatmapDatasetFingerprint,
        reference: Date
    ) -> Bool {
        guard let snapshot else { return false }
        guard snapshot.datasetFingerprint == datasetFingerprint else { return false }

        let referenceTimestamp = reference.timeIntervalSince1970
        guard referenceTimestamp >= snapshot.computedAt else { return false }
        return referenceTimestamp <= snapshot.validThrough
    }

    /// 현재 polygon 목록의 heatmap 셀을 background task에서 집계합니다.
    /// - Parameters:
    ///   - polygons: heatmap 집계에 사용할 polygon 목록입니다.
    ///   - datasetFingerprint: 현재 polygon 목록의 fingerprint입니다.
    ///   - reference: decay weight와 snapshot 유효 구간 계산에 사용할 기준 시각입니다.
    /// - Returns: 재사용 가능한 heatmap 집계 snapshot입니다.
    func makeAggregationSnapshot(
        polygons: [Polygon],
        datasetFingerprint: MapHeatmapDatasetFingerprint,
        reference: Date
    ) async -> MapHeatmapAggregationSnapshot {
        let points = polygons.flatMap(\.locations)
        let computedAt = reference.timeIntervalSince1970
        let validThrough = nextBucketBoundary(after: reference)
        let geohashPrecision = self.geohashPrecision

        return await Task.detached(priority: .utility) {
            let cells = HeatmapEngine.aggregate(
                points: points,
                now: reference,
                precision: geohashPrecision
            )
            return MapHeatmapAggregationSnapshot(
                datasetFingerprint: datasetFingerprint,
                computedAt: computedAt,
                validThrough: validThrough,
                sourcePointCount: points.count,
                cells: cells
            )
        }.value
    }

    /// 기준 시각이 속한 재사용 버킷의 다음 경계를 계산합니다.
    /// - Parameter reference: 이번 heatmap snapshot 기준 시각입니다.
    /// - Returns: snapshot을 다시 계산해야 하는 다음 시간 경계입니다.
    private func nextBucketBoundary(after reference: Date) -> TimeInterval {
        let current = reference.timeIntervalSince1970
        let bucket = max(60.0, refreshBucketInterval)
        let bucketIndex = floor(current / bucket)
        return (bucketIndex + 1.0) * bucket
    }

    /// FNV-1a 스타일 rolling hash에 문자열 바이트를 반영합니다.
    /// - Parameters:
    ///   - value: hash에 섞을 문자열 바이트 시퀀스입니다.
    ///   - hash: 누적 중인 64-bit hash 값입니다.
    private func mix<S: Sequence>(value: S, into hash: inout UInt64) where S.Element == UInt8 {
        for byte in value {
            hash ^= UInt64(byte)
            hash &*= 1099511628211
        }
    }

    /// FNV-1a 스타일 rolling hash에 64-bit 값을 반영합니다.
    /// - Parameters:
    ///   - value: hash에 섞을 64-bit 값입니다.
    ///   - hash: 누적 중인 64-bit hash 값입니다.
    private func mix(value: UInt64, into hash: inout UInt64) {
        withUnsafeBytes(of: value.littleEndian) { bytes in
            mix(value: bytes, into: &hash)
        }
    }
}
