//
//  MapView.swift
//  dogArea
//
//  Created by 김태훈 on 10/19/23.
//

import Foundation
import SwiftUI
import _MapKit_SwiftUI
#if canImport(UIKit)
import UIKit
#endif
struct MapView : View{
    @EnvironmentObject var loading: LoadingViewModel
    @EnvironmentObject var authFlow: AuthFlowCoordinator
    @StateObject private var myAlert = CustomAlertViewModel()
    @ObservedObject var viewModel: MapViewModel
    @State private var isModalPresented = false
    @State private var isWalkingViewPresented = false
    @State private var endWalkingViewPresented = false
    @State private var isCameraSeeingSomewhere: Bool = false
    @State private var distance = 2000.0
    @State private var selectedPolygonData: WalkDataModel? = nil
    @State private var recoveryIssue: RecoveryIssue? = nil
    @State private var activeBanner: MapTopBannerCandidate? = nil
    @State private var bannerSuppressedUntil: [MapTopBannerKind: Date] = [:]
    @State private var bannerAutoDismissTask: Task<Void, Never>? = nil
    @State private var pendingUndoPointID: UUID? = nil
    @State private var addPointUndoDismissTask: Task<Void, Never>? = nil
    @State private var lastCameraEventProcessedAt: Date = .distantPast

    /// 지도 화면에 사용할 상태 객체를 주입해 탭 전환 후에도 카메라/산책 상태를 유지합니다.
    /// - Parameter viewModel: 지도 상태를 보유하는 `MapViewModel`입니다.
    init(viewModel: MapViewModel = MapViewModel()) {
        self._viewModel = ObservedObject(wrappedValue: viewModel)
    }
    
