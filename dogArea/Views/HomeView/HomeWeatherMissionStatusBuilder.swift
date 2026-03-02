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
    ///   - now: 현재 시각입니다.
    ///   - shieldApplyCount: 당일 날씨 보호 적용 횟수입니다.
    ///   - localizedCopy: 한/영 문구를 현재 로케일에 맞춰 선택하는 함수입니다.
    /// - Returns: 홈 카드에서 바로 렌더링 가능한 `WeatherMissionStatusSummary`입니다.
    func makeStatusSummary(
        board: IndoorMissionBoard,
        status: IndoorWeatherStatus,
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
    ///   - now: 현재 시각입니다.
    ///   - shieldApplyCount: 당일 날씨 보호 적용 횟수입니다.
    ///   - localizedCopy: 한/영 문구를 현재 로케일에 맞춰 선택하는 함수입니다.
    /// - Returns: 홈 카드에서 바로 렌더링 가능한 `WeatherMissionStatusSummary`입니다.
    func makeStatusSummary(
        board: IndoorMissionBoard,
        status: IndoorWeatherStatus,
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
                "날씨 연동이 아직 준비되지 않아 기본 퀘스트로 진행합니다.",
                "Weather integration is not ready yet. Running default quests."
            )
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

        let fallbackNotice: String?
        if status.source == .fallback {
            fallbackNotice = localizedCopy(
                "연동 전에도 산책/기록/퀘스트는 정상적으로 계속됩니다.",
                "Walk, logs, and quests continue normally even before weather integration."
            )
        } else {
            fallbackNotice = nil
        }

        let appliedAtText = localizedCopy(
            "적용 시점 \(appliedTime)",
            "Applied at \(appliedTime)"
        )
        let accessibilityText = "\(badgeText). \(reasonText). \(appliedAtText). \(shieldText)"

        return WeatherMissionStatusSummary(
            badgeText: badgeText,
            title: localizedCopy("오늘 날씨 연동 상태", "Today's Weather Status"),
            reasonText: reasonText,
            appliedAtText: appliedAtText,
            shieldUsageText: shieldText,
            fallbackNotice: fallbackNotice,
            accessibilityText: accessibilityText,
            isFallback: status.source == .fallback,
            riskLevel: board.riskLevel
        )
    }
}
