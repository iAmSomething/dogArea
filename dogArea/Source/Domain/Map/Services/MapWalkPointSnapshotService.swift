//
//  MapWalkPointSnapshotService.swift
//  dogArea
//
//  Created by Codex on 3/8/26.
//

import Foundation
import CoreLocation

protocol MapWalkPointSnapshotServicing {
    /// 주어진 폴리곤의 route/mark 파생값 snapshot을 반환합니다.
    /// - Parameter polygon: route/mark 파생값을 계산할 산책 폴리곤입니다.
    /// - Returns: route 좌표, mark 포인트, 렌더링 판정에 필요한 메타데이터를 담은 snapshot입니다.
    func snapshot(for polygon: Polygon) -> MapWalkPointSnapshot
}

final class MapWalkPointSnapshotService: MapWalkPointSnapshotServicing {
    private struct CachedSnapshot {
        let pointIDs: [UUID]
        let snapshot: MapWalkPointSnapshot
    }

    private let lock = NSLock()
    private var snapshotsByPolygonID: [UUID: CachedSnapshot] = [:]
    private let maxCachedPolygonCount = 96

    /// 주어진 폴리곤의 route/mark 파생값 snapshot을 반환합니다.
    /// - Parameter polygon: route/mark 파생값을 계산할 산책 폴리곤입니다.
    /// - Returns: route 좌표, mark 포인트, 렌더링 판정에 필요한 메타데이터를 담은 snapshot입니다.
    func snapshot(for polygon: Polygon) -> MapWalkPointSnapshot {
        let pointIDs = polygon.locations.map(\.id)

        lock.lock()
        defer { lock.unlock() }

        if let cached = snapshotsByPolygonID[polygon.id] {
            if cached.pointIDs == pointIDs {
                return cached.snapshot
            }

            if let appended = appendedSnapshotIfPossible(
                for: polygon,
                pointIDs: pointIDs,
                cached: cached
            ) {
                snapshotsByPolygonID[polygon.id] = appended
                trimCacheIfNeeded(retaining: polygon.id)
                return appended.snapshot
            }
        }

        let rebuilt = makeCachedSnapshot(for: polygon, pointIDs: pointIDs)
        snapshotsByPolygonID[polygon.id] = rebuilt
        trimCacheIfNeeded(retaining: polygon.id)
        return rebuilt.snapshot
    }

    /// append-only 업데이트인지 확인하고, 가능하면 기존 snapshot에 마지막 포인트만 반영합니다.
    /// - Parameters:
    ///   - polygon: 최신 포인트 배열을 가진 폴리곤입니다.
    ///   - pointIDs: 최신 포인트 ID 배열입니다.
    ///   - cached: 기존에 저장된 snapshot입니다.
    /// - Returns: append-only 경로가 유효하면 마지막 포인트만 반영된 새 캐시, 아니면 `nil`입니다.
    private func appendedSnapshotIfPossible(
        for polygon: Polygon,
        pointIDs: [UUID],
        cached: CachedSnapshot
    ) -> CachedSnapshot? {
        guard pointIDs.count == cached.pointIDs.count + 1 else { return nil }
        guard pointIDs.starts(with: cached.pointIDs) else { return nil }
        guard let appendedPoint = polygon.locations.last else { return nil }

        var routeCoordinates = cached.snapshot.routeCoordinates
        var markLocations = cached.snapshot.markLocations

        switch appendedPoint.pointRole {
        case .route:
            routeCoordinates.append(appendedPoint.coordinate)
        case .mark:
            markLocations.append(appendedPoint)
        }

        return CachedSnapshot(
            pointIDs: pointIDs,
            snapshot: MapWalkPointSnapshot(
                polygonID: polygon.id,
                sourcePointCount: polygon.locations.count,
                routeCoordinates: routeCoordinates,
                markLocations: markLocations
            )
        )
    }

    /// 캐시에 저장할 snapshot을 포인트 원본에서 새로 생성합니다.
    /// - Parameters:
    ///   - polygon: snapshot을 생성할 폴리곤입니다.
    ///   - pointIDs: 캐시 비교에 사용할 포인트 ID 배열입니다.
    /// - Returns: ID 시그니처와 계산된 snapshot을 함께 담은 캐시 엔트리입니다.
    private func makeCachedSnapshot(
        for polygon: Polygon,
        pointIDs: [UUID]
    ) -> CachedSnapshot {
        CachedSnapshot(
            pointIDs: pointIDs,
            snapshot: buildSnapshot(
                polygonID: polygon.id,
                points: polygon.locations
            )
        )
    }

    /// 포인트 원본을 한 번만 순회하며 route 좌표와 mark 포인트를 동시에 분리합니다.
    /// - Parameters:
    ///   - polygonID: snapshot 대상 폴리곤 ID입니다.
    ///   - points: route/mark 역할이 섞여 있는 원본 포인트 배열입니다.
    /// - Returns: route 좌표와 mark 포인트가 분리된 snapshot입니다.
    private func buildSnapshot(
        polygonID: UUID,
        points: [Location]
    ) -> MapWalkPointSnapshot {
        var routeCoordinates: [CLLocationCoordinate2D] = []
        var markLocations: [Location] = []
        routeCoordinates.reserveCapacity(points.count)
        markLocations.reserveCapacity(points.count)

        for point in points {
            switch point.pointRole {
            case .route:
                routeCoordinates.append(point.coordinate)
            case .mark:
                markLocations.append(point)
            }
        }

        return MapWalkPointSnapshot(
            polygonID: polygonID,
            sourcePointCount: points.count,
            routeCoordinates: routeCoordinates,
            markLocations: markLocations
        )
    }

    /// 캐시 엔트리가 과도하게 쌓이면 현재 폴리곤 snapshot만 남기고 정리합니다.
    /// - Parameter polygonID: 즉시 다시 사용할 가능성이 높은 현재 폴리곤 ID입니다.
    private func trimCacheIfNeeded(retaining polygonID: UUID) {
        guard snapshotsByPolygonID.count > maxCachedPolygonCount else { return }
        let retained = snapshotsByPolygonID[polygonID]
        snapshotsByPolygonID.removeAll(keepingCapacity: true)
        if let retained {
            snapshotsByPolygonID[polygonID] = retained
        }
    }
}