    var body : some View {
        var composed = AnyView(rootContent)
        composed = AnyView(composed.onAppear {
            viewModel.activateMapRuntimeServices()
            viewModel.reloadSelectedPetContext()
            viewModel.updateAnnotations(cameraDistance: self.distance)
            recomputeBannerQueue()
        })
        composed = AnyView(composed.onChange(of: viewModel.walkStatusMessage) { _, newValue in
            guard let newValue else { return }
            let clearDelay: TimeInterval = shouldShowLocationSettingsAction(for: newValue) ? 6.0 : 2.5
            DispatchQueue.main.asyncAfter(deadline: .now() + clearDelay) {
                viewModel.clearWalkStatusMessage()
            }
        })
        composed = AnyView(composed.onChange(of: viewModel.runtimeGuardStatusText) { _, newValue in
            guard newValue.isEmpty == false else { return }
            recomputeBannerQueue()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                viewModel.clearRuntimeGuardStatus()
                recomputeBannerQueue()
            }
        })
        composed = AnyView(composed.onChange(of: viewModel.syncOutboxLastErrorCodeText) { recomputeBannerQueue() })
        composed = AnyView(composed.onChange(of: viewModel.syncOutboxPendingCount) { recomputeBannerQueue() })
        composed = AnyView(composed.onChange(of: viewModel.syncOutboxPermanentFailureCount) { recomputeBannerQueue() })
        composed = AnyView(composed.onChange(of: viewModel.hasRecoverableWalkSession) { recomputeBannerQueue() })
        composed = AnyView(composed.onChange(of: viewModel.hasReturnToOriginSuggestion) { recomputeBannerQueue() })
        composed = AnyView(composed.onChange(of: viewModel.isWalking) { recomputeBannerQueue() })
        composed = AnyView(composed.onChange(of: viewModel.watchSyncStatusText) { recomputeBannerQueue() })
        composed = AnyView(composed.onChange(of: viewModel.latestWatchActionText) { recomputeBannerQueue() })
        composed = AnyView(composed.onChange(of: viewModel.polygonList.count) { recomputeBannerQueue() })
        composed = AnyView(composed.onChange(of: viewModel.syncRecoveryToastMessage) { _, message in
            guard let message else { return }
            viewModel.walkStatusMessage = message
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                viewModel.clearSyncRecoveryToastMessage()
            }
        })
        composed = AnyView(composed.onReceive(authFlow.objectWillChange) { _ in
            recomputeBannerQueue()
        })
        composed = AnyView(composed.onReceive(NotificationCenter.default.publisher(for: .walkWidgetActionRequested)) { notification in
            guard
                let rawKind = notification.userInfo?["kind"] as? String,
                let kind = WalkWidgetActionKind(rawValue: rawKind),
                let actionId = notification.userInfo?["actionId"] as? String
            else { return }
            let source = (notification.userInfo?["source"] as? String) ?? "widget"
            let route = WalkWidgetActionRoute(
                kind: kind,
                actionId: actionId,
                source: source,
                contextId: notification.userInfo?["contextId"] as? String
            )
            viewModel.applyWidgetWalkAction(route)
        })
        composed = AnyView(composed.onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            recomputeBannerQueue()
        })
        composed = AnyView(composed.onDisappear {
            viewModel.deactivateMapRuntimeServices()
            bannerAutoDismissTask?.cancel()
            clearPendingAddPointUndo()
        })
        composed = AnyView(composed.sheet(isPresented: $isModalPresented) {
            MapSettingView(viewModel: self.viewModel, myAlert: self.myAlert)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        })
        composed = AnyView(composed.fullScreenCover(isPresented: $isWalkingViewPresented) {
            StartModalView(
                petName: viewModel.selectedPetName,
                onCompleted: { viewModel.startWalkNow() }
            )
            .interactiveDismissDisabled(true)
        })
        composed = AnyView(composed.sheet(isPresented: $endWalkingViewPresented) {
            WalkDetailView()
                .environmentObject(loading)
                .environmentObject(viewModel)
                .interactiveDismissDisabled(true)
        })
        composed = AnyView(composed.fullScreenCover(item: $selectedPolygonData, onDismiss: {
            self.selectedPolygonData = nil
        }, content: { model in
            WalkListDetailView(model: model)
        }))
        composed = AnyView(composed.onMapCameraChange(frequency: .onEnd) { context in
            handleMapCameraChange(context)
        })
        return composed
    }

    private var rootContent: some View {
        ZStack {
            mapContent
                .allowsHitTesting(!isCriticalModalPresented)
                .accessibilityHidden(isCriticalModalPresented)

            if isCriticalModalPresented {
                MapAlertSubView(viewModel: viewModel, myAlert: myAlert)
                    .zIndex(10)
            }
        }
        .appTabBarVisibility(resolvedTabBarVisibility)
    }

    private var mapContent: some View {
        GeometryReader { proxy in
            ZStack {
                MapSubView(myAlert: myAlert, viewModel: viewModel)
                Rectangle()
                    .fill(viewModel.weatherOverlayTintColor)
                    .opacity(viewModel.weatherOverlayOpacity)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .animation(
                        .easeInOut(duration: viewModel.weatherOverlayAnimationDuration),
                        value: viewModel.weatherOverlayRiskLevel
                    )
            }
            .overlay(alignment: .top) {
                MapTopChromeView(
                    safeAreaTopInset: proxy.safeAreaInsets.top,
                    weatherStatusText: viewModel.weatherOverlayStatusText,
                    isWeatherFallbackActive: viewModel.weatherOverlayFallbackActive,
                    heatmapSummaryText: (!viewModel.isWalking && viewModel.isHeatmapFeatureAvailable && viewModel.heatmapEnabled)
                        ? viewModel.seasonTileStatusSummaryText
                        : nil,
                    bannerContent: activeBanner.map { AnyView(topBannerView(for: $0)) },
                    statusContent: statusOverlayContent,
                    onOpenSettings: {
                        viewModel.fetchPolygonList()
                        isModalPresented.toggle()
                    }
                )
            }
            .overlay(alignment: .bottom) {
                if shouldShowBottomControls {
                    mapBottomControlOverlay
                }
            }
            .appTabBarContentPadding(extra: 8)
        }
    }

    private var isCriticalModalPresented: Bool {
        myAlert.isAlert
    }

    private var shouldShowBottomControls: Bool {
        !isCriticalModalPresented && !endWalkingViewPresented
    }

    private var resolvedTabBarVisibility: AppTabBarVisibility {
        (isCriticalModalPresented || endWalkingViewPresented) ? .hidden : .automatic
    }

    private var statusOverlayView: some View {
        VStack(spacing: 6) {
            if let message = viewModel.walkStatusMessage {
                HStack(spacing: 10) {
                    Text(message)
                        .font(.appFont(for: .SemiBold, size: 13))
                        .foregroundStyle(MapChromePalette.primaryText)
                    if shouldShowLocationSettingsAction(for: message) {
                        Button("설정 열기") {
                            openAppSettings()
                        }
                        .font(.appFont(for: .SemiBold, size: 12))
                        .foregroundStyle(MapChromePalette.primaryText)
                        .frame(minHeight: 44)
                        .padding(.horizontal, 10)
                        .mapChromePill(.neutral)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .mapChromeSurface(emphasized: true)
            }

            if pendingUndoPointID != nil {
                HStack(spacing: 10) {
                    Text("포인트를 추가했어요")
                        .font(.appFont(for: .SemiBold, size: 13))
                        .foregroundStyle(MapChromePalette.primaryText)
                    Spacer()
                    Button("실행 취소") {
                        undoLastAddedPoint()
                    }
                    .font(.appFont(for: .SemiBold, size: 12))
                    .frame(minHeight: 44)
                    .foregroundStyle(MapChromePalette.primaryText)
                    .padding(.horizontal, 10)
                    .mapChromePill(.neutral)
                    .accessibilityLabel("포인트 추가 실행 취소")
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .mapChromeSurface(emphasized: true)
            }
        }
    }

    private var statusOverlayContent: AnyView? {
        guard viewModel.walkStatusMessage != nil || pendingUndoPointID != nil else { return nil }
        return AnyView(statusOverlayView)
    }

    /// 지도 카메라 이벤트를 반영해 UI 상태와 클러스터 계산을 갱신합니다.
    /// - Parameter context: `Map` 카메라 이벤트 컨텍스트입니다.
    private func handleMapCameraChange(_ context: MapCameraUpdateContext) {
        viewModel.recordCameraChange(context.camera)
        let now = Date()
        guard now.timeIntervalSince(lastCameraEventProcessedAt) >= 0.15 else { return }
        lastCameraEventProcessedAt = now

        guard context.camera.centerCoordinate.latitude.isFinite,
              context.camera.centerCoordinate.longitude.isFinite else { return }

        if let loc = viewModel.location {
            let distanceMeters = greatCircleDistanceMeters(
                from: context.camera.centerCoordinate,
                to: loc.coordinate
            )
            self.isCameraSeeingSomewhere = distanceMeters > 300
        } else {
            self.isCameraSeeingSomewhere = false
        }

        guard !viewModel.showOnlyOne else { return }
        let nextDistance = max(120.0, context.camera.distance)
        guard abs(nextDistance - self.distance) >= 120 else { return }
        self.distance = nextDistance
        viewModel.updateAnnotations(cameraDistance: nextDistance)
    }

    @ViewBuilder
    private func topBannerView(for candidate: MapTopBannerCandidate) -> some View {
        switch candidate.kind {
        case .recoveryIssue:
            if let issue = recoveryIssue {
                RecoveryActionBanner(
                    issue: issue,
                    onPrimary: { handleRecoveryPrimaryAction(issue) },
                    onDismiss: { dismissTopBanner(candidate) }
                )
            }
        case .recoverableSession:
            recoverableSessionBanner
        case .returnToOrigin:
            returnToOriginSuggestionBanner
        case .runtimeGuard:
            runtimeGuardBanner
        case .syncOutbox:
            syncOutboxBanner
        case .offlineMode:
            offlineModeBadge
        case .guestBackup:
            guestBackupBanner
        case .watchStatus:
            watchStatusBanner
        }
    }

    private var mapBottomControlOverlay: some View {
        MapBottomControlOverlayView(
            showsPrimaryAction: true,
            primaryAction: AnyView(mapPrimaryActionOverlay),
            floatingControls: AnyView(mapFloatingControlOverlay),
            selectedPolygonTray: selectedPolygonTrayView
        )
    }

    private var mapPrimaryActionOverlay: some View {
        StartButtonView(
            viewModel: viewModel,
            myAlert: myAlert,
            isModalPresented: $isWalkingViewPresented,
            endWalkingViewPresented: $endWalkingViewPresented
        )
    }

    private var mapFloatingControlOverlay: some View {
        MapFloatingControlColumnView(
            showsRecenterButton: isCameraSeeingSomewhere && viewModel.location != nil,
            showsAddPointButton: viewModel.isWalking,
            isAutoPointRecordMode: viewModel.isAutoPointRecordMode,
            isAddPointLongPressModeEnabled: viewModel.isAddPointLongPressModeEnabled,
            onRecenterTapped: {
                viewModel.handleLocationButtonTap()
            },
            onAddPointTapped: {
                guard viewModel.isAddPointLongPressModeEnabled == false else {
                    viewModel.walkStatusMessage = "길게 눌러 포인트를 추가하세요."
                    return
                }
                handleAddPointRequest()
            },
            onAddPointLongPressEnded: {
                handleAddPointRequest()
            }
        )
    }

    private var selectedPolygonTrayView: AnyView? {
        guard !viewModel.selectedPolygonList.isEmpty && !viewModel.isWalking else { return nil }
        return AnyView(selectedPolygonTrayOverlay)
    }

    private var selectedPolygonTrayOverlay: some View {
        Group {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("선택한 산책 기록")
                        .font(.appFont(for: .SemiBold, size: 15))
                        .foregroundStyle(MapChromePalette.primaryText)
                    Spacer()
                    Button("닫기") {
                        viewModel.selectedPolygonList = []
                    }
                    .font(.appFont(for: .SemiBold, size: 12))
                    .foregroundStyle(MapChromePalette.primaryText)
                    .frame(minHeight: 44)
                    .padding(.horizontal, 10)
                    .mapChromePill(.neutral)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(viewModel.selectedPolygonList) { item in
                            SelectedPolygonCell(walkData: .init(polygon: item))
                                .onTapGesture {
                                    self.selectedPolygonData = WalkDataModel(polygon: item)
                                }
                                .padding()
                                .myCornerRadius(radius: 15)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 15)
                                        .stroke(MapChromePalette.surfaceBorder, lineWidth: 1)
                                )
                        }
                    }
                }
                .padding(.horizontal, MapChromeLayoutMetrics.horizontalPadding)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, MapChromeLayoutMetrics.horizontalPadding)
            .mapChromeSurface()
            .padding(.horizontal, MapChromeLayoutMetrics.horizontalPadding)
        }
    }

    var recoverableSessionBanner: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("미종료 산책 감지")
                    .font(.appFont(for: .SemiBold, size: 13))
                    .foregroundStyle(MapChromePalette.primaryText)
                Text(viewModel.recoverableWalkSummaryText)
                    .font(.appFont(for: .Light, size: 11))
                    .foregroundStyle(MapChromePalette.secondaryText)
                if viewModel.recoverableWalkEstimateText.isEmpty == false {
                    Text(viewModel.recoverableWalkEstimateText)
                        .font(.appFont(for: .Light, size: 11))
                        .foregroundStyle(MapChromePalette.secondaryText)
                }
            }
            Spacer()
            Button("복구") {
                viewModel.resumeRecoverableWalkSession()
            }
            .font(.appFont(for: .SemiBold, size: 12))
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.appGreen)
            .cornerRadius(8)
            Button("추정 종료") {
                viewModel.finalizeRecoverableWalkSessionEstimated()
            }
            .font(.appFont(for: .SemiBold, size: 12))
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.appTextLightGray)
            .cornerRadius(8)
            Button("지금 종료") {
                viewModel.finalizeRecoverableWalkSessionNow()
            }
            .font(.appFont(for: .SemiBold, size: 12))
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.appYellow)
            .cornerRadius(8)
            Button("닫기") {
                dismissTopBanner(.recoverableSession, suppressFor: 180)
            }
            .font(.appFont(for: .SemiBold, size: 12))
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.appYellowPale)
            .cornerRadius(8)
        }
        .padding(10)
        .mapChromeSurface()
    }

    var watchStatusBanner: some View {
        VStack(spacing: 3) {
            Text(viewModel.watchSyncStatusText)
                .font(.appFont(for: .Light, size: 11))
                .foregroundStyle(MapChromePalette.secondaryText)
            if viewModel.latestWatchActionText.isEmpty == false {
                Text(viewModel.latestWatchActionText)
                    .font(.appFont(for: .Light, size: 11))
                    .foregroundStyle(MapChromePalette.secondaryText)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .mapChromeSurface()
    }

    var returnToOriginSuggestionBanner: some View {
        Group {
            if let context = viewModel.returnToOriginSuggestionContext {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("출발지 근처예요")
                            .font(.appFont(for: .SemiBold, size: 13))
                            .foregroundStyle(MapChromePalette.primaryText)
                        Text("약 \(context.distanceFromOriginMeters)m · \(context.dwellSeconds)초 체류")
                            .font(.appFont(for: .Light, size: 11))
                            .foregroundStyle(MapChromePalette.secondaryText)
                        Text("산책을 종료할까요?")
                            .font(.appFont(for: .Light, size: 11))
                            .foregroundStyle(MapChromePalette.secondaryText)
                    }
                    Spacer(minLength: 8)
                    Button("계속") {
                        viewModel.continueWalkAfterReturnToOriginSuggestion()
                    }
                    .font(.appFont(for: .SemiBold, size: 12))
                    .frame(minHeight: 44)
                    .padding(.horizontal, 10)
                    .background(Color.appTextLightGray.opacity(0.85))
                    .cornerRadius(8)
                    Button("종료") {
                        viewModel.endWalkAfterReturnToOriginSuggestion()
                    }
                    .font(.appFont(for: .SemiBold, size: 12))
                    .frame(minHeight: 44)
                    .padding(.horizontal, 10)
                    .background(Color.appYellow)
                    .cornerRadius(8)
                }
                .padding(10)
                .mapChromeSurface()
            }
        }
    }

    var runtimeGuardBanner: some View {
        Text(viewModel.runtimeGuardStatusText)
            .font(.appFont(for: .Light, size: 11))
            .foregroundStyle(Color.appRed)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .mapChromeSurface()
    }

    var syncOutboxBanner: some View {
        Text(viewModel.syncOutboxStatusText)
            .font(.appFont(for: .Light, size: 11))
            .foregroundStyle(MapChromePalette.secondaryText)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .mapChromeSurface()
    }

    var offlineModeBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.appRed)
                .frame(width: 8, height: 8)
            Text("오프라인 모드 · 온라인 복귀 시 자동 동기화")
                .font(.appFont(for: .Light, size: 11))
                .foregroundStyle(MapChromePalette.secondaryText)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .mapChromeSurface()
    }

    var guestBackupBanner: some View {
        HStack(spacing: 8) {
            Text("게스트 기록은 이 기기에만 저장돼요.")
                .font(.appFont(for: .Light, size: 11))
                .foregroundStyle(MapChromePalette.secondaryText)
            Spacer()
            Button("로그인하고 백업") {
                _ = authFlow.requestAccess(feature: .cloudSync)
            }
            .font(.appFont(for: .SemiBold, size: 11))
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.appYellow)
            .cornerRadius(8)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .mapChromeSurface()
    }

    /// 영역 추가 버튼 요청을 처리하고 3초 Undo 토스트를 예약합니다.
    private func handleAddPointRequest() {
        viewModel.preparePointAddCameraSnapshot()
        guard let addedPointID = viewModel.addLocationPreservingCamera() else { return }
        scheduleAddPointUndo(for: addedPointID)
    }

    /// 방금 추가된 포인트에 대해 3초 실행 취소 윈도우를 시작합니다.
    /// - Parameter pointID: 실행 취소 대상으로 추적할 포인트 UUID입니다.
    private func scheduleAddPointUndo(for pointID: UUID) {
        addPointUndoDismissTask?.cancel()
        pendingUndoPointID = pointID
        addPointUndoDismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard pendingUndoPointID == pointID else { return }
            clearPendingAddPointUndo()
        }
    }

    /// 활성화된 포인트 추가 Undo 요청을 실행합니다.
    private func undoLastAddedPoint() {
        guard let pointID = pendingUndoPointID else { return }
        guard viewModel.undoAddedPoint(pointID) else { return }
        clearPendingAddPointUndo()
    }

    /// 현재 표시 중인 포인트 추가 Undo 상태를 정리합니다.
    private func clearPendingAddPointUndo() {
        addPointUndoDismissTask?.cancel()
        addPointUndoDismissTask = nil
        pendingUndoPointID = nil
    }

    /// 상태 메시지에 위치 권한 안내가 포함되어 설정 이동 버튼을 노출해야 하는지 판단합니다.
    /// - Parameter message: 상단 토스트에 표시할 상태 메시지 문자열입니다.
    /// - Returns: 위치 권한/설정 키워드가 포함되면 `true`, 아니면 `false`입니다.
    private func shouldShowLocationSettingsAction(for message: String) -> Bool {
        let normalized = message.lowercased()
        return normalized.contains("위치 권한") || normalized.contains("설정")
    }

    /// iOS 앱 설정 화면을 열어 사용자가 위치 권한을 즉시 조정할 수 있게 합니다.
    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        guard UIApplication.shared.canOpenURL(url) else { return }
        UIApplication.shared.open(url)
    }

    /// 두 좌표 사이의 대권 거리(미터)를 계산합니다.
    /// - Parameters:
    ///   - from: 시작 좌표입니다.
    ///   - to: 도착 좌표입니다.
    /// - Returns: 두 좌표 간 거리(미터)입니다.
    private func greatCircleDistanceMeters(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D
    ) -> Double {
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

    private func recomputeBannerQueue() {
        evaluateRecoveryIssue()
        refreshTopBannerQueue()
    }

    private func refreshTopBannerQueue() {
        let candidates = prioritizedBannerCandidates()
        let now = Date()
        let next = candidates.first { candidate in
            guard let suppressedUntil = bannerSuppressedUntil[candidate.kind] else { return true }
            return suppressedUntil <= now
        }

        guard next != activeBanner else { return }
        activeBanner = next
        scheduleAutoDismissIfNeeded(for: next)
    }

    private func scheduleAutoDismissIfNeeded(for candidate: MapTopBannerCandidate?) {
        bannerAutoDismissTask?.cancel()
        guard let candidate,
              let autoDismissAfter = candidate.autoDismissAfter,
              autoDismissAfter > 0 else {
            return
        }

        bannerAutoDismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(autoDismissAfter * 1_000_000_000))
            guard activeBanner == candidate else { return }
            dismissTopBanner(candidate)
        }
    }

    private func dismissTopBanner(_ candidate: MapTopBannerCandidate) {
        dismissTopBanner(candidate.kind, suppressFor: candidate.suppressFor)
    }

    private func dismissTopBanner(_ kind: MapTopBannerKind, suppressFor: TimeInterval) {
        bannerSuppressedUntil[kind] = Date().addingTimeInterval(suppressFor)
        if activeBanner?.kind == kind {
            activeBanner = nil
        }
        refreshTopBannerQueue()
    }

    private func prioritizedBannerCandidates() -> [MapTopBannerCandidate] {
        var candidates: [MapTopBannerCandidate] = []

        if recoveryIssue != nil {
            candidates.append(
                MapTopBannerCandidate(
                    kind: .recoveryIssue,
                    severity: .p0,
                    autoDismissAfter: nil,
                    suppressFor: 60
                )
            )
        }

        if viewModel.hasRecoverableWalkSession && !viewModel.isWalking {
            candidates.append(
                MapTopBannerCandidate(
                    kind: .recoverableSession,
                    severity: .p0,
                    autoDismissAfter: nil,
                    suppressFor: 180
                )
            )
        }

        if viewModel.isWalking && viewModel.hasReturnToOriginSuggestion {
            candidates.append(
                MapTopBannerCandidate(
                    kind: .returnToOrigin,
                    severity: .p0,
                    autoDismissAfter: nil,
                    suppressFor: 600
                )
            )
        }

        if viewModel.syncOutboxPermanentFailureCount > 0 {
            candidates.append(
                MapTopBannerCandidate(
                    kind: .syncOutbox,
                    severity: .p1,
                    autoDismissAfter: nil,
                    suppressFor: 120
                )
            )
        } else if viewModel.hasSyncOutboxStatus {
            candidates.append(
                MapTopBannerCandidate(
                    kind: .syncOutbox,
                    severity: .p1,
                    autoDismissAfter: 4.0,
                    suppressFor: 20
                )
            )
        }

        if viewModel.hasRuntimeGuardStatus {
            candidates.append(
                MapTopBannerCandidate(
                    kind: .runtimeGuard,
                    severity: .p1,
                    autoDismissAfter: 4.0,
                    suppressFor: 20
                )
            )
        }

        if viewModel.isOfflineRecoveryMode {
            candidates.append(
                MapTopBannerCandidate(
                    kind: .offlineMode,
                    severity: .p1,
                    autoDismissAfter: 4.0,
                    suppressFor: 20
                )
            )
        }

        if !authFlow.canAccess(.cloudSync) && !viewModel.isWalking && !viewModel.polygonList.isEmpty {
            candidates.append(
                MapTopBannerCandidate(
                    kind: .guestBackup,
                    severity: .p2,
                    autoDismissAfter: 6.0,
                    suppressFor: 180
                )
            )
        }

        if viewModel.shouldShowWatchStatus {
            candidates.append(
                MapTopBannerCandidate(
                    kind: .watchStatus,
                    severity: .p2,
                    autoDismissAfter: 4.0,
                    suppressFor: 12
                )
            )
        }

        return candidates.sorted()
    }

    private func evaluateRecoveryIssue() {
        if viewModel.isLocationPermissionDenied {
            recoveryIssue = RecoveryIssue(kind: .locationPermissionDenied, detail: nil)
            return
        }
        if let syncIssue = RecoveryIssueClassifier.fromSyncErrorCode(viewModel.syncOutboxLastErrorCodeText) {
            recoveryIssue = syncIssue
            return
        }
        recoveryIssue = nil
    }

    private func handleRecoveryPrimaryAction(_ issue: RecoveryIssue) {
        switch issue.kind {
        case .locationPermissionDenied:
            RecoverySystemAction.openAppSettings()
        case .networkOffline:
            viewModel.retrySyncNow()
        case .authExpired:
            authFlow.startReauthenticationFlow()
        }
        refreshTopBannerQueue()
    }
}
#Preview {
    MapView()
}

