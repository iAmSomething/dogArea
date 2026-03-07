//
//  CustomAlertView.swift
//  dogArea
//
//  Created by 김태훈 on 10/16/23.
//

import Foundation
import SwiftUI

private enum CustomAlertLayoutMetrics {
    static let maxWidth: CGFloat = 420
    static let horizontalPadding: CGFloat = 24
    static let surfacePadding: CGFloat = 20
    static let surfaceCornerRadius: CGFloat = 24
    static let buttonCornerRadius: CGFloat = 14
    static let sectionSpacing: CGFloat = 18
    static let actionSpacing: CGFloat = 10
    static let actionMinHeight: CGFloat = 52
    static let iconSize: CGFloat = 22
    static let iconContainerSize: CGFloat = 46
}

private enum CustomAlertPalette {
    static let overlay = Color.black.opacity(0.42)
    static let neutralSurface = Color.appDynamicHex(light: 0xFFFFFF, dark: 0x243244, alpha: 0.98)
    static let cautionSurface = Color.appDynamicHex(light: 0xFFF7E7, dark: 0x2E2618, alpha: 0.98)
    static let dangerSurface = Color.appDynamicHex(light: 0xFFF1F2, dark: 0x3B1D26, alpha: 0.98)
    static let neutralBorder = Color.appDynamicHex(light: 0xD8DEE7, dark: 0x475569, alpha: 0.92)
    static let cautionBorder = Color.appDynamicHex(light: 0xF59E0B, dark: 0xF59E0B, alpha: 0.42)
    static let dangerBorder = Color.appDynamicHex(light: 0xF97316, dark: 0xF97316, alpha: 0.42)
    static let primaryText = Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC)
    static let secondaryText = Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1)
    static let primaryActionBackground = Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC)
    static let primaryActionText = Color.appDynamicHex(light: 0xFFFFFF, dark: 0x0F172A)
    static let secondaryActionBackground = Color.appDynamicHex(light: 0xFFFFFF, dark: 0x334155, alpha: 0.92)
    static let secondaryActionBorder = Color.appDynamicHex(light: 0xCBD5E1, dark: 0x64748B, alpha: 0.88)
    static let destructiveActionBackground = Color.appDynamicHex(light: 0xFEE2E2, dark: 0x4C1D1D, alpha: 0.96)
    static let destructiveActionBorder = Color.appDynamicHex(light: 0xFCA5A5, dark: 0xF87171, alpha: 0.72)
    static let destructiveActionText = Color.appDynamicHex(light: 0xB42318, dark: 0xFECACA)
    static let cautionAccent = Color.appYellow
    static let dangerAccent = Color.appDynamicHex(light: 0xF97316, dark: 0xFB923C)
    static let neutralAccent = Color.appInk
}

private struct CustomAlertActionItem: Identifiable {
    let descriptor: AlertButtonDescriptor
    let handler: (() -> Void)?

    var id: String { descriptor.id }
}

struct CustomAlert: View {
    @Binding var presentAlert: Bool
    let alertModel: AlertModel
    var isShowVerticalButtons = false

    var leftButtonAction: (() -> Void)?
    var middleButtonAction: (() -> Void)?
    var rightButtonAction: (() -> Void)?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ZStack {
            CustomAlertPalette.overlay
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    guard alertModel.allowsBackdropDismiss else { return }
                    dismissAlert()
                }
                .accessibilityHidden(true)

