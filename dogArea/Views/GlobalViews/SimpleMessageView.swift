//
//  SimpleMessageView.swift
//  dogArea
//
//  Created by 김태훈 on 11/10/23.
//

import SwiftUI

struct SimpleMessageView: View {
    let message: String
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 13, weight: .bold))
            Text(message)
                .font(.appFont(for: .Medium, size: 13))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .foregroundStyle(Color.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Color.appInk.opacity(0.9))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 4)
    }
}

#Preview {
    SimpleMessageView(message: "저장이 완료되었습니다.")
}
