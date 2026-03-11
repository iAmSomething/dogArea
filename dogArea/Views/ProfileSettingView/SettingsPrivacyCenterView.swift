import SwiftUI
import UIKit

struct SettingsPrivacyCenterView: View {
    @StateObject var viewModel: SettingsPrivacyCenterViewModel
    let onRequestSignIn: () -> Void
    let onOpenDeletionRequest: () -> Void
    let onClose: () -> Void

    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var activeDocument: SettingsDocumentContent? = nil

    /// 프라이버시 센터 화면에 사용할 상태 객체와 라우팅 콜백을 구성합니다.
    /// - Parameters:
    ///   - viewModel: 프라이버시 센터 읽기/쓰기 상태를 관리할 뷰모델입니다.
    ///   - onRequestSignIn: 게스트 상태에서 로그인/회원가입 흐름을 여는 콜백입니다.
    ///   - onOpenDeletionRequest: 삭제 요청 전용 화면으로 전환할 때 실행할 콜백입니다.
    ///   - onClose: 프라이버시 센터 시트를 닫을 때 실행할 콜백입니다.
    init(
        viewModel: SettingsPrivacyCenterViewModel,
        onRequestSignIn: @escaping () -> Void,
        onOpenDeletionRequest: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onRequestSignIn = onRequestSignIn
        self.onOpenDeletionRequest = onOpenDeletionRequest
        self.onClose = onClose
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    statusCard(viewModel.snapshot.currentStatus)
                    controlCard
                    permissionCard
                    statusCard(viewModel.snapshot.recentStatus, identifier: "settings.privacyCenter.recent")
                    moderationCard
                    deletionRequestCard
                    documentCard
                }
                .padding(.horizontal, 16)
                .padding(.bottom, AppTabLayoutMetrics.comfortableScrollExtraBottomPadding)
                .padding(.top, 12)
            }
        }
        .background(Color.appTabScaffoldBackground.ignoresSafeArea())
        .task {
            await viewModel.refresh()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task {
                await viewModel.refresh()
            }
        }
        .sheet(item: $activeDocument) { document in
            SettingsDocumentSheetView(document: document) {
                activeDocument = nil
            }
        }
        .overlay(alignment: .bottom) {
            if let toastMessage = viewModel.toastMessage {
                SimpleMessageView(message: toastMessage)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                            viewModel.clearToast()
                        }
                    }
            }
        }
        .accessibilityIdentifier("screen.settings.privacyCenter")
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("프라이버시 센터")
                    .font(.appScaledFont(for: .SemiBold, size: 28, relativeTo: .title2))
                    .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
                    .accessibilityIdentifier("settings.privacyCenter.header.title")
                Text("공유 상태와 권한, 보존/삭제 요청을 여기서 확인할 수 있어요")
                    .font(.appScaledFont(for: .Regular, size: 13, relativeTo: .body))
                    .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("settings.privacyCenter.header.subtitle")
            }

            Spacer(minLength: 12)

            Button("닫기", action: onClose)
                .buttonStyle(.plain)
                .font(.appScaledFont(for: .SemiBold, size: 14, relativeTo: .body))
                .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
                .accessibilityIdentifier("settings.privacyCenter.close")
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
        .padding(.bottom, 12)
        .background(Color.appTabScaffoldBackground)
    }

    private var controlCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(viewModel.snapshot.controlTitle)
                .font(.appScaledFont(for: .SemiBold, size: 18, relativeTo: .headline))
                .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))

            Text(viewModel.snapshot.controlSubtitle)
                .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .body))
                .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
                .fixedSize(horizontal: false, vertical: true)

            Button {
                handlePrimaryAction(viewModel.snapshot.primaryActionKind)
            } label: {
                Text(viewModel.snapshot.primaryActionTitle)
                    .frame(maxWidth: .infinity)
            }
            .accessibilityIdentifier("settings.privacyCenter.primaryAction")
            .buttonStyle(buttonStyle(for: viewModel.snapshot.primaryActionKind))
            .frame(minHeight: 44)
        }
        .appCardSurface()
        .accessibilityIdentifier("settings.privacyCenter.control")
    }

    private var permissionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("권한 상태")
                .font(.appScaledFont(for: .SemiBold, size: 18, relativeTo: .headline))
                .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))

            permissionRow(viewModel.snapshot.locationPermission, identifier: "settings.privacyCenter.permission.location")
            Divider()
            permissionRow(viewModel.snapshot.notificationPermission, identifier: "settings.privacyCenter.permission.notification")

            Button("설정 열기") {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                openURL(url)
            }
            .accessibilityIdentifier("settings.privacyCenter.openSettings")
            .buttonStyle(AppFilledButtonStyle(role: .neutral, fillsWidth: false))
            .frame(minHeight: 44)
        }
        .appCardSurface()
        .accessibilityIdentifier("settings.privacyCenter.permissions")
    }

    private var moderationCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("숨김/차단 요약")
                .font(.appScaledFont(for: .SemiBold, size: 18, relativeTo: .headline))
                .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
            Text(viewModel.snapshot.moderationSummary.title)
                .font(.appScaledFont(for: .SemiBold, size: 14, relativeTo: .body))
                .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
            Text(viewModel.snapshot.moderationSummary.subtitle)
                .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .body))
                .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
                .fixedSize(horizontal: false, vertical: true)
        }
        .appCardSurface()
        .accessibilityIdentifier("settings.privacyCenter.moderation")
    }

    private var deletionRequestCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(viewModel.snapshot.deletionRequestSummary.title)
                        .font(.appScaledFont(for: .SemiBold, size: 18, relativeTo: .headline))
                        .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
                    Text(viewModel.snapshot.deletionRequestSummary.subtitle)
                        .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .body))
                        .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Text(viewModel.snapshot.deletionRequestSummary.badgeText)
                    .font(.appScaledFont(for: .SemiBold, size: 11, relativeTo: .caption))
                    .foregroundStyle(toneForegroundColor(viewModel.snapshot.deletionRequestSummary.tone))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(toneBackgroundColor(viewModel.snapshot.deletionRequestSummary.tone))
                    .clipShape(Capsule())
            }

            if let requestId = viewModel.snapshot.deletionRequestSummary.requestId {
                Text("요청 ID · \(requestId)")
                    .font(.appScaledFont(for: .SemiBold, size: 12, relativeTo: .caption))
                    .foregroundStyle(Color.appDynamicHex(light: 0x334155, dark: 0xCBD5E1))
                    .accessibilityIdentifier("settings.privacyCenter.deleteRequest.requestId")
            }

            Text(viewModel.snapshot.deletionRequestSummary.footer)
                .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .caption))
                .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0x94A3B8))
                .fixedSize(horizontal: false, vertical: true)

            Button(viewModel.snapshot.deletionRequestSummary.buttonTitle, action: onOpenDeletionRequest)
            .buttonStyle(AppFilledButtonStyle(role: .destructive, fillsWidth: false))
            .frame(minHeight: 44)
            .accessibilityIdentifier("settings.privacyCenter.deleteRequest.open")
        }
        .appCardSurface()
        .accessibilityIdentifier("settings.privacyCenter.deleteRequest")
    }

    private var documentCard: some View {
        SettingsActionSectionCardView(
            title: "보존 / 삭제 / 문서",
            subtitle: "보존 정책, 삭제 요청 운영 기준, 현재 숨김/차단 관계를 한 번에 다시 확인합니다.",
            accessibilityIdentifier: "settings.privacyCenter.documents",
            actions: viewModel.snapshot.documentActions,
            onSelect: handleDocumentAction
        )
    }

    /// 프라이버시 센터의 상태 배지 카드 한 장을 렌더링합니다.
    /// - Parameters:
    ///   - content: 카드 제목/본문/배지 표현에 사용할 상태 콘텐츠입니다.
    ///   - identifier: UI 테스트와 접근성에 사용할 식별자입니다.
    /// - Returns: 카드 표면 스타일이 적용된 상태 카드 뷰입니다.
    private func statusCard(
        _ content: SettingsPrivacyStatusContent,
        identifier: String = "settings.privacyCenter.currentStatus"
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(content.title)
                    .font(.appScaledFont(for: .SemiBold, size: 18, relativeTo: .headline))
                    .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
                Spacer(minLength: 8)
                Text(content.badgeText)
                    .font(.appScaledFont(for: .SemiBold, size: 11, relativeTo: .caption))
                    .foregroundStyle(toneForegroundColor(content.tone))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(toneBackgroundColor(content.tone))
                    .clipShape(Capsule())
            }

            Text(content.subtitle)
                .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .body))
                .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
                .fixedSize(horizontal: false, vertical: true)
        }
        .appCardSurface()
        .accessibilityIdentifier(identifier)
    }

    /// 프라이버시 센터 권한 카드의 단일 권한 행을 렌더링합니다.
    /// - Parameters:
    ///   - content: 위치/알림 권한의 제목, 설명, 배지 표현입니다.
    ///   - identifier: UI 테스트와 접근성에 사용할 식별자입니다.
    /// - Returns: 권한 상태 한 줄을 표현하는 행 뷰입니다.
    private func permissionRow(
        _ content: SettingsPrivacyPermissionRowContent,
        identifier: String
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(content.title)
                    .font(.appScaledFont(for: .SemiBold, size: 14, relativeTo: .body))
                    .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
                Text(content.subtitle)
                    .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .caption))
                    .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Text(content.badgeText)
                .font(.appScaledFont(for: .SemiBold, size: 11, relativeTo: .caption))
                .foregroundStyle(toneForegroundColor(content.tone))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(toneBackgroundColor(content.tone))
                .clipShape(Capsule())
        }
        .accessibilityIdentifier(identifier)
    }

    /// 프라이버시 센터의 주행동 버튼을 현재 상태에 맞는 동작으로 라우팅합니다.
    /// - Parameter kind: 현재 버튼이 수행해야 할 주행동 종류입니다.
    private func handlePrimaryAction(_ kind: SettingsPrivacyPrimaryActionKind) {
        switch kind {
        case .openSignIn:
            onClose()
            onRequestSignIn()
        case .openSystemSettings:
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            openURL(url)
        case .enableSharing:
            Task {
                await viewModel.setSharingEnabled(true)
            }
        case .disableSharing:
            Task {
                await viewModel.setSharingEnabled(false)
            }
        }
    }

    /// 문서/외부 링크 액션을 내부 시트 또는 외부 URL로 라우팅합니다.
    /// - Parameter action: 사용자가 선택한 문서 또는 외부 링크 액션입니다.
    private func handleDocumentAction(_ action: SettingsSurfaceAction) {
        switch action.target {
        case .external(let url):
            openURL(url)
        case .document(let document):
            activeDocument = document
        }
    }

    /// 주행동 종류에 맞는 버튼 스타일을 선택합니다.
    /// - Parameter kind: 현재 버튼이 수행해야 할 주행동 종류입니다.
    /// - Returns: 주행동 의미에 맞는 채움 버튼 스타일입니다.
    private func buttonStyle(for kind: SettingsPrivacyPrimaryActionKind) -> AppFilledButtonStyle {
        switch kind {
        case .openSignIn, .enableSharing:
            return AppFilledButtonStyle(role: .secondary)
        case .openSystemSettings:
            return AppFilledButtonStyle(role: .neutral)
        case .disableSharing:
            return AppFilledButtonStyle(role: .destructive)
        }
    }

    /// 프라이버시 상태 톤에 맞는 전경색을 반환합니다.
    /// - Parameter tone: 현재 카드/배지의 강조 톤입니다.
    /// - Returns: 텍스트와 배지 전경에 사용할 색상입니다.
    private func toneForegroundColor(_ tone: SettingsPrivacyTone) -> Color {
        switch tone {
        case .neutral:
            return Color.appTextDarkGray
        case .positive:
            return Color.appGreen
        case .warning:
            return Color.appYellow
        case .critical:
            return Color.appRed
        }
    }

    /// 프라이버시 상태 톤에 맞는 배경색을 반환합니다.
    /// - Parameter tone: 현재 카드/배지의 강조 톤입니다.
    /// - Returns: 배지 배경에 사용할 색상입니다.
    private func toneBackgroundColor(_ tone: SettingsPrivacyTone) -> Color {
        switch tone {
        case .neutral:
            return Color.appTextLightGray.opacity(0.18)
        case .positive:
            return Color.appGreen.opacity(0.14)
        case .warning:
            return Color.appYellow.opacity(0.14)
        case .critical:
            return Color.appRed.opacity(0.14)
        }
    }
}
