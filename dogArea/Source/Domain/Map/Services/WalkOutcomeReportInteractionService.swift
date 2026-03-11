import Foundation

enum WalkOutcomeReportSurface: String {
    case mapSavedCard = "map_saved_card"
    case walkListDetail = "walklist_detail"
}

enum WalkOutcomeReportDisclosureSection: String {
    case exclusions
    case connections
    case contribution
}

protocol WalkOutcomeReportInteracting {
    /// 결과 리포트 surface가 사용자에게 처음 노출된 시점을 기록합니다.
    /// - Parameters:
    ///   - surface: 결과 리포트가 노출된 화면 surface입니다.
    ///   - context: surface 공통 analytics context입니다.
    ///   - userKey: metric 수집에 사용할 사용자 식별자입니다.
    func trackPresented(
        surface: WalkOutcomeReportSurface,
        context: WalkOutcomeReportAnalyticsContext,
        userKey: String?
    )

    /// 결과 리포트 surface가 명시적으로 닫힌 시점을 기록합니다.
    /// - Parameters:
    ///   - surface: 닫힌 결과 리포트 화면 surface입니다.
    ///   - context: surface 공통 analytics context입니다.
    ///   - dismissalSource: 닫기 액션 출처입니다.
    ///   - userKey: metric 수집에 사용할 사용자 식별자입니다.
    func trackDismissed(
        surface: WalkOutcomeReportSurface,
        context: WalkOutcomeReportAnalyticsContext,
        dismissalSource: String,
        userKey: String?
    )

    /// 저장 직후 카드에서 산책 목록 히스토리로 이동한 시점을 기록합니다.
    /// - Parameters:
    ///   - surface: 이동이 발생한 결과 리포트 surface입니다.
    ///   - context: surface 공통 analytics context입니다.
    ///   - userKey: metric 수집에 사용할 사용자 식별자입니다.
    func trackHistoryOpened(
        surface: WalkOutcomeReportSurface,
        context: WalkOutcomeReportAnalyticsContext,
        userKey: String?
    )

    /// 결과 리포트에서 상세 화면으로 진입한 시점을 기록합니다.
    /// - Parameters:
    ///   - surface: 상세 진입이 발생한 결과 리포트 surface입니다.
    ///   - context: surface 공통 analytics context입니다.
    ///   - userKey: metric 수집에 사용할 사용자 식별자입니다.
    func trackDetailOpened(
        surface: WalkOutcomeReportSurface,
        context: WalkOutcomeReportAnalyticsContext,
        userKey: String?
    )

    /// 상세 결과 리포트의 disclosure 토글 변화를 기록합니다.
    /// - Parameters:
    ///   - section: 사용자가 펼치거나 접은 결과 리포트 section입니다.
    ///   - isExpanded: 토글 이후 펼침 상태입니다.
    ///   - surface: 토글이 일어난 결과 리포트 surface입니다.
    ///   - context: surface 공통 analytics context입니다.
    ///   - userKey: metric 수집에 사용할 사용자 식별자입니다.
    func trackDisclosureToggle(
        section: WalkOutcomeReportDisclosureSection,
        isExpanded: Bool,
        surface: WalkOutcomeReportSurface,
        context: WalkOutcomeReportAnalyticsContext,
        userKey: String?
    )

    /// 사용자가 결과 리포트에서 문의 경로를 요청한 시점을 기록합니다.
    /// - Parameters:
    ///   - surface: 문의 경로 요청이 발생한 결과 리포트 surface입니다.
    ///   - context: surface 공통 analytics context입니다.
    ///   - channel: 실제 문의 채널 식별자입니다.
    ///   - userKey: metric 수집에 사용할 사용자 식별자입니다.
    func trackInquiryOpened(
        surface: WalkOutcomeReportSurface,
        context: WalkOutcomeReportAnalyticsContext,
        channel: String,
        userKey: String?
    )

