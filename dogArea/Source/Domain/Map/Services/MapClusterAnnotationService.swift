//
//  MapClusterAnnotationService.swift
//  dogArea
//
//  Created by Codex on 3/2/26.
//

import Foundation
import MapKit
import UserNotifications
#if canImport(ActivityKit)
import ActivityKit
#endif

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

    /// 실시간 핫스팟 렌더링 후보를 뷰포트/캡/LOD 규칙으로 계산합니다.
    /// - Parameters:
    ///   - hotspots: 렌더링 원본 핫스팟 목록입니다.
    ///   - viewportCenter: 현재 지도 중심 좌표입니다. `nil`이면 뷰포트 필터를 건너뜁니다.
    ///   - cameraDistance: 현재 카메라 거리(미터)입니다.
    ///   - maxVisible: 최종 렌더링 최대 개수입니다.
    ///   - pageMultiplier: 뷰포트 내부 후보 풀 확장 배수입니다.
    ///   - clusterDistanceThreshold: 클러스터 모드로 전환할 최소 카메라 거리(미터)입니다.
    ///   - distanceRatio: 카메라 거리 대비 클러스터 셀 크기 비율입니다.
    ///   - minCellMeters: 셀 크기의 최소값(미터)입니다.
    ///   - maxCellMeters: 셀 크기의 최대값(미터)입니다.
    /// - Returns: LOD/캡 규칙이 반영된 최종 렌더링 노드 목록입니다.
    func renderHotspots(
        hotspots: [NearbyHotspotRenderInput],
        viewportCenter: CLLocationCoordinate2D?,
        cameraDistance: Double,
        maxVisible: Int,
        pageMultiplier: Int,
        clusterDistanceThreshold: Double,
        distanceRatio: Double,
        minCellMeters: Double,
        maxCellMeters: Double
    ) -> [NearbyHotspotRenderNode]
}

final class MapClusterAnnotationService: MapClusterAnnotationServicing {
    private struct ClusterBucketKey: Hashable {
        let x: Int
        let y: Int
    }

    private struct HotspotBucketValue {
        var memberCount: Int
        var weightedLatitudeSum: Double
        var weightedLongitudeSum: Double
        var activityCountSum: Int
        var maxIntensity: Double
        var visualState: NearbyHotspotVisualState
        var representativeID: String

        /// 버킷에 핫스팟 샘플을 누적 병합합니다.
        /// - Parameter hotspot: 같은 셀로 분류된 핫스팟 입력입니다.
        mutating func merge(with hotspot: NearbyHotspotRenderInput) {
            let weight = max(1.0, Double(hotspot.count))
            memberCount += 1
            weightedLatitudeSum += hotspot.centerCoordinate.latitude * weight
            weightedLongitudeSum += hotspot.centerCoordinate.longitude * weight
            activityCountSum += max(1, hotspot.count)
            maxIntensity = max(maxIntensity, hotspot.intensity)
            visualState = visualState.merged(with: hotspot.visualState)
        }

        /// 누적 버킷 값을 렌더 노드로 변환합니다.
        /// - Parameter bucketKey: 버킷 좌표 키입니다.
        /// - Returns: 지도에 직접 그릴 수 있는 핫스팟 렌더 노드입니다.
        func asNode(bucketKey: ClusterBucketKey) -> NearbyHotspotRenderNode {
            let weight = max(1.0, Double(activityCountSum))
            return NearbyHotspotRenderNode(
                id: "cluster-\(bucketKey.x)-\(bucketKey.y)-\(representativeID)",
                centerCoordinate: .init(
                    latitude: weightedLatitudeSum / weight,
                    longitude: weightedLongitudeSum / weight
                ),
                count: activityCountSum,
                intensity: maxIntensity,
                visualState: visualState,
                isCluster: memberCount > 1
            )
        }
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