private enum MapTopBannerKind: String, Hashable {
    case recoveryIssue
    case recoverableSession
    case returnToOrigin
    case runtimeGuard
    case syncOutbox
    case offlineMode
    case guestBackup
    case watchStatus
}

private enum MapTopBannerSeverity: Int, Comparable {
    case p0 = 0
    case p1 = 1
    case p2 = 2

    static func < (lhs: MapTopBannerSeverity, rhs: MapTopBannerSeverity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

private struct MapTopBannerCandidate: Identifiable, Equatable, Comparable {
    let kind: MapTopBannerKind
    let severity: MapTopBannerSeverity
    let autoDismissAfter: TimeInterval?
    let suppressFor: TimeInterval

    var id: MapTopBannerKind {
        kind
    }

    static func < (lhs: MapTopBannerCandidate, rhs: MapTopBannerCandidate) -> Bool {
        if lhs.severity == rhs.severity {
            return lhs.kind.priorityRank < rhs.kind.priorityRank
        }
        return lhs.severity < rhs.severity
    }
}

private extension MapTopBannerKind {
    var priorityRank: Int {
        switch self {
        case .recoverableSession: return 0
        case .returnToOrigin: return 1
        case .recoveryIssue: return 2
        case .syncOutbox: return 3
        case .runtimeGuard: return 4
        case .offlineMode: return 5
        case .guestBackup: return 6
        case .watchStatus: return 7
        }
    }
}
