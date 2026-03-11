import Foundation

protocol WalkOutcomeExplaining {
    /// 산책 종료 결과를 공통 계산 스냅샷으로 정규화합니다.
    /// - Parameters:
    ///   - appliedPointCount: 실제 저장된 포인트 수입니다.
    ///   - exclusions: 산책 중 보호 정책으로 제외된 기록 집계입니다.
    ///   - contribution: 영역 기여 계산 스냅샷입니다.
    ///   - connections: 기록/영역/시즌/미션 연결 상태 스냅샷입니다.
    /// - Returns: 종료 직후와 상세 화면이 함께 사용할 계산 스냅샷입니다.
    func makeCalculationSnapshot(
        appliedPointCount: Int,
        exclusions: WalkOutcomeExclusionSnapshot,
        contribution: WalkOutcomeContributionSnapshot,
        connections: WalkOutcomeConnectionSnapshot
    ) -> WalkOutcomeCalculationSnapshot

    /// 저장된 산책의 레거시 데이터만으로 기본 결과 스냅샷을 구성합니다.
    /// - Parameters:
    ///   - appliedPointCount: 저장된 포인트 수입니다.
    ///   - areaM2: 저장된 산책 영역 값입니다.
    ///   - markPointCount: 영역 표시 포인트 수입니다.
    ///   - routePointCount: 이동 경로 포인트 수입니다.
    /// - Returns: 제외 사유 상세가 없는 레거시 산책용 계산 스냅샷입니다.
    func makeLegacyCalculationSnapshot(
        appliedPointCount: Int,
        areaM2: Double,
        markPointCount: Int,
        routePointCount: Int
    ) -> WalkOutcomeCalculationSnapshot

    /// 계산 스냅샷을 사용자용 설명 DTO로 변환합니다.
    /// - Parameter snapshot: 사용자 문구로 풀어낼 계산 스냅샷입니다.
    /// - Returns: 종료 직후 카드와 상세 리포트가 함께 사용할 결과 설명 DTO입니다.
    func makeExplanationDTO(from snapshot: WalkOutcomeCalculationSnapshot) -> WalkOutcomeExplanationDTO
}

struct WalkOutcomeExplanationService: WalkOutcomeExplaining {
    private let sourceVersion = "walk-outcome-v1"

    /// 산책 종료 결과를 공통 계산 스냅샷으로 정규화합니다.
    /// - Parameters:
    ///   - appliedPointCount: 실제 저장된 포인트 수입니다.
    ///   - exclusions: 산책 중 보호 정책으로 제외된 기록 집계입니다.
    ///   - contribution: 영역 기여 계산 스냅샷입니다.
    ///   - connections: 기록/영역/시즌/미션 연결 상태 스냅샷입니다.
    /// - Returns: 종료 직후와 상세 화면이 함께 사용할 계산 스냅샷입니다.
    func makeCalculationSnapshot(
        appliedPointCount: Int,
        exclusions: WalkOutcomeExclusionSnapshot,
        contribution: WalkOutcomeContributionSnapshot,
        connections: WalkOutcomeConnectionSnapshot
    ) -> WalkOutcomeCalculationSnapshot {
        let excludedPointCount = exclusions.totalExcludedCount
        let denominator = max(1, appliedPointCount + excludedPointCount)
        return WalkOutcomeCalculationSnapshot(
            appliedPointCount: appliedPointCount,
            excludedPointCount: excludedPointCount,
            excludedRatio: Double(excludedPointCount) / Double(denominator),
            exclusions: exclusions,
            contribution: contribution,
            connections: connections,
            calculationSourceVersion: sourceVersion
        )
    }

