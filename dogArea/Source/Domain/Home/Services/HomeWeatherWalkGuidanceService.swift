import Foundation

/// 홈 날씨 카드에서 반려견 기준 행동 가이드를 생성하는 계약입니다.
protocol HomeWeatherWalkGuidancePresenting {
    /// 날씨 스냅샷과 반려견 프로필을 바탕으로 오늘 산책 가이드를 생성합니다.
    /// - Parameters:
    ///   - snapshot: 최신 날씨 스냅샷입니다. 없으면 기본 안전 기준으로 fallback합니다.
    ///   - missionSummary: 오늘 미션/위험도 요약입니다.
    ///   - selectedPet: 현재 선택 반려견 정보입니다.
    ///   - missionContext: 최근 산책량을 포함한 반려견 컨텍스트입니다.
    ///   - now: 현재 시각입니다.
    ///   - localizedCopy: 현재 로케일에 맞는 한/영 문구를 선택하는 함수입니다.
    /// - Returns: 홈 날씨 더보기 시트가 바로 사용할 행동 가이드 프레젠테이션입니다.
    func makePresentation(
        snapshot: WeatherSnapshot?,
        missionSummary: WeatherMissionStatusSummary,
        selectedPet: PetInfo?,
        missionContext: IndoorMissionPetContext,
        now: Date,
        localizedCopy: (_ ko: String, _ en: String) -> String
    ) -> HomeWeatherGuidancePresentation
}

final class HomeWeatherWalkGuidanceService: HomeWeatherWalkGuidancePresenting {
    private enum Threshold {
        static let coldTemperatureC: Double = 4
        static let freezingFeelsLikeC: Double = 0
        static let hotFeelsLikeC: Double = 28
        static let highHumidityPercent: Double = 75
        static let highWindMps: Double = 6
        static let severeWindMps: Double = 9
        static let rainNoticeMMPerHour: Double = 0.5
        static let heavyRainMMPerHour: Double = 4
        static let badPm25: Double = 35
        static let severePm25: Double = 75
        static let badPm10: Double = 80
        static let severePm10: Double = 150
    }

    private enum PetAgeProfile: Equatable {
        case puppy
        case adult
        case senior
        case unknown

        var badgeText: String {
            switch self {
            case .puppy: return "유년기"
            case .adult: return "성견"
            case .senior: return "노령기"
            case .unknown: return "연령 정보 부족"
            }
        }
    }

    private enum PetActivityProfile: Equatable {
        case low
        case moderate
        case high

        var badgeText: String {
            switch self {
            case .low: return "최근 활동량 낮음"
            case .moderate: return "최근 활동량 보통"
            case .high: return "최근 활동량 높음"
            }
        }
    }

    private enum PetSizeProfile: Equatable {
        case small
        case medium
        case large
        case unknown

        var badgeText: String {
            switch self {
            case .small: return "소형견 추정"
            case .medium: return "중형견 추정"
            case .large: return "대형견 추정"
            case .unknown: return "체형 정보 부족"
            }
        }
    }

    private struct PetSignals {
        let displayName: String
        let breedLabel: String?
        let ageProfile: PetAgeProfile
        let activityProfile: PetActivityProfile
        let sizeProfile: PetSizeProfile
        let hasSparseProfile: Bool
    }

    /// 날씨 스냅샷과 반려견 프로필을 바탕으로 오늘 산책 가이드를 생성합니다.
    /// - Parameters:
    ///   - snapshot: 최신 날씨 스냅샷입니다. 없으면 기본 안전 기준으로 fallback합니다.
    ///   - missionSummary: 오늘 미션/위험도 요약입니다.
    ///   - selectedPet: 현재 선택 반려견 정보입니다.
    ///   - missionContext: 최근 산책량을 포함한 반려견 컨텍스트입니다.
    ///   - now: 현재 시각입니다.
    ///   - localizedCopy: 현재 로케일에 맞는 한/영 문구를 선택하는 함수입니다.
    /// - Returns: 홈 날씨 더보기 시트가 바로 사용할 행동 가이드 프레젠테이션입니다.
    func makePresentation(
        snapshot: WeatherSnapshot?,
        missionSummary: WeatherMissionStatusSummary,
        selectedPet: PetInfo?,
        missionContext: IndoorMissionPetContext,
        now: Date,
        localizedCopy: (_ ko: String, _ en: String) -> String
    ) -> HomeWeatherGuidancePresentation {
        let petSignals = makePetSignals(selectedPet: selectedPet, missionContext: missionContext)
        let sections = makeSections(
            snapshot: snapshot,
            missionSummary: missionSummary,
            petSignals: petSignals,
            localizedCopy: localizedCopy
        )
        let badges = makePetBadges(petSignals: petSignals)
        let primaryAction = makePrimaryAction(
            snapshot: snapshot,
            missionSummary: missionSummary,
            petSignals: petSignals,
            localizedCopy: localizedCopy
        )
        let decisionFactors = makeDecisionFactors(
            snapshot: snapshot,
            missionSummary: missionSummary,
            petSignals: petSignals,
            localizedCopy: localizedCopy
        )
        let observedSummary = makeObservedSummary(
            snapshot: snapshot,
            now: now,
            localizedCopy: localizedCopy
        )
        let fallbackNotice = makeProfileFallbackNotice(
            selectedPet: selectedPet,
            petSignals: petSignals,
            localizedCopy: localizedCopy
        )
        let title = localizedCopy("오늘 산책 가이드", "Today's Walk Guide")
        let subtitle = localizedCopy(
            "\(petSignals.displayName) 기준으로 오늘 날씨를 어떻게 해석하면 좋은지 정리했어요.",
            "This summarizes how today's weather affects \(petSignals.displayName)'s walk."
        )
        let profileTitle = localizedCopy(
            "선택 반려견 기준",
            "Selected Pet Context"
        )
        let footerText = localizedCopy(
            "이 안내는 제품 안전 기준을 행동으로 옮긴 요약이에요. 증상이 심하거나 평소와 다른 반응이 있으면 산책을 줄이고 필요한 도움을 바로 받아주세요.",
            "This is a product safety guide, not a medical diagnosis. If the pet shows unusual reactions, shorten the walk and seek appropriate help."
        )

        return HomeWeatherGuidancePresentation(
            title: title,
            subtitle: subtitle,
            observedSummaryText: observedSummary,
            primaryActionTitle: localizedCopy("오늘 추천", "Today's Recommendation"),
            primaryAction: primaryAction,
            decisionFactorsTitle: localizedCopy("이렇게 판단했어요", "Why This Guidance"),
            decisionFactorsSubtitle: localizedCopy(
                "오늘 날씨와 \(petSignals.displayName) 문맥을 함께 보고 판단했어요.",
                "This combines today's weather with \(petSignals.displayName)'s context."
            ),
            decisionFactors: decisionFactors,
            profileTitle: profileTitle,
            profileBadges: badges,
            profileFallbackNotice: fallbackNotice,
            sections: sections,
            footerText: footerText,
            accessibilityText: makeAccessibilityText(
                title: title,
                observedSummary: observedSummary,
                primaryAction: primaryAction,
                decisionFactors: decisionFactors,
                sections: sections
            )
        )
    }

