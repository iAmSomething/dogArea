//
//  LoadingView.swift
//  dogArea
//
//  Created by 김태훈 on 11/20/23.
//

import SwiftUI

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 10) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(Color.appInk)
                .scaleEffect(1.2)
            Text("불러오는 중...")
                .font(.appFont(for: .Medium, size: 13))
                .foregroundStyle(Color.appInk)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.appSurface.opacity(0.98))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.appTextLightGray.opacity(0.5), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.1), radius: 14, x: 0, y: 6)
        .ignoresSafeArea()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.opacity(0.15))
    }
}

#Preview {
    LoadingView()
}