    /// 실시간 핫스팟 렌더링 후보를 뷰포트/캡/LOD 규칙으로 계산합니다.
    /// - Parameters:
    ///   - hotspots: 렌더링 원본 핫스팟 목록입니다.
    ///   - viewportCenter: 현재 지도 중심 좌표입니다. `nil`이면 뷰포트 필터를 건너뜁니다.
    ///   - cameraDistance: 현재 카메라 거리(미터)입니다.
    ///   - maxVisible: 최종 렌더링 최대 개수입니다.
    ///   - pageMultiplier: 뷰포트 내부 후보 풀 확장 배수입니다.
    ///   - clusterDistanceThreshold: 클러스터 모드로 전환할 최소 카메라 거리(미터)입니다.
    ///   - distanceRatio: 카메라 거리 대비 클러스터 셀 크기 비율입니다.
    ///   - minCellMeters: 셀 크기의 최소값(미터)입니다.
    ///   - maxCellMeters: 셀 크기의 최대값(미터)입니다.
    /// - Returns: LOD/캡 규칙이 반영된 최종 렌더링 노드 목록입니다.
    func renderHotspots(
        hotspots: [NearbyHotspotRenderInput],
        viewportCenter: CLLocationCoordinate2D?,
        cameraDistance: Double,
        maxVisible: Int,
        pageMultiplier: Int,
        clusterDistanceThreshold: Double,
        distanceRatio: Double,
        minCellMeters: Double,
        maxCellMeters: Double
    ) -> [NearbyHotspotRenderNode] {
        guard hotspots.isEmpty == false else { return [] }

        let visibleCap = max(8, maxVisible)
        let candidateLimit = max(visibleCap, visibleCap * max(1, pageMultiplier))
        let viewportRadius = max(240.0, min(10_000.0, cameraDistance * 1.35))
        let scoped = filterByViewport(
            hotspots: hotspots,
            center: viewportCenter,
            radiusMeters: viewportRadius
        )
        let source = scoped.isEmpty ? hotspots : scoped
        let ranked = rankedHotspots(
            source,
            center: viewportCenter
        )
        let candidates = Array(ranked.prefix(candidateLimit))
        guard candidates.isEmpty == false else { return [] }

        let nodes: [NearbyHotspotRenderNode]
        if cameraDistance >= clusterDistanceThreshold {
            nodes = clusterHotspots(
                candidates,
                cameraDistance: cameraDistance,
                distanceRatio: distanceRatio,
                minCellMeters: minCellMeters,
                maxCellMeters: maxCellMeters
            )
        } else {
            nodes = candidates.map {
                NearbyHotspotRenderNode(
                    id: $0.id,
                    centerCoordinate: $0.centerCoordinate,
                    count: $0.count,
                    intensity: $0.intensity,
                    visualState: $0.visualState,
                    isCluster: false
                )
            }
        }

        let resorted = rankedRenderNodes(nodes, center: viewportCenter)
        return Array(resorted.prefix(visibleCap))
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

    /// 뷰포트 중심/반경 기준으로 핫스팟 목록을 필터링합니다.
    /// - Parameters:
    ///   - hotspots: 필터링할 원본 핫스팟 목록입니다.
    ///   - center: 현재 지도 중심 좌표입니다.
    ///   - radiusMeters: 뷰포트 반경(미터)입니다.
    /// - Returns: 뷰포트 반경 안에 포함된 핫스팟 목록입니다.
    private func filterByViewport(
        hotspots: [NearbyHotspotRenderInput],
        center: CLLocationCoordinate2D?,
        radiusMeters: CLLocationDistance
    ) -> [NearbyHotspotRenderInput] {
        guard let center else { return hotspots }
        return hotspots.filter {
            greatCircleDistanceMeters(from: center, to: $0.centerCoordinate) <= radiusMeters
        }
    }

    /// 핫스팟 목록을 거리/강도/활동 수 기준으로 정렬합니다.
    /// - Parameters:
    ///   - hotspots: 정렬할 핫스팟 목록입니다.
    ///   - center: 현재 지도 중심 좌표입니다.
    /// - Returns: 렌더 우선순위가 반영된 정렬 결과입니다.
    private func rankedHotspots(
        _ hotspots: [NearbyHotspotRenderInput],
        center: CLLocationCoordinate2D?
    ) -> [NearbyHotspotRenderInput] {
        hotspots.sorted { lhs, rhs in
            if let center {
                let lhsDistance = greatCircleDistanceMeters(from: center, to: lhs.centerCoordinate)
                let rhsDistance = greatCircleDistanceMeters(from: center, to: rhs.centerCoordinate)
                if abs(lhsDistance - rhsDistance) >= 8 {
                    return lhsDistance < rhsDistance
                }
            }
            if lhs.intensity != rhs.intensity {
                return lhs.intensity > rhs.intensity
            }
            if lhs.count != rhs.count {
                return lhs.count > rhs.count
            }
            return lhs.id < rhs.id
        }
    }

    /// 원거리 모드에서 핫스팟을 버킷 단위로 병합합니다.
    /// - Parameters:
    ///   - hotspots: 병합 대상 핫스팟 목록입니다.
    ///   - cameraDistance: 현재 카메라 거리(미터)입니다.
    ///   - distanceRatio: 카메라 거리 대비 셀 크기 비율입니다.
    ///   - minCellMeters: 셀 크기의 최소값(미터)입니다.
    ///   - maxCellMeters: 셀 크기의 최대값(미터)입니다.
    /// - Returns: 버킷 병합 결과 노드 목록입니다.
    private func clusterHotspots(
        _ hotspots: [NearbyHotspotRenderInput],
        cameraDistance: Double,
        distanceRatio: Double,
        minCellMeters: Double,
        maxCellMeters: Double
    ) -> [NearbyHotspotRenderNode] {
        guard hotspots.count > 1 else {
            return hotspots.map {
                NearbyHotspotRenderNode(
                    id: $0.id,
                    centerCoordinate: $0.centerCoordinate,
                    count: $0.count,
                    intensity: $0.intensity,
                    visualState: $0.visualState,
                    isCluster: false
                )
            }
        }

        let referenceLatitude = hotspots.map(\.centerCoordinate.latitude).reduce(0.0, +) / Double(hotspots.count)
        let cellMeters = clusterCellSizeMeters(
            cameraDistance: cameraDistance,
            distanceRatio: distanceRatio,
            minCellMeters: minCellMeters,
            maxCellMeters: maxCellMeters
        )
        let metersPerMapPoint = MKMetersPerMapPointAtLatitude(referenceLatitude)
        let cellMapPoints = max(1.0, cellMeters / max(0.0001, metersPerMapPoint))

        var buckets: [ClusterBucketKey: HotspotBucketValue] = [:]
        buckets.reserveCapacity(hotspots.count)

        for hotspot in hotspots {
            let point = MKMapPoint(hotspot.centerCoordinate)
            let key = ClusterBucketKey(
                x: Int(floor(point.x / cellMapPoints)),
                y: Int(floor(point.y / cellMapPoints))
            )
            if var existing = buckets[key] {
                existing.merge(with: hotspot)
                buckets[key] = existing
            } else {
                let weight = max(1.0, Double(hotspot.count))
                buckets[key] = HotspotBucketValue(
                    memberCount: 1,
                    weightedLatitudeSum: hotspot.centerCoordinate.latitude * weight,
                    weightedLongitudeSum: hotspot.centerCoordinate.longitude * weight,
                    activityCountSum: max(1, hotspot.count),
                    maxIntensity: hotspot.intensity,
                    visualState: hotspot.visualState,
                    representativeID: hotspot.id
                )
            }
        }

        return buckets
            .sorted { lhs, rhs in
                lhs.value.activityCountSum > rhs.value.activityCountSum
            }
            .map { key, value in
                value.asNode(bucketKey: key)
            }
    }

    /// 렌더링 노드를 거리/강도 기준으로 정렬합니다.
    /// - Parameters:
    ///   - nodes: 정렬할 렌더링 노드 목록입니다.
    ///   - center: 현재 지도 중심 좌표입니다.
    /// - Returns: 정렬된 렌더링 노드 목록입니다.
    private func rankedRenderNodes(
        _ nodes: [NearbyHotspotRenderNode],
        center: CLLocationCoordinate2D?
    ) -> [NearbyHotspotRenderNode] {
        nodes.sorted { lhs, rhs in
            if let center {
                let lhsDistance = greatCircleDistanceMeters(from: center, to: lhs.centerCoordinate)
                let rhsDistance = greatCircleDistanceMeters(from: center, to: rhs.centerCoordinate)
                if abs(lhsDistance - rhsDistance) >= 8 {
                    return lhsDistance < rhsDistance
                }
            }
            if lhs.intensity != rhs.intensity {
                return lhs.intensity > rhs.intensity
            }
            if lhs.count != rhs.count {
                return lhs.count > rhs.count
            }
            return lhs.id < rhs.id
        }
    }

    /// 두 좌표 사이 대권 거리를 미터 단위로 계산합니다.
    /// - Parameters:
    ///   - from: 시작 좌표입니다.
    ///   - to: 도착 좌표입니다.
    /// - Returns: 두 좌표 사이 거리(미터)입니다.
    private func greatCircleDistanceMeters(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D
    ) -> CLLocationDistance {
        let earthRadius = 6_371_000.0
        let lat1 = from.latitude * .pi / 180
        let lon1 = from.longitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let lon2 = to.longitude * .pi / 180
        let dLat = lat2 - lat1
        let dLon = lon2 - lon1
        let a = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(max(0, 1 - a)))
        return earthRadius * c
    }
}

enum NearbyHotspotVisualState: String, Codable, CaseIterable {
    case normal
    case stale
    case lowConfidence