    /// 선택 반려견 정보와 최근 활동량을 행동 가이드용 신호로 정규화합니다.
    /// - Parameters:
    ///   - selectedPet: 현재 선택 반려견 정보입니다.
    ///   - missionContext: 최근 산책 집계가 반영된 반려견 컨텍스트입니다.
    /// - Returns: 연령/활동량/체형/프로필 누락 여부를 포함한 해석 신호입니다.
    private func makePetSignals(
        selectedPet: PetInfo?,
        missionContext: IndoorMissionPetContext
    ) -> PetSignals {
        let displayName = selectedPet?.petName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty ?? "반려견"
        let breedLabel = selectedPet?.breed?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        let ageProfile: PetAgeProfile
        switch selectedPet?.ageYears {
        case let age? where age <= 1:
            ageProfile = .puppy
        case let age? where age >= 10:
            ageProfile = .senior
        case .some:
            ageProfile = .adult
        case .none:
            ageProfile = .unknown
        }

        let activityProfile: PetActivityProfile
        if missionContext.recentDailyMinutes >= 60 || missionContext.averageWeeklyWalkCount >= 10 {
            activityProfile = .high
        } else if missionContext.recentDailyMinutes <= 20 || missionContext.averageWeeklyWalkCount < 3 {
            activityProfile = .low
        } else {
            activityProfile = .moderate
        }

        let sizeProfile = inferSizeProfile(from: breedLabel)
        let hasSparseProfile = selectedPet == nil || ageProfile == .unknown || sizeProfile == .unknown

        return PetSignals(
            displayName: displayName,
            breedLabel: breedLabel,
            ageProfile: ageProfile,
            activityProfile: activityProfile,
            sizeProfile: sizeProfile,
            hasSparseProfile: hasSparseProfile
        )
    }

    /// 선택 반려견 문맥을 시트 상단 배지 배열로 변환합니다.
    /// - Parameter petSignals: 행동 가이드 규칙 계산에 사용할 반려견 신호입니다.
    /// - Returns: 시트 상단에 노출할 반려견 문맥 배지 목록입니다.
    private func makePetBadges(petSignals: PetSignals) -> [HomeWeatherGuidanceBadgePresentation] {
        var badges: [HomeWeatherGuidanceBadgePresentation] = [
            .init(id: "age", title: petSignals.ageProfile.badgeText),
            .init(id: "activity", title: petSignals.activityProfile.badgeText),
            .init(id: "size", title: petSignals.sizeProfile.badgeText)
        ]
        if let breedLabel = petSignals.breedLabel {
            badges.insert(.init(id: "breed", title: breedLabel), at: 1)
        }
        return badges
    }

