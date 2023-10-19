//
//  RootView.swift
//  dogArea
//
//  Created by 김태훈 on 10/19/23.
//

import Foundation
import SwiftUI

struct RootView: View {
  @Environment(\.managedObjectContext) private var viewContext
  @StateObject var myAlert: CustomAlertViewModel = .init()
  @State private var selectedTab = 2
  var body: some View {
    GeometryReader { geometry in
      VStack(spacing: 0) {
        if self.selectedTab == 0 { HomeView() }
        else if self.selectedTab == 1 { RankingView() }
        else if self.selectedTab == 2 { MapView() }
        else if self.selectedTab == 3 { ProfileSettingsView() }
        else if self.selectedTab == 4 { NotificationCenterView() }
        
        CustomTabBar(selectedTab: $selectedTab)
      }.edgesIgnoringSafeArea(.all)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .gesture(
          DragGesture(minimumDistance: geometry.size.height / 10, coordinateSpace: .global)
            .onEnded({ value in
              if selectedTab != 2{
                // Swipe up to go to the next tab
                if value.startLocation.y > value.predictedEndLocation.y {
                  selectedTab = (selectedTab + 1) % 5
                }
                
                // Swipe down to go to the previous tab
                if value.startLocation.y < value.predictedEndLocation.y {
                  selectedTab = (selectedTab - 1 + 5) % 5
                }
              }
            })
        )
    }
  }
}

private let itemFormatter: DateFormatter = {
  let formatter = DateFormatter()
  formatter.dateStyle = .short
  formatter.timeStyle = .medium
  return formatter
}()
