//
//  dogAreaApp.swift
//  dogArea
//
//  Created by 김태훈 on 10/12/23.
//

import SwiftUI
import SwiftData
import CoreLocation
import ObjectiveC.runtime

private enum CoreLocationRuntimeTrace {
    private static let lock = NSLock()
    private static var installed = false
    private static var heartbeatTimer: DispatchSourceTimer?
    private static var eventCounts: [String: Int] = [:]
    private static var windowStartedAt: Date = Date()
    private static var stackPrintedKeys: Set<String> = []

    /// CoreLocation 런타임 호출 추적 스위즐을 설치합니다.
    static func installIfNeeded() {
        #if DEBUG
        lock.lock()
        if installed {
            lock.unlock()
            return
        }
        installed = true
        lock.unlock()

        swizzleInstanceMethod(
            on: CLLocationManager.self,
            original: #selector(CLLocationManager.startUpdatingLocation),
            swizzled: #selector(CLLocationManager.dogarea_trace_startUpdatingLocation)
        )
        swizzleInstanceMethod(
            on: CLLocationManager.self,
            original: #selector(CLLocationManager.stopUpdatingLocation),
            swizzled: #selector(CLLocationManager.dogarea_trace_stopUpdatingLocation)
        )
        swizzleInstanceMethod(
            on: CLLocationManager.self,
            original: #selector(CLLocationManager.requestWhenInUseAuthorization),
            swizzled: #selector(CLLocationManager.dogarea_trace_requestWhenInUseAuthorization)
        )
        swizzleInstanceMethod(
            on: CLLocationManager.self,
            original: #selector(CLLocationManager.requestAlwaysAuthorization),
            swizzled: #selector(CLLocationManager.dogarea_trace_requestAlwaysAuthorization)
        )
        swizzleClassMethod(
            on: CLLocationManager.self,
            original: NSSelectorFromString("locationServicesEnabled"),
            swizzled: #selector(CLLocationManager.dogarea_trace_locationServicesEnabled)
        )
        swizzleClassMethod(
            on: CLLocationManager.self,
            original: NSSelectorFromString("authorizationStatus"),
            swizzled: #selector(CLLocationManager.dogarea_trace_authorizationStatus)
        )
        startHeartbeat()
        print("[CoreLocationRuntimeTrace] installed")
        #endif
    }

    /// 인스턴스 메서드 호출을 집계하고 호출 스택(최초 1회)을 출력합니다.
    /// - Parameters:
    ///   - method: 추적 대상 메서드명입니다.
    ///   - manager: 호출 대상 매니저 인스턴스입니다.
    static func record(method: String, manager: CLLocationManager) {
        #if DEBUG
        let key = "instance.\(method)"
        appendCount(for: key)
        let managerKey = "\(method)#\(ObjectIdentifier(manager).hashValue)"
        printStackIfNeeded(label: managerKey)
        #else
        _ = method
        _ = manager
        #endif
    }

    /// 클래스 메서드 호출을 집계하고 호출 스택(최초 1회)을 출력합니다.
    /// - Parameter method: 추적 대상 클래스 메서드명입니다.
    static func recordClass(method: String) {
        #if DEBUG
        let key = "class.\(method)"
        appendCount(for: key)
        printStackIfNeeded(label: key)
        #else
        _ = method
        #endif
    }

    /// 1초 주기로 누적 호출량을 요약 출력합니다.
    private static func startHeartbeat() {
        #if DEBUG
        lock.lock()
        if heartbeatTimer != nil {
            lock.unlock()
            return
        }
        let timer = DispatchSource.makeTimerSource(queue: .global(qos: .utility))
        timer.schedule(deadline: .now() + 1.0, repeating: 1.0)
        timer.setEventHandler {
            flushSummary()
        }
        heartbeatTimer = timer
        lock.unlock()
        timer.resume()
        #endif
    }

    /// 메서드 호출 카운트를 누적합니다.
    /// - Parameter key: 집계 키입니다.
    private static func appendCount(for key: String) {
        lock.lock()
        eventCounts[key, default: 0] += 1
        lock.unlock()
    }

    /// 아직 출력하지 않은 레이블이면 호출 스택 상위 프레임을 1회 출력합니다.
    /// - Parameter label: 스택 출력 중복 방지용 레이블입니다.
    private static func printStackIfNeeded(label: String) {
        lock.lock()
        if stackPrintedKeys.contains(label) {
            lock.unlock()
            return
        }
        stackPrintedKeys.insert(label)
        lock.unlock()

        let stack = Thread.callStackSymbols.prefix(14).joined(separator: "\n")
        print("[CoreLocationRuntimeTrace][stack] \(label)\n\(stack)")
    }

