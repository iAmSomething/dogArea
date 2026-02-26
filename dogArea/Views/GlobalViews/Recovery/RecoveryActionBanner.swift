//
//  RecoveryActionBanner.swift
//  dogArea
//
//  Created by Codex on 2/26/26.
//

import SwiftUI
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
    static func openAppSettings() {
        #if canImport(UIKit)
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
        #endif
    }
}

struct RecoveryActionBanner: View {
    let issue: RecoveryIssue
    let onPrimary: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(issue.title)
                .font(.appFont(for: .SemiBold, size: 13))
            Text(issue.message)
                .font(.appFont(for: .Light, size: 11))
                .foregroundStyle(Color.appTextDarkGray)
            HStack(spacing: 10) {
                Button(issue.primaryButtonTitle) {
                    onPrimary()
                }
                .font(.appFont(for: .SemiBold, size: 11))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.appYellow)
                .cornerRadius(8)

                Button("닫기") {
                    onDismiss()
                }
                .font(.appFont(for: .SemiBold, size: 11))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.appYellowPale)
                .cornerRadius(8)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.95))
        .cornerRadius(12)
        .padding(.horizontal, 12)
    }
}

#Preview("snapshot-permission-denied") {
    RecoveryActionBanner(
        issue: .init(kind: .locationPermissionDenied, detail: nil),
        onPrimary: {},
        onDismiss: {}
    )
}

#Preview("snapshot-network-offline") {
    RecoveryActionBanner(
        issue: .init(kind: .networkOffline, detail: nil),
        onPrimary: {},
        onDismiss: {}
    )
}

#Preview("snapshot-auth-expired") {
    RecoveryActionBanner(
        issue: .init(kind: .authExpired, detail: nil),
        onPrimary: {},
        onDismiss: {}
    )
}