    /// 두 시각 상태를 병합할 때 더 보수적인 상태를 우선합니다.
    /// - Parameter other: 병합 대상 상태입니다.
    /// - Returns: stale > lowConfidence > normal 우선순위로 병합된 상태입니다.
    fileprivate func merged(with other: NearbyHotspotVisualState) -> NearbyHotspotVisualState {
        if self == .stale || other == .stale { return .stale }
        if self == .lowConfidence || other == .lowConfidence { return .lowConfidence }
        return .normal
    }
}

struct NearbyHotspotRenderInput: Identifiable {
    let id: String
    let centerCoordinate: CLLocationCoordinate2D
    let count: Int
    let intensity: Double
    let visualState: NearbyHotspotVisualState
}

struct NearbyHotspotRenderNode: Identifiable {
    let id: String
    let centerCoordinate: CLLocationCoordinate2D
    let count: Int
    let intensity: Double
    let visualState: NearbyHotspotVisualState
    let isCluster: Bool
}

enum WalkLiveActivityFallbackReason: String, Equatable {
    case unsupportedOS = "unsupported_os"
    case activitiesDisabled = "activities_disabled"
    case requestFailed = "request_failed"
}

enum WalkLiveActivityServiceResult: Equatable {
    case liveActivity
    case fallback(WalkLiveActivityFallbackReason)
    case ended
}

protocol WalkLiveActivityServicing {
    /// 산책 상태를 Live Activity 또는 fallback 채널로 동기화합니다.
    /// - Parameter state: 현재 산책 세션 상태입니다.
    /// - Returns: Live Activity 반영 여부 또는 fallback 전환 결과입니다.
    func sync(state: WalkLiveActivityState) async -> WalkLiveActivityServiceResult

