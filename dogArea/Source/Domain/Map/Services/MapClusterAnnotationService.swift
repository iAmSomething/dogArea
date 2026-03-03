//
//  MapClusterAnnotationService.swift
//  dogArea
//
//  Created by Codex on 3/2/26.
//

import Foundation
import MapKit

protocol MapClusterAnnotationServicing {
    /// 현재 폴리곤 목록과 카메라 거리 기반 설정으로 클러스터 배열을 계산합니다.
    /// - Parameters:
    ///   - polygons: 지도에 표시되는 산책 폴리곤 목록입니다.
    ///   - cameraDistance: 현재 카메라 거리(미터)입니다.
    ///   - distanceRatio: 카메라 거리 대비 클러스터 셀 크기 비율입니다.
    ///   - minCellMeters: 셀 크기의 최소값(미터)입니다.
    ///   - maxCellMeters: 셀 크기의 최대값(미터)입니다.
    /// - Returns: 버킷 병합 결과가 반영된 정렬된 클러스터 목록입니다.
    func cluster(
        polygons: [Polygon],
        cameraDistance: Double,
        distanceRatio: Double,
        minCellMeters: Double,
        maxCellMeters: Double
    ) -> [Cluster]
}

final class MapClusterAnnotationService: MapClusterAnnotationServicing {
    private struct ClusterBucketKey: Hashable {
        let x: Int
        let y: Int
    }

    /// 현재 폴리곤 목록과 카메라 거리 기반 설정으로 클러스터 배열을 계산합니다.
    /// - Parameters:
    ///   - polygons: 지도에 표시되는 산책 폴리곤 목록입니다.
    ///   - cameraDistance: 현재 카메라 거리(미터)입니다.
    ///   - distanceRatio: 카메라 거리 대비 클러스터 셀 크기 비율입니다.
    ///   - minCellMeters: 셀 크기의 최소값(미터)입니다.
    ///   - maxCellMeters: 셀 크기의 최대값(미터)입니다.
    /// - Returns: 버킷 병합 결과가 반영된 정렬된 클러스터 목록입니다.
    func cluster(
        polygons: [Polygon],
        cameraDistance: Double,
        distanceRatio: Double,
        minCellMeters: Double,
        maxCellMeters: Double
    ) -> [Cluster] {
        let seedClusters = initialClusters(from: polygons)
        return bucketClusters(
            from: seedClusters,
            cameraDistance: cameraDistance,
            distanceRatio: distanceRatio,
            minCellMeters: minCellMeters,
            maxCellMeters: maxCellMeters
        )
    }

    /// 폴리곤 중심점을 단일 클러스터로 초기화합니다.
    /// - Parameter polygons: 산책 폴리곤 목록입니다.
    /// - Returns: 폴리곤별 단일 멤버 클러스터 배열입니다.
    private func initialClusters(from polygons: [Polygon]) -> [Cluster] {
        polygons.compactMap { polygon in
            guard let mapPolygon = polygon.polygon else { return nil }
            return Cluster(center: mapPolygon.coordinate, id: polygon.id)
        }
    }

    /// 클러스터를 셀 버킷에 할당해 동일 셀 클러스터를 병합합니다.
    /// - Parameters:
    ///   - clusters: 초기 클러스터 배열입니다.
    ///   - cameraDistance: 현재 카메라 거리(미터)입니다.
    ///   - distanceRatio: 카메라 거리 대비 셀 크기 비율입니다.
    ///   - minCellMeters: 셀 크기의 최소값(미터)입니다.
    ///   - maxCellMeters: 셀 크기의 최대값(미터)입니다.
    /// - Returns: 병합/정렬된 클러스터 배열입니다.
    private func bucketClusters(
        from clusters: [Cluster],
        cameraDistance: Double,
        distanceRatio: Double,
        minCellMeters: Double,
        maxCellMeters: Double
    ) -> [Cluster] {
        guard clusters.count > 1 else { return clusters }

        let referenceLatitude = clusters.map(\.center.latitude).reduce(0.0, +) / Double(clusters.count)
        let cellMeters = clusterCellSizeMeters(
            cameraDistance: cameraDistance,
            distanceRatio: distanceRatio,
            minCellMeters: minCellMeters,
            maxCellMeters: maxCellMeters
        )
        let metersPerMapPoint = MKMetersPerMapPointAtLatitude(referenceLatitude)
        let cellMapPoints = max(1.0, cellMeters / max(0.0001, metersPerMapPoint))

        var buckets: [ClusterBucketKey: Cluster] = [:]
        buckets.reserveCapacity(clusters.count)

        for cluster in clusters {
            let point = MKMapPoint(cluster.center)
            let key = ClusterBucketKey(
                x: Int(floor(point.x / cellMapPoints)),
                y: Int(floor(point.y / cellMapPoints))
            )

            if var existing = buckets[key] {
                existing.updateCenter(with: cluster)
                buckets[key] = existing
            } else {
                buckets[key] = cluster
            }
        }

        return buckets.values.sorted { lhs, rhs in
            if lhs.sumLocs.count != rhs.sumLocs.count {
                return lhs.sumLocs.count > rhs.sumLocs.count
            }
            if lhs.center.latitude != rhs.center.latitude {
                return lhs.center.latitude < rhs.center.latitude
            }
            return lhs.center.longitude < rhs.center.longitude
        }
    }

    /// 카메라 거리를 기준으로 클러스터 셀 크기를 계산합니다.
    /// - Parameters:
    ///   - cameraDistance: 현재 카메라 거리(미터)입니다.
    ///   - distanceRatio: 카메라 거리 대비 셀 크기 비율입니다.
    ///   - minCellMeters: 셀 크기의 최소값(미터)입니다.
    ///   - maxCellMeters: 셀 크기의 최대값(미터)입니다.
    /// - Returns: 최소/최대 범위로 clamp된 셀 크기(미터)입니다.
    private func clusterCellSizeMeters(
        cameraDistance: Double,
        distanceRatio: Double,
        minCellMeters: Double,
        maxCellMeters: Double
    ) -> Double {
        let raw = cameraDistance * distanceRatio
        return min(maxCellMeters, max(minCellMeters, raw))
    }
}
