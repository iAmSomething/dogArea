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
        ZStack {
            Color.gray.opacity(0.8)
                .frame(maxWidth: .infinity)
                .frame(height: 30)
                .padding(.horizontal, 50)
            Text(message)
                .foregroundColor(.white)
                .font(.appFont(for: .Light, size: 20))
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity)
                .frame(height: 30)
                .padding(.horizontal, 50)
                
        }
        .cornerRadius(10)
    }
}

#Preview {
    SimpleMessageView(message: "저장이 완료되었습니다.")
}