    /// 저장된 산책의 레거시 데이터만으로 기본 결과 스냅샷을 구성합니다.
    /// - Parameters:
    ///   - appliedPointCount: 저장된 포인트 수입니다.
    ///   - areaM2: 저장된 산책 영역 값입니다.
    ///   - markPointCount: 영역 표시 포인트 수입니다.
    ///   - routePointCount: 이동 경로 포인트 수입니다.
    /// - Returns: 제외 사유 상세가 없는 레거시 산책용 계산 스냅샷입니다.
    func makeLegacyCalculationSnapshot(
        appliedPointCount: Int,
        areaM2: Double,
        markPointCount: Int,
        routePointCount: Int
    ) -> WalkOutcomeCalculationSnapshot {
        let totalPointCount = max(1, appliedPointCount)
        let markRatio = Double(markPointCount) / Double(totalPointCount)
        let routeRatio = Double(routePointCount) / Double(totalPointCount)
        let contribution = WalkOutcomeContributionSnapshot(
            markAreaM2: areaM2 * markRatio,
            routeAreaM2: areaM2 * routeRatio,
            routeCappedAreaM2: min(areaM2 * routeRatio, areaM2 * markRatio),
            finalAreaM2: areaM2,
            routeContributionRatio: min(0.2, max(0.0, routeRatio))
        )
        return makeCalculationSnapshot(
            appliedPointCount: appliedPointCount,
            exclusions: .empty,
            contribution: contribution,
            connections: WalkOutcomeConnectionSnapshot(
                recordStatus: .updated,
                territoryStatus: areaM2 > 0 ? .updated : .pending,
                seasonStatus: appliedPointCount > 0 ? .updated : .pending,
                questStatus: appliedPointCount > 0 ? .pending : .notApplicable
            )
        )
    }

    /// 계산 스냅샷을 사용자용 설명 DTO로 변환합니다.
    /// - Parameter snapshot: 사용자 문구로 풀어낼 계산 스냅샷입니다.
    /// - Returns: 종료 직후 카드와 상세 리포트가 함께 사용할 결과 설명 DTO입니다.
    func makeExplanationDTO(from snapshot: WalkOutcomeCalculationSnapshot) -> WalkOutcomeExplanationDTO {
        let summaryState = resolveSummaryState(for: snapshot)
        let reasonSummaries = makeReasonSummaries(from: snapshot.exclusions)
        return WalkOutcomeExplanationDTO(
            summaryState: summaryState,
            statusTitle: summaryTitle(for: summaryState),
            statusBody: summaryBody(for: summaryState, snapshot: snapshot),
            appliedPointCount: snapshot.appliedPointCount,
            excludedPointCount: snapshot.excludedPointCount,
            excludedRatioText: percentageText(for: snapshot.excludedRatio),
            topExclusionReasons: Array(reasonSummaries.prefix(3)),
            primaryReasonLine: makePrimaryReasonLine(from: reasonSummaries),
            primaryConnectionLine: makePrimaryConnectionLine(from: snapshot.connections),
            contributionRows: makeContributionRows(from: snapshot.contribution),
            connectionRows: makeConnectionRows(from: snapshot.connections),
            calculationSourceVersion: snapshot.calculationSourceVersion,
            analyticsContext: makeAnalyticsContext(from: snapshot, summaryState: summaryState, reasons: reasonSummaries)
        )
    }

    /// 결과 설명 DTO가 공통으로 쓸 analytics 분석 축을 생성합니다.
    /// - Parameters:
    ///   - snapshot: 원본 계산 스냅샷입니다.
    ///   - summaryState: 사용자 요약 상태입니다.
    ///   - reasons: 사용자 노출용 제외 사유 요약 배열입니다.
    /// - Returns: surface 간 동일하게 재사용할 analytics context입니다.
    private func makeAnalyticsContext(
        from snapshot: WalkOutcomeCalculationSnapshot,
        summaryState: WalkOutcomeSummaryState,
        reasons: [WalkOutcomeExclusionReasonSummary]
    ) -> WalkOutcomeReportAnalyticsContext {
        WalkOutcomeReportAnalyticsContext(
            summaryState: summaryState,
            appliedPointCount: snapshot.appliedPointCount,
            appliedPointBucket: appliedPointBucket(for: snapshot.appliedPointCount),
            excludedPointCount: snapshot.excludedPointCount,
            excludedRatioBucket: excludedRatioBucket(for: snapshot.excludedRatio),
            topExclusionReasonIDs: Array(reasons.prefix(3).map(\.reasonID)),
            recordConnectionStatus: snapshot.connections.recordStatus,
            territoryConnectionStatus: snapshot.connections.territoryStatus,
            seasonConnectionStatus: snapshot.connections.seasonStatus,
            questConnectionStatus: snapshot.connections.questStatus,
            connectionStateKey: connectionStateKey(for: snapshot.connections),
            calculationSourceVersion: snapshot.calculationSourceVersion
        )
    }

