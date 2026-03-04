//
//  CustomTabBar.swift
//  dogArea
//
//  Created by 김태훈 on 10/19/23.
//

import Foundation
import SwiftUI

struct CustomTabBar: View {
    static let reservedContentHeight: CGFloat = 124

    @Binding var selectedTab: Int

    private let sideItems: [TabVisualItem] = [
        .init(id: 0, title: "홈", icon: "house"),
        .init(id: 1, title: "산책 목록", icon: "list.bullet"),
        .init(id: 3, title: "라이벌", icon: "person.2"),
        .init(id: 4, title: "설정", icon: "gearshape")
    ]

    var body: some View {
        HStack(spacing: 8) {
            tabItemButton(for: sideItems[0])
            tabItemButton(for: sideItems[1])

            centerMapButton

            tabItemButton(for: sideItems[2])
            tabItemButton(for: sideItems[3])
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color.appDynamicHex(light: 0xFFFFFF, dark: 0x1E293B, alpha: 0.98))
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(Color.appDynamicHex(light: 0xE2E8F0, dark: 0x334155), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.09), radius: 18, x: 0, y: -6)
        )
        .padding(.horizontal, 10)
        .padding(.bottom, 6)
    }

    /// 일반 탭 아이템 버튼을 렌더링합니다.
    private func tabItemButton(for item: TabVisualItem) -> some View {
        let isSelected = selectedTab == item.id
        return Button {
            selectedTab = item.id
        } label: {
            VStack(spacing: 4) {
                Image(systemName: isSelected ? "\(item.icon).fill" : item.icon)
                    .font(.system(size: 19, weight: .semibold))
                    .frame(width: 28, height: 22)
                    .foregroundStyle(
                        isSelected
                        ? Color.appDynamicHex(light: 0xF59E0B, dark: 0xEAB308)
                        : Color.appDynamicHex(light: 0x94A3B8, dark: 0x64748B)
                    )
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
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .accessibilityIdentifier("tab.\(item.id)")
        .accessibilityLabel(item.title)
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
    let icon: String
}

#Preview {
    CustomTabBar(selectedTab: .constant(2))
}
