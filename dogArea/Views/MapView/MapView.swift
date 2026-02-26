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
    @ObservedObject var myAlert: CustomAlertViewModel = .init()
    @ObservedObject var viewModel: MapViewModel = .init()
    @State private var isModalPresented = false
    @State private var isWalkingViewPresented = false
    @State private var endWalkingViewPresented = false
    @State private var isCameraSeeingSomewhere: Bool = false
    @State private var distance = 2000.0
    @State private var selectedPolygonData: WalkDataModel? = nil
    @State private var recoveryIssue: RecoveryIssue? = nil
    @ObservedObject var tabStatus = TabAppear.shared
    
    var body : some View {
        ZStack{
            MapSubView(myAlert: myAlert, viewModel: viewModel)
            MapAlertSubView(viewModel: viewModel, myAlert: myAlert)
            
            VStack {
                Spacer().frame(height: 50)
                HStack {
                    Spacer()
                    Button(action:{
                        viewModel.fetchPolygonList()
                        isModalPresented.toggle()
                    }, label: {
                        Text("설정")
                            .font(.appFont(for: .Bold, size: 16))
                            .foregroundStyle(Color.appTextDarkGray)
                            .padding(7)
                            .background(Color.appYellow)
                            .cornerRadius(10)
                    })
                }
                if viewModel.hasRecoverableWalkSession && !viewModel.isWalking {
                    recoverableSessionBanner
                }
                if viewModel.shouldShowWatchStatus {
                    watchStatusBanner
                }
                if viewModel.hasRuntimeGuardStatus {
                    runtimeGuardBanner
                }
                if viewModel.hasSyncOutboxStatus {
                    syncOutboxBanner
                }
                if viewModel.isOfflineRecoveryMode {
                    offlineModeBadge
                }
                if !authFlow.canAccess(.cloudSync) && !viewModel.isWalking && !viewModel.polygonList.isEmpty {
                    guestBackupBanner
                }
                Spacer()
                
                if viewModel.isWalking {
                    HStack {
                        if isCameraSeeingSomewhere,
                           let loc = viewModel.location{
                            Button(action: {viewModel.setRegion(loc,distance: 2000)}, label: {Text("내 위치 보기")})
                                .buttonStyle(.borderedProminent)
                                .padding(.leading)
                        }
                        Spacer()
                        addPointBtn
                    }
                } else {
                    HStack {
                        if isCameraSeeingSomewhere,
                           let loc = viewModel.location{
                            Button(action: {viewModel.setRegion(loc,distance: 2000)}, label: {Text("내 위치 보기")})
                                .buttonStyle(.borderedProminent)
                                .padding(.leading)
                        }
                        Spacer()
                    }
                    
                }
                StartButtonView(viewModel: viewModel,
                                myAlert: myAlert,
                                isModalPresented: $isWalkingViewPresented,
                                endWalkingViewPresented: $endWalkingViewPresented)
                if !viewModel.selectedPolygonList.isEmpty && !viewModel.isWalking {
                    VStack {
                        Text("닫기")
                            .frame(maxWidth: .infinity, maxHeight: 20)
                            .onTapGesture {
                                viewModel.selectedPolygonList = []
                            }.padding()
                            .aspectRatio(contentMode: .fit)
                        UnderLine()
                        ScrollView(.horizontal) {
                            HStack{
                                ForEach(viewModel.selectedPolygonList) { item in
                                    SelectedPolygonCell(walkData: .init(polygon: item))
                                        .onTapGesture {
                                            self.selectedPolygonData = WalkDataModel(polygon: item)
                                        }
                                        .padding()
                                        .myCornerRadius(radius: 15)
                                        .overlay(                                        RoundedRectangle(cornerRadius: 15)
                                            .stroke(Color.appTextDarkGray, lineWidth: 0.3))
                                }.padding(10)
                            }.frame(maxHeight: .infinity)
                                .aspectRatio(contentMode: .fit)
                        }.frame(width: screenSize.width)
                        .aspectRatio(contentMode: .fit)
                    }.frame(maxHeight: .infinity)
                        .aspectRatio(contentMode: .fit)
                        .background(.white)
                        .clipShape(RoundedCornersShape(radius: 20,corners: [.topLeft,.topRight]))
                }
            }
        }
        .onAppear {
            viewModel.reloadSelectedPetContext()
            viewModel.updateAnnotations(cameraDistance: self.distance)
            evaluateRecoveryIssue()
            tabStatus.appear()
        }
        .onChange(of: viewModel.walkStatusMessage) { newValue in
            guard newValue != nil else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                viewModel.clearWalkStatusMessage()
            }
        }
        .onChange(of: viewModel.runtimeGuardStatusText) { newValue in
            guard newValue.isEmpty == false else { return }
            evaluateRecoveryIssue()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                viewModel.clearRuntimeGuardStatus()
            }
        }
        .onChange(of: viewModel.syncOutboxLastErrorCodeText) { _ in
            evaluateRecoveryIssue()
        }
        .onChange(of: viewModel.syncOutboxPendingCount) { _ in
            evaluateRecoveryIssue()
        }
        .onChange(of: viewModel.syncRecoveryToastMessage) { message in
            guard let message else { return }
            viewModel.walkStatusMessage = message
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                viewModel.clearSyncRecoveryToastMessage()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            evaluateRecoveryIssue()
        }
        .sheet(isPresented: $isModalPresented){
            MapSettingView(viewModel: self.viewModel, myAlert: self.myAlert)
                .presentationDetents([.oneThird])
            
        }.fullScreenCover(isPresented: $isWalkingViewPresented) {
            StartModalView(
                petName: viewModel.selectedPetName,
                onCompleted: { viewModel.startWalkNow() }
            )
            .interactiveDismissDisabled(true)
        }.sheet(isPresented: $endWalkingViewPresented) {
            WalkDetailView()
                .environmentObject(loading)
                .environmentObject(viewModel).interactiveDismissDisabled(true)
        }.fullScreenCover(item: $selectedPolygonData, onDismiss: {self.selectedPolygonData = nil}, content: {model in
            WalkListDetailView(model: model)
        })
        .onMapCameraChange{ context in
            if let loc = viewModel.location {
                self.isCameraSeeingSomewhere =  context.camera.centerCoordinate.clLocation.distance(from: loc) > 300
                if !viewModel.showOnlyOne {
                    if Int(context.camera.distance) != Int(self.distance) {
                        self.distance = context.camera.distance
                        viewModel.updateAnnotations(cameraDistance: context.camera.distance)
                    }
                }
            }
        }
        .overlay(alignment: .top) {
            VStack(spacing: 6) {
                if let issue = recoveryIssue {
                    RecoveryActionBanner(
                        issue: issue,
                        onPrimary: { handleRecoveryPrimaryAction(issue) },
                        onDismiss: { recoveryIssue = nil }
                    )
                    .padding(.top, 12)
                }
                if let message = viewModel.walkStatusMessage {
                    Text(message)
                        .font(.appFont(for: .SemiBold, size: 13))
                        .foregroundStyle(Color.black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.appYellow)
                        .cornerRadius(10)
                        .padding(.top, issueTopPadding)
                }
            }
        }
    }

    private var issueTopPadding: CGFloat {
        recoveryIssue == nil ? 12 : 0
    }

    var recoverableSessionBanner: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("미종료 산책 감지")
                    .font(.appFont(for: .SemiBold, size: 13))
                Text(viewModel.recoverableWalkSummaryText)
                    .font(.appFont(for: .Light, size: 11))
                    .foregroundStyle(Color.appTextDarkGray)
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
            Button("지금 종료") {
                viewModel.finalizeRecoverableWalkSessionNow()
            }
            .font(.appFont(for: .SemiBold, size: 12))
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.appTextLightGray)
            .cornerRadius(8)
        }
        .padding(10)
        .background(Color.white.opacity(0.95))
        .cornerRadius(12)
        .padding(.horizontal, 12)
    }

    var watchStatusBanner: some View {
        VStack(spacing: 3) {
            Text(viewModel.watchSyncStatusText)
                .font(.appFont(for: .Light, size: 11))
                .foregroundStyle(Color.appTextDarkGray)
            if viewModel.latestWatchActionText.isEmpty == false {
                Text(viewModel.latestWatchActionText)
                    .font(.appFont(for: .Light, size: 11))
                    .foregroundStyle(Color.appTextDarkGray)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.9))
        .cornerRadius(8)
        .padding(.top, 4)
    }

    var runtimeGuardBanner: some View {
        Text(viewModel.runtimeGuardStatusText)
            .font(.appFont(for: .Light, size: 11))
            .foregroundStyle(Color.appRed)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.9))
            .cornerRadius(8)
            .padding(.top, 2)
    }

    var syncOutboxBanner: some View {
        Text(viewModel.syncOutboxStatusText)
            .font(.appFont(for: .Light, size: 11))
            .foregroundStyle(Color.appTextDarkGray)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.9))
            .cornerRadius(8)
            .padding(.top, 2)
    }

    var offlineModeBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.appRed)
                .frame(width: 8, height: 8)
            Text("오프라인 모드 · 온라인 복귀 시 자동 동기화")
                .font(.appFont(for: .Light, size: 11))
                .foregroundStyle(Color.appTextDarkGray)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.9))
        .cornerRadius(8)
        .padding(.top, 2)
    }

    var guestBackupBanner: some View {
        HStack(spacing: 8) {
            Text("게스트 기록은 이 기기에만 저장돼요.")
                .font(.appFont(for: .Light, size: 11))
                .foregroundStyle(Color.appTextDarkGray)
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
        .background(Color.white.opacity(0.9))
        .cornerRadius(8)
        .padding(.top, 2)
    }

    var addPointBtn: some View {
        VStack(spacing: 6) {
            if viewModel.isAutoPointRecordMode {
                Text("AUTO")
                    .font(.appFont(for: .SemiBold, size: 11))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.appGreen)
                    .cornerRadius(6)
            }
            Image("plusButton")
                .resizable()
                .frame(width: 70, height: 70)
                .onTapGesture {
                    viewModel.setTrackingMode()
                    myAlert.alertType = .addPoint
                    myAlert.callAlert(type: .addPoint)
                }
        }
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
    }
}
#Preview {
    MapView()
}