    /// 오늘 산책에서 가장 먼저 따라야 할 핵심 행동 가이드를 생성합니다.
    /// - Parameters:
    ///   - snapshot: 최신 날씨 스냅샷입니다.
    ///   - missionSummary: 오늘 미션/위험도 요약입니다.
    ///   - petSignals: 정규화된 반려견 신호입니다.
    ///   - localizedCopy: 현재 로케일에 맞는 한/영 문구를 선택하는 함수입니다.
    /// - Returns: 시트 상단 행동 가이드 카드에 노출할 핵심 추천 프레젠테이션입니다.
    private func makePrimaryAction(
        snapshot: WeatherSnapshot?,
        missionSummary: WeatherMissionStatusSummary,
        petSignals: PetSignals,
        localizedCopy: (_ ko: String, _ en: String) -> String
    ) -> HomeWeatherGuidancePrimaryActionPresentation {
        guard let snapshot else {
            let title = localizedCopy("짧은 확인 산책부터 시작하세요", "Start with a short check walk")
            let body = localizedCopy(
                "관측값이 비어 있을 때는 5~10분 확인 산책으로 반응을 보고, 괜찮을 때만 거리를 조금 늘리세요.",
                "When observations are unavailable, begin with a 5–10 minute check walk and extend only if the dog stays comfortable."
            )
            return .init(
                eyebrow: localizedCopy("기본 안전 기준", "Default Safety Baseline"),
                title: title,
                body: body,
                emphasisText: localizedCopy("짧게 시작", "Short Start"),
                accessibilityText: [title, body].joined(separator: ". ")
            )
        }

        let isHotHumid = snapshot.apparentTemperatureC >= Threshold.hotFeelsLikeC || snapshot.relativeHumidityPercent >= Threshold.highHumidityPercent
        let isCold = snapshot.temperatureC <= Threshold.coldTemperatureC || snapshot.apparentTemperatureC <= Threshold.coldTemperatureC
        let hasRainOrWind = snapshot.isPrecipitating || snapshot.precipitationMMPerHour >= Threshold.rainNoticeMMPerHour || snapshot.windMps >= Threshold.highWindMps
        let shouldPreferIndoor = missionSummary.riskLevel == .severe || isSevereOutdoorRisk(snapshot)

        if shouldPreferIndoor {
            let title = localizedCopy(
                "\(petSignals.displayName)는 오늘 실내 루틴을 메인으로 잡는 편이 안전해요",
                "It is safer for \(petSignals.displayName) to treat indoor routines as the main plan today"
            )
            let body = localizedCopy(
                "실외는 배변과 컨디션 확인 중심으로만 짧게 다녀오고, 운동량은 노즈워크나 짧은 훈련으로 채워주세요.",
                "Keep outdoor time to a brief essential outing and cover activity with scent work or short training indoors."
            )
            return .init(
                eyebrow: localizedCopy("실내 우선", "Indoor First"),
                title: title,
                body: body,
                emphasisText: localizedCopy("용무 중심", "Essentials Only"),
                accessibilityText: [title, body].joined(separator: ". ")
            )
        }

        if isHotHumid {
            let title = localizedCopy(
                "\(petSignals.displayName)는 길게 한 번보다 짧게 나누어 걷는 편이 좋아요",
                "\(petSignals.displayName) is better off with short split outings than one long walk"
            )
            let body = localizedCopy(
                "그늘이 많은 짧은 코스를 먼저 잡고, 물과 휴식 지점을 기준으로 산책 시간을 나누세요.",
                "Choose short shaded loops first and split the outing around water and rest points."
            )
            return .init(
                eyebrow: localizedCopy("짧고 자주", "Short and Frequent"),
                title: title,
                body: body,
                emphasisText: localizedCopy("그늘 우선", "Shade First"),
                accessibilityText: [title, body].joined(separator: ". ")
            )
        }

        if isCold || hasRainOrWind {
            let title = localizedCopy(
                "\(petSignals.displayName)는 오늘 짧은 확인 산책이 더 잘 맞아요",
                "\(petSignals.displayName) fits a short check walk better today"
            )
            let body = localizedCopy(
                "집 근처 짧은 루프를 일정한 리듬으로 걷고, 젖은 털과 발은 바로 말려주세요.",
                "Use a short loop near home at a steady pace, then dry the coat and paws right away."
            )
            return .init(
                eyebrow: localizedCopy("짧게 확인", "Short Check"),
                title: title,
                body: body,
                emphasisText: localizedCopy("보온·건조", "Warm and Dry"),
                accessibilityText: [title, body].joined(separator: ". ")
            )
        }

        let title = localizedCopy(
            "\(petSignals.displayName)는 오늘 평소 루틴을 유지해도 괜찮아요",
            "\(petSignals.displayName) can keep the usual routine today"
        )
        let body = localizedCopy(
            "첫 몇 분 반응을 본 뒤 속도와 거리를 결정하면 충분해요. 컨디션이 좋으면 평소 코스를 유지해도 괜찮아요.",
            "Decide speed and distance after the first few minutes. If the dog feels stable, the usual route is fine."
        )
        return .init(
            eyebrow: localizedCopy("평소 루틴 가능", "Normal Routine"),
            title: title,
            body: body,
            emphasisText: localizedCopy("반응 확인 후 유지", "Confirm Then Continue"),
            accessibilityText: [title, body].joined(separator: ". ")
        )
    }

