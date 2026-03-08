import Foundation

struct WalkListDetailPresentationSnapshot {
    let hero: WalkListDetailHeroModel
    let metrics: [WalkListDetailMetricModel]
    let timeline: [WalkListDetailTimelineChipModel]
    let metaRows: [WalkListDetailMetaRowModel]
    let selectedPointSummary: String
    let timelineFootnote: String?
    let hasMapContent: Bool
}

struct WalkListDetailHeroModel {
    let badge: String
    let title: String
    let subtitle: String
    let petBadge: String
    let statusBadge: String?
}

struct WalkListDetailMetricModel: Identifiable {
    enum Tone {
        case warm
        case neutral
        case accent
    }

    let id: String
    let title: String
    let value: String
    let detail: String
    let tone: Tone
}

struct WalkListDetailTimelineChipModel: Identifiable {
    let id: UUID
    let title: String
    let subtitle: String
    let roleLabel: String
    let isSelected: Bool
}

struct WalkListDetailMetaRowModel: Identifiable {
    let id: String
    let title: String
    let value: String
}

protocol WalkListDetailPresentationServicing {
    /// 산책 상세 화면에 필요한 표시 전용 스냅샷을 구성합니다.
    /// - Parameters:
    ///   - model: 현재 상세 화면이 표현할 산책 기록 모델입니다.
    ///   - sessionMetadata: 종료 사유/종료 시각 등 세션 메타데이터입니다.
    ///   - pets: 현재 사용자에게 연결된 반려견 목록입니다.
    ///   - isMeter: 영역 넓이를 ㎡ 기준으로 보여줄지 여부입니다.
    ///   - selectedLocationID: 현재 사용자가 강조 중인 포인트 식별자입니다.
    /// - Returns: 상세 화면의 각 섹션이 바로 사용할 수 있는 스냅샷입니다.
    func makeSnapshot(
        model: WalkDataModel,
        sessionMetadata: WalkSessionMetadata?,
        pets: [PetInfo],
        isMeter: Bool,
        selectedLocationID: UUID?
    ) -> WalkListDetailPresentationSnapshot
}
