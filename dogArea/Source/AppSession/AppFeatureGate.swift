//
//  AppFeatureGate.swift
//  dogArea
//

import Foundation

enum AppSessionState: Equatable {
    case guest
    case member(userId: String)

    var isMember: Bool {
        if case .member = self { return true }
        return false
    }
}

enum FeatureCapability: String, CaseIterable {
    case walkRead = "walk_read"
    case walkWrite = "walk_write"
    case cloudSync = "cloud_sync"
    case aiGeneration = "ai_generation"
    case nearbySocial = "nearby_social"
}

enum FeatureGateDecision: Equatable {
    case allowed
    case requiresMember(MemberUpgradeTrigger)
}

enum AppFeatureGate {
    private enum AccessPolicy {
        case guestAllowed
        case memberOnly(trigger: MemberUpgradeTrigger)
    }

    private static let matrix: [FeatureCapability: AccessPolicy] = [
        .walkRead: .guestAllowed,
        .walkWrite: .guestAllowed,
        .cloudSync: .memberOnly(trigger: .walkHistory),
        .aiGeneration: .memberOnly(trigger: .imageGenerator),
        .nearbySocial: .memberOnly(trigger: .walkHistory),
    ]

    static func currentSession() -> AppSessionState {
        guard let identity = DefaultAuthSessionStore.shared.currentIdentity(),
              identity.userId.isEmpty == false else {
            return .guest
        }
        guard DefaultAuthSessionStore.shared.currentTokenSession() != nil else {
            return .guest
        }
        return .member(userId: identity.userId)
    }

    static func decision(for capability: FeatureCapability, session: AppSessionState) -> FeatureGateDecision {
        guard let policy = matrix[capability] else {
            return .allowed
        }
        switch policy {
        case .guestAllowed:
            return .allowed
        case .memberOnly(let trigger):
            return session.isMember ? .allowed : .requiresMember(trigger)
        }
    }

    static func isAllowed(_ capability: FeatureCapability, session: AppSessionState = currentSession()) -> Bool {
        if case .allowed = decision(for: capability, session: session) {
            return true
        }
        return false
    }
}

enum MemberUpgradeTrigger: String {
    case walkStart = "walk_start"
    case imageGenerator = "image_generator"
    case walkHistory = "walk_history"
    case walkBackup = "walk_backup"

    var title: String {
        switch self {
        case .walkStart:
            return "회원 전환 후 산책 기록"
        case .imageGenerator:
            return "회원 전환 후 이미지 생성"
        case .walkHistory:
            return "회원 전환 후 기록 동기화"
        case .walkBackup:
            return "로그인하고 산책 백업"
        }
    }

    var message: String {
        switch self {
        case .walkStart:
            return "산책 기록은 계정과 연결되어야 안전하게 저장되고 기기 간 동기화됩니다."
        case .imageGenerator:
            return "AI 이미지 생성 결과를 안정적으로 저장하려면 계정 연동이 필요합니다."
        case .walkHistory:
            return "지금 로그인하면 현재 기기의 산책 기록을 계정에 백업하고 다른 기기에서도 볼 수 있어요."
        case .walkBackup:
            return "게스트 모드 기록은 기기 삭제 시 유실될 수 있어요. 로그인 후 자동 백업을 켜세요."
        }
    }
}

struct MemberUpgradeRequest: Identifiable {
    let id = UUID()
    let trigger: MemberUpgradeTrigger
}

struct GuestDataUpgradeSnapshot: Equatable {
    let sessionCount: Int
    let pointCount: Int
    let totalAreaM2: Double
    let totalDurationSec: Double
    let sessionIds: [String]
    let signature: String
}

struct GuestDataUpgradeReport: Codable, Equatable, Identifiable {
    var id: String { userId + ":" + signature }
    let userId: String
    let signature: String
    let sessionCount: Int
    let pointCount: Int
    let totalAreaM2: Double
    let totalDurationSec: Double
    let pendingCount: Int
    let permanentFailureCount: Int
    let lastErrorCode: String?
    let remoteSessionCount: Int?
    let remotePointCount: Int?
    let remoteTotalAreaM2: Double?
    let remoteTotalDurationSec: Double?
    let validationPassed: Bool?
    let validationMessage: String?
    let executedAt: TimeInterval

    var hasOutstandingWork: Bool {
        pendingCount > 0 || permanentFailureCount > 0
    }
}

struct GuestDataUpgradePrompt: Identifiable {
    let id = UUID()
    let snapshot: GuestDataUpgradeSnapshot
    let shouldEmphasizeRetry: Bool
}

