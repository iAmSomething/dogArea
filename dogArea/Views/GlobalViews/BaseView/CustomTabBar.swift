//
//  CustomTabBar.swift
//  dogArea
//
//  Created by 김태훈 on 10/19/23.
//

import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct CustomTabBar: View {
    @Binding var selectedTab: Int

    private let sideItems: [TabVisualItem] = [
        .init(id: 0, title: "홈", defaultSymbolName: "house", selectedSymbolName: "house.fill"),
        .init(id: 1, title: "산책 기록", defaultSymbolName: "list.bullet", selectedSymbolName: "list.bullet.circle.fill"),
        .init(id: 3, title: "라이벌", defaultSymbolName: "person.2", selectedSymbolName: "person.2.fill"),
        .init(id: 4, title: "설정", defaultSymbolName: "gearshape", selectedSymbolName: "gearshape.fill")
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            bottomBackdrop

            HStack(spacing: 8) {
                tabItemButton(for: sideItems[0])
                tabItemButton(for: sideItems[1])

                centerMapButton

                tabItemButton(for: sideItems[2])
                tabItemButton(for: sideItems[3])
            }
            .padding(.horizontal, 12)
            .padding(.top, 6)
            .padding(.bottom, 10)
            .padding(.horizontal, 10)
            .padding(.bottom, 6)
        }
        .overlay {
            if ProcessInfo.processInfo.arguments.contains("-UITest.FeatureRegression") {
                Color.clear
                    .allowsHitTesting(false)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("하단 탭바 영역")
                    .accessibilityIdentifier("tabBar.surface")
            }
        }
        .overlay(alignment: .bottom) {
            if ProcessInfo.processInfo.arguments.contains("-UITest.FeatureRegression") {
                Color.clear
                    .frame(height: 76)
                    .allowsHitTesting(false)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("하단 탭바 시각 영역")
                    .accessibilityIdentifier("tabBar.visualBand")
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: AppTabLayoutMetrics.defaultTabBarReservedHeight, alignment: .bottom)
    }

    private var bottomBackdrop: some View {
        LinearGradient(
            colors: [
                Color.appDynamicHex(light: 0xFFFFFF, dark: 0x020617, alpha: 0.0),
                Color.appDynamicHex(light: 0xFFFFFF, dark: 0x020617, alpha: 0.86)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(maxWidth: .infinity)
        .frame(height: 76)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.appDynamicHex(light: 0xE2E8F0, dark: 0x334155, alpha: 0.72))
                .frame(height: 1)
                .padding(.horizontal, 18)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// 일반 탭 아이템 버튼을 렌더링합니다.
    private func tabItemButton(for item: TabVisualItem) -> some View {
        let isSelected = selectedTab == item.id
        let resolvedSymbolName = item.resolvedSymbolName(isSelected: isSelected)
        return Button {
            selectedTab = item.id
        } label: {
            VStack(spacing: 4) {
                Image(systemName: resolvedSymbolName)
                    .font(.system(size: 19, weight: .semibold))
                    .frame(width: 28, height: 22)
                    .foregroundStyle(
                        isSelected
                        ? Color.appDynamicHex(light: 0xF59E0B, dark: 0xEAB308)
                        : Color.appDynamicHex(light: 0x94A3B8, dark: 0x64748B)
                    )
                    .accessibilityHidden(true)
                Text(item.title)
                    .font(.appScaledFont(for: .SemiBold, size: 11, relativeTo: .caption))
                    .foregroundStyle(
                        isSelected
                        ? Color.appDynamicHex(light: 0xF59E0B, dark: 0xEAB308)
                        : Color.appDynamicHex(light: 0x94A3B8, dark: 0x64748B)
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .background {
                if isSelected {
                    Capsule(style: .continuous)
                        .fill(Color.appDynamicHex(light: 0xFFFFFF, dark: 0x1E293B, alpha: 0.92))
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(Color.appDynamicHex(light: 0xE2E8F0, dark: 0x475569), lineWidth: 1)
                        )
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .accessibilityIdentifier("tab.\(item.id)")
        .accessibilityLabel(item.title)
        .accessibilityValue(isSelected ? "selected:\(resolvedSymbolName)" : "default:\(resolvedSymbolName)")
    }

    /// 중앙 지도 액션을 강조한 탭 버튼입니다.
    private var centerMapButton: some View {
        let isSelected = selectedTab == 2
        return Button {
            selectedTab = 2
        } label: {
            VStack(spacing: 3) {
                Image(systemName: isSelected ? "map.fill" : "map")
                    .font(.system(size: 21, weight: .bold))
                Text("지도")
                    .font(.appScaledFont(for: .SemiBold, size: 11, relativeTo: .caption))
            }
            .foregroundStyle(
                isSelected
                ? Color.appDynamicHex(light: 0xFFFFFF, dark: 0x0F172A)
                : Color.appDynamicHex(light: 0x334155, dark: 0xCBD5E1)
            )
            .frame(width: 72, height: 72)
            .background(
                Circle()
                    .fill(
                        isSelected
                        ? Color.appDynamicHex(light: 0xF59E0B, dark: 0xEAB308)
                        : Color.appDynamicHex(light: 0xE2E8F0, dark: 0x334155)
                    )
            )
            .overlay(
                Circle()
                    .stroke(Color.appDynamicHex(light: 0xFFFFFF, dark: 0x0F172A), lineWidth: 4)
            )
            .shadow(color: Color.black.opacity(0.14), radius: 14, x: 0, y: 8)
            .offset(y: -14)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 52)
        .accessibilityIdentifier("tab.2")
        .accessibilityLabel("지도")
    }
}

private struct TabVisualItem: Equatable {
    let id: Int
    let title: String
    let defaultSymbolName: String
    let selectedSymbolName: String

    /// 현재 선택 상태에 맞는 SF Symbol 이름을 반환합니다.
    /// - Parameter isSelected: 탭이 현재 선택 상태인지 여부입니다.
    /// - Returns: 현재 상태에서 실제로 렌더링에 사용할 유효한 SF Symbol 이름입니다.
    func resolvedSymbolName(isSelected: Bool) -> String {
        guard isSelected else { return defaultSymbolName }
        return Self.preferredSymbolName(primary: selectedSymbolName, fallback: defaultSymbolName)
    }

    /// 우선 사용할 심볼이 유효한지 확인하고, 실패하면 fallback 심볼을 반환합니다.
    /// - Parameters:
    ///   - primary: 선택 상태에서 우선 사용할 심볼 이름입니다.
    ///   - fallback: 우선 심볼을 사용할 수 없을 때 대체할 기본 심볼 이름입니다.
    /// - Returns: 현재 런타임에서 렌더링 가능한 안전한 SF Symbol 이름입니다.
    private static func preferredSymbolName(primary: String, fallback: String) -> String {
#if canImport(UIKit)
        return UIImage(systemName: primary) == nil ? fallback : primary
#else
        return primary
#endif
    }
}

#Preview {
    CustomTabBar(selectedTab: .constant(2))
}