    /// 계산 스냅샷을 대표 상태 3종 중 하나로 분류합니다.
    /// - Parameter snapshot: 평가할 산책 결과 계산 스냅샷입니다.
    /// - Returns: 현재 산책 결과를 대표하는 요약 상태입니다.
    private func resolveSummaryState(for snapshot: WalkOutcomeCalculationSnapshot) -> WalkOutcomeSummaryState {
        let policyHeavyCount = snapshot.exclusions.policyGuardCount + snapshot.exclusions.jumpCount
        if snapshot.excludedPointCount > 0,
           policyHeavyCount >= max(1, snapshot.excludedPointCount / 2),
           snapshot.excludedRatio >= 0.45 {
            return .policyExcludedDominant
        }
        if snapshot.appliedPointCount <= 2 || snapshot.excludedRatio >= 0.55 {
            return .lowApplied
        }
        return .normalApplied
    }

    /// 요약 상태에 대응하는 대표 제목을 반환합니다.
    /// - Parameter state: 사용자에게 보여줄 요약 상태입니다.
    /// - Returns: 상태 카드 제목 문자열입니다.
    private func summaryTitle(for state: WalkOutcomeSummaryState) -> String {
        switch state {
        case .lowApplied:
            return "거의 반영 안 됨"
        case .normalApplied:
            return "정상 반영"
        case .policyExcludedDominant:
            return "정책 제외 다수"
        }
    }

    /// 요약 상태와 계산값에 맞는 본문 문구를 조립합니다.
    /// - Parameters:
    ///   - state: 대표 상태입니다.
    ///   - snapshot: 상태 설명에 사용할 계산 스냅샷입니다.
    /// - Returns: 사용자에게 보여줄 상태 본문 문자열입니다.
    private func summaryBody(
        for state: WalkOutcomeSummaryState,
        snapshot: WalkOutcomeCalculationSnapshot
    ) -> String {
        switch state {
        case .lowApplied:
            return "이번 산책은 저장됐지만 실제 반영은 적었어요. 제외된 기록과 연결 흐름을 함께 확인해보세요."
        case .normalApplied:
            return "이번 산책 기록이 저장됐고, 영역과 시즌 흐름에도 이어질 준비가 됐어요."
        case .policyExcludedDominant:
            return "보호 기준 때문에 제외된 기록이 많았어요. 어떤 기록이 걸러졌는지 먼저 확인해보세요."
        }
    }