    /// 현재 가이드가 어떤 입력 신호를 근거로 만들어졌는지 칩 형태로 정리합니다.
    /// - Parameters:
    ///   - snapshot: 최신 날씨 스냅샷입니다.
    ///   - missionSummary: 오늘 미션/위험도 요약입니다.
    ///   - petSignals: 정규화된 반려견 신호입니다.
    ///   - localizedCopy: 현재 로케일에 맞는 한/영 문구를 선택하는 함수입니다.
    /// - Returns: 시트 상단 판단 근거 카드에서 노출할 칩 배열입니다.
    private func makeDecisionFactors(
        snapshot: WeatherSnapshot?,
        missionSummary: WeatherMissionStatusSummary,
        petSignals: PetSignals,
        localizedCopy: (_ ko: String, _ en: String) -> String
    ) -> [HomeWeatherGuidanceDecisionFactorPresentation] {
        var factors: [HomeWeatherGuidanceDecisionFactorPresentation] = []

        if let snapshot {
            if snapshot.apparentTemperatureC <= Threshold.coldTemperatureC {
                factors.append(.init(
                    id: "factor.weather.cold",
                    title: localizedCopy("체감 \(Int(snapshot.apparentTemperatureC.rounded()))°", "Feels like \(Int(snapshot.apparentTemperatureC.rounded()))°"),
                    tone: .weather
                ))
            }
            if snapshot.apparentTemperatureC >= Threshold.hotFeelsLikeC || snapshot.relativeHumidityPercent >= Threshold.highHumidityPercent {
                factors.append(.init(
                    id: "factor.weather.heatHumidity",
                    title: localizedCopy("습도 \(Int(snapshot.relativeHumidityPercent.rounded()))%", "Humidity \(Int(snapshot.relativeHumidityPercent.rounded()))%"),
                    tone: .weather
                ))
            }
            if snapshot.isPrecipitating || snapshot.precipitationMMPerHour >= Threshold.rainNoticeMMPerHour {
                factors.append(.init(
                    id: "factor.weather.rain",
                    title: localizedCopy("강수 \(String(format: "%.1f", snapshot.precipitationMMPerHour))mm/h", "Rain \(String(format: "%.1f", snapshot.precipitationMMPerHour))mm/h"),
                    tone: .weather
                ))
            }
            if snapshot.windMps >= Threshold.highWindMps {
                factors.append(.init(
                    id: "factor.weather.wind",
                    title: localizedCopy("바람 \(String(format: "%.1f", snapshot.windMps))m/s", "Wind \(String(format: "%.1f", snapshot.windMps))m/s"),
                    tone: .weather
                ))
            }
            if isDustHigh(snapshot) {
                factors.append(.init(
                    id: "factor.weather.dust",
                    title: localizedCopy("공기질 주의", "Air Quality Caution"),
                    tone: .weather
                ))
            }
        } else {
            factors.append(.init(
                id: "factor.fallback.observation",
                title: localizedCopy("관측값 준비 중", "Observation Pending"),
                tone: .fallback
            ))
        }

        factors.append(.init(
            id: "factor.pet.age.\(petSignals.ageProfile.badgeText)",
            title: petSignals.ageProfile.badgeText,
            tone: petSignals.ageProfile == .unknown ? .fallback : .pet
        ))
        factors.append(.init(
            id: "factor.pet.activity.\(petSignals.activityProfile.badgeText)",
            title: petSignals.activityProfile.badgeText,
            tone: .pet
        ))
        factors.append(.init(
            id: "factor.pet.size.\(petSignals.sizeProfile.badgeText)",
            title: petSignals.sizeProfile.badgeText,
            tone: petSignals.sizeProfile == .unknown ? .fallback : .pet
        ))

        if missionSummary.riskLevel == .severe {
            factors.append(.init(
                id: "factor.weather.severe",
                title: localizedCopy("실내 대체 우선 판정", "Indoor Backup Priority"),
                tone: .weather
            ))
        }

        return Array(factors.prefix(6))
    }

    /// 프로필 입력 부족 시 안전한 기본 안내 문구를 생성합니다.
    /// - Parameters:
    ///   - selectedPet: 현재 선택 반려견 정보입니다.
    ///   - petSignals: 정규화된 반려견 신호입니다.
    ///   - localizedCopy: 현재 로케일에 맞는 한/영 문구를 선택하는 함수입니다.
    /// - Returns: 프로필 보완 안내가 필요할 때만 문구를 반환합니다.
    private func makeProfileFallbackNotice(
        selectedPet: PetInfo?,
        petSignals: PetSignals,
        localizedCopy: (_ ko: String, _ en: String) -> String
    ) -> String? {
        guard petSignals.hasSparseProfile else { return nil }
        if selectedPet == nil {
            return localizedCopy(
                "활성 반려견 정보를 아직 확인하지 못해 기본 안전 기준으로 안내해요. 나이와 견종을 입력하면 더 맞춤형으로 정리할 수 있어요.",
                "The active pet profile is missing, so this uses safe default guidance. Add age and breed details for more tailored advice."
            )
        }
        return localizedCopy(
            "연령이나 견종 정보가 부족해 기본 안전 기준을 함께 사용했어요. 프로필을 보완하면 더 정확한 가이드를 보여드릴게요.",
            "Some profile details are missing, so this also applies the default safety baseline. Fill in the profile for more precise guidance."
        )
    }

    /// 시트에 노출할 행동 가이드 섹션 3종을 생성합니다.
    /// - Parameters:
    ///   - snapshot: 최신 날씨 스냅샷입니다.
    ///   - missionSummary: 오늘 미션/위험도 요약입니다.
    ///   - petSignals: 정규화된 반려견 신호입니다.
    ///   - localizedCopy: 현재 로케일에 맞는 한/영 문구를 선택하는 함수입니다.
    /// - Returns: 주의/산책 방식/실내 대체 섹션 프레젠테이션 배열입니다.
    private func makeSections(
        snapshot: WeatherSnapshot?,
        missionSummary: WeatherMissionStatusSummary,
        petSignals: PetSignals,
        localizedCopy: (_ ko: String, _ en: String) -> String
    ) -> [HomeWeatherGuidanceSectionPresentation] {
        [
            .init(
                id: "caution",
                title: localizedCopy("오늘 산책 시 주의", "Today's Caution"),
                subtitle: localizedCopy("지금 날씨에서 먼저 줄여야 할 위험만 모았어요.", "This lists the main risks to reduce first."),
                items: makeCautionItems(
                    snapshot: snapshot,
                    missionSummary: missionSummary,
                    petSignals: petSignals,
                    localizedCopy: localizedCopy
                )
            ),
            .init(
                id: "walkStyle",
                title: localizedCopy("산책 권장 방식", "Recommended Walk Style"),
                subtitle: localizedCopy("오늘은 얼마나, 어떻게 걷는 게 안전한지 정리했어요.", "This suggests a safer walk pattern for today."),
                items: makeWalkStyleItems(
                    snapshot: snapshot,
                    missionSummary: missionSummary,
                    petSignals: petSignals,
                    localizedCopy: localizedCopy
                )
            ),
            .init(
                id: "indoorAlternative",
                title: localizedCopy("실내 대체 추천", "Indoor Backup Plan"),
                subtitle: localizedCopy("실외가 애매할 때 바로 대체할 수 있는 루틴입니다.", "These are fallback routines when outdoor time is questionable."),
                items: makeIndoorAlternativeItems(
                    snapshot: snapshot,
                    missionSummary: missionSummary,
                    petSignals: petSignals,
                    localizedCopy: localizedCopy
                )
            )
        ]
    }

