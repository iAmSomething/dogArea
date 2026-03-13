//
//  dogAreaApp.swift
//  dogArea
//
//  Created by 김태훈 on 10/12/23.
//

import SwiftUI
import SwiftData

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
    @StateObject private var authFlow = AuthFlowCoordinator()
    private let launchArguments = ProcessInfo.processInfo.arguments
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

    /// UI 테스트 런치 인자에서 지정한 인터페이스 스타일을 해석합니다.
    private var forcedInterfaceStyleForUITest: ColorScheme? {
        guard let index = launchArguments.firstIndex(of: "-UITest.InterfaceStyle"),
              launchArguments.indices.contains(index + 1) else {
            return nil
        }
        switch launchArguments[index + 1].lowercased() {
        case "dark":
            return .dark
        case "light":
            return .light
        default:
            return nil
        }
    }

    /// UI 테스트에서 스플래시 화면을 건너뛸지 여부를 반환합니다.
    private var shouldSkipSplashForUITest: Bool {
        launchArguments.contains("-UITest.SkipSplash")
    }

    /// UI 테스트에서 엔트리 선택 시트 없이 게스트로 바로 진입할지 여부를 반환합니다.
    private var shouldAutoGuestForUITest: Bool {
        launchArguments.contains("-UITest.AutoGuest")
    }

    /// UI 테스트에서 이전 진입 선택을 제거한 무세션 첫 진입 상태를 강제할지 여부를 반환합니다.
    /// - Returns: `-UITest.ResetUnauthenticatedEntry` 인자가 포함되면 `true`를 반환합니다.
    private var shouldResetUnauthenticatedEntryForUITest: Bool {
        launchArguments.contains("-UITest.ResetUnauthenticatedEntry")
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if splash && shouldSkipSplashForUITest == false {
                    SplashView().onAppear{
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.7) {
                            withAnimation {
                                splash = false
                            }
                        }
                    }
                } else {
                    rootContent
                }
            }
            .preferredColorScheme(forcedInterfaceStyleForUITest)
        }
        .modelContainer(sharedModelContainer)
    }

    @ViewBuilder
    private var rootContent: some View {
        let baseRoot = RootView()
            .environmentObject(CustomAlertViewModel())
            .environmentObject(authFlow)
            .onAppear {
                if shouldAutoGuestForUITest {
                    authFlow.configureUITestAutoGuestEntry()
                } else if shouldResetUnauthenticatedEntryForUITest {
                    authFlow.configureUITestUnauthenticatedEntry()
                } else {
                    authFlow.refresh()
                }
            }

        if shouldAutoGuestForUITest {
            baseRoot
        } else {
            baseRoot
                .sheet(isPresented: $authFlow.shouldShowEntryChoice, onDismiss: {
                    #if DEBUG
                    print("[AuthFlow] dogAreaApp entryChoice onDismiss")
                    #endif
                    authFlow.presentDeferredSignInIfNeeded()
                }) {
                    GuestEntryChoiceSheet(
                        onContinueAsGuest: { authFlow.continueAsGuest() },
                        onSignIn: { authFlow.chooseSignInFromEntry() }
                    )
                    .presentationDetents([.medium])
                    .interactiveDismissDisabled(true)
                }
        }
    }
}

private struct GuestEntryChoiceSheet: View {
    let onContinueAsGuest: () -> Void
    let onSignIn: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("DogArea 시작 방법 선택")
                .font(.appFont(for: .Bold, size: 24))
            Text("지금은 바로 시작하고, 필요할 때 로그인해서 기록을 동기화할 수 있어요.")
                .font(.appFont(for: .Regular, size: 14))
                .foregroundStyle(Color.appTextDarkGray)
            Button("바로 시작") {
                onContinueAsGuest()
            }
            .accessibilityIdentifier("entry.continueGuest")
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.appYellowPale)
            .foregroundStyle(Color.appTextDarkGray)
            .cornerRadius(12)
            Button("로그인하고 동기화") {
                onSignIn()
            }
            .accessibilityIdentifier("entry.openSignIn")
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.appGreen)
            .foregroundStyle(Color.white)
            .cornerRadius(12)
        }
        .padding(20)
    }
}