    /// 결과 리포트 기반 지원 문의 메일 `URL`을 생성합니다.
    /// - Parameters:
    ///   - surface: 문의가 시작된 결과 리포트 surface입니다.
    ///   - context: surface 공통 analytics context입니다.
    ///   - walkCreatedAt: 문의 대상 산책의 시작 시각입니다.
    ///   - walkDurationText: 문의 대상 산책 시간 문자열입니다.
    ///   - areaText: 문의 대상 산책 영역 문자열입니다.
    ///   - pointCount: 문의 대상 산책 포인트 수입니다.
    ///   - currentUserId: 현재 사용자 식별자입니다.
    /// - Returns: 시스템 메일 앱으로 연결할 문의 `URL`입니다.
    func makeInquiryURL(
        surface: WalkOutcomeReportSurface,
        context: WalkOutcomeReportAnalyticsContext,
        walkCreatedAt: TimeInterval,
        walkDurationText: String,
        areaText: String,
        pointCount: Int,
        currentUserId: String?
    ) -> URL?
}

struct WalkOutcomeReportInteractionService: WalkOutcomeReportInteracting {
    private let metricTracker: AppMetricTracker
    private let metadataProvider: SettingsAppMetadataProviding
    private let isoFormatter: ISO8601DateFormatter

    /// 결과 리포트 interaction 서비스 의존성을 구성합니다.
    /// - Parameters:
    ///   - metricTracker: 결과 리포트 telemetry를 전송할 metric 추적기입니다.
    ///   - metadataProvider: 문의 메일 작성에 쓸 앱 메타데이터 공급자입니다.
    ///   - isoFormatter: 산책 시작 시각을 고정 포맷으로 직렬화할 formatter입니다.
    init(
        metricTracker: AppMetricTracker = .shared,
        metadataProvider: SettingsAppMetadataProviding = SettingsAppMetadataService(),
        isoFormatter: ISO8601DateFormatter = {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
            return formatter
        }()
    ) {
        self.metricTracker = metricTracker
        self.metadataProvider = metadataProvider
        self.isoFormatter = isoFormatter
    }

    /// 결과 리포트 surface가 사용자에게 처음 노출된 시점을 기록합니다.
    /// - Parameters:
    ///   - surface: 결과 리포트가 노출된 화면 surface입니다.
    ///   - context: surface 공통 analytics context입니다.
    ///   - userKey: metric 수집에 사용할 사용자 식별자입니다.
    func trackPresented(
        surface: WalkOutcomeReportSurface,
        context: WalkOutcomeReportAnalyticsContext,
        userKey: String?
    ) {
        track(.walkOutcomeReportPresented, surface: surface, context: context, userKey: userKey)
    }

    /// 결과 리포트 surface가 명시적으로 닫힌 시점을 기록합니다.
    /// - Parameters:
    ///   - surface: 닫힌 결과 리포트 화면 surface입니다.
    ///   - context: surface 공통 analytics context입니다.
    ///   - dismissalSource: 닫기 액션 출처입니다.
    ///   - userKey: metric 수집에 사용할 사용자 식별자입니다.
    func trackDismissed(
        surface: WalkOutcomeReportSurface,
        context: WalkOutcomeReportAnalyticsContext,
        dismissalSource: String,
        userKey: String?
    ) {
        track(
            .walkOutcomeReportDismissed,
            surface: surface,
            context: context,
            userKey: userKey,
            extraPayload: ["dismissal_source": dismissalSource]
        )
    }

    /// 저장 직후 카드에서 산책 목록 히스토리로 이동한 시점을 기록합니다.
    /// - Parameters:
    ///   - surface: 이동이 발생한 결과 리포트 surface입니다.
    ///   - context: surface 공통 analytics context입니다.
    ///   - userKey: metric 수집에 사용할 사용자 식별자입니다.
    func trackHistoryOpened(
        surface: WalkOutcomeReportSurface,
        context: WalkOutcomeReportAnalyticsContext,
        userKey: String?
    ) {
        track(.walkOutcomeReportHistoryOpened, surface: surface, context: context, userKey: userKey)
    }

    /// 결과 리포트에서 상세 화면으로 진입한 시점을 기록합니다.
    /// - Parameters:
    ///   - surface: 상세 진입이 발생한 결과 리포트 surface입니다.
    ///   - context: surface 공통 analytics context입니다.
    ///   - userKey: metric 수집에 사용할 사용자 식별자입니다.
    func trackDetailOpened(
        surface: WalkOutcomeReportSurface,
        context: WalkOutcomeReportAnalyticsContext,
        userKey: String?
    ) {
        track(.walkOutcomeReportDetailOpened, surface: surface, context: context, userKey: userKey)
    }