    /// 날씨와 반려견 기준으로 오늘 특히 주의할 행동 항목을 생성합니다.
    /// - Parameters:
    ///   - snapshot: 최신 날씨 스냅샷입니다.
    ///   - missionSummary: 오늘 미션/위험도 요약입니다.
    ///   - petSignals: 정규화된 반려견 신호입니다.
    ///   - localizedCopy: 현재 로케일에 맞는 한/영 문구를 선택하는 함수입니다.
    /// - Returns: 주의 섹션에 표시할 행동 항목 배열입니다.
    private func makeCautionItems(
        snapshot: WeatherSnapshot?,
        missionSummary: WeatherMissionStatusSummary,
        petSignals: PetSignals,
        localizedCopy: (_ ko: String, _ en: String) -> String
    ) -> [HomeWeatherGuidanceItemPresentation] {
        guard let snapshot else {
            return [
                .init(
                    id: "fallback.surface",
                    title: localizedCopy("출발 전 노면과 반응을 먼저 확인하세요", "Check the ground and the dog's reaction first"),
                    body: localizedCopy(
                        "기온 정보가 아직 없더라도 첫 몇 분은 속도를 올리지 말고 발걸음, 호흡, 떨림·헐떡임 같은 반응을 먼저 보세요.",
                        "Even without live weather, keep the first few minutes slow and watch gait, breathing, shivering, or heavy panting."
                    )
                )
            ]
        }

        var items: [HomeWeatherGuidanceItemPresentation] = []
        let isCold = snapshot.temperatureC <= Threshold.coldTemperatureC || snapshot.apparentTemperatureC <= Threshold.coldTemperatureC
        let isVeryCold = snapshot.apparentTemperatureC <= Threshold.freezingFeelsLikeC
        let hasRainOrWind = snapshot.isPrecipitating || snapshot.precipitationMMPerHour >= Threshold.rainNoticeMMPerHour || snapshot.windMps >= Threshold.highWindMps
        let isHotHumid = snapshot.apparentTemperatureC >= Threshold.hotFeelsLikeC || snapshot.relativeHumidityPercent >= Threshold.highHumidityPercent
        let badDust = isDustHigh(snapshot)

        if isCold {
            let body = localizedCopy(
                (petSignals.ageProfile == .senior || petSignals.ageProfile == .puppy || petSignals.sizeProfile == .small)
                    ? "체감 온도가 낮아 \(petSignals.displayName)는 체온을 빨리 잃을 수 있어요. 옷이나 수건을 준비하고 산책 시간을 짧게 잡으세요."
                    : "체감 온도가 낮아 출발 직후 몸이 덜 풀릴 수 있어요. 첫 몇 분은 천천히 걷고 귀가 후에는 몸을 말려주세요.",
                (petSignals.ageProfile == .senior || petSignals.ageProfile == .puppy || petSignals.sizeProfile == .small)
                    ? "Low feels-like temperature can drop \(petSignals.displayName)'s body warmth quickly. Prepare a coat or towel and keep the walk short."
                    : "Low feels-like temperature can make the first minutes stiff. Start slowly and dry the body after returning."
            )
            items.append(.init(
                id: "cold",
                title: localizedCopy(isVeryCold ? "보온 우선으로 잡으세요" : "차가운 공기 노출을 줄이세요", isVeryCold ? "Prioritize warmth" : "Reduce cold exposure"),
                body: body
            ))
        }

        if hasRainOrWind {
            items.append(.init(
                id: "rainWind",
                title: localizedCopy("젖은 털과 강한 바람을 오래 두지 마세요", "Do not keep the coat wet or exposed to wind"),
                body: localizedCopy(
                    (petSignals.sizeProfile == .small || petSignals.ageProfile == .senior)
                        ? "비나 바람이 있으면 작은 체형·노령견은 체온과 컨디션이 더 빨리 떨어질 수 있어요. 목적 없이 오래 걷지 말고 확인 위주로 짧게 마치세요."
                        : "비나 강한 바람이 이어지면 귀·발바닥·배 쪽이 먼저 불편해질 수 있어요. 코스를 짧게 잡고 젖은 부위는 빨리 말려주세요.",
                    (petSignals.sizeProfile == .small || petSignals.ageProfile == .senior)
                        ? "Rain or wind can tire small or senior dogs faster. Keep the walk short and purposeful instead of lingering outside."
                        : "Rain or strong wind can bother the ears, paws, and belly first. Shorten the route and dry wet spots quickly."
                )
            ))
        }

        if isHotHumid {
            items.append(.init(
                id: "heatHumidity",
                title: localizedCopy("헐떡임과 속도 저하를 먼저 보세요", "Watch for panting and pace drop first"),
                body: localizedCopy(
                    "체감 온도나 습도가 높으면 같은 거리도 더 힘들게 느껴져요. 그늘과 물을 먼저 확보하고, 입을 크게 벌리기 시작하면 바로 휴식하세요.",
                    "High feels-like temperature or humidity can make the same route much harder. Secure shade and water first, and stop as soon as heavy panting starts."
                )
            ))
        }

        if badDust {
            items.append(.init(
                id: "dust",
                title: localizedCopy("공기질이 나쁘면 실외 체류를 줄이세요", "Reduce outdoor exposure when air quality is poor"),
                body: localizedCopy(
                    "미세먼지가 높으면 짧은 산책도 자극이 될 수 있어요. 오래 걷기보다 용무 중심으로 짧게 마치고 실내 대체 루틴을 준비하세요.",
                    "Poor air quality can irritate even during a short walk. Prefer a quick essential outing and prepare an indoor backup routine."
                )
            ))
        }

        if items.isEmpty {
            items.append(.init(
                id: "default",
                title: localizedCopy("특별한 위험은 낮아도 출발 전 점검은 필요해요", "Even on milder days, do a quick check before leaving"),
                body: localizedCopy(
                    "오늘은 큰 위험 신호가 적지만, 노면 온도와 발바닥 상태를 확인하고 첫 몇 분은 반응을 본 뒤 거리를 늘리세요.",
                    "Today's signals look relatively calm, but still check the ground and paws first, then extend the route only after the first few minutes feel stable."
                )
            ))
        }

        if missionSummary.riskLevel == .severe {
            items.append(.init(
                id: "missionRisk",
                title: localizedCopy("오늘 판정은 고위험 악천후예요", "Today's mission state is severe weather"),
                body: localizedCopy(
                    "제품 기준으로는 실외 목표보다 안전 확보가 우선이에요. 꼭 나가야 한다면 짧은 확인 산책만 하고 실내 대체를 바로 이어가세요.",
                    "By product policy, safety comes before outdoor goals. If you must go out, keep it to a brief check walk and switch to indoor alternatives immediately."
                )
            ))
        }

        return items
    }

