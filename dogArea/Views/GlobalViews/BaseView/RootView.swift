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
    @StateObject var loading: LoadingViewModel = LoadingViewModel()
    @State private var selectedTab = 2
    @State private var tabbarHidden = false
    @StateObject var tabStatus = TabAppear.shared
    private var homeView: HomeView
    private var walkListView: WalkListView    
    private var mapView: MapView
    private var textToImageView: TextToImageView
    private var notificationCenterView: NotificationCenterView
    init() {
        self.homeView = HomeView()
        self.walkListView = WalkListView()
        self.mapView = MapView()
        self.textToImageView = TextToImageView()
        self.notificationCenterView = NotificationCenterView()
    }
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
                        .environmentObject(loading)
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
                    .frame(maxHeight: .infinity)
                    .border(Color.appTextDarkGray, width: 0.3)
                    .aspectRatio(contentMode: .fit)
            }
        }.edgesIgnoringSafeArea(.all)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(content: {
                if loading.phase == .loading {
                    LoadingView()
                }
            })

    }
}

private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .medium
    return formatter
}()
