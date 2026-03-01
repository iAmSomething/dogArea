import SwiftUI

struct SeasonProfileFrameStyle {
    let stroke: Color
    let fill: Color

    /// 시즌 랭크에 대응하는 프로필 프레임 색상 세트를 반환합니다.
    /// - Parameter rankTier: 시즌 랭크 티어 값입니다. `nil`이면 기본 프레임 스타일을 반환합니다.
    /// - Returns: 프로필 이미지 외곽선/배경에 사용할 색상 스타일입니다.
    static func style(for rankTier: SeasonRankTier?) -> SeasonProfileFrameStyle {
        switch rankTier {
        case .some(.platinum):
            return .init(stroke: Color.appRed, fill: Color.appRed)
        case .some(.gold):
            return .init(stroke: Color.appYellow, fill: Color.appYellow)
        case .some(.silver):
            return .init(stroke: Color.appTextLightGray, fill: Color.appTextLightGray)
        case .some(.bronze):
            return .init(stroke: Color.appPeach, fill: Color.appPeach)
        case .some(.rookie):
            return .init(stroke: Color.appGreen, fill: Color.appGreen)
        case .none:
            return .init(stroke: Color.appTextDarkGray, fill: Color.appYellowPale)
        }
    }
}