    /// 진행 중인 Live Activity를 종료 상태로 정리합니다.
    /// - Parameters:
    ///   - state: 종료 시점 상태 스냅샷입니다.
    ///   - dismissImmediately: `true`면 즉시 제거, `false`면 시스템 기본 정책으로 제거합니다.
    /// - Returns: 종료 처리 결과입니다.
    func end(state: WalkLiveActivityState, dismissImmediately: Bool) async -> WalkLiveActivityServiceResult

    /// 앱 진입 시 세션 상태와 Live Activity 상태를 정합화합니다.
    /// - Parameters:
    ///   - activeSession: 현재 앱에 활성 산책 세션이 존재하는지 여부입니다.
    ///   - state: 활성 세션이 있을 때 반영할 산책 상태입니다.
    func reconcile(activeSession: Bool, state: WalkLiveActivityState?) async
}

actor WalkLiveActivityService: WalkLiveActivityServicing {
    private let notificationCenter: UNUserNotificationCenter
    private var lastFallbackNotificationKey: String = ""

    /// Live Activity/알림 fallback 동기화 서비스를 생성합니다.
    /// - Parameter notificationCenter: fallback 로컬 알림 전송에 사용할 시스템 알림 센터입니다.
    init(notificationCenter: UNUserNotificationCenter = .current()) {
        self.notificationCenter = notificationCenter
    }

    /// 산책 상태를 Live Activity 또는 fallback 채널로 동기화합니다.
    /// - Parameter state: 현재 산책 세션 상태입니다.
    /// - Returns: Live Activity 반영 여부 또는 fallback 전환 결과입니다.
    func sync(state: WalkLiveActivityState) async -> WalkLiveActivityServiceResult {
        guard state.isWalking else {
            return await end(state: state, dismissImmediately: false)
        }
        guard #available(iOS 16.1, *) else {
            await postFallbackNotificationIfNeeded(state: state, reason: .unsupportedOS)
            return .fallback(.unsupportedOS)
        }

        let authorization = ActivityAuthorizationInfo()
        guard authorization.areActivitiesEnabled else {
            await postFallbackNotificationIfNeeded(state: state, reason: .activitiesDisabled)
            return .fallback(.activitiesDisabled)
        }

        do {
            let activity = try await ensureActivity(for: state)
            let content = ActivityContent(
                state: state.makeContentState(),
                staleDate: Date().addingTimeInterval(600)
            )
            await activity.update(content)
            return .liveActivity
        } catch {
            await postFallbackNotificationIfNeeded(state: state, reason: .requestFailed)
            return .fallback(.requestFailed)
        }
    }

