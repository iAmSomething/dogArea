//
//  UnderLine.swift
//  dogArea
//
//  Created by 김태훈 on 11/13/23.
//

import SwiftUI

struct UnderLine: View {
    var body: some View {
        Rectangle()
            .foregroundColor(.clear)
            .frame(height: 1)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: [
                        Color.appTextLightGray.opacity(0.05),
                        Color.appTextLightGray.opacity(0.45),
                        Color.appTextLightGray.opacity(0.05)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .padding(.horizontal, 16)
    }
}

#Preview {
    UnderLine()
}
