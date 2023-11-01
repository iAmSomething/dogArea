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
      RootView()
        .environmentObject(CustomAlertViewModel())
    }
    .modelContainer(sharedModelContainer)
  }
}
