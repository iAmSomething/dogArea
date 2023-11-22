//
//  WalkListCell.swift
//  dogArea
//
//  Created by 김태훈 on 11/8/23.
//

import SwiftUI

struct WalkListCell: View {
  @State var walkData: WalkDataModel
    @Environment(\.colorScheme) var scheme
    var body: some View {
      HStack {
        VStack(alignment: .leading) {
          HStack {
            Text(walkData.createdAt.createdAtTimeYYMMDD)
              .font(.regular14)
              .padding(.leading, 10)
              .foregroundStyle(Color.appColor(type: .appTextBlack, scheme: scheme))
            Spacer()
          }
            ScrollView(.horizontal) {
                HStack {
                  ForEach(0..<self.walkData.locations.count, id: \.self){ _ in
                      PositionMarkerView()
                          .frame(width: 25, height: 25)
                  }
              }
          }.padding(.leading, 10)
            
        }.frame(maxWidth: .infinity)
          ThumnailImageView(image: walkData.image)
      }.frame(height: 80)
    }
}


struct ThumnailImageView: View {
  @State var image: UIImage?
  var body: some View {
    Rectangle()
      .foregroundColor(.clear)
      .frame(width: 60, height: 60)
      .background(
        Image(uiImage: image ?? .emptyImage)
          .resizable()
          .aspectRatio(contentMode: .fit)
          .frame(width: 60, height: 60)
          .clipped()
      )
      .cornerRadius(10)
      .overlay(
        RoundedRectangle(cornerRadius: 10)
          .inset(by: 0.5)
          .stroke(Color(red: 0.85, green: 0.85, blue: 0.85), lineWidth: 1)
      )
    
      .padding(.trailing, 10)
  }
}
