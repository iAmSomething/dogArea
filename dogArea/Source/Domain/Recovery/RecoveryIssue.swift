import Foundation
#if canImport(UIKit)
import UIKit
#endif

enum RecoveryIssueKind: Equatable {
    case locationPermissionDenied
    case networkOffline
    case authExpired
}

struct RecoveryIssue: Identifiable, Equatable {
    let kind: RecoveryIssueKind
    let detail: String?

    var id: String {
        "\(kind)-\(detail ?? "")"
    }

    var title: String {
        switch kind {
        case .locationPermissionDenied:
            return "위치 권한이 필요해요"
        case .networkOffline:
            return "오프라인 모드"
        case .authExpired:
            return "인증이 만료됐어요"
        }
    }

    var message: String {
        switch kind {
        case .locationPermissionDenied:
            return "설정에서 위치 권한을 허용하면 산책 기록을 계속할 수 있어요."
        case .networkOffline:
            return "지금 기록은 기기에 저장되고, 온라인 복귀 시 자동 동기화돼요."
        case .authExpired:
            return "다시 로그인하면 현재 화면으로 돌아와서 이어서 진행할 수 있어요."
        }
    }

    var primaryButtonTitle: String {
        switch kind {
        case .locationPermissionDenied:
            return "설정 열기"
        case .networkOffline:
            return "다시 시도"
        case .authExpired:
            return "다시 로그인"
        }
    }
}

enum RecoveryIssueClassifier {
    /// 동기화 에러 코드를 바탕으로 복구 배너 이슈를 분류합니다.
    /// - Parameter rawValue: 동기화 아웃박스에서 전달된 원본 에러 코드 문자열입니다.
    /// - Returns: 매핑 가능한 경우 복구 이슈, 불가능하면 `nil`입니다.
    static func fromSyncErrorCode(_ rawValue: String?) -> RecoveryIssue? {
        guard let rawValue, rawValue.isEmpty == false else { return nil }
        switch rawValue {
        case SyncOutboxErrorCode.offline.rawValue:
            return RecoveryIssue(kind: .networkOffline, detail: rawValue)
        case SyncOutboxErrorCode.tokenExpired.rawValue, SyncOutboxErrorCode.unauthorized.rawValue:
            return RecoveryIssue(kind: .authExpired, detail: rawValue)
        default:
            return nil
        }
    }

    /// 일반 에러 메시지 문자열에서 복구 이슈를 추론합니다.
    /// - Parameter raw: 네트워크/인증 키워드를 포함할 수 있는 원본 에러 메시지입니다.
    /// - Returns: 추론 가능한 복구 이슈, 추론 불가하면 `nil`입니다.
    static func fromErrorMessage(_ raw: String?) -> RecoveryIssue? {
        guard let raw else { return nil }
        let normalized = raw.lowercased()
        if normalized.contains("network"),
           normalized.contains("offline") || normalized.contains("internet") {
            return RecoveryIssue(kind: .networkOffline, detail: raw)
        }
        if normalized.contains("token") || normalized.contains("unauthorized") || normalized.contains("auth") {
            return RecoveryIssue(kind: .authExpired, detail: raw)
        }
        return nil
    }
}

enum RecoverySystemAction {
    /// 앱 설정 화면을 열어 사용자가 권한 문제를 직접 복구할 수 있게 합니다.
    static func openAppSettings() {
        #if canImport(UIKit)
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
        #endif
    }
}
