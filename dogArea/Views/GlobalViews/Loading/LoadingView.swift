//
//  LoadingView.swift
//  dogArea
//
//  Created by 김태훈 on 11/20/23.
//

import SwiftUI

struct LoadingView: View {
    var body: some View {
        VStack {
                ProgressView() // 로딩 애니메이션 표시
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(2) // 애니메이션 크기 조정
        }.ignoresSafeArea()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.opacity(0.2))
    }
}

#Preview {
    LoadingView()
}
