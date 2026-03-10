import SwiftUI

enum AppTabBarVisibility: Equatable {
    case automatic
    case hidden
}

enum AppTabLayoutMetrics {
    static let defaultTabBarReservedHeight: CGFloat = 124
    static let nonMapRootTopSafeAreaPadding: CGFloat = 18
    static let nonMapRootHeaderTopSpacing: CGFloat = 12
    static let nonMapRootChromeBottomSpacing: CGFloat = 16
    static let mapOverlayTopExtraSpacing: CGFloat = 8
    static let minimumBottomPadding: CGFloat = 12
    static let defaultScrollExtraBottomPadding: CGFloat = 12
    static let comfortableScrollExtraBottomPadding: CGFloat = 20
    static let floatingOverlayLift: CGFloat = 28

    /// 상단 오버레이가 상태 바와 겹치지 않도록 필요한 여백을 계산합니다.
    /// - Parameters:
    ///   - safeAreaTopInset: 현재 컨테이너의 상단 safe area inset 값입니다.
    ///   - extra: 추가로 확보할 상단 여백입니다.
    /// - Returns: 상단 오버레이에 적용할 최종 spacing 값입니다.
    static func topOverlaySpacing(
        safeAreaTopInset: CGFloat,
        extra: CGFloat = mapOverlayTopExtraSpacing
    ) -> CGFloat {
        max(safeAreaTopInset, 0) + extra
    }
}

private struct AppTabBarReservedHeightKey: EnvironmentKey {
    static let defaultValue: CGFloat = AppTabLayoutMetrics.defaultTabBarReservedHeight
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

private struct AppTabRootScrollLayoutModifier: ViewModifier {
    let extraBottomPadding: CGFloat
    let topSafeAreaPadding: CGFloat
    let showsIndicators: Bool

    /// 탭 루트 스크롤 화면의 공통 safe area, 배경, 하단 inset 정책을 적용합니다.
    /// - Parameter content: 공통 탭 스크롤 레이아웃을 적용할 원본 뷰입니다.
    /// - Returns: 전역 탭 스캐폴드 계약이 반영된 스크롤 뷰입니다.
    func body(content: Content) -> some View {
        content
            .scrollIndicators(showsIndicators ? .visible : .hidden)
            .safeAreaInset(edge: .top, spacing: 0) {
                Color.clear
                    .frame(height: topSafeAreaPadding)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            .background(Color.appTabScaffoldBackground)
            .appTabBarContentPadding(extra: extraBottomPadding)
    }
}

private struct AppTabFloatingOverlayPaddingModifier: ViewModifier {
    @Environment(\.appTabBarReservedHeight) private var reservedHeight

    let lift: CGFloat
    let minimumBottomPadding: CGFloat

    /// 플로팅 CTA/오버레이가 하단 탭바 위에 안정적으로 배치되도록 여백을 적용합니다.
    /// - Parameter content: 하단 플로팅 오버레이로 배치할 원본 뷰입니다.
    /// - Returns: 탭바 회피용 하단 여백이 적용된 뷰입니다.
    func body(content: Content) -> some View {
        content.padding(.bottom, max(reservedHeight - lift, minimumBottomPadding))
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

struct NonMapRootHeaderContainer<Content: View>: View {
    private let topSpacing: CGFloat
    private let bottomSpacing: CGFloat
    private let content: Content

    /// 비지도 탭 루트의 첫 커스텀 헤더 블록에 공통 시작 간격을 적용합니다.
    /// - Parameters:
    ///   - topSpacing: 루트 safe area 예약 이후 헤더 앞에 확보할 공통 상단 간격입니다.
    ///   - bottomSpacing: 헤더 블록 아래에 유지할 공통 하단 간격입니다.
    ///   - content: 루트 헤더 영역에 렌더링할 커스텀 헤더 콘텐츠입니다.
    init(
        topSpacing: CGFloat = AppTabLayoutMetrics.nonMapRootHeaderTopSpacing,
        bottomSpacing: CGFloat = 0,
        @ViewBuilder content: () -> Content
    ) {
        self.topSpacing = topSpacing
        self.bottomSpacing = bottomSpacing
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, topSpacing)
            .padding(.bottom, bottomSpacing)
    }
}

struct NonMapRootTopChromeContainer<Content: View>: View {
    private let topSpacing: CGFloat
    private let bottomSpacing: CGFloat
    private let content: Content

