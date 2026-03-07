import Foundation

/// 홈 실내 미션 카드의 사용자 노출 문구와 섹션 구조를 조합하는 계약입니다.
protocol HomeIndoorMissionPresenting {
    /// 실내 미션 보드와 날씨 요약을 바탕으로 홈 카드 프레젠테이션 모델을 생성합니다.
    /// - Parameters:
    ///   - board: 현재 일일 실내 미션 보드 상태입니다.
    ///   - weatherSummary: 날씨 연동/치환 상태를 요약한 카드 정보입니다.
    ///   - localizedCopy: 현재 로케일에 맞는 한/영 문구를 선택하는 함수입니다.
    /// - Returns: 홈 실내 미션 카드에서 직접 사용할 프레젠테이션 모델입니다.
    func makePresentation(
        board: IndoorMissionBoard,
        weatherSummary: WeatherMissionStatusSummary,
        localizedCopy: (_ ko: String, _ en: String) -> String
    ) -> HomeIndoorMissionBoardPresentation
}

final class HomeIndoorMissionPresentationService: HomeIndoorMissionPresenting {
    /// 실내 미션 보드와 날씨 요약을 바탕으로 홈 카드 프레젠테이션 모델을 생성합니다.
    /// - Parameters:
    ///   - board: 현재 일일 실내 미션 보드 상태입니다.
    ///   - weatherSummary: 날씨 연동/치환 상태를 요약한 카드 정보입니다.
    ///   - localizedCopy: 현재 로케일에 맞는 한/영 문구를 선택하는 함수입니다.
    /// - Returns: 홈 실내 미션 카드에서 직접 사용할 프레젠테이션 모델입니다.
    func makePresentation(
        board: IndoorMissionBoard,
        weatherSummary: WeatherMissionStatusSummary,
        localizedCopy: (_ ko: String, _ en: String) -> String
    ) -> HomeIndoorMissionBoardPresentation {
        let rows = board.missions.map { mission in
            makeRowPresentation(
                mission: mission,
                riskLevel: board.riskLevel,
                localizedCopy: localizedCopy
            )
        }
        let activeRows = rows.filter { $0.lifecycleState != .completed }
        let completedRows = rows.filter { $0.lifecycleState == .completed }
        let completedTitle = completedRows.isEmpty
            ? nil
            : localizedCopy(
                "오늘 완료한 미션 \(completedRows.count)개",
                "Completed Today \(completedRows.count)"
            )

        return HomeIndoorMissionBoardPresentation(
            sectionTitle: localizedCopy(
                board.riskLevel == .clear ? "오늘 미션 안내" : "오늘 실내 대체 미션 안내",
                board.riskLevel == .clear ? "Today's Mission Guide" : "Today's Indoor Replacement Missions"
            ),
            sectionSubtitle: boardSubtitle(
                board: board,
                weatherSummary: weatherSummary,
                localizedCopy: localizedCopy
            ),
            rationaleItems: rationaleItems(
                board: board,
                weatherSummary: weatherSummary,
                localizedCopy: localizedCopy
            ),
            activeMissions: activeRows,
            completedMissions: completedRows,
            completedSectionTitle: completedTitle,
            emptyTitle: localizedCopy("오늘 진행할 미션이 없어요.", "No missions are active today."),
            emptyMessage: localizedCopy(
                "날씨 기준과 연장 상태를 확인한 뒤 새 미션이 열리면 여기서 바로 진행할 수 있어요.",
                "When weather or extension conditions open a mission, it will appear here."
            )
        )
    }

    /// 카드 상단 보조 설명 문구를 생성합니다.
    /// - Parameters:
    ///   - board: 현재 실내 미션 보드 상태입니다.
    ///   - weatherSummary: 날씨 연동/치환 상태를 요약한 카드 정보입니다.
    ///   - localizedCopy: 현재 로케일에 맞는 한/영 문구를 선택하는 함수입니다.
    /// - Returns: 카드 상단에 표시할 보조 설명 문구입니다.
    private func boardSubtitle(
        board: IndoorMissionBoard,
        weatherSummary: WeatherMissionStatusSummary,
        localizedCopy: (_ ko: String, _ en: String) -> String
    ) -> String {
        if board.riskLevel != .clear {
            return localizedCopy(
                "실외 대신 열린 실내 미션입니다. 카드마다 완료 기준과 부족분을 바로 확인하세요.",
                "Indoor replacement missions are open. Review each card for the exact requirement and remaining steps."
            )
        }
        if board.extensionState == .active || board.extensionState == .consumed {
            return localizedCopy(
                "전일 연장 슬롯과 오늘 상태를 한 번에 정리했습니다.",
                "This summarizes today's mission state together with the carry-over extension slot."
            )
        }
        return weatherSummary.reasonText
    }