    /// 제외 사유 집계를 사용자용 요약 행 배열로 변환합니다.
    /// - Parameter snapshot: 제외 사유 집계 스냅샷입니다.
    /// - Returns: 카운트가 있는 사유만 count 내림차순으로 정렬한 배열입니다.
    private func makeReasonSummaries(from snapshot: WalkOutcomeExclusionSnapshot) -> [WalkOutcomeExclusionReasonSummary] {
        [
            makeReasonSummary(
                reasonID: .lowAccuracy,
                count: snapshot.lowAccuracyCount,
                title: "정확도가 낮아 제외된 기록",
                explanation: "위치 정확도가 충분하지 않아 안전하게 제외했어요."
            ),
            makeReasonSummary(
                reasonID: .jump,
                count: snapshot.jumpCount,
                title: "갑자기 크게 튄 기록",
                explanation: "짧은 시간에 과도하게 이동한 샘플은 비정상 점프로 보고 제외했어요."
            ),
            makeReasonSummary(
                reasonID: .duplicateOrPause,
                count: snapshot.duplicateOrPauseCount,
                title: "중복되거나 멈춤으로 본 기록",
                explanation: "너무 가까운 반복 샘플이나 멈춤 구간 후보는 따로 쌓지 않았어요."
            ),
            makeReasonSummary(
                reasonID: .policyGuard,
                count: snapshot.policyGuardCount,
                title: "보호 정책으로 제외된 기록",
                explanation: "현재 세션을 안전하게 유지하기 위한 보호 규칙으로 제외했어요."
            )
        ]
        .compactMap { $0 }
        .sorted { lhs, rhs in
            if lhs.count == rhs.count {
                return lhs.title < rhs.title
            }
            return lhs.count > rhs.count
        }
    }

    /// 단일 제외 사유 요약이 0건이 아닐 때만 결과 모델을 생성합니다.
    /// - Parameters:
    ///   - reasonID: 제외 사유 식별자입니다.
    ///   - count: 해당 사유 카운트입니다.
    ///   - title: 사용자 노출용 사유 제목입니다.
    ///   - explanation: 사용자 노출용 짧은 해설입니다.
    /// - Returns: 카운트가 1 이상이면 요약 모델, 아니면 `nil`입니다.
    private func makeReasonSummary(
        reasonID: WalkOutcomeExclusionReasonID,
        count: Int,
        title: String,
        explanation: String
    ) -> WalkOutcomeExclusionReasonSummary? {
        guard count > 0 else { return nil }
        return WalkOutcomeExclusionReasonSummary(
            reasonID: reasonID,
            title: title,
            count: count,
            shortExplanation: explanation
        )
    }

    /// 종료 직후 카드에 노출할 대표 제외 사유 한 줄을 생성합니다.
    /// - Parameter reasons: 사용자용 제외 사유 요약 배열입니다.
    /// - Returns: 대표 사유가 있으면 한 줄 요약, 없으면 `nil`입니다.
    private func makePrimaryReasonLine(from reasons: [WalkOutcomeExclusionReasonSummary]) -> String? {
        guard let top = reasons.first else { return nil }
        return "가장 많이 걸러진 이유: \(top.title) \(top.count)건"
    }

    /// 연결 상태 스냅샷을 종료 직후 대표 한 줄 문구로 변환합니다.
    /// - Parameter connections: 기록 연결 상태 스냅샷입니다.
    /// - Returns: 종료 직후 카드에서 보여줄 대표 연결 요약 문구입니다.
    private func makePrimaryConnectionLine(from connections: WalkOutcomeConnectionSnapshot) -> String {
        if connections.territoryStatus == .updated {
            return "이 산책은 기록과 홈 목표 흐름에 바로 이어져요."
        }
        if connections.seasonStatus == .updated {
            return "이 산책은 기록과 시즌 흐름에 이어져요."
        }
        return "이 산책 기록은 목록에서 다시 보고 다음 흐름을 확인할 수 있어요."
    }

    /// 계산 기여값을 사용자용 상세 행 배열로 변환합니다.
    /// - Parameter contribution: 기여 계산 스냅샷입니다.
    /// - Returns: 상세 화면에서 노출할 계산 근거 행 배열입니다.
    private func makeContributionRows(from contribution: WalkOutcomeContributionSnapshot) -> [WalkOutcomeContributionRow] {
        [
            WalkOutcomeContributionRow(
                id: "mark",
                title: "영역 표시 기여",
                value: areaText(for: contribution.markAreaM2),
                detail: "직접 남긴 표시 포인트가 만든 기본 영역이에요."
            ),
            WalkOutcomeContributionRow(
                id: "route",
                title: "경로 기여",
                value: areaText(for: contribution.routeAreaM2),
                detail: "이동 경로가 추가로 넓힌 영역 계산값이에요."
            ),
            WalkOutcomeContributionRow(
                id: "decay",
                title: "감쇠 적용",
                value: areaText(for: max(0, contribution.routeAreaM2 - contribution.routeCappedAreaM2)),
                detail: "과도하게 커지는 경로 기여를 부드럽게 줄였어요."
            ),
            WalkOutcomeContributionRow(
                id: "cap",
                title: "상한 적용",
                value: areaText(for: contribution.routeCappedAreaM2),
                detail: "최종 계산에 반영된 경로 기여 상한값이에요."
            )
        ]
    }

