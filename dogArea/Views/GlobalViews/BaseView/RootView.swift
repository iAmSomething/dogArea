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
    @EnvironmentObject var myAlert: CustomAlertViewModel
    @State private var selectedTab = 2
    @State private var tabbarHidden = false
    @ObservedObject var tabStatus = TabAppear.shared
    private var homeView = HomeView()
    private var walkListView: WalkListView = WalkListView()
    private var mapView = MapView()
    private var textToImageView = TextToImageView()
    private var notificationCenterView = NotificationCenterView()
    var body: some View {
        VStack(spacing: 0) {
            if self.selectedTab == 0 {
                NavigationView {
                    homeView.frame(maxWidth: .infinity,maxHeight: .infinity)
                        .navigationBarHidden(selectedTab == 0)
                }
            }
            else if self.selectedTab == 1 {
                NavigationView {
                    walkListView.frame(maxWidth: .infinity,maxHeight: .infinity)
                        .navigationBarHidden(selectedTab == 1)
                }
            }
            else if self.selectedTab == 2 {
                NavigationView {
                    mapView
                        .navigationBarHidden(selectedTab == 2)
                }
            }
            else if self.selectedTab == 3 {
                NavigationView {
                    textToImageView.frame(maxWidth: .infinity,maxHeight: .infinity)
                        .navigationBarHidden(selectedTab == 3)
                }
            }
            else if self.selectedTab == 4 {
                NavigationView {
                    notificationCenterView.frame(maxWidth: .infinity,maxHeight: .infinity)
                        .navigationBarHidden(selectedTab == 4)
                }
            }
            if tabStatus.isTabAppear {
                CustomTabBar(selectedTab: $selectedTab)
            }
        }.edgesIgnoringSafeArea(.all)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

    }
}

private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .medium
    return formatter
}()
