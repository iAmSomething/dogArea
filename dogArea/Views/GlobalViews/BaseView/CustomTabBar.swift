//
//  CustomTabBar.swift
//  dogArea
//
//  Created by 김태훈 on 10/19/23.
//

import Foundation
import SwiftUI

struct CustomTabBar: View {
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
        .padding(.top, 10)
        .padding(.bottom, 14)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.appSurface.opacity(0.97))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.appTextLightGray.opacity(0.55), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.08), radius: 16, x: 0, y: -4)
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
                    .font(.system(size: 20, weight: .semibold))
                    .frame(width: 28, height: 24)
                    .foregroundStyle(isSelected ? Color.appInk : Color.appTextDarkGray)
                Text(item.title)
                    .font(.appFont(for: .Medium, size: 12))
                    .foregroundStyle(isSelected ? Color.appInk : Color.appTextDarkGray)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(isSelected ? Color.appYellowPale : .clear)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("tab.\(item.id)")
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
                    .font(.appFont(for: .SemiBold, size: 12))
            }
            .foregroundStyle(isSelected ? Color.appInk : Color.appTextDarkGray)
            .frame(width: 68, height: 68)
            .background(
                Circle()
                    .fill(isSelected ? Color.appYellow : Color.appTextLightGray.opacity(0.55))
            )
            .overlay(
                Circle()
                    .stroke(Color.appSurface, lineWidth: 4)
            )
            .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 6)
            .offset(y: -8)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("tab.2")
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