    /// 비지도 탭 루트의 고정 상단 chrome을 safe area 아래에 배치합니다.
    /// - Parameters:
    ///   - topSpacing: 상태 바 safe area 뒤에 헤더 콘텐츠가 시작할 상단 간격입니다.
    ///   - bottomSpacing: 고정 헤더와 스크롤 본문 사이에 유지할 하단 간격입니다.
    ///   - content: 스크롤 바깥 상단 chrome에 고정할 헤더 콘텐츠입니다.
    init(
        topSpacing: CGFloat = AppTabLayoutMetrics.nonMapRootHeaderTopSpacing,
        bottomSpacing: CGFloat = AppTabLayoutMetrics.nonMapRootChromeBottomSpacing,
        @ViewBuilder content: () -> Content
    ) {
        self.topSpacing = topSpacing
        self.bottomSpacing = bottomSpacing
        self.content = content()
    }

    var body: some View {
        NonMapRootHeaderContainer(
            topSpacing: topSpacing,
            bottomSpacing: bottomSpacing
        ) {
            content
        }
        .padding(.top, AppTabLayoutMetrics.nonMapRootTopSafeAreaPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appTabScaffoldBackground)
    }
}

private struct NonMapRootTopChromeModifier<Chrome: View>: ViewModifier {
    let topSpacing: CGFloat
    let bottomSpacing: CGFloat
    let chrome: Chrome

    /// 실제 헤더 chrome을 safe area inset으로 삽입해 스크롤 콘텐츠와 구조적으로 분리합니다.
    /// - Parameter content: 상단 chrome을 제외한 스크롤 콘텐츠 원본 뷰입니다.
    /// - Returns: 고정 상단 chrome이 적용된 루트 스크롤 뷰입니다.
    func body(content: Content) -> some View {
        content.safeAreaInset(edge: .top, spacing: 0) {
            NonMapRootTopChromeContainer(
                topSpacing: topSpacing,
                bottomSpacing: bottomSpacing
            ) {
                chrome
            }
        }
    }
}

private struct NonMapRootPinnedHeaderLayoutModifier<Chrome: View>: ViewModifier {
    let topSpacing: CGFloat
    let bottomSpacing: CGFloat
    let chrome: Chrome