    /// 카드 상단의 미션 진행 가이드 목록을 생성합니다.
    /// - Parameters:
    ///   - board: 현재 실내 미션 보드 상태입니다.
    ///   - weatherSummary: 날씨 연동/치환 상태를 요약한 카드 정보입니다.
    ///   - localizedCopy: 현재 로케일에 맞는 한/영 문구를 선택하는 함수입니다.
    /// - Returns: 사용자가 카드 상단에서 먼저 읽어야 할 가이드 문장 목록입니다.
    private func rationaleItems(
        board: IndoorMissionBoard,
        weatherSummary: WeatherMissionStatusSummary,
        localizedCopy: (_ ko: String, _ en: String) -> String
    ) -> [String] {
        var items: [String] = []
        if board.riskLevel != .clear {
            items.append(
                localizedCopy(
                    "오늘은 \(board.riskLevel.displayTitle) 단계라 실외 목표 대신 실내 대체 미션이 열렸어요.",
                    "The weather is \(board.riskLevel.displayTitle), so indoor replacement missions are open instead of outdoor goals."
                )
            )
        } else if board.extensionState == .active || board.extensionState == .consumed {
            items.append(
                localizedCopy(
                    "오늘 카드에는 어제 마치지 못한 미션의 연장 슬롯이 포함되어 있어요.",
                    "Today's card includes a carry-over extension slot from an unfinished mission."
                )
            )
        }

        items.append(
            localizedCopy(
                "`행동 +1 기록`은 실제로 끝낸 루틴 1회를 직접 남기는 버튼입니다.",
                "Use `+1` only after you actually finish one routine."
            )
        )
        items.append(
            localizedCopy(
                "기준 횟수를 채운 뒤 `완료 확인` 또는 `보상 받기`를 눌러야 미션이 완료로 확정됩니다.",
                "A mission is finalized only after you hit the required count and confirm completion."
            )
        )

        if weatherSummary.lifecycleGuideText.isEmpty == false {
            items.append(weatherSummary.lifecycleGuideText)
        }

        return items
    }