enum RecoveryIssueKind: Equatable {
    case locationPermissionDenied
    case networkOffline
    case authExpired
}

struct RecoveryIssue: Identifiable, Equatable {
    let kind: RecoveryIssueKind
    let detail: String?

    var id: String {
        "\(kind)-\(detail ?? "")"
    }

    var title: String {
        switch kind {
        case .locationPermissionDenied:
            return "위치 권한이 필요해요"
        case .networkOffline:
            return "오프라인 모드"
        case .authExpired:
            return "인증이 만료됐어요"
        }
    }

    var message: String {
        switch kind {
        case .locationPermissionDenied:
            return "설정에서 위치 권한을 허용하면 산책 기록을 계속할 수 있어요."
        case .networkOffline:
            return "지금 기록은 기기에 저장되고, 온라인 복귀 시 자동 동기화돼요."
        case .authExpired:
            return "다시 로그인하면 현재 화면으로 돌아와서 이어서 진행할 수 있어요."
        }
    }

    var primaryButtonTitle: String {
        switch kind {
        case .locationPermissionDenied:
            return "설정 열기"
        case .networkOffline:
            return "다시 시도"
        case .authExpired:
            return "다시 로그인"
        }
    }
}

enum RecoveryIssueClassifier {
    static func fromSyncErrorCode(_ rawValue: String?) -> RecoveryIssue? {
        guard let rawValue, rawValue.isEmpty == false else { return nil }
        switch rawValue {
        case SyncOutboxErrorCode.offline.rawValue:
            return RecoveryIssue(kind: .networkOffline, detail: rawValue)
        case SyncOutboxErrorCode.tokenExpired.rawValue, SyncOutboxErrorCode.unauthorized.rawValue:
            return RecoveryIssue(kind: .authExpired, detail: rawValue)
        default:
            return nil
        }
    }

