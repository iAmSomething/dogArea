import SwiftUI

struct HomeScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    /// 최신 스크롤 오프셋 값을 preference 시스템에 병합합니다.
    /// - Parameters:
    ///   - value: 현재까지 누적된 preference 값입니다.
    ///   - nextValue: 이번 레이아웃 패스에서 전달된 다음 preference 값 클로저입니다.
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
