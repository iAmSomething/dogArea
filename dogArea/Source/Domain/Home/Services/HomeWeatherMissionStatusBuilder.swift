//
//  HomeWeatherMissionStatusBuilder.swift
//  dogArea
//
//  Created by Codex on 3/2/26.
//

import Foundation

/// 홈 실내 미션 카드의 날씨 상태 요약 문자열을 생성하는 빌더 계약입니다.
protocol HomeWeatherMissionStatusBuilding {
    /// 실내 미션 보드/날씨 상태/로케일을 바탕으로 사용자 노출용 상태 요약을 생성합니다.
    /// - Parameters:
    ///   - board: 현재 실내 미션 보드 상태입니다.
    ///   - status: 날씨 연동 소스 및 최신 반영 시각을 포함한 상태입니다.
    ///   - serverSummary: 서버가 확정한 날씨 치환 canonical summary입니다.
    ///   - now: 현재 시각입니다.
    ///   - shieldApplyCount: 당일 날씨 보호 적용 횟수입니다.
    ///   - localizedCopy: 한/영 문구를 현재 로케일에 맞춰 선택하는 함수입니다.
    /// - Returns: 홈 카드에서 바로 렌더링 가능한 `WeatherMissionStatusSummary`입니다.
    func makeStatusSummary(
        board: IndoorMissionBoard,
        status: IndoorWeatherStatus,
        serverSummary: WeatherReplacementSummarySnapshot?,
        now: Date,
        shieldApplyCount: Int,
        localizedCopy: (_ ko: String, _ en: String) -> String
    ) -> WeatherMissionStatusSummary
}

final class HomeWeatherMissionStatusBuilder: HomeWeatherMissionStatusBuilding {
    private static let appliedTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    /// 실내 미션 보드/날씨 상태/로케일을 바탕으로 사용자 노출용 상태 요약을 생성합니다.
    /// - Parameters:
    ///   - board: 현재 실내 미션 보드 상태입니다.
    ///   - status: 날씨 연동 소스 및 최신 반영 시각을 포함한 상태입니다.
    ///   - serverSummary: 서버가 확정한 날씨 치환 canonical summary입니다.
    ///   - now: 현재 시각입니다.
    ///   - shieldApplyCount: 당일 날씨 보호 적용 횟수입니다.
    ///   - localizedCopy: 한/영 문구를 현재 로케일에 맞춰 선택하는 함수입니다.
    /// - Returns: 홈 카드에서 바로 렌더링 가능한 `WeatherMissionStatusSummary`입니다.
    func makeStatusSummary(
        board: IndoorMissionBoard,
        status: IndoorWeatherStatus,
        serverSummary: WeatherReplacementSummarySnapshot?,
        now: Date,
        shieldApplyCount: Int,
        localizedCopy: (_ ko: String, _ en: String) -> String
    ) -> WeatherMissionStatusSummary {
        let badgeText: String
        if status.source == .fallback {
            badgeText = localizedCopy("기본 모드", "Base Mode")
        } else if board.riskLevel == .clear {
            badgeText = localizedCopy("정상", "Normal")
        } else {
            badgeText = localizedCopy("치환", "Replaced")
        }

        let reasonText: String
        if status.source == .fallback {
            reasonText = localizedCopy(
                "실시간 날씨 정보를 불러오지 못해 최근 안전 기준으로 미션을 조정했어요.",
                "Live weather is unavailable. Missions are adjusted with a conservative safety baseline."
            )
        } else if let replacementReason = serverSummary?.replacementReason,
                  replacementReason.isEmpty == false,
                  board.riskLevel != .clear {
            reasonText = replacementReason
        } else if board.riskLevel == .clear {
            reasonText = localizedCopy(
                "날씨 안정 단계로 기본 퀘스트를 진행합니다.",
                "Stable weather. Running default quests."
            )
        } else {
            reasonText = localizedCopy(
                "\(board.riskLevel.displayTitle) 단계로 일부 실외 목표를 실내 미션으로 치환했어요.",
                "Risk \(board.riskLevel.rawValue) replaced some outdoor goals with indoor missions."
            )
        }

        let appliedTimestamp = status.lastUpdatedAt ?? now.timeIntervalSince1970
        let appliedTime = Self.appliedTimeFormatter.string(from: Date(timeIntervalSince1970: appliedTimestamp))
        let shieldText = localizedCopy(
            "보호 사용 \(shieldApplyCount)회",
            "Shield used \(shieldApplyCount)x"
        )

        let policyTitle = localizedCopy(
            "실내 미션이 열리는 기준",
            "When Indoor Missions Open"
        )
        let policyText: String
        if status.source == .fallback {
            policyText = localizedCopy(
                "연결이 복구될 때까지 산책 안전 기준을 보수적으로 보고, 필요하면 실내 보조 흐름만 먼저 열어둡니다.",
                "Until connectivity recovers, the app uses a conservative walk safety baseline and opens only the indoor backup flow when needed."
            )
        } else if board.riskLevel == .clear {
            policyText = localizedCopy(
                "오늘의 기본 루프는 산책 기록입니다. 악천후가 되면 그때만 실내 미션이 보조로 열려요.",
                "Today's primary loop is the walk record. Indoor missions open only as a backup when severe weather appears."
            )
        } else {
            policyText = localizedCopy(
                "오늘은 날씨 위험 때문에 산책 보조용 실내 미션이 열렸어요. `행동 +1 기록`은 실제로 끝낸 행동 1회를 남기는 체크입니다.",
                "Indoor backup missions are open today because of weather risk. `Log +1` records one action you actually completed."
            )
        }

        let lifecycleGuideText = localizedCopy(
            "실내 미션을 진행했다면 기준 횟수를 채운 뒤 `완료 확인` 또는 `보상 받기`를 눌러야 완료가 확정됩니다.",
            "If you use an indoor mission, it is finalized only after you reach the target count and confirm it."
        )

        let fallbackNotice: String?
        if status.source == .fallback {
            fallbackNotice = localizedCopy(
                "연결이 복구되면 자동으로 최신 위험도를 다시 반영합니다.",
                "When connectivity recovers, the latest risk will be applied automatically."
            )
        } else {
            fallbackNotice = nil
        }

        let appliedAtText = localizedCopy(
            "적용 시점 \(appliedTime)",
            "Applied at \(appliedTime)"
        )
        let accessibilityText = "\(badgeText). \(reasonText). \(policyText). \(lifecycleGuideText). \(appliedAtText). \(shieldText)"

        return WeatherMissionStatusSummary(
            badgeText: badgeText,
            title: localizedCopy("실내 미션 전환 요약", "Indoor Mission Shift Summary"),
            reasonText: reasonText,
            appliedAtText: appliedAtText,
            shieldUsageText: shieldText,
            policyTitle: policyTitle,
            policyText: policyText,
            lifecycleGuideText: lifecycleGuideText,
            fallbackNotice: fallbackNotice,
            accessibilityText: accessibilityText,
            isFallback: status.source == .fallback,
            riskLevel: board.riskLevel
        )
    }
}