    /// 오늘 날씨와 반려견 상태에 맞는 산책 방식 가이드를 생성합니다.
    /// - Parameters:
    ///   - snapshot: 최신 날씨 스냅샷입니다.
    ///   - missionSummary: 오늘 미션/위험도 요약입니다.
    ///   - petSignals: 정규화된 반려견 신호입니다.
    ///   - localizedCopy: 현재 로케일에 맞는 한/영 문구를 선택하는 함수입니다.
    /// - Returns: 산책 방식 섹션에 표시할 행동 항목 배열입니다.
    private func makeWalkStyleItems(
        snapshot: WeatherSnapshot?,
        missionSummary: WeatherMissionStatusSummary,
        petSignals: PetSignals,
        localizedCopy: (_ ko: String, _ en: String) -> String
    ) -> [HomeWeatherGuidanceItemPresentation] {
        guard let snapshot else {
            return [
                .init(
                    id: "fallback.short",
                    title: localizedCopy("짧게 시작해 컨디션을 확인하세요", "Start short and confirm condition"),
                    body: localizedCopy(
                        "날씨 스냅샷이 비어 있을 때는 5~10분 확인 산책부터 시작하고, 괜찮을 때만 코스를 조금 늘리세요.",
                        "When the weather snapshot is empty, begin with a 5–10 minute check walk and extend only if the dog stays comfortable."
                    )
                )
            ]
        }

        var items: [HomeWeatherGuidanceItemPresentation] = []
        let isIndoorFirst = missionSummary.riskLevel == .severe || isSevereOutdoorRisk(snapshot)
        if isIndoorFirst {
            items.append(.init(
                id: "walkStyle.indoorFirst",
                title: localizedCopy("오늘은 확인 산책만 짧게 권장해요", "Today favors a brief check walk only"),
                body: localizedCopy(
                    "용무 중심으로 짧게 다녀오고, 운동량은 실내 놀이와 훈련으로 채우는 편이 더 안전해요.",
                    "Keep outdoor time to a brief essential outing and cover the rest of the activity with indoor play or training."
                )
            ))
        } else if snapshot.apparentTemperatureC >= Threshold.hotFeelsLikeC || snapshot.relativeHumidityPercent >= Threshold.highHumidityPercent {
            items.append(.init(
                id: "walkStyle.heat",
                title: localizedCopy("짧고 자주 나누어 걸으세요", "Split the walk into short, frequent outings"),
                body: localizedCopy(
                    petSignals.activityProfile == .high
                        ? "활동량이 높은 편이라도 오늘은 한 번에 길게 걷기보다 짧은 코스를 2회로 나누는 편이 안전해요."
                        : "오늘은 긴 한 번보다 짧은 여러 번이 더 안전해요. 그늘이 많은 코스와 쉬는 지점을 먼저 잡아두세요.",
                    petSignals.activityProfile == .high
                        ? "Even with a high activity profile, today is safer as two short outings than one long walk."
                        : "Today is safer as several short outings than one long route. Pick shaded paths and rest points first."
                )
            ))
        } else if snapshot.isPrecipitating || snapshot.windMps >= Threshold.highWindMps || snapshot.temperatureC <= Threshold.coldTemperatureC {
            items.append(.init(
                id: "walkStyle.compact",
                title: localizedCopy("짧은 코스를 일정한 리듬으로 걸으세요", "Use a compact route with a steady pace"),
                body: localizedCopy(
                    "우회 코스보다 집 근처 짧은 루프가 좋아요. 멈춰 서는 시간을 줄이고, 불편해 보이면 바로 귀가할 수 있게 동선을 짜세요.",
                    "A short loop near home is better than a long detour. Keep a steady pace and stay close enough to return immediately if needed."
                )
            ))
        } else {
            items.append(.init(
                id: "walkStyle.default",
                title: localizedCopy("오늘은 평소 루틴을 유지해도 괜찮아요", "Your normal routine is reasonable today"),
                body: localizedCopy(
                    petSignals.activityProfile == .low
                        ? "다만 최근 활동량이 낮은 편이라 처음엔 냄새 맡기와 천천한 걷기로 몸을 깨우고, 반응이 좋을 때만 시간을 늘리세요."
                        : "오늘은 평소 코스를 유지하되 첫 몇 분 반응을 보고 속도와 거리를 결정하면 충분해요.",
                    petSignals.activityProfile == .low
                        ? "Recent activity is low, so wake the body up with sniffing and a slow start before extending time."
                        : "You can keep the usual route today, as long as you decide speed and distance after the first few minutes."
                )
            ))
        }

        items.append(.init(
            id: "walkStyle.water",
            title: localizedCopy("물과 닦을 수건은 기본으로 챙기세요", "Carry water and a towel by default"),
            body: localizedCopy(
                "온도, 비, 먼지 조건이 자주 바뀌기 때문에 짧은 산책이라도 물과 닦을 수건을 함께 준비해두면 대응이 빨라져요.",
                "Temperature, rain, and air quality can shift quickly. Even on a short walk, carrying water and a towel makes responses faster."
            )
        ))
        return items
    }

