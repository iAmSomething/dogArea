//
//  dogAreaApp.swift
//  dogArea
//
//  Created by 김태훈 on 10/12/23.
//

import SwiftUI
import SwiftData
import CoreData

@main
struct dogAreaApp: App {
  @State var splash = true
  let persistenceController = PersistenceController.shared
  var sharedModelContainer: ModelContainer = {
    let schema = Schema([
      Item.self,
    ])
    let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
    do {
      return try ModelContainer(for: schema, configurations: [modelConfiguration])
    } catch {
      fatalError("Could not create ModelContainer: \(error)")
    }
  }()
  
  var body: some Scene {
    WindowGroup {
      if splash {
        SplashView().onAppear{
          DispatchQueue.main.asyncAfter(deadline: .now() + 2.7) {
            withAnimation {
              splash = false
            }
          }
        }
      } else {
        RootView()
          .environmentObject(CustomAlertViewModel())
      }
    }
    .modelContainer(sharedModelContainer)
  }
}