    /// 개별 미션 행의 프레젠테이션 정보를 생성합니다.
    /// - Parameters:
    ///   - mission: 렌더링할 개별 미션 상태입니다.
    ///   - riskLevel: 현재 날씨 위험 단계입니다.
    ///   - localizedCopy: 현재 로케일에 맞는 한/영 문구를 선택하는 함수입니다.
    /// - Returns: 개별 미션 행 렌더링에 사용할 프레젠테이션 정보입니다.
    private func makeRowPresentation(
        mission: IndoorMissionCardModel,
        riskLevel: IndoorWeatherRiskLevel,
        localizedCopy: (_ ko: String, _ en: String) -> String
    ) -> HomeIndoorMissionRowPresentation {
        let lifecycleState: HomeIndoorMissionLifecycleState
        if mission.progress.isCompleted {
            lifecycleState = .completed
        } else if mission.progress.actionCount >= mission.minimumActionCount {
            lifecycleState = .readyToFinalize
        } else {
            lifecycleState = .actionRequired
        }

        let shortage = max(0, mission.minimumActionCount - mission.progress.actionCount)
        let requirementText = requirementText(for: mission, localizedCopy: localizedCopy)
        let progressText = progressText(for: mission, localizedCopy: localizedCopy)
        let remainingText = shortage == 0
            ? nil
            : localizedCopy(
                "지금은 \(shortage)회가 부족해요. 실제로 끝낸 행동만 추가 기록해 주세요.",
                "You still need \(shortage) more records. Log only actions you actually completed."
            )

        let badgeText: String
        let lifecycleMessage: String
        let finalizeTitle: String
        switch lifecycleState {
        case .actionRequired:
            badgeText = localizedCopy("진행 중", "In Progress")
            lifecycleMessage = localizedCopy(
                "아직 진행 중인 미션입니다. 기준 횟수를 채운 뒤 완료를 확정하세요.",
                "This mission is still in progress. Reach the target count, then confirm completion."
            )
            finalizeTitle = localizedCopy("완료 확인", "Check Completion")
        case .readyToFinalize:
            badgeText = localizedCopy("확정 가능", "Ready")
            lifecycleMessage = localizedCopy(
                "기준을 모두 채웠어요. 지금 완료를 확정하면 보상이 지급됩니다.",
                "The requirement is met. Confirm now to grant the reward."
            )
            finalizeTitle = localizedCopy("보상 받기", "Claim Reward")
        case .completed:
            badgeText = localizedCopy("완료됨", "Completed")
            lifecycleMessage = mission.isExtension
                ? localizedCopy(
                    "오늘 완료된 연장 미션입니다. 감액 보상만 지급되고 시즌 점수/연속 보상은 제외돼요.",
                    "This archived extension mission already paid a reduced reward and does not count toward season or streak rewards."
                )
                : localizedCopy(
                    "오늘 완료된 미션입니다. 더 이상 행동 유도 카드로 노출되지 않아요.",
                    "This mission is already completed and archived out of the active action state."
                )
            finalizeTitle = localizedCopy("수령 완료", "Claimed")
        }

        return HomeIndoorMissionRowPresentation(
            id: mission.id,
            mission: mission,
            lifecycleState: lifecycleState,
            badgeText: badgeText,
            requirementText: requirementText,
            progressText: progressText,
            remainingText: remainingText,
            guideTitle: localizedCopy("이렇게 기록하세요", "How to Log"),
            guideItems: guideItems(for: mission, localizedCopy: localizedCopy),
            lifecycleMessage: lifecycleMessage,
            rewardFootnote: rewardFootnote(for: mission, riskLevel: riskLevel, localizedCopy: localizedCopy),
            recordActionTitle: localizedCopy("행동 +1 기록", "Log +1"),
            finalizeActionTitle: finalizeTitle
        )
    }

    /// 미션 카테고리별 완료 기준 문장을 생성합니다.
    /// - Parameters:
    ///   - mission: 렌더링 대상 미션입니다.
    ///   - localizedCopy: 현재 로케일에 맞는 한/영 문구를 선택하는 함수입니다.
    /// - Returns: 사용자가 바로 이해할 수 있는 완료 기준 문장입니다.
    private func requirementText(
        for mission: IndoorMissionCardModel,
        localizedCopy: (_ ko: String, _ en: String) -> String
    ) -> String {
        switch mission.category {
        case .recordCleanup:
            return localizedCopy(
                "완료 기준: 산책 기록·사진·메모 정리를 합쳐 \(mission.minimumActionCount)회 기록하면 완료돼요.",
                "Complete this by logging \(mission.minimumActionCount) record/photo/note cleanup actions."
            )
        case .petCareCheck:
            return localizedCopy(
                "완료 기준: 물 보충·브러싱·컨디션 체크를 합쳐 \(mission.minimumActionCount)회 기록하면 완료돼요.",
                "Complete this by logging \(mission.minimumActionCount) pet-care routines such as water, brushing, or condition checks."
            )
        case .trainingCheck:
            return localizedCopy(
                "완료 기준: 기다려·손·하우스 같은 훈련을 합쳐 \(mission.minimumActionCount)회 기록하면 완료돼요.",
                "Complete this by logging \(mission.minimumActionCount) indoor training repetitions such as wait, paw, or house."
            )
        }
    }