    /// 연결 상태 스냅샷을 상세 화면용 행 배열로 변환합니다.
    /// - Parameter connections: 기록 연결 상태 스냅샷입니다.
    /// - Returns: 기록, 영역/목표, 시즌, 미션 연결 순서를 유지한 행 배열입니다.
    private func makeConnectionRows(from connections: WalkOutcomeConnectionSnapshot) -> [WalkOutcomeConnectionRow] {
        [
            makeConnectionRow(
                id: "record",
                title: "산책 기록",
                status: connections.recordStatus,
                updatedDetail: "이번 산책은 목록과 상세에서 바로 다시 볼 수 있어요.",
                pendingDetail: "기록 저장 상태를 다시 확인해주세요.",
                notApplicableDetail: "이번 항목은 기록 허브 연결이 비활성 상태예요."
            ),
            makeConnectionRow(
                id: "territory",
                title: "영역/목표",
                status: connections.territoryStatus,
                updatedDetail: "홈 목표와 영역 해석이 같은 산책 결과를 기준으로 이어져요.",
                pendingDetail: "영역 반영이 적어 목표 변화가 작게 보일 수 있어요.",
                notApplicableDetail: "이번 산책은 영역 변화가 거의 없어 목표 연결이 작게 보여요."
            ),
            makeConnectionRow(
                id: "season",
                title: "시즌",
                status: connections.seasonStatus,
                updatedDetail: "시즌 지도에서도 같은 산책 결과를 이어서 읽어요.",
                pendingDetail: "시즌 반영은 지형과 구간 조건에 따라 약하게 보일 수 있어요.",
                notApplicableDetail: "이번 산책은 시즌 흐름에 직접 연결되지 않았어요."
            ),
            makeConnectionRow(
                id: "quest",
                title: "미션/퀘스트",
                status: connections.questStatus,
                updatedDetail: "산책 기반 미션 진행에도 같은 기록이 이어졌어요.",
                pendingDetail: "미션 반영 여부는 현재 조건을 만족할 때 확인할 수 있어요.",
                notApplicableDetail: "이번 산책은 별도 미션 연결 없이 기록 자체가 핵심이에요."
            )
        ]
    }

    /// 반영 포인트 수를 coarse bucket으로 변환합니다.
    /// - Parameter count: 실제 반영 포인트 수입니다.
    /// - Returns: 분석에 사용할 포인트 수 bucket 문자열입니다.
    private func appliedPointBucket(for count: Int) -> String {
        switch count {
        case ..<1:
            return "0"
        case 1...2:
            return "1_2"
        case 3...5:
            return "3_5"
        case 6...10:
            return "6_10"
        default:
            return "11_plus"
        }
    }

    /// 제외 비율을 coarse bucket으로 변환합니다.
    /// - Parameter ratio: 제외 비율입니다.
    /// - Returns: 분석에 사용할 제외 비율 bucket 문자열입니다.
    private func excludedRatioBucket(for ratio: Double) -> String {
        switch ratio {
        case ..<0.001:
            return "none"
        case ..<0.25:
            return "low_0_24"
        case ..<0.5:
            return "mid_25_49"
        case ..<0.75:
            return "high_50_74"
        default:
            return "very_high_75_plus"
        }
    }