    static func fromErrorMessage(_ raw: String?) -> RecoveryIssue? {
        guard let raw else { return nil }
        let normalized = raw.lowercased()
        if normalized.contains("network"),
           normalized.contains("offline") || normalized.contains("internet") {
            return RecoveryIssue(kind: .networkOffline, detail: raw)
        }
        if normalized.contains("token") || normalized.contains("unauthorized") || normalized.contains("auth") {
            return RecoveryIssue(kind: .authExpired, detail: raw)
        }
        return nil
    }
}

enum RecoverySystemAction {
    static func openAppSettings() {
        #if canImport(UIKit)
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
        #endif
    }
}

struct RecoveryActionBanner: View {
    let issue: RecoveryIssue
    let onPrimary: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(issue.title)
                .font(.appFont(for: .SemiBold, size: 13))
            Text(issue.message)
                .font(.appFont(for: .Light, size: 11))
                .foregroundStyle(Color.appTextDarkGray)
            HStack(spacing: 10) {
                Button(issue.primaryButtonTitle) {
                    onPrimary()
                }
                .font(.appFont(for: .SemiBold, size: 11))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.appYellow)
                .cornerRadius(8)

                Button("닫기") {
                    onDismiss()
                }
                .font(.appFont(for: .SemiBold, size: 11))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.appYellowPale)
                .cornerRadius(8)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.95))
        .cornerRadius(12)
        .padding(.horizontal, 12)
    }
}
