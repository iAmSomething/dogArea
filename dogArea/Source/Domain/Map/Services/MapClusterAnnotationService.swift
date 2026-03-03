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
