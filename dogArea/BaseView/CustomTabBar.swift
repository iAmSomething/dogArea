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
    HStack(spacing:30){
      // Home Button
      Label("홈",systemImage: self.selectedTab==0 ? "house.fill" : "house")
        .onTapGesture {self.selectedTab=0}
        .labelStyle(TabStyle())
        .frame(maxWidth: .infinity)
      
      // Ranking Button
      Label("랭킹",systemImage: self.selectedTab==1 ? "star.fill" : "star")
        .onTapGesture {self.selectedTab=1}
        .labelStyle(TabStyle())
        .frame(maxWidth: .infinity)
      
      // Center Big Map Button
      CircleButton(iconName:"map.fill", action:{
        self.selectedTab=2
      })
      .frame(maxWidth: .infinity)
      
      // Ranking button
      Label("프로필",systemImage: self.selectedTab==3 ? "gearshape.fill" : "gearshape")
        .onTapGesture {self.selectedTab=3}
        .labelStyle(TabStyle())
        .frame(maxWidth: .infinity)
      
      // Settings button
      Label("설정",systemImage: self.selectedTab==4 ? "gearshape.fill" : "gearshape")
        .onTapGesture {self.selectedTab=4}
        .labelStyle(TabStyle())
        .frame(maxWidth: .infinity)
      
    }.padding(.horizontal,30)
      .padding(.vertical,10)
      .background(Color.white.edgesIgnoringSafeArea(.bottom))
      .border(Color.black, width: 0.3)
  }
}


struct CircleButton : View{
  let iconName : String
  let action : ()->Void
  
  var body:some View{
    ZStack{
      Circle().foregroundColor(Color.blue).frame(width :60,height :60)
        .shadow(radius :5)
      
      VStack{
        Image(systemName:self.iconName).resizable().frame(width :25,height :25).foregroundColor(Color.white)
        Text("지도").font(.system(size:12)).foregroundColor(Color.white)
      }
    }.onTapGesture(perform:self.action)
  }
}