    /// 연결 상태 스냅샷을 compact combo key로 변환합니다.
    /// - Parameter connections: 기록/영역/시즌/미션 연결 상태 스냅샷입니다.
    /// - Returns: 분석과 필터링에 사용할 고정 combo 문자열입니다.
    private func connectionStateKey(for connections: WalkOutcomeConnectionSnapshot) -> String {
        [
            "record:\(connections.recordStatus.rawValue)",
            "territory:\(connections.territoryStatus.rawValue)",
            "season:\(connections.seasonStatus.rawValue)",
            "quest:\(connections.questStatus.rawValue)"
        ].joined(separator: "|")
    }

    /// 단일 연결 상태를 사용자용 상세 행 모델로 변환합니다.
    /// - Parameters:
    ///   - id: 행 식별자입니다.
    ///   - title: 연결 대상 제목입니다.
    ///   - status: 현재 연결 상태입니다.
    ///   - updatedDetail: `updated` 상태 설명입니다.
    ///   - pendingDetail: `pending` 상태 설명입니다.
    ///   - notApplicableDetail: `notApplicable` 상태 설명입니다.
    /// - Returns: 상세 화면에 노출할 연결 상태 행 모델입니다.
    private func makeConnectionRow(
        id: String,
        title: String,
        status: WalkOutcomeConnectionStatus,
        updatedDetail: String,
        pendingDetail: String,
        notApplicableDetail: String
    ) -> WalkOutcomeConnectionRow {
        switch status {
        case .updated:
            return WalkOutcomeConnectionRow(id: id, title: title, statusTitle: "반영됨", detail: updatedDetail)
        case .pending:
            return WalkOutcomeConnectionRow(id: id, title: title, statusTitle: "확인 필요", detail: pendingDetail)
        case .notApplicable:
            return WalkOutcomeConnectionRow(id: id, title: title, statusTitle: "해당 없음", detail: notApplicableDetail)
        }
    }

    /// 비율 값을 사용자용 퍼센트 문자열로 변환합니다.
    /// - Parameter ratio: 0~1 범위 비율 값입니다.
    /// - Returns: 백분율 문자열입니다.
    private func percentageText(for ratio: Double) -> String {
        "\(Int((ratio * 100).rounded()))%"
    }

    /// 면적 값을 사용자용 문자열로 변환합니다.
    /// - Parameter area: 면적 값(m²)입니다.
    /// - Returns: 소수 둘째 자리까지 반영한 면적 문자열입니다.
    private func areaText(for area: Double) -> String {
        String(format: "%.2f㎡", area)
    }
}

protocol MapWalkTopHUDPresenting {
    /// safe area 아래 slim HUD에서 사용할 산책 상태 프레젠테이션을 생성합니다.
    /// - Parameters:
    ///   - petName: 현재 산책 중인 반려견 이름입니다.
    ///   - routePointCount: 현재까지 기록한 포인트 수입니다.
    ///   - areaText: 현재까지 누적된 영역 문자열입니다.
    ///   - hasCompetingTopChrome: 배너/상세 카드 등 상단 chrome 경쟁 요소 존재 여부입니다.
    /// - Returns: 상단 slim HUD 렌더링에 사용할 프레젠테이션입니다.
    func makePresentation(
        petName: String,
        routePointCount: Int,
        areaText: String,
        hasCompetingTopChrome: Bool
    ) -> MapWalkTopHUDPresentation
}

protocol MapWalkValueFlowPresenting {
    /// 산책 진행 중 helper 카드 프레젠테이션을 생성합니다.
    /// - Parameters:
    ///   - petName: 현재 산책 중인 반려견 이름입니다.
    ///   - routePointCount: 현재까지 기록한 포인트 수입니다.
    ///   - durationText: 현재까지 누적된 산책 시간 문자열입니다.
    ///   - areaText: 현재까지 누적된 영역 문자열입니다.
    /// - Returns: 진행 중 현재형 설명 카드에 사용할 프레젠테이션입니다.
    func makeActiveValuePresentation(
        petName: String,
        routePointCount: Int,
        durationText: String,
        areaText: String
    ) -> MapWalkActiveValuePresentation