    /// 실외를 줄여야 할 때 바로 대체할 실내 루틴 가이드를 생성합니다.
    /// - Parameters:
    ///   - snapshot: 최신 날씨 스냅샷입니다.
    ///   - missionSummary: 오늘 미션/위험도 요약입니다.
    ///   - petSignals: 정규화된 반려견 신호입니다.
    ///   - localizedCopy: 현재 로케일에 맞는 한/영 문구를 선택하는 함수입니다.
    /// - Returns: 실내 대체 섹션에 표시할 행동 항목 배열입니다.
    private func makeIndoorAlternativeItems(
        snapshot: WeatherSnapshot?,
        missionSummary: WeatherMissionStatusSummary,
        petSignals: PetSignals,
        localizedCopy: (_ ko: String, _ en: String) -> String
    ) -> [HomeWeatherGuidanceItemPresentation] {
        let shouldPreferIndoor = snapshot.map(isSevereOutdoorRisk(_:)) ?? false || missionSummary.riskLevel == .severe
        var items: [HomeWeatherGuidanceItemPresentation] = []

        items.append(.init(
            id: "indoor.sniff",
            title: localizedCopy("노즈워크나 찾기 놀이로 에너지를 분산하세요", "Use scent work or search games to spread the energy"),
            body: localizedCopy(
                petSignals.activityProfile == .high
                    ? "최근 활동량이 높은 편이라면 실외 한 번 대신 짧은 노즈워크 여러 라운드가 더 안정적이에요."
                    : "짧은 간식 찾기나 장난감 찾기만으로도 산책이 줄었을 때 답답함을 덜 수 있어요.",
                petSignals.activityProfile == .high
                    ? "With a high activity profile, several short scent-work rounds are more stable than forcing a long outdoor session."
                    : "Even a short treat or toy search can reduce frustration when outdoor time is cut back."
            )
        ))

        items.append(.init(
            id: "indoor.training",
            title: localizedCopy("짧은 훈련 루틴으로 산책 대체를 연결하세요", "Bridge the missing walk with a short training routine"),
            body: localizedCopy(
                petSignals.ageProfile == .senior
                    ? "노령견은 무리한 점프보다 기다려·터치 같은 저충격 훈련이 좋아요."
                    : "기다려, 손, 하우스처럼 짧고 성공이 쉬운 훈련을 3~5분 단위로 끊어 진행해보세요.",
                petSignals.ageProfile == .senior
                    ? "For senior dogs, low-impact cues like wait or touch are safer than anything jump-heavy."
                    : "Use short 3–5 minute routines with easy-success cues such as wait, paw, or house."
            )
        ))

        if shouldPreferIndoor {
            items.append(.init(
                id: "indoor.first",
                title: localizedCopy("오늘은 실내 루틴을 메인으로 잡는 편이 안전해요", "Today is safer with indoor routines as the main plan"),
                body: localizedCopy(
                    "고위험 악천후나 공기질 저하가 겹치면 산책 가치를 실외에서만 찾지 않는 편이 좋아요. 용무 산책만 짧게 하고 바로 실내 루틴으로 전환하세요.",
                    "When severe weather or poor air quality stacks up, do not force outdoor value. Keep outdoor time to essentials and switch indoors immediately."
                )
            ))
        }

        return items
    }