    /// 진행 중인 Live Activity를 종료 상태로 정리합니다.
    /// - Parameters:
    ///   - state: 종료 시점 상태 스냅샷입니다.
    ///   - dismissImmediately: `true`면 즉시 제거, `false`면 시스템 기본 정책으로 제거합니다.
    /// - Returns: 종료 처리 결과입니다.
    func end(state: WalkLiveActivityState, dismissImmediately: Bool = true) async -> WalkLiveActivityServiceResult {
        guard #available(iOS 16.1, *) else {
            await postFallbackNotificationIfNeeded(state: state, reason: .unsupportedOS)
            return .ended
        }
        let finalized = finalizedState(from: state)
        let activities = Activity<WalkLiveActivityAttributes>.activities
        guard activities.isEmpty == false else {
            return .ended
        }

        let content = ActivityContent(
            state: finalized.makeContentState(),
            staleDate: nil
        )
        for activity in activities {
            await activity.end(content, dismissalPolicy: dismissImmediately ? .immediate : .default)
        }
        return .ended
    }

    /// 앱 진입 시 세션 상태와 Live Activity 상태를 정합화합니다.
    /// - Parameters:
    ///   - activeSession: 현재 앱에 활성 산책 세션이 존재하는지 여부입니다.
    ///   - state: 활성 세션이 있을 때 반영할 산책 상태입니다.
    func reconcile(activeSession: Bool, state: WalkLiveActivityState?) async {
        if activeSession, let state {
            _ = await sync(state: state)
            return
        }
        _ = await end(state: state ?? defaultEndedState(), dismissImmediately: false)
    }

    /// 현재 세션에 대응하는 Live Activity를 찾거나 새로 생성합니다.
    /// - Parameter state: 동기화 대상 산책 상태입니다.
    /// - Returns: 업데이트 가능한 Live Activity 인스턴스입니다.
    @available(iOS 16.1, *)
    private func ensureActivity(for state: WalkLiveActivityState) async throws -> Activity<WalkLiveActivityAttributes> {
        if let current = matchingActivity(for: state.sessionId) {
            return current
        }
        let attributes = WalkLiveActivityAttributes(
            sessionId: state.sessionId,
            startedAt: state.startedAt
        )
        let content = ActivityContent(
            state: state.makeContentState(),
            staleDate: Date().addingTimeInterval(600)
        )
        return try Activity.request(attributes: attributes, content: content, pushType: nil)
    }

    /// 세션 ID와 일치하는 Live Activity를 조회합니다.
    /// - Parameter sessionId: 찾을 산책 세션 ID입니다.
    /// - Returns: 일치 activity가 있으면 해당 인스턴스, 없으면 첫 번째 activity 또는 `nil`입니다.
    @available(iOS 16.1, *)
    private func matchingActivity(for sessionId: String) -> Activity<WalkLiveActivityAttributes>? {
        if let matched = Activity<WalkLiveActivityAttributes>.activities.first(where: { $0.attributes.sessionId == sessionId }) {
            return matched
        }
        return Activity<WalkLiveActivityAttributes>.activities.first
    }

    /// 종료 이벤트용 상태 스냅샷을 생성합니다.
    /// - Parameter state: 종료 직전 상태입니다.
    /// - Returns: 종료 단계(`ended`)가 반영된 상태입니다.
    private func finalizedState(from state: WalkLiveActivityState) -> WalkLiveActivityState {
        WalkLiveActivityState(
            sessionId: state.sessionId,
            startedAt: state.startedAt,
            isWalking: false,
            elapsedSeconds: state.elapsedSeconds,
            pointCount: state.pointCount,
            petName: state.petName,
            autoEndStage: .ended,
            statusMessage: state.statusMessage,
            updatedAt: Date().timeIntervalSince1970
        )
    }

    /// 세션 정보가 없을 때 orphan 정리용 기본 종료 상태를 생성합니다.
    /// - Parameter now: 상태 생성 기준 시각입니다.
    /// - Returns: orphan 정리 시 사용할 기본 종료 상태입니다.
    private func defaultEndedState(now: Date = Date()) -> WalkLiveActivityState {
        WalkLiveActivityState(
            sessionId: "orphan",
            startedAt: now.timeIntervalSince1970,
            isWalking: false,
            elapsedSeconds: 0,
            pointCount: 0,
            petName: "반려견",
            autoEndStage: .ended,
            statusMessage: "세션 동기화로 정리되었습니다.",
            updatedAt: now.timeIntervalSince1970
        )
    }

    /// fallback 알림 중복 방지를 위한 고유 키를 생성합니다.
    /// - Parameters:
    ///   - state: 현재 산책 상태입니다.
    ///   - reason: fallback 사유입니다.
    /// - Returns: 상태/사유 조합을 나타내는 키 문자열입니다.
    private func fallbackNotificationKey(
        state: WalkLiveActivityState,
        reason: WalkLiveActivityFallbackReason
    ) -> String {
        "\(reason.rawValue)|\(state.sessionId)|\(state.autoEndStage.rawValue)|\(state.isWalking)"
    }

    /// 필요할 때만 fallback 로컬 알림을 발송합니다.
    /// - Parameters:
    ///   - state: 현재 산책 상태입니다.
    ///   - reason: Live Activity fallback 사유입니다.
    private func postFallbackNotificationIfNeeded(
        state: WalkLiveActivityState,
        reason: WalkLiveActivityFallbackReason
    ) async {
        let key = fallbackNotificationKey(state: state, reason: reason)
        guard key != lastFallbackNotificationKey else { return }
        lastFallbackNotificationKey = key

        let granted = await ensureNotificationAuthorization()
        guard granted else { return }

        let content = UNMutableNotificationContent()
        content.title = "산책 상태 업데이트"
        content.body = state.autoEndStage.fallbackNotificationBody
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "walk.live.fallback.\(state.autoEndStage.rawValue)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        await addNotificationRequest(request)
    }

    /// 로컬 알림 권한을 확인하고 필요 시 권한 요청을 수행합니다.
    /// - Returns: 알림 전송이 가능한 권한 상태면 `true`, 아니면 `false`입니다.
    private func ensureNotificationAuthorization() async -> Bool {
        let settings = await notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    continuation.resume(returning: granted)
                }
            }
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    /// 시스템 알림 센터의 현재 권한 설정을 비동기로 조회합니다.
    /// - Returns: 현재 알림 설정 스냅샷입니다.
    private func notificationSettings() async -> UNNotificationSettings {
        await withCheckedContinuation { continuation in
            notificationCenter.getNotificationSettings { settings in
                continuation.resume(returning: settings)
            }
        }
    }

    /// 로컬 알림 요청을 시스템 큐에 등록합니다.
    /// - Parameter request: 등록할 로컬 알림 요청입니다.
    private func addNotificationRequest(_ request: UNNotificationRequest) async {
        await withCheckedContinuation { continuation in
            notificationCenter.add(request) { _ in
                continuation.resume()
            }
        }
    }
}