    /// 상세 결과 리포트의 disclosure 토글 변화를 기록합니다.
    /// - Parameters:
    ///   - section: 사용자가 펼치거나 접은 결과 리포트 section입니다.
    ///   - isExpanded: 토글 이후 펼침 상태입니다.
    ///   - surface: 토글이 일어난 결과 리포트 surface입니다.
    ///   - context: surface 공통 analytics context입니다.
    ///   - userKey: metric 수집에 사용할 사용자 식별자입니다.
    func trackDisclosureToggle(
        section: WalkOutcomeReportDisclosureSection,
        isExpanded: Bool,
        surface: WalkOutcomeReportSurface,
        context: WalkOutcomeReportAnalyticsContext,
        userKey: String?
    ) {
        track(
            .walkOutcomeReportDisclosureToggled,
            surface: surface,
            context: context,
            userKey: userKey,
            extraPayload: [
                "section": section.rawValue,
                "is_expanded": isExpanded ? "true" : "false"
            ]
        )
    }

    /// 사용자가 결과 리포트에서 문의 경로를 요청한 시점을 기록합니다.
    /// - Parameters:
    ///   - surface: 문의 경로 요청이 발생한 결과 리포트 surface입니다.
    ///   - context: surface 공통 analytics context입니다.
    ///   - channel: 실제 문의 채널 식별자입니다.
    ///   - userKey: metric 수집에 사용할 사용자 식별자입니다.
    func trackInquiryOpened(
        surface: WalkOutcomeReportSurface,
        context: WalkOutcomeReportAnalyticsContext,
        channel: String,
        userKey: String?
    ) {
        track(
            .walkOutcomeReportInquiryOpened,
            surface: surface,
            context: context,
            userKey: userKey,
            extraPayload: ["channel": channel]
        )
    }