    /// 카드/시트 상단에 노출할 관측 요약 한 줄을 생성합니다.
    /// - Parameters:
    ///   - snapshot: 최신 날씨 스냅샷입니다.
    ///   - now: 현재 시각입니다.
    ///   - localizedCopy: 현재 로케일에 맞는 한/영 문구를 선택하는 함수입니다.
    /// - Returns: 체감 온도, 강수, 바람, 공기질 상태를 요약한 문자열입니다.
    private func makeObservedSummary(
        snapshot: WeatherSnapshot?,
        now: Date,
        localizedCopy: (_ ko: String, _ en: String) -> String
    ) -> String {
        guard let snapshot else {
            return localizedCopy(
                "최신 관측값이 아직 없어 기본 안전 기준으로 먼저 안내해요.",
                "The latest observation is not ready yet, so this starts from the default safety baseline."
            )
        }
        let observedMinutes = max(0, Int((now.timeIntervalSince1970 - snapshot.observedAt) / 60.0))
        let rainText = snapshot.isPrecipitating || snapshot.precipitationMMPerHour >= Threshold.rainNoticeMMPerHour
            ? localizedCopy("비 영향 있음", "Rain present")
            : localizedCopy("강수 영향 낮음", "Low rain impact")
        let airText = isDustHigh(snapshot)
            ? localizedCopy("공기질 주의", "Air quality caution")
            : localizedCopy("공기질 보통", "Air quality stable")
        return localizedCopy(
            "체감 \(Int(snapshot.apparentTemperatureC.rounded()))° · \(rainText) · 바람 \(String(format: "%.1f", snapshot.windMps))m/s · \(airText) · \(observedMinutes)분 전 갱신",
            "Feels like \(Int(snapshot.apparentTemperatureC.rounded()))° · \(rainText) · wind \(String(format: "%.1f", snapshot.windMps))m/s · \(airText) · updated \(observedMinutes)m ago"
        )
    }

    /// 시트 전체 내용을 접근성 한 문장으로 합칩니다.
    /// - Parameters:
    ///   - title: 시트 제목입니다.
    ///   - observedSummary: 관측 요약 한 줄입니다.
    ///   - sections: 시트에 노출할 가이드 섹션 배열입니다.
    /// - Returns: VoiceOver가 읽을 전체 요약 문자열입니다.
    private func makeAccessibilityText(
        title: String,
        observedSummary: String,
        primaryAction: HomeWeatherGuidancePrimaryActionPresentation,
        decisionFactors: [HomeWeatherGuidanceDecisionFactorPresentation],
        sections: [HomeWeatherGuidanceSectionPresentation]
    ) -> String {
        let factorText = decisionFactors.map(\.title).joined(separator: ". ")
        let sectionText = sections
            .flatMap { section in
                [section.title, section.subtitle] + section.items.flatMap { [$0.title, $0.body] }
            }
            .joined(separator: ". ")
        return [title, observedSummary, primaryAction.accessibilityText, factorText, sectionText].joined(separator: ". ")
    }

    /// 견종 문자열에서 대략적인 체형 분류를 추정합니다.
    /// - Parameter breedLabel: 사용자가 입력한 견종 문자열입니다.
    /// - Returns: 소형/중형/대형/미상 중 하나입니다.
    private func inferSizeProfile(from breedLabel: String?) -> PetSizeProfile {
        guard let breedLabel = breedLabel?.lowercased(), breedLabel.isEmpty == false else {
            return .unknown
        }

        let smallKeywords = ["말티", "maltese", "치와와", "chihuahua", "포메", "pomeranian", "비숑", "bichon", "요크", "york", "시츄", "shih", "토이", "toy", "닥스", "dachsh"]
        if smallKeywords.contains(where: { breedLabel.contains($0) }) {
            return .small
        }

        let largeKeywords = ["리트리버", "retriever", "허스키", "husky", "셰퍼드", "shepherd", "말라뮤트", "malamute", "도베르만", "doberman", "로트와일러", "rott", "사모예드", "samoyed", "래브라도", "labrador"]
        if largeKeywords.contains(where: { breedLabel.contains($0) }) {
            return .large
        }
        return .medium
    }

    /// 공기질이 산책 가이드를 바꿔야 할 정도로 높아졌는지 판단합니다.
    /// - Parameter snapshot: 최신 날씨 스냅샷입니다.
    /// - Returns: PM2.5 또는 PM10이 주의 이상이면 `true`입니다.
    private func isDustHigh(_ snapshot: WeatherSnapshot) -> Bool {
        (snapshot.pm2_5 ?? 0) >= Threshold.badPm25 || (snapshot.pm10 ?? 0) >= Threshold.badPm10
    }

    /// 실외보다 실내 대체를 우선할 정도의 강한 기상 위험인지 판단합니다.
    /// - Parameter snapshot: 최신 날씨 스냅샷입니다.
    /// - Returns: 폭우/강풍/심한 공기질/혹한/폭염 중 하나라도 만족하면 `true`입니다.
    private func isSevereOutdoorRisk(_ snapshot: WeatherSnapshot) -> Bool {
        snapshot.apparentTemperatureC <= Threshold.freezingFeelsLikeC
            || snapshot.apparentTemperatureC >= Threshold.hotFeelsLikeC + 3
            || snapshot.windMps >= Threshold.severeWindMps
            || snapshot.precipitationMMPerHour >= Threshold.heavyRainMMPerHour
            || (snapshot.pm2_5 ?? 0) >= Threshold.severePm25
            || (snapshot.pm10 ?? 0) >= Threshold.severePm10
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
