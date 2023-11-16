//
//  SelectedPolygonCell.swift
//  dogArea
//
//  Created by 김태훈 on 11/16/23.
//

import SwiftUI

struct SelectedPolygonCell: View {
    @State var walkData: WalkDataModel
      var body: some View {
        HStack {
          VStack(alignment: .leading) {
              Text("산책 정보")
                  .padding(.leading, 10)
                  .font(.appFont(for: .SemiBold, size: 15))
                  .foregroundStyle(Color.black)
            HStack {
              Text(walkData.createdAt.createdAtTimeYYMMDD)
                .font(.regular14)
                .padding(.leading, 10)
                .foregroundStyle(Color.black)
              Spacer()
            }
          }.frame(maxWidth: .infinity)
            ThumnailImageView(image: walkData.image)
        }.frame(height: 80)
      }
}