    /// pinned section header를 쓰는 비지도 탭 루트에서 고정 chrome과 스크롤 본문을 서로 다른 레이아웃 영역으로 분리합니다.
    /// - Parameter content: 고정 chrome 아래에서 스크롤될 본문 콘텐츠입니다.
    /// - Returns: pinned section header가 고정 chrome 아래에 머무는 루트 레이아웃입니다.
    func body(content: Content) -> some View {
        VStack(spacing: 0) {
            NonMapRootTopChromeContainer(
                topSpacing: topSpacing,
                bottomSpacing: bottomSpacing
            ) {
                chrome
            }

            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.appTabScaffoldBackground.ignoresSafeArea())
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

    /// 탭 루트의 스크롤 화면에 공통 safe area, 배경, 탭바 회피 여백을 적용합니다.
    /// - Parameters:
    ///   - extraBottomPadding: 탭바 예약 높이에 추가할 여분 하단 여백입니다.
    ///   - topSafeAreaPadding: 상단 safe area 뒤에 추가할 공통 여백입니다.
    ///   - showsIndicators: 스크롤 인디케이터 노출 여부입니다.
    /// - Returns: 전역 탭 스크롤 레이아웃이 적용된 뷰입니다.
    func appTabRootScrollLayout(
        extraBottomPadding: CGFloat = AppTabLayoutMetrics.defaultScrollExtraBottomPadding,
        topSafeAreaPadding: CGFloat = AppTabLayoutMetrics.nonMapRootTopSafeAreaPadding,
        showsIndicators: Bool = false
    ) -> some View {
        modifier(
            AppTabRootScrollLayoutModifier(
                extraBottomPadding: extraBottomPadding,
                topSafeAreaPadding: topSafeAreaPadding,
                showsIndicators: showsIndicators
            )
        )
    }

    /// 하단 플로팅 CTA/오버레이가 전역 탭바를 기준으로 자동 배치되도록 여백을 적용합니다.
    /// - Parameters:
    ///   - lift: 탭바 상단에서 얼마나 위로 띄울지 결정하는 값입니다.
    ///   - minimumBottomPadding: 탭바 높이가 작을 때 보장할 최소 하단 여백입니다.
    /// - Returns: 하단 플로팅 오버레이 여백이 적용된 뷰입니다.
    func appTabFloatingOverlayPadding(
        lift: CGFloat = AppTabLayoutMetrics.floatingOverlayLift,
        minimumBottomPadding: CGFloat = AppTabLayoutMetrics.minimumBottomPadding
    ) -> some View {
        modifier(
            AppTabFloatingOverlayPaddingModifier(
                lift: lift,
                minimumBottomPadding: minimumBottomPadding
            )
        )
    }

    /// 현재 화면이 전역 탭 바를 숨겨야 하는지 선언형으로 전달합니다.
    /// - Parameter visibility: 현재 화면이 요구하는 탭 바 표시 정책입니다.
    /// - Returns: 탭 바 표시 정책 preference가 적용된 뷰입니다.
    func appTabBarVisibility(_ visibility: AppTabBarVisibility) -> some View {
        preference(key: AppTabBarVisibilityPreferenceKey.self, value: visibility)
    }

    /// 비지도 탭 루트의 첫 헤더를 스크롤 콘텐츠 밖 상단 chrome으로 고정합니다.
    /// - Parameters:
    ///   - topSpacing: safe area 아래에서 헤더 콘텐츠가 시작할 상단 간격입니다.
    ///   - bottomSpacing: 고정 헤더와 스크롤 본문 사이에 확보할 하단 간격입니다.
    ///   - chrome: 스크롤 밖 상단 chrome으로 고정할 헤더 콘텐츠입니다.
    /// - Returns: 상단 chrome이 safe area inset으로 적용된 뷰입니다.
    func nonMapRootTopChrome<Chrome: View>(
        topSpacing: CGFloat = AppTabLayoutMetrics.nonMapRootHeaderTopSpacing,
        bottomSpacing: CGFloat = AppTabLayoutMetrics.nonMapRootChromeBottomSpacing,
        @ViewBuilder chrome: () -> Chrome
    ) -> some View {
        modifier(
            NonMapRootTopChromeModifier(
                topSpacing: topSpacing,
                bottomSpacing: bottomSpacing,
                chrome: chrome()
            )
        )
    }

    /// pinned section header를 쓰는 비지도 탭 루트에 고정 top chrome 분리 레이아웃을 적용합니다.
    /// - Parameters:
    ///   - topSpacing: safe area 아래에서 헤더 콘텐츠가 시작할 상단 간격입니다.
    ///   - bottomSpacing: 고정 헤더와 스크롤 본문 사이에 확보할 하단 간격입니다.
    ///   - chrome: 스크롤 밖 상단 chrome으로 고정할 헤더 콘텐츠입니다.
    /// - Returns: pinned section header가 고정 chrome 아래에 머무는 분리 레이아웃이 적용된 뷰입니다.
    func nonMapRootPinnedHeaderLayout<Chrome: View>(
        topSpacing: CGFloat = AppTabLayoutMetrics.nonMapRootHeaderTopSpacing,
        bottomSpacing: CGFloat = AppTabLayoutMetrics.nonMapRootChromeBottomSpacing,
        @ViewBuilder chrome: () -> Chrome
    ) -> some View {
        modifier(
            NonMapRootPinnedHeaderLayoutModifier(
                topSpacing: topSpacing,
                bottomSpacing: bottomSpacing,
                chrome: chrome()
            )
        )
    }
}
