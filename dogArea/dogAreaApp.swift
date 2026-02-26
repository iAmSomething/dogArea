//
//  dogAreaApp.swift
//  dogArea
//
//  Created by 김태훈 on 10/12/23.
//

import SwiftUI
import SwiftData
import CoreData
import FirebaseCore
import FirebaseFirestore

struct SupabaseConfiguration {
    let url: URL
    let anonKey: String
    let projectRef: String
    let storageBuckets: [String]
    let authRedirectURL: URL?

    static func load(from bundle: Bundle = .main) -> SupabaseConfiguration? {
        guard
            let urlString = bundle.stringValue(forInfoDictionaryKey: "SUPABASE_URL"),
            let url = URL(string: urlString),
            let anonKey = bundle.stringValue(forInfoDictionaryKey: "SUPABASE_ANON_KEY"),
            let projectRef = bundle.stringValue(forInfoDictionaryKey: "PROJECT_REF")
        else {
            return nil
        }

        let bucketsString = bundle.stringValue(forInfoDictionaryKey: "STORAGE_BUCKETS") ?? ""
        let buckets = bucketsString
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let redirect = bundle
            .stringValue(forInfoDictionaryKey: "AUTH_REDIRECT_URL")
            .flatMap(URL.init(string:))

        return .init(
            url: url,
            anonKey: anonKey,
            projectRef: projectRef,
            storageBuckets: buckets,
            authRedirectURL: redirect
        )
    }
}

private extension Bundle {
    func stringValue(forInfoDictionaryKey key: String) -> String? {
        guard let value = object(forInfoDictionaryKey: key) as? String else {
            return nil
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        let db = Firestore.firestore()
        if SupabaseConfiguration.load() == nil {
            print("Supabase configuration is missing required values.")
        }
        return true
    }
}

@main
struct dogAreaApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
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
                    .fullScreenCover(isPresented: .constant(
                        UserdefaultSetting().getValue()?.id == nil
//                        true
                    ), content: {
                        SignInView()
                    })
            }
        }
        .modelContainer(sharedModelContainer)
    }
}