            VStack(spacing: CustomAlertLayoutMetrics.sectionSpacing) {
                alertHeader
                if alertModel.messageStr().isEmpty == false {
                    alertMessage
                }
                actionContainer
            }
            .padding(CustomAlertLayoutMetrics.surfacePadding)
            .frame(maxWidth: CustomAlertLayoutMetrics.maxWidth)
            .background(surfaceBackground)
            .overlay(
                RoundedRectangle(cornerRadius: CustomAlertLayoutMetrics.surfaceCornerRadius, style: .continuous)
                    .stroke(surfaceBorder, lineWidth: 1)
            )
            .clipShape(
                RoundedRectangle(cornerRadius: CustomAlertLayoutMetrics.surfaceCornerRadius, style: .continuous)
            )
            .shadow(color: Color.black.opacity(0.14), radius: 22, x: 0, y: 12)
            .padding(.horizontal, CustomAlertLayoutMetrics.horizontalPadding)
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
            .accessibilityIdentifier("customAlert.surface")
        }
        .zIndex(2)
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
        .accessibilityIdentifier("customAlert.surface")
    }

    private var alertHeader: some View {
        HStack(alignment: .top, spacing: 14) {
            alertToneBadge

            VStack(alignment: .leading, spacing: 6) {
                if alertModel.titleStr().isEmpty == false {
                    Text(alertModel.titleStr())
                        .font(.appScaledFont(for: .SemiBold, size: 20, relativeTo: .title3))
                        .foregroundStyle(CustomAlertPalette.primaryText)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 0)
        }
    }

    private var alertToneBadge: some View {
        Image(systemName: toneIconName)
            .font(.system(size: CustomAlertLayoutMetrics.iconSize, weight: .semibold))
            .foregroundStyle(toneAccentColor)
            .frame(
                width: CustomAlertLayoutMetrics.iconContainerSize,
                height: CustomAlertLayoutMetrics.iconContainerSize
            )
            .background(toneAccentColor.opacity(0.12))
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(toneAccentColor.opacity(0.22), lineWidth: 1)
            )
            .accessibilityHidden(true)
    }

    private var alertMessage: some View {
        ScrollView(showsIndicators: false) {
            Text(alertModel.messageStr())
                .font(.appScaledFont(for: .Regular, size: 14, relativeTo: .body))
                .foregroundStyle(CustomAlertPalette.secondaryText)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxHeight: 180)
    }

    @ViewBuilder
    private var actionContainer: some View {
        let items = actionItems
        if resolvedButtonLayout == .horizontal, items.count == 2 {
            HStack(spacing: CustomAlertLayoutMetrics.actionSpacing) {
                ForEach(items) { item in
                    actionButton(for: item)
                }
            }
        } else {
            VStack(spacing: CustomAlertLayoutMetrics.actionSpacing) {
                ForEach(items) { item in
                    actionButton(for: item)
                }
            }
        }
    }

    /// 현재 알림 모델과 버튼 액션을 화면 렌더링용 action item 배열로 조합합니다.
    /// - Returns: 버튼 의미와 동작 핸들러를 모두 포함한 action item 배열입니다.
    private var actionItems: [CustomAlertActionItem] {
        let handlers = [leftButtonAction, middleButtonAction, rightButtonAction]
        return zip(alertModel.buttonDescriptors, handlers).map { descriptor, handler in
            CustomAlertActionItem(descriptor: descriptor, handler: handler)
        }
    }

    /// 현재 런타임 조건에 맞는 버튼 레이아웃 방향을 계산합니다.
    /// - Returns: 수평 또는 수직 버튼 레이아웃 방향입니다.
    private var resolvedButtonLayout: AlertButtonLayout {
        if isShowVerticalButtons {
            return .vertical
        }

        switch alertModel.preferredButtonLayout {
        case .horizontal, .vertical:
            return alertModel.preferredButtonLayout
        case .adaptive:
            let titles = alertModel.buttonDescriptors.map(\.title)
            let hasLongCopy = titles.contains { $0.count >= 7 }
            let shouldStack = dynamicTypeSize.isAccessibilitySize || hasLongCopy
            return shouldStack ? .vertical : .horizontal
        }
    }

    /// 지정한 액션 item의 의미 계층에 맞는 버튼을 생성합니다.
    /// - Parameter item: 렌더링할 action item입니다.
    /// - Returns: alert action 버튼 뷰입니다.
    @ViewBuilder
    private func actionButton(for item: CustomAlertActionItem) -> some View {
        Button(role: item.descriptor.role == .destructive ? .destructive : nil) {
            performAction(item.handler)
        } label: {
            Text(item.descriptor.title)
                .font(.appScaledFont(for: .SemiBold, size: 15, relativeTo: .body))
                .foregroundStyle(actionTextColor(for: item.descriptor.role))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: CustomAlertLayoutMetrics.actionMinHeight)
                .padding(.horizontal, 14)
                .padding(.vertical, 4)
                .background(actionBackground(for: item.descriptor.role))
                .overlay(
                    RoundedRectangle(
                        cornerRadius: CustomAlertLayoutMetrics.buttonCornerRadius,
                        style: .continuous
                    )
                    .stroke(actionBorder(for: item.descriptor.role), lineWidth: 1)
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: CustomAlertLayoutMetrics.buttonCornerRadius,
                        style: .continuous
                    )
                )
        }
        .buttonStyle(.plain)
        .contentShape(
            RoundedRectangle(
                cornerRadius: CustomAlertLayoutMetrics.buttonCornerRadius,
                style: .continuous
            )
        )
        .accessibilityIdentifier(accessibilityIdentifier(for: item.descriptor.role))
        .accessibilityLabel(item.descriptor.title)
    }

    /// 알림 액션을 실행한 뒤 알림을 닫습니다.
    /// - Parameter action: 버튼 탭 후 실행할 후속 액션입니다.
    private func performAction(_ action: (() -> Void)?) {
        withAnimation(.easeInOut(duration: 0.18)) {
            action?()
            dismissAlert()
        }
    }

    /// 현재 알림을 화면에서 닫습니다.
    private func dismissAlert() {
        presentAlert = false
    }

    /// 의미 계층별 접근성 식별자를 반환합니다.
    /// - Parameter role: 접근성 식별자를 계산할 버튼 의미 계층입니다.
    /// - Returns: UI 테스트에서 사용할 접근성 식별자 문자열입니다.
    private func accessibilityIdentifier(for role: AlertActionSemanticRole) -> String {
        switch role {
        case .primary:
            return "customAlert.action.primary"
        case .secondary:
            return "customAlert.action.secondary"
        case .destructive:
            return "customAlert.action.destructive"
        }
    }

    private var surfaceBackground: Color {
        switch alertModel.surfaceTone {
        case .neutral:
            return CustomAlertPalette.neutralSurface
        case .caution:
            return CustomAlertPalette.cautionSurface
        case .danger:
            return CustomAlertPalette.dangerSurface
        }
    }

    private var surfaceBorder: Color {
        switch alertModel.surfaceTone {
        case .neutral:
            return CustomAlertPalette.neutralBorder
        case .caution:
            return CustomAlertPalette.cautionBorder
        case .danger:
            return CustomAlertPalette.dangerBorder
        }
    }

    private var toneAccentColor: Color {
        switch alertModel.surfaceTone {
        case .neutral:
            return CustomAlertPalette.neutralAccent
        case .caution:
            return CustomAlertPalette.cautionAccent
        case .danger:
            return CustomAlertPalette.dangerAccent
        }
    }

    private var toneIconName: String {
        switch alertModel.surfaceTone {
        case .neutral:
            return "questionmark.circle.fill"
        case .caution:
            return "exclamationmark.circle.fill"
        case .danger:
            return "exclamationmark.triangle.fill"
        }
    }

    /// 버튼 의미 계층에 대응하는 배경색을 반환합니다.
    /// - Parameter role: 현재 렌더링 중인 버튼 의미 계층입니다.
    /// - Returns: 버튼 카드에 적용할 배경색입니다.
    private func actionBackground(for role: AlertActionSemanticRole) -> Color {
        switch role {
        case .primary:
            return CustomAlertPalette.primaryActionBackground
        case .secondary:
            return CustomAlertPalette.secondaryActionBackground
        case .destructive:
            return CustomAlertPalette.destructiveActionBackground
        }
    }

    /// 버튼 의미 계층에 대응하는 테두리색을 반환합니다.
    /// - Parameter role: 현재 렌더링 중인 버튼 의미 계층입니다.
    /// - Returns: 버튼 카드 외곽선에 적용할 색상입니다.
    private func actionBorder(for role: AlertActionSemanticRole) -> Color {
        switch role {
        case .primary:
            return CustomAlertPalette.primaryActionBackground.opacity(0.16)
        case .secondary:
            return CustomAlertPalette.secondaryActionBorder
        case .destructive:
            return CustomAlertPalette.destructiveActionBorder
        }
    }

    /// 버튼 의미 계층에 대응하는 전경 텍스트색을 반환합니다.
    /// - Parameter role: 현재 렌더링 중인 버튼 의미 계층입니다.
    /// - Returns: 버튼 라벨에 적용할 텍스트 색상입니다.
    private func actionTextColor(for role: AlertActionSemanticRole) -> Color {
        switch role {
        case .primary:
            return CustomAlertPalette.primaryActionText
        case .secondary:
            return CustomAlertPalette.primaryText
        case .destructive:
            return CustomAlertPalette.destructiveActionText
        }
    }
}
