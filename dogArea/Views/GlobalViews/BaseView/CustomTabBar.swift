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
  
  var body: some View {
    HStack{
      // Home Button
      TabButtonView(selectedTab: $selectedTab,
                    imageName: ("homeBtn","homeBtnGray"), tabId: 0,
                    titleName: "홈")
      
      // Ranking Button
      TabButtonView(selectedTab: $selectedTab,
                    imageName: ("listBtn","listBtnGray"),
                    tabId: 1,
                    titleName: "산책 목록")
      
      
      // Center Big Map Button
      CircleButton(iconName:"map.fill",
                   isSelected: self.selectedTab == 2 ,
                   action:{
        self.selectedTab=2
      })
      .frame(maxWidth: .infinity)
      
      // Ranking button
      TabButtonView(selectedTab: $selectedTab,
                    imageName: ("imageBtn","imageBtnGray"),
                    tabId: 3,
                    titleName: "이미지")
      
      // Settings button
      TabButtonView(selectedTab: $selectedTab,
                    imageName: ("settingBtn","settingBtnGray"),
                    tabId: 4,
                    titleName: "설정")
      
    }.padding(.horizontal,30)
      .padding(.vertical, 10)
      .padding(.bottom, 10)
      .background(Color.white.edgesIgnoringSafeArea(.bottom))
  }
}

#Preview {
  
  CustomTabBar(selectedTab: .constant(2))
}
struct CircleButton : View{
  let iconName : String
  let isSelected: Bool
  let action : ()->Void
  var body:some View{
    ZStack{
      if isSelected {
        Circle().foregroundColor(Color.appGreen).frame(width :70,height :70)
          .shadow(radius :5)
      }
      else {
        Circle().foregroundColor(Color.appTextLightGray).frame(width :70,height :70)
      }
      VStack{
        Image(systemName:self.iconName)
          .resizable()
          .frame(width :25,height :25)
          .foregroundColor(Color.appPinkYello)
        Text("지도").font(.regular14)
          .foregroundColor(isSelected ? Color.appPinkYello : Color.appTextDarkGray)
      }
    }.onTapGesture(perform:self.action)
  }
}

struct TabButtonView: View {
  @Binding var selectedTab: Int
  var imageName: (String, String)
  var tabId: Int
  var titleName: String
  var body: some View {
    Label(
      title: { Text(titleName) },
      icon: {
        Image(self.selectedTab==tabId ? imageName.0 : imageName.1)
          .resizable()
          .frame(width: 30, height: 30)
          .aspectRatio(contentMode: .fit)
      }
    ).padding(.horizontal, 5)
      .font(.regular12)
      .onTapGesture {selectedTab=tabId}
      .labelStyle(TabStyle())
      .frame(maxWidth: .infinity)
  }
}