    /// 결과 리포트 기반 지원 문의 메일 `URL`을 생성합니다.
    /// - Parameters:
    ///   - surface: 문의가 시작된 결과 리포트 surface입니다.
    ///   - context: surface 공통 analytics context입니다.
    ///   - walkCreatedAt: 문의 대상 산책의 시작 시각입니다.
    ///   - walkDurationText: 문의 대상 산책 시간 문자열입니다.
    ///   - areaText: 문의 대상 산책 영역 문자열입니다.
    ///   - pointCount: 문의 대상 산책 포인트 수입니다.
    ///   - currentUserId: 현재 사용자 식별자입니다.
    /// - Returns: 시스템 메일 앱으로 연결할 문의 `URL`입니다.
    func makeInquiryURL(
        surface: WalkOutcomeReportSurface,
        context: WalkOutcomeReportAnalyticsContext,
        walkCreatedAt: TimeInterval,
        walkDurationText: String,
        areaText: String,
        pointCount: Int,
        currentUserId: String?
    ) -> URL? {
        let metadata = metadataProvider.loadMetadata(currentIdentity: nil)
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = metadata.supportEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: "[DogArea 산책 결과 설명 문의] \(context.summaryState.rawValue)"),
            URLQueryItem(
                name: "body",
                value: inquiryBody(
                    surface: surface,
                    context: context,
                    walkCreatedAt: walkCreatedAt,
                    walkDurationText: walkDurationText,
                    areaText: areaText,
                    pointCount: pointCount,
                    currentUserId: currentUserId,
                    metadata: metadata
                )
            )
        ]
        return components.url ?? metadata.repositoryURL
    }

    /// 공통 결과 리포트 metric payload를 조립해 추적기로 전송합니다.
    /// - Parameters:
    ///   - event: 기록할 결과 리포트 metric 이벤트입니다.
    ///   - surface: 이벤트가 발생한 결과 리포트 surface입니다.
    ///   - context: surface 공통 analytics context입니다.
    ///   - userKey: metric 수집에 사용할 사용자 식별자입니다.
    ///   - extraPayload: 이벤트별 추가 payload입니다.
    private func track(
        _ event: AppMetricEvent,
        surface: WalkOutcomeReportSurface,
        context: WalkOutcomeReportAnalyticsContext,
        userKey: String?,
        extraPayload: [String: String] = [:]
    ) {
        metricTracker.track(
            event,
            userKey: userKey,
            featureKey: .heatmapV1,
            payload: makeBasePayload(surface: surface, context: context).merging(extraPayload) { _, latest in latest }
        )
    }

    /// surface 간 공통 분석 축을 metric payload 문자열 맵으로 변환합니다.
    /// - Parameters:
    ///   - surface: 이벤트가 발생한 결과 리포트 surface입니다.
    ///   - context: surface 공통 analytics context입니다.
    /// - Returns: 결과 리포트 interaction에 공통으로 붙일 payload입니다.
    private func makeBasePayload(
        surface: WalkOutcomeReportSurface,
        context: WalkOutcomeReportAnalyticsContext
    ) -> [String: String] {
        let topReasons = context.topExclusionReasonIDs.map(\.rawValue)
        return [
            "surface": surface.rawValue,
            "summary_state": context.summaryState.rawValue,
            "applied_point_count": String(context.appliedPointCount),
            "applied_point_bucket": context.appliedPointBucket,
            "excluded_point_count": String(context.excludedPointCount),
            "excluded_ratio_bucket": context.excludedRatioBucket,
            "top_exclusion_reasons": topReasons.isEmpty ? "none" : topReasons.joined(separator: ","),
            "primary_exclusion_reason": topReasons.first ?? "none",
            "record_connection_status": context.recordConnectionStatus.rawValue,
            "territory_connection_status": context.territoryConnectionStatus.rawValue,
            "season_connection_status": context.seasonConnectionStatus.rawValue,
            "quest_connection_status": context.questConnectionStatus.rawValue,
            "connection_state_key": context.connectionStateKey,
            "calculation_source_version": context.calculationSourceVersion
        ]
    }

    /// 문의 메일 본문을 결과 리포트 분석 축과 함께 조립합니다.
    /// - Parameters:
    ///   - surface: 문의가 시작된 결과 리포트 surface입니다.
    ///   - context: surface 공통 analytics context입니다.
    ///   - walkCreatedAt: 문의 대상 산책의 시작 시각입니다.
    ///   - walkDurationText: 문의 대상 산책 시간 문자열입니다.
    ///   - areaText: 문의 대상 산책 영역 문자열입니다.
    ///   - pointCount: 문의 대상 산책 포인트 수입니다.
    ///   - currentUserId: 현재 사용자 식별자입니다.
    ///   - metadata: 앱 메타데이터입니다.
    /// - Returns: 메일 본문 문자열입니다.
    private func inquiryBody(
        surface: WalkOutcomeReportSurface,
        context: WalkOutcomeReportAnalyticsContext,
        walkCreatedAt: TimeInterval,
        walkDurationText: String,
        areaText: String,
        pointCount: Int,
        currentUserId: String?,
        metadata: SettingsAppMetadata
    ) -> String {
        let startedAtText = isoFormatter.string(from: Date(timeIntervalSince1970: walkCreatedAt))
        let topReasons = context.topExclusionReasonIDs.map(\.rawValue).joined(separator: ",")
        return """
        어떤 부분이 이해되지 않았는지 적어주세요.

        [결과 리포트 분석 정보]
        surface: \(surface.rawValue)
        summary_state: \(context.summaryState.rawValue)
        applied_point_count: \(context.appliedPointCount)
        excluded_point_count: \(context.excludedPointCount)
        excluded_ratio_bucket: \(context.excludedRatioBucket)
        top_exclusion_reasons: \(topReasons.isEmpty ? "none" : topReasons)
        connection_state_key: \(context.connectionStateKey)
        calculation_source_version: \(context.calculationSourceVersion)

        [산책 정보]
        started_at: \(startedAtText)
        duration: \(walkDurationText)
        area: \(areaText)
        point_count: \(pointCount)

        [앱 정보]
        app_version: \(metadata.version)
        build: \(metadata.build)
        bundle_id: \(metadata.bundleIdentifier)
        current_user_id: \(currentUserId ?? "guest")
        """
    }
}
