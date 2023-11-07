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
    HStack(spacing:25){
      // Home Button
      Label("홈",systemImage: self.selectedTab==0 ? "house.fill" : "house")
        .font(.regular14)
        .onTapGesture {self.selectedTab=0}
        .labelStyle(TabStyle())
        .frame(maxWidth: .infinity)
      
      // Ranking Button
      Label("랭킹",systemImage: self.selectedTab==1 ? "star.fill" : "star")
        .font(.regular14)
        .onTapGesture {self.selectedTab=1}
        .labelStyle(TabStyle())
        .frame(maxWidth: .infinity)
        
      
      // Center Big Map Button
      CircleButton(iconName:"map.fill",
                   isSelected: self.selectedTab == 2 ,
                   action:{
        self.selectedTab=2
      })
      .padding(.bottom, 20)
      .frame(maxWidth: .infinity)
      
      // Ranking button
      Label("이미지",systemImage: self.selectedTab==3 ? "bolt.circle.fill" : "bolt.circle")
        .font(.regular14)
        .onTapGesture {self.selectedTab=3}
        .labelStyle(TabStyle())
        .frame(maxWidth: .infinity)
      
      // Settings button
      Label("설정",systemImage: self.selectedTab==4 ? "gearshape.fill" : "gearshape")
        .font(.regular14)
        .onTapGesture {self.selectedTab=4}
        .labelStyle(TabStyle())
        .frame(maxWidth: .infinity)
      
    }.padding(.horizontal,30)
      .padding(.top,-5)
      .padding(.bottom, 20)
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