    /// 현재 진행량과 부족분을 설명하는 문장을 생성합니다.
    /// - Parameters:
    ///   - mission: 렌더링 대상 미션입니다.
    ///   - localizedCopy: 현재 로케일에 맞는 한/영 문구를 선택하는 함수입니다.
    /// - Returns: 현재 진행량과 즉시 이해 가능한 상태 설명입니다.
    private func progressText(
        for mission: IndoorMissionCardModel,
        localizedCopy: (_ ko: String, _ en: String) -> String
    ) -> String {
        if mission.progress.isCompleted {
            return localizedCopy(
                "현재 \(mission.progress.actionCount)/\(mission.minimumActionCount)회 기록이 완료됐고 보상도 지급됐어요.",
                "You completed \(mission.progress.actionCount)/\(mission.minimumActionCount) logs and the reward has already been granted."
            )
        }
        if mission.progress.actionCount >= mission.minimumActionCount {
            return localizedCopy(
                "현재 \(mission.progress.actionCount)/\(mission.minimumActionCount)회 기록이 되어 있어요. 이제 완료만 확정하면 됩니다.",
                "You have \(mission.progress.actionCount)/\(mission.minimumActionCount) logs. Only the completion confirmation is left."
            )
        }
        return localizedCopy(
            "현재 \(mission.progress.actionCount)/\(mission.minimumActionCount)회 기록했어요.",
            "You have logged \(mission.progress.actionCount)/\(mission.minimumActionCount) actions so far."
        )
    }

    /// 미션 카테고리별 자가 기록 가이드 목록을 생성합니다.
    /// - Parameters:
    ///   - mission: 렌더링 대상 미션입니다.
    ///   - localizedCopy: 현재 로케일에 맞는 한/영 문구를 선택하는 함수입니다.
    /// - Returns: `행동 +1 기록` 버튼을 언제 눌러야 하는지 설명하는 가이드 목록입니다.
    private func guideItems(
        for mission: IndoorMissionCardModel,
        localizedCopy: (_ ko: String, _ en: String) -> String
    ) -> [String] {
        switch mission.category {
        case .recordCleanup:
            return [
                localizedCopy(
                    "기록 정리 1회가 끝날 때마다 `행동 +1 기록`을 한 번만 누르세요.",
                    "Tap `Log +1` once per finished record cleanup action."
                ),
                localizedCopy(
                    "같은 사진 정리를 반복 탭으로 올리지 말고, 실제로 끝난 정리만 기록하세요.",
                    "Do not spam repeated taps for the same photo task. Log only real completed cleanup work."
                )
            ]
        case .petCareCheck:
            return [
                localizedCopy(
                    "물 보충·브러싱·컨디션 체크처럼 끝난 루틴 1건마다 기록하세요.",
                    "Log each finished care routine such as refilling water, brushing, or a health check."
                ),
                localizedCopy(
                    "한 번에 여러 루틴을 했다면 실제 완료한 횟수만큼만 추가하세요.",
                    "If you finished multiple routines, add only the number you actually completed."
                )
            ]
        case .trainingCheck:
            return [
                localizedCopy(
                    "기다려·손·하우스처럼 한 세트가 끝날 때마다 1회 기록하세요.",
                    "Log one count each time you finish one training set like wait, paw, or house."
                ),
                localizedCopy(
                    "강아지가 실제로 수행한 훈련만 체크하고 실패한 시도는 제외하세요.",
                    "Record only successful repetitions the dog actually completed."
                )
            ]
        }
    }

    /// 보상과 라이프사이클 예외를 묶은 보조 문구를 생성합니다.
    /// - Parameters:
    ///   - mission: 렌더링 대상 미션입니다.
    ///   - riskLevel: 현재 날씨 위험 단계입니다.
    ///   - localizedCopy: 현재 로케일에 맞는 한/영 문구를 선택하는 함수입니다.
    /// - Returns: 보상/예외 규칙을 설명하는 보조 문구입니다.
    private func rewardFootnote(
        for mission: IndoorMissionCardModel,
        riskLevel: IndoorWeatherRiskLevel,
        localizedCopy: (_ ko: String, _ en: String) -> String
    ) -> String {
        if mission.isExtension {
            return localizedCopy(
                "연장 슬롯 보상 70% 적용 · \(mission.rewardPoint)pt · 시즌 점수/연속 보상 제외",
                "Extension reward at 70% · \(mission.rewardPoint)pt · excluded from season and streak rewards"
            )
        }
        return localizedCopy(
            "완료 보상 \(mission.rewardPoint)pt · \(riskLevel.displayTitle) 기준 반영",
            "Reward \(mission.rewardPoint)pt · adjusted for \(riskLevel.displayTitle)"
        )
    }
}
