import SwiftUI

struct SettingsPrivacyDeletionRequestSheetView: View {
    @StateObject var viewModel: SettingsPrivacyDeletionRequestSheetViewModel
    let onClose: () -> Void

    @Environment(\.openURL) private var openURL
    @State private var activeDraft: SettingsPrivacyDeletionRequestDraft? = nil
    @State private var previewDraft: SettingsPrivacyDeletionRequestDraft? = nil

    /// 삭제 요청 전용 시트에 사용할 상태 객체와 닫기 콜백을 구성합니다.
    /// - Parameters:
    ///   - viewModel: 삭제 요청 흐름의 로컬 추적 상태와 메일 초안을 관리할 뷰모델입니다.
    ///   - onClose: 시트를 닫을 때 실행할 콜백입니다.
    init(
        viewModel: SettingsPrivacyDeletionRequestSheetViewModel,
        onClose: @escaping () -> Void
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onClose = onClose
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    summaryCard
                    collectionCard
                    nextStepCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 32)
            }
            .background(Color.appTabScaffoldBackground.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                actionCard
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                    .background(Color.appTabScaffoldBackground)
            }
            .navigationTitle("삭제 요청")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기", action: onClose)
                }
            }
        }
        .task {
            viewModel.refresh()
            previewDraft = viewModel.previewDeletionRequestDraft()
        }
        .sheet(item: $activeDraft) { draft in
            SettingsMailComposeSheet(draft: draft) { result in
                viewModel.handleMailComposeResult(result, draft: draft)
                activeDraft = nil
                previewDraft = viewModel.previewDeletionRequestDraft()
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
        .accessibilityIdentifier("sheet.settings.privacyDeletionRequest")
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(viewModel.summary.title)
                        .font(.appScaledFont(for: .SemiBold, size: 22, relativeTo: .title3))
                        .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
                    Text(viewModel.summary.subtitle)
                        .font(.appScaledFont(for: .Regular, size: 13, relativeTo: .body))
                        .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                statusBadge(
                    text: viewModel.summary.badgeText,
                    tone: viewModel.summary.tone
                )
            }

            if let requestId = viewModel.summary.requestId {
                VStack(alignment: .leading, spacing: 4) {
                    Text("현재 요청 ID")
                        .font(.appScaledFont(for: .SemiBold, size: 12, relativeTo: .caption))
                        .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0x94A3B8))
                    Text(requestId)
                        .font(.appScaledFont(for: .SemiBold, size: 16, relativeTo: .body))
                        .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
                        .accessibilityIdentifier("settings.privacyDeletionRequest.requestId")
                }
            }

            Text(viewModel.summary.footer)
                .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .caption))
                .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0x94A3B8))
                .fixedSize(horizontal: false, vertical: true)
        }
        .appCardSurface()
    }

    private var collectionCard: some View {
        let previewDraft = activeDraft ?? previewDraft ?? viewModel.previewDeletionRequestDraft()
        return VStack(alignment: .leading, spacing: 12) {
            Text("메일 본문에 함께 들어가는 정보")
                .font(.appScaledFont(for: .SemiBold, size: 18, relativeTo: .headline))
                .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))

            ForEach(previewDraft.collectionItems, id: \.self) { item in
                HStack(alignment: .top, spacing: 8) {
                    Circle()
                        .fill(Color.appYellow)
                        .frame(width: 6, height: 6)
                        .padding(.top, 6)
                    Text(item)
                        .font(.appScaledFont(for: .Regular, size: 13, relativeTo: .body))
                        .foregroundStyle(Color.appDynamicHex(light: 0x334155, dark: 0xCBD5E1))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Button {
                let draft = viewModel.prepareDeletionRequestDraft()
                viewModel.copyDraftBody(draft)
                self.previewDraft = viewModel.previewDeletionRequestDraft()
            } label: {
                Text("메일 본문 복사")
                    .accessibilityIdentifier("settings.privacyDeletionRequest.copyBody")
            }
            .buttonStyle(AppFilledButtonStyle(role: .neutral, fillsWidth: false))
            .frame(minHeight: 44)
            .accessibilityIdentifier("settings.privacyDeletionRequest.copyBody")
        }
        .appCardSurface()
        .accessibilityIdentifier("settings.privacyDeletionRequest.collection")
    }

    private var nextStepCard: some View {
        let previewDraft = activeDraft ?? previewDraft ?? viewModel.previewDeletionRequestDraft()
        return VStack(alignment: .leading, spacing: 12) {
            Text("전송 후 다음 단계")
                .font(.appScaledFont(for: .SemiBold, size: 18, relativeTo: .headline))
                .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))

            ForEach(previewDraft.nextStepChecklist, id: \.self) { item in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "arrow.turn.down.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.appYellow)
                        .padding(.top, 1)
                    Text(item)
                        .font(.appScaledFont(for: .Regular, size: 13, relativeTo: .body))
                        .foregroundStyle(Color.appDynamicHex(light: 0x334155, dark: 0xCBD5E1))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .appCardSurface()
        .accessibilityIdentifier("settings.privacyDeletionRequest.nextSteps")
    }

    private var actionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("요청 보내기 / 상태 문의")
                .font(.appScaledFont(for: .SemiBold, size: 18, relativeTo: .headline))
                .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))

            Button {
                presentDeleteRequestDraft()
            } label: {
                Text(viewModel.summary.buttonTitle)
                    .accessibilityIdentifier("settings.privacyDeletionRequest.primary")
            }
            .buttonStyle(AppFilledButtonStyle(role: .destructive))
            .frame(minHeight: 44)
            .accessibilityIdentifier("settings.privacyDeletionRequest.primary")

            if viewModel.latestRecord != nil {
                Button {
                    presentStatusInquiryDraft()
                } label: {
                    Text("처리 상태 문의 열기")
                        .accessibilityIdentifier("settings.privacyDeletionRequest.inquiry")
                }
                .buttonStyle(AppFilledButtonStyle(role: .secondary))
                .frame(minHeight: 44)
                .accessibilityIdentifier("settings.privacyDeletionRequest.inquiry")
            }

            if viewModel.latestRecord?.status == .handedOffToMailApp {
                Button {
                    viewModel.confirmExternalMailSent()
                    previewDraft = viewModel.previewDeletionRequestDraft()
                } label: {
                    Text("메일 보냈어요")
                        .accessibilityIdentifier("settings.privacyDeletionRequest.confirmSent")
                }
                .buttonStyle(AppFilledButtonStyle(role: .neutral))
                .frame(minHeight: 44)
                .accessibilityIdentifier("settings.privacyDeletionRequest.confirmSent")
            }

            Button {
                viewModel.copyRequestID()
            } label: {
                Text("요청 ID 복사")
                    .accessibilityIdentifier("settings.privacyDeletionRequest.copyRequestId")
            }
            .buttonStyle(AppFilledButtonStyle(role: .neutral, fillsWidth: false))
            .frame(minHeight: 44)
            .accessibilityIdentifier("settings.privacyDeletionRequest.copyRequestId")
        }
        .appCardSurface()
        .accessibilityIdentifier("settings.privacyDeletionRequest.actions")
    }

    /// 삭제 요청 메일 초안을 현재 기기 환경에 맞는 경로로 엽니다.
    private func presentDeleteRequestDraft() {
        let draft = viewModel.prepareDeletionRequestDraft()
        previewDraft = draft
        if SettingsMailComposeSheet.canSendMail() {
            activeDraft = draft
            return
        }
        viewModel.recordExternalMailHandoff(for: draft)
        previewDraft = viewModel.previewDeletionRequestDraft()
        openURL(draft.fallbackURL)
    }

    /// 상태 문의 메일 초안을 현재 기기 환경에 맞는 경로로 엽니다.
    private func presentStatusInquiryDraft() {
        guard let draft = viewModel.prepareStatusInquiryDraft() else { return }
        previewDraft = draft
        if SettingsMailComposeSheet.canSendMail() {
            activeDraft = draft
            return
        }
        viewModel.recordExternalMailHandoff(for: draft)
        previewDraft = viewModel.previewDeletionRequestDraft()
        openURL(draft.fallbackURL)
    }

    /// 삭제 요청 상태 톤에 맞는 배지 뷰를 생성합니다.
    /// - Parameters:
    ///   - text: 배지 본문 문구입니다.
    ///   - tone: 강조 톤입니다.
    /// - Returns: 삭제 요청 상태를 나타내는 capsule badge 뷰입니다.
    private func statusBadge(text: String, tone: SettingsPrivacyTone) -> some View {
        Text(text)
            .font(.appScaledFont(for: .SemiBold, size: 11, relativeTo: .caption))
            .foregroundStyle(foregroundColor(for: tone))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(backgroundColor(for: tone))
            .clipShape(Capsule())
    }

    /// 삭제 요청 상태 톤에 맞는 전경색을 계산합니다.
    /// - Parameter tone: 강조 톤입니다.
    /// - Returns: 상태 배지 전경에 사용할 색상입니다.
    private func foregroundColor(for tone: SettingsPrivacyTone) -> Color {
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

    /// 삭제 요청 상태 톤에 맞는 배경색을 계산합니다.
    /// - Parameter tone: 강조 톤입니다.
    /// - Returns: 상태 배지 배경에 사용할 색상입니다.
    private func backgroundColor(for tone: SettingsPrivacyTone) -> Color {
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
