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
            .frame(height: 0.3)
            .frame(maxWidth: .infinity)
            .background(Color(red: 0.19, green: 0.19, blue: 0.19))
            .padding(.horizontal, 20)
    }
}

#Preview {
    UnderLine()
}
