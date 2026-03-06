import SwiftUI

enum AppTabBarVisibility: Equatable {
    case automatic
    case hidden
}

private struct AppTabBarReservedHeightKey: EnvironmentKey {
    static let defaultValue: CGFloat = CustomTabBar.reservedContentHeight
}

struct AppTabBarVisibilityPreferenceKey: PreferenceKey {
    static let defaultValue: AppTabBarVisibility = .automatic

    /// 하위 화면이 요청한 탭 바 표시 정책을 상위 스캐폴드에 병합합니다.
    /// - Parameters:
    ///   - value: 현재까지 병합된 탭 바 표시 정책입니다.
    ///   - nextValue: 이번 레이아웃 패스에서 전달된 다음 정책입니다.
    static func reduce(value: inout AppTabBarVisibility, nextValue: () -> AppTabBarVisibility) {
        value = nextValue() == .hidden ? .hidden : value
    }
}

extension EnvironmentValues {
    var appTabBarReservedHeight: CGFloat {
        get { self[AppTabBarReservedHeightKey.self] }
        set { self[AppTabBarReservedHeightKey.self] = newValue }
    }
}

private struct AppTabBarContentPaddingModifier: ViewModifier {
    @Environment(\.appTabBarReservedHeight) private var reservedHeight

    let extra: CGFloat

    /// 커스텀 탭 바가 차지하는 하단 공간만큼 콘텐츠 여백을 확보합니다.
    /// - Parameter content: 하단 여백을 적용할 원본 뷰입니다.
    /// - Returns: 탭 바 예약 높이가 반영된 뷰입니다.
    func body(content: Content) -> some View {
        content.padding(.bottom, reservedHeight + extra)
    }
}

private struct AppRootNavigationChromeModifier: ViewModifier {
    let isHidden: Bool

    /// 루트 탭 화면에서 네비게이션 바 노출 정책을 일관되게 적용합니다.
    /// - Parameter content: 네비게이션 크롬 정책을 적용할 원본 뷰입니다.
    /// - Returns: 루트 화면 정책이 반영된 뷰입니다.
    func body(content: Content) -> some View {
        if isHidden {
            content.toolbar(.hidden, for: .navigationBar)
        } else {
            content
        }
    }
}

struct AppTabRootContainer<Content: View>: View {
    private let accessibilityIdentifier: String
    private let hidesNavigationBar: Bool
    private let content: Content

    /// 탭 루트 화면을 독립 `NavigationStack`으로 감싸 전역 네비게이션 정책을 표준화합니다.
    /// - Parameters:
    ///   - accessibilityIdentifier: 루트 화면 식별에 사용할 접근성 식별자입니다.
    ///   - hidesNavigationBar: 루트 화면에서 기본 네비게이션 바를 숨길지 여부입니다.
    ///   - content: 탭 내부에 렌더링할 루트 콘텐츠입니다.
    init(
        accessibilityIdentifier: String,
        hidesNavigationBar: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.accessibilityIdentifier = accessibilityIdentifier
        self.hidesNavigationBar = hidesNavigationBar
        self.content = content()
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .topLeading) {
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .modifier(AppRootNavigationChromeModifier(isHidden: hidesNavigationBar))

                Color.black
                    .opacity(0.01)
                    .frame(width: 1, height: 1)
                    .allowsHitTesting(false)
                    .accessibilityIdentifier(accessibilityIdentifier)
            }
        }
    }
}

extension View {
    /// 전역 탭 스캐폴드가 예약한 하단 높이를 하위 뷰 환경에 주입합니다.
    /// - Parameter height: 탭 바가 점유하는 예약 높이입니다.
    /// - Returns: 하단 예약 높이가 환경에 주입된 뷰입니다.
    func appTabBarReservedHeight(_ height: CGFloat) -> some View {
        environment(\.appTabBarReservedHeight, height)
    }

    /// 루트 탭 화면 콘텐츠가 탭 바 아래로 가려지지 않도록 하단 여백을 적용합니다.
    /// - Parameter extra: 기본 예약 높이에 추가할 여분 여백입니다.
    /// - Returns: 탭 바 대비 하단 여백이 적용된 뷰입니다.
    func appTabBarContentPadding(extra: CGFloat = 0) -> some View {
        modifier(AppTabBarContentPaddingModifier(extra: extra))
    }

    /// 현재 화면이 전역 탭 바를 숨겨야 하는지 선언형으로 전달합니다.
    /// - Parameter visibility: 현재 화면이 요구하는 탭 바 표시 정책입니다.
    /// - Returns: 탭 바 표시 정책 preference가 적용된 뷰입니다.
    func appTabBarVisibility(_ visibility: AppTabBarVisibility) -> some View {
        preference(key: AppTabBarVisibilityPreferenceKey.self, value: visibility)
    }
}