    /// 산책 저장 직후 후속 행동 카드 프레젠테이션을 생성합니다.
    /// - Parameters:
    ///   - detailModel: 저장 직후 상세 화면을 바로 열 때 사용할 산책 모델입니다.
    ///   - petName: 저장한 산책에 연결된 반려견 이름입니다.
    ///   - areaText: 저장한 세션의 영역 문자열입니다.
    ///   - explanation: 종료 직후 요약과 상세 화면이 함께 사용할 결과 설명 DTO입니다.
    /// - Returns: 저장 후 무엇이 반영됐는지 설명하는 후속 카드 프레젠테이션입니다.
    func makeSavedOutcomePresentation(
        detailModel: WalkDataModel,
        petName: String,
        areaText: String,
        explanation: WalkOutcomeExplanationDTO
    ) -> MapWalkSavedOutcomePresentation

    /// 산책 종료 직전 확인 시트에서 사용할 가치 설명 프레젠테이션을 생성합니다.
    /// - Parameters:
    ///   - petName: 종료할 산책에 연결된 반려견 이름입니다.
    ///   - durationText: 종료할 산책의 시간 문자열입니다.
    ///   - areaText: 종료할 산책의 영역 문자열입니다.
    ///   - pointCount: 종료할 산책의 포인트 수입니다.
    /// - Returns: 저장 후 이어질 결과를 설명하는 확인 카드 프레젠테이션입니다.
    func makeCompletionValuePresentation(
        petName: String,
        durationText: String,
        areaText: String,
        pointCount: Int
    ) -> WalkCompletionValuePresentation
}

struct MapWalkTopHUDPresentationService: MapWalkTopHUDPresenting {
    /// safe area 아래 slim HUD에서 사용할 산책 상태 프레젠테이션을 생성합니다.
    /// - Parameters:
    ///   - petName: 현재 산책 중인 반려견 이름입니다.
    ///   - routePointCount: 현재까지 기록한 포인트 수입니다.
    ///   - areaText: 현재까지 누적된 영역 문자열입니다.
    ///   - hasCompetingTopChrome: 배너/상세 카드 등 상단 chrome 경쟁 요소 존재 여부입니다.
    /// - Returns: 상단 slim HUD 렌더링에 사용할 프레젠테이션입니다.
    func makePresentation(
        petName: String,
        routePointCount: Int,
        areaText: String,
        hasCompetingTopChrome: Bool
    ) -> MapWalkTopHUDPresentation {
        let resolvedPetName = petName.isEmpty ? "현재 반려견" : petName
        return MapWalkTopHUDPresentation(
            title: "\(resolvedPetName)와 산책 중",
            statusText: hasCompetingTopChrome ? "기록 상태" : "경로·영역·포인트를 계속 누적하고 있어요",
            metrics: [
                .init(id: "duration", title: "시간", value: "0분"),
                .init(id: "area", title: "영역", value: areaText),
                .init(id: "points", title: "포인트", value: "\(routePointCount)개")
            ],
            displayMode: hasCompetingTopChrome ? .compact : .regular,
            disclosureTitle: hasCompetingTopChrome ? "설명 보기" : "자세히",
            disclosureMode: hasCompetingTopChrome ? .openGuideSheet : .expandInline
        )
    }
}

struct MapWalkValueFlowPresentationService: MapWalkValueFlowPresenting {
    /// 산책 진행 중 helper 카드 프레젠테이션을 생성합니다.
    /// - Parameters:
    ///   - petName: 현재 산책 중인 반려견 이름입니다.
    ///   - routePointCount: 현재까지 기록한 포인트 수입니다.
    ///   - durationText: 현재까지 누적된 산책 시간 문자열입니다.
    ///   - areaText: 현재까지 누적된 영역 문자열입니다.
    /// - Returns: 진행 중 현재형 설명 카드에 사용할 프레젠테이션입니다.
    func makeActiveValuePresentation(
        petName: String,
        routePointCount: Int,
        durationText: String,
        areaText: String
    ) -> MapWalkActiveValuePresentation {
        MapWalkActiveValuePresentation(
            title: "지금 \(petName)와 산책 기록을 쌓는 중이에요",
            summary: "경로와 시간은 계속 누적되고, 포인트를 더할수록 영역 기록도 또렷해집니다.",
            metrics: [
                .init(id: "duration", title: "시간", value: durationText),
                .init(id: "area", title: "영역", value: areaText),
                .init(id: "points", title: "포인트", value: "\(routePointCount)개")
            ],
            footer: "마칠 때 저장하면 이 세션이 목록, 목표, 미션 해석으로 이어집니다."
        )
    }

