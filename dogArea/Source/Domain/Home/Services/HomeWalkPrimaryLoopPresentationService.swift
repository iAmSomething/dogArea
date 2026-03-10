import Foundation

/// 홈 대시보드에서 산책을 제품의 기본 루프로 설명하는 프레젠테이션을 생성하는 계약입니다.
protocol HomeWalkPrimaryLoopPresenting {
    /// 선택 반려견과 누적 산책 요약을 바탕으로 홈 1차 설명 카드 프레젠테이션을 생성합니다.
    /// - Parameters:
    ///   - selectedPetName: 현재 선택된 반려견 이름입니다.
    ///   - walkRecordCount: 현재 반려견 기준 누적 산책 기록 수입니다.
    ///   - totalDuration: 현재 반려견 기준 누적 산책 시간(초)입니다.
    ///   - totalArea: 현재 반려견 기준 누적 영역 넓이(㎡)입니다.
    ///   - hasIndoorMissionReplacement: 실내 미션 보조 흐름이 현재 열려 있는지 여부입니다.
    ///   - localizedCopy: 현재 로케일에 맞는 한/영 문구를 선택하는 함수입니다.
    /// - Returns: 홈 카드가 바로 렌더링할 수 있는 산책 기본 루프 프레젠테이션입니다.
    func makePresentation(
        selectedPetName: String,
        walkRecordCount: Int,
        totalDuration: TimeInterval,
        totalArea: Double,
        hasIndoorMissionReplacement: Bool,
        localizedCopy: (_ ko: String, _ en: String) -> String
    ) -> HomeWalkPrimaryLoopPresentation
}

struct HomeWalkPrimaryLoopPresentationService: HomeWalkPrimaryLoopPresenting {
    /// 선택 반려견과 누적 산책 요약을 바탕으로 홈 1차 설명 카드 프레젠테이션을 생성합니다.
    /// - Parameters:
    ///   - selectedPetName: 현재 선택된 반려견 이름입니다.
    ///   - walkRecordCount: 현재 반려견 기준 누적 산책 기록 수입니다.
    ///   - totalDuration: 현재 반려견 기준 누적 산책 시간(초)입니다.
    ///   - totalArea: 현재 반려견 기준 누적 영역 넓이(㎡)입니다.
    ///   - hasIndoorMissionReplacement: 실내 미션 보조 흐름이 현재 열려 있는지 여부입니다.
    ///   - localizedCopy: 현재 로케일에 맞는 한/영 문구를 선택하는 함수입니다.
    /// - Returns: 홈 카드가 바로 렌더링할 수 있는 산책 기본 루프 프레젠테이션입니다.
    func makePresentation(
        selectedPetName: String,
        walkRecordCount: Int,
        totalDuration: TimeInterval,
        totalArea: Double,
        hasIndoorMissionReplacement: Bool,
        localizedCopy: (_ ko: String, _ en: String) -> String
    ) -> HomeWalkPrimaryLoopPresentation {
        let summaryText: String
        if walkRecordCount > 0 {
            summaryText = localizedCopy(
                "\(selectedPetName)와 남긴 산책 \(walkRecordCount)건이 오늘 상태와 목표 해석의 기준이 됩니다.",
                "Your \(walkRecordCount) walks with \(selectedPetName) anchor today's status and goal interpretation."
            )
        } else {
            summaryText = localizedCopy(
                "첫 산책을 시작하면 \(selectedPetName) 기준 기록이 쌓이고 이후 목표와 시즌 해석이 그 기록을 따라 이어집니다.",
                "Once you start the first walk for \(selectedPetName), records begin to accumulate and drive goals and seasonal interpretation."
            )
        }

        let metrics = [
            HomeWalkPrimaryLoopMetricPresentation(
                id: "records",
                title: localizedCopy("누적 기록", "Total Walks"),
                value: localizedCopy("\(walkRecordCount)건", "\(walkRecordCount)"),
                detail: localizedCopy("저장된 산책 수", "Saved walk sessions")
            ),
            HomeWalkPrimaryLoopMetricPresentation(
                id: "duration",
                title: localizedCopy("누적 시간", "Total Duration"),
                value: totalDuration.simpleWalkingTimeInterval,
                detail: localizedCopy("쌓인 산책 시간", "Accumulated walking time")
            ),
            HomeWalkPrimaryLoopMetricPresentation(
                id: "area",
                title: localizedCopy("누적 영역", "Total Area"),
                value: totalArea > 0 ? totalArea.calculatedAreaString : localizedCopy("0㎡", "0 m²"),
                detail: localizedCopy("기록된 영역 넓이", "Recorded covered area")
            )
        ]

        let pillars = [
            HomeWalkPrimaryLoopPillarPresentation(
                id: "route",
                title: localizedCopy("경로와 영역이 기록돼요", "Routes and area are recorded"),
                body: localizedCopy(
                    "산책을 저장하면 어디를 걸었는지와 얼마나 넓혔는지가 남아요.",
                    "Saving a walk preserves where you walked and how much territory you expanded."
                )
            ),
            HomeWalkPrimaryLoopPillarPresentation(
                id: "history",
                title: localizedCopy("시간과 기록이 누적돼요", "Time and history accumulate"),
                body: localizedCopy(
                    "산책 한 번이 지나가는 이벤트가 아니라 다시 보는 기록으로 쌓입니다.",
                    "Each walk becomes reusable history rather than a one-off event."
                )
            ),
            HomeWalkPrimaryLoopPillarPresentation(
                id: "systems",
                title: localizedCopy("목표·미션·시즌에 이어져요", "It flows into goals, missions, and seasons"),
                body: localizedCopy(
                    "산책 결과가 영역 목표, 미션 해석, 시즌 진행을 읽는 기준이 됩니다.",
                    "Walk results become the reference point for territory goals, mission interpretation, and seasonal progress."
                )
            )
        ]

        let secondaryFlowText = hasIndoorMissionReplacement
            ? localizedCopy(
                "오늘은 날씨 때문에 실내 미션 보조 흐름도 함께 열려 있어요. 기본 루프는 여전히 산책 기록입니다.",
                "Indoor backup missions are also open today because of weather. The primary loop is still the walk record."
            )
            : localizedCopy(
                "실내 미션은 악천후나 예외 상황에서만 열리는 보조 흐름이에요.",
                "Indoor missions are a supporting path that opens only for bad weather or exception days."
            )

        let accessibilityText = (
            [localizedCopy("산책 기본 루프", "Walk primary loop"), summaryText] +
            metrics.map { "\($0.title) \($0.value)" } +
            [secondaryFlowText, localizedCopy("설명 보기에서 자세한 가이드를 열 수 있어요.", "Open the guide for more details.")]
        ).joined(separator: " ")

        return HomeWalkPrimaryLoopPresentation(
            badgeText: localizedCopy("기본 행동", "Primary Loop"),
            title: localizedCopy("산책이 이 앱의 시작점이에요", "Walking is the start of this app"),
            summaryText: summaryText,
            metrics: metrics,
            pillars: pillars,
            secondaryFlowText: secondaryFlowText,
            accessibilityText: accessibilityText
        )
    }
}