    /// 최근 1초 구간의 호출 집계를 출력하고 카운터를 초기화합니다.
    private static func flushSummary() {
        lock.lock()
        let now = Date()
        let elapsed = now.timeIntervalSince(windowStartedAt)
        let summary = eventCounts
            .sorted { lhs, rhs in lhs.value > rhs.value }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: ", ")
        eventCounts.removeAll()
        windowStartedAt = now
        lock.unlock()

        guard elapsed >= 0.95 else { return }
        if summary.isEmpty {
            print("[CoreLocationRuntimeTrace][1s] idle")
        } else {
            print("[CoreLocationRuntimeTrace][1s] \(summary)")
        }
    }

    /// 인스턴스 메서드 구현을 교체합니다.
    /// - Parameters:
    ///   - targetClass: 스위즐할 대상 클래스입니다.
    ///   - original: 원본 셀렉터입니다.
    ///   - swizzled: 대체 셀렉터입니다.
    private static func swizzleInstanceMethod(on targetClass: AnyClass, original: Selector, swizzled: Selector) {
        guard
            let originalMethod = class_getInstanceMethod(targetClass, original),
            let swizzledMethod = class_getInstanceMethod(targetClass, swizzled)
        else { return }
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }

    /// 클래스 메서드 구현을 교체합니다.
    /// - Parameters:
    ///   - targetClass: 스위즐할 대상 클래스입니다.
    ///   - original: 원본 셀렉터입니다.
    ///   - swizzled: 대체 셀렉터입니다.
    private static func swizzleClassMethod(on targetClass: AnyClass, original: Selector, swizzled: Selector) {
        guard
            let originalMethod = class_getClassMethod(targetClass, original),
            let swizzledMethod = class_getClassMethod(targetClass, swizzled)
        else { return }
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }
}

private extension CLLocationManager {
    /// `startUpdatingLocation()` 호출을 런타임 추적합니다.
    @objc func dogarea_trace_startUpdatingLocation() {
        CoreLocationRuntimeTrace.record(method: "startUpdatingLocation", manager: self)
        dogarea_trace_startUpdatingLocation()
    }

    /// `stopUpdatingLocation()` 호출을 런타임 추적합니다.
    @objc func dogarea_trace_stopUpdatingLocation() {
        CoreLocationRuntimeTrace.record(method: "stopUpdatingLocation", manager: self)
        dogarea_trace_stopUpdatingLocation()
    }

    /// `requestWhenInUseAuthorization()` 호출을 런타임 추적합니다.
    @objc func dogarea_trace_requestWhenInUseAuthorization() {
        CoreLocationRuntimeTrace.record(method: "requestWhenInUseAuthorization", manager: self)
        dogarea_trace_requestWhenInUseAuthorization()
    }

    /// `requestAlwaysAuthorization()` 호출을 런타임 추적합니다.
    @objc func dogarea_trace_requestAlwaysAuthorization() {
        CoreLocationRuntimeTrace.record(method: "requestAlwaysAuthorization", manager: self)
        dogarea_trace_requestAlwaysAuthorization()
    }

    /// `CLLocationManager.locationServicesEnabled()` 호출을 런타임 추적합니다.
    @objc class func dogarea_trace_locationServicesEnabled() -> Bool {
        CoreLocationRuntimeTrace.recordClass(method: "locationServicesEnabled")
        return dogarea_trace_locationServicesEnabled()
    }

    /// `CLLocationManager.authorizationStatus()` 호출을 런타임 추적합니다.
    @objc class func dogarea_trace_authorizationStatus() -> CLAuthorizationStatus {
        CoreLocationRuntimeTrace.recordClass(method: "authorizationStatus")
        return dogarea_trace_authorizationStatus()
    }
}

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
        CoreLocationRuntimeTrace.installIfNeeded()
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
                authFlow.refresh()
                if shouldAutoGuestForUITest {
                    DispatchQueue.main.async {
                        authFlow.continueAsGuest()
                    }
                }
            }

        if shouldAutoGuestForUITest {
            baseRoot
                .fullScreenCover(isPresented: $authFlow.shouldShowSignIn, content: {
                    SignInView(
                        allowDismiss: true,
                        onAuthenticated: { authFlow.completeSignIn() },
                        onDismiss: { authFlow.dismissSignIn() }
                    )
                })
        } else {
            baseRoot
                .sheet(isPresented: $authFlow.shouldShowEntryChoice) {
                    GuestEntryChoiceSheet(
                        onContinueAsGuest: { authFlow.continueAsGuest() },
                        onSignIn: { authFlow.chooseSignInFromEntry() }
                    )
                    .presentationDetents([.medium])
                    .interactiveDismissDisabled(true)
                }
                .fullScreenCover(isPresented: $authFlow.shouldShowSignIn, content: {
                    SignInView(
                        allowDismiss: true,
                        onAuthenticated: { authFlow.completeSignIn() },
                        onDismiss: { authFlow.dismissSignIn() }
                    )
                })
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