    /// 산책 저장 직후 후속 행동 카드 프레젠테이션을 생성합니다.
    /// - Parameters:
    ///   - detailModel: 저장 직후 상세 화면을 바로 열 때 사용할 산책 모델입니다.
    ///   - petName: 저장한 산책에 연결된 반려견 이름입니다.
    ///   - areaText: 저장한 세션의 영역 문자열입니다.
    ///   - explanation: 종료 직후 요약과 상세 화면이 함께 사용할 결과 설명 DTO입니다.
    /// - Returns: 저장 후 무엇이 반영됐는지 설명하는 후속 카드 프레젠테이션입니다.
    func makeSavedOutcomePresentation(
        detailModel: WalkDataModel,
        petName: String,
        areaText: String,
        explanation: WalkOutcomeExplanationDTO
    ) -> MapWalkSavedOutcomePresentation {
        let summary = "\(petName)와 남긴 포인트 \(explanation.appliedPointCount)개가 저장됐고, 이번 산책 영역은 \(areaText)예요."
        return MapWalkSavedOutcomePresentation(
            detailModel: detailModel,
            title: explanation.statusTitle,
            summary: summary,
            statusBody: explanation.statusBody,
            appliedSummary: "반영된 포인트 \(explanation.appliedPointCount)개 · 제외 비율 \(explanation.excludedRatioText)",
            primaryReasonLine: explanation.primaryReasonLine,
            connectionLine: explanation.primaryConnectionLine,
            primaryActionTitle: "목록에서 보기",
            secondaryActionTitle: "방금 상세 보기",
            analyticsContext: explanation.analyticsContext
        )
    }

    /// 산책 종료 직전 확인 시트에서 사용할 가치 설명 프레젠테이션을 생성합니다.
    /// - Parameters:
    ///   - petName: 종료할 산책에 연결된 반려견 이름입니다.
    ///   - durationText: 종료할 산책의 시간 문자열입니다.
    ///   - areaText: 종료할 산책의 영역 문자열입니다.
    ///   - pointCount: 종료할 산책의 포인트 수입니다.
    /// - Returns: 저장 후 이어질 결과를 설명하는 확인 카드 프레젠테이션입니다.
    func makeCompletionValuePresentation(
        petName: String,
        durationText: String,
        areaText: String,
        pointCount: Int
    ) -> WalkCompletionValuePresentation {
        WalkCompletionValuePresentation(
            title: "저장하면 무엇이 남는지 확인하고 마칠게요",
            summary: "이번 산책은 \(petName) 기준 기록으로 저장되고, 경로·영역·시간이 한 세션으로 남습니다.",
            items: [
                .init(id: "session", title: "저장될 기록", body: "시간 \(durationText), 영역 \(areaText), 포인트 \(pointCount)개가 한 번의 산책으로 저장됩니다."),
                .init(id: "history", title: "다시 볼 곳", body: "산책 목록과 상세에서 방금 세션을 다시 볼 수 있어요."),
                .init(id: "systems", title: "이어지는 결과", body: "홈 목표, 미션 진행, 시즌 해석이 이 기록을 기준으로 연결됩니다.")
            ],
            footnote: "사진 저장과 공유는 보조 흐름이고, 이 화면의 핵심 행동은 산책 기록 저장입니다."
        )
    }
}
