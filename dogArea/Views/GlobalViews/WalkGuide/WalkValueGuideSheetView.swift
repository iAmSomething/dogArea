import SwiftUI

struct WalkValueGuideSheetView: View {
    private enum SheetStep {
        case understanding
        case preferences
    }

    let presentation: WalkValueGuidePresentation
    let onClose: () -> Void
    let onSkipWithSafeDefaults: () -> Void
    let onApplyPreferences: (String, Bool) -> Void

    @State private var step: SheetStep = .understanding
    @State private var selectedPointRecordModeRawValue: String

    /// 첫 산책 가이드 시트의 초기 상태와 콜백을 구성합니다.
    /// - Parameters:
    ///   - presentation: 현재 시트가 렌더링할 가이드 프레젠테이션입니다.
    ///   - onClose: 사용자가 시트를 단순히 닫을 때 실행할 동작입니다.
    ///   - onSkipWithSafeDefaults: Step2를 스킵하고 안전 기본값을 적용할 때 실행할 동작입니다.
    ///   - onApplyPreferences: Step2 선택값을 저장할 때 실행할 동작입니다.
    init(
        presentation: WalkValueGuidePresentation,
        onClose: @escaping () -> Void,
        onSkipWithSafeDefaults: @escaping () -> Void,
        onApplyPreferences: @escaping (String, Bool) -> Void
    ) {
        self.presentation = presentation
        self.onClose = onClose
        self.onSkipWithSafeDefaults = onSkipWithSafeDefaults
        self.onApplyPreferences = onApplyPreferences
        _selectedPointRecordModeRawValue = State(initialValue: presentation.defaultPointRecordModeRawValue)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    headerSection
                    stepProgressSection
                    switch step {
                    case .understanding:
                        understandingSection
                        understandingCTASection
                    case .preferences:
                        preferencesSection
                        preferencesCTASection
                    }
                    revisitSection
                }
                .padding(16)
            }
            .navigationTitle("첫 산책 가이드")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기", action: onClose)
                        .accessibilityIdentifier("map.walk.guide.close")
                }
            }
            .accessibilityIdentifier("map.walk.guide.sheet")
        }
    }

    /// 가이드 상단의 맥락/제목/부제목 섹션을 렌더링합니다.
    /// - Returns: 시트 목적을 빠르게 전달하는 헤더 뷰입니다.
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(presentation.badgeText)
                .font(.appFont(for: .SemiBold, size: 11))
                .foregroundStyle(Color.appInk)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.appYellowPale.opacity(0.9))
                .clipShape(Capsule())
                .accessibilityIdentifier("map.walk.guide.context")

            Text(presentation.title)
                .font(.appFont(for: .ExtraBold, size: 24))
                .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))

            Text(presentation.subtitle)
                .font(.appFont(for: .Regular, size: 14))
                .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// 현재 Step 위치를 시각적으로 보여줍니다.
    /// - Returns: Step1/Step2 진행 상황 뷰입니다.
    private var stepProgressSection: some View {
        HStack(spacing: 8) {
            stepPill(title: "1. 첫 산책 이해", isActive: step == .understanding, identifier: "map.walk.guide.step.understanding")
            stepPill(title: "2. 핵심 설정", isActive: step == .preferences, identifier: "map.walk.guide.step.preferences")
        }
    }

    /// Step 진행 상태 pill을 렌더링합니다.
    /// - Parameters:
    ///   - title: 표시할 step 제목입니다.
    ///   - isActive: 현재 활성 step 여부입니다.
    ///   - identifier: 접근성 식별자입니다.
    /// - Returns: 활성/비활성 시각 상태가 반영된 pill 뷰입니다.
    private func stepPill(title: String, isActive: Bool, identifier: String) -> some View {
        Text(title)
            .font(.appFont(for: .SemiBold, size: 11))
            .foregroundStyle(isActive ? Color.appInk : Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isActive ? Color.appYellowPale.opacity(0.9) : Color.appDynamicHex(light: 0xF1F5F9, dark: 0x334155))
            .clipShape(Capsule())
            .accessibilityIdentifier(identifier)
    }

    /// Step1의 이해 카드 4장을 렌더링합니다.
    /// - Returns: 기록, 영역, 시즌, 미션 카드 섹션입니다.
    private var understandingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(presentation.understandingCards) { card in
                VStack(alignment: .leading, spacing: 6) {
                    Text(card.badgeText)
                        .font(.appFont(for: .SemiBold, size: 11))
                        .foregroundStyle(Color.appInk)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.appYellowPale.opacity(0.9))
                        .clipShape(Capsule())
                    Text(card.title)
                        .font(.appFont(for: .SemiBold, size: 14))
                        .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
                        .accessibilityIdentifier("map.walk.guide.card.\(card.id)")
                    Text(card.body)
                        .font(.appFont(for: .Regular, size: 12))
                        .foregroundStyle(Color.appDynamicHex(light: 0x475569, dark: 0xCBD5E1))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.appDynamicHex(light: 0xFFFFFF, dark: 0x1E293B))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.appDynamicHex(light: 0xE2E8F0, dark: 0x334155), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(card.badgeText) \(card.title) \(card.body)")
                .accessibilityIdentifier("map.walk.guide.card.\(card.id)")
            }
        }
    }

    /// Step1에서 Step2 이동/나중에 보기 CTA를 렌더링합니다.
    /// - Returns: Step1 CTA 섹션입니다.
    private var understandingCTASection: some View {
        VStack(spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    step = .preferences
                }
            } label: {
                Text("이해했어요")
                    .font(.appFont(for: .SemiBold, size: 14))
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(Color.appInk)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("map.walk.guide.next")

            Button("나중에 다시 보기", action: onClose)
                .font(.appFont(for: .SemiBold, size: 13))
                .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
                .frame(maxWidth: .infinity, minHeight: 44)
                .accessibilityIdentifier("map.walk.guide.defer")
        }
    }

    /// Step2에서 기록 방식과 공유 기본값 안내를 렌더링합니다.
    /// - Returns: 핵심 설정 선택 섹션입니다.
    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(presentation.stepTwoTitle)
                    .font(.appFont(for: .ExtraBold, size: 22))
                    .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
                Text(presentation.stepTwoSubtitle)
                    .font(.appFont(for: .Regular, size: 13))
                    .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("포인트 기록 방식")
                    .font(.appFont(for: .SemiBold, size: 15))
                    .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
                ForEach(presentation.recordModeOptions) { option in
                    recordModeOptionButton(option)
                }
                Text(presentation.recordModeFootnote)
                    .font(.appFont(for: .Regular, size: 11))
                    .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(presentation.sharingDefaultTitle)
                    .font(.appFont(for: .SemiBold, size: 15))
                    .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
                Text(presentation.sharingDefaultBody)
                    .font(.appFont(for: .Regular, size: 12))
                    .foregroundStyle(Color.appDynamicHex(light: 0x475569, dark: 0xCBD5E1))
                    .fixedSize(horizontal: false, vertical: true)
                Text(presentation.sharingDefaultFootnote)
                    .font(.appFont(for: .Regular, size: 11))
                    .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.appDynamicHex(light: 0xFFF7EB, dark: 0x2B2116))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .accessibilityIdentifier("map.walk.guide.sharingDefault")
        }
    }

    /// Step2의 기록 방식 선택 버튼을 렌더링합니다.
    /// - Parameter option: 현재 렌더링할 기록 방식 옵션입니다.
    /// - Returns: 선택 상태가 반영된 기록 방식 버튼 뷰입니다.
    private func recordModeOptionButton(_ option: WalkValueGuideRecordModeOptionPresentation) -> some View {
        let isSelected = selectedPointRecordModeRawValue == option.id
        return Button {
            selectedPointRecordModeRawValue = option.id
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.appYellow : Color.appDynamicHex(light: 0x94A3B8, dark: 0xCBD5E1))
                VStack(alignment: .leading, spacing: 4) {
                    Text(option.title)
                        .font(.appFont(for: .SemiBold, size: 13))
                        .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
                    Text(option.body)
                        .font(.appFont(for: .Regular, size: 12))
                        .foregroundStyle(Color.appDynamicHex(light: 0x475569, dark: 0xCBD5E1))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Color.appDynamicHex(light: 0xFFF7EB, dark: 0x2B2116) : Color.appDynamicHex(light: 0xFFFFFF, dark: 0x1E293B))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? Color.appYellow.opacity(0.7) : Color.appDynamicHex(light: 0xE2E8F0, dark: 0x334155), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("map.walk.guide.recordMode.\(option.id)")
    }

    /// Step2의 저장/스킵 CTA를 렌더링합니다.
    /// - Returns: 핵심 설정 저장 CTA 섹션입니다.
    private var preferencesCTASection: some View {
        VStack(spacing: 10) {
            Button {
                onApplyPreferences(selectedPointRecordModeRawValue, false)
            } label: {
                Text("이 설정으로 시작할게요")
                    .font(.appFont(for: .SemiBold, size: 14))
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(Color.appInk)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("map.walk.guide.apply")

            Button("기본값으로 넘어가기", action: onSkipWithSafeDefaults)
                .font(.appFont(for: .SemiBold, size: 13))
                .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
                .frame(maxWidth: .infinity, minHeight: 44)
                .accessibilityIdentifier("map.walk.guide.skip")
        }
    }

    /// 가이드 재진입 경로를 안내합니다.
    /// - Returns: 지도/설정 재진입 경로를 설명하는 footer 문구입니다.
    private var revisitSection: some View {
        Text(presentation.revisitLine)
            .font(.appFont(for: .Regular, size: 12))
            .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("map.walk.guide.revisit")
    }
}
