import Foundation

enum AuthMailActionType: String, Codable, CaseIterable {
    case signupConfirmation = "signup_confirmation"
    case passwordReset = "password_reset"
    case emailChange = "email_change"

    var analyticsKey: String {
        rawValue
    }

    var fallbackCooldownSeconds: Int {
        switch self {
        case .signupConfirmation:
            return 60
        case .passwordReset:
            return 75
        case .emailChange:
            return 90
        }
    }

    var resendButtonTitle: String {
        switch self {
        case .signupConfirmation:
            return "인증 메일 다시 보내기"
        case .passwordReset:
            return "재설정 메일 다시 보내기"
        case .emailChange:
            return "변경 확인 메일 다시 보내기"
        }
    }

    var sendingButtonTitle: String {
        switch self {
        case .signupConfirmation:
            return "인증 메일 보내는 중..."
        case .passwordReset:
            return "재설정 메일 보내는 중..."
        case .emailChange:
            return "변경 확인 메일 보내는 중..."
        }
    }

    /// 액션 타입에 맞는 발송 성공 제목을 반환합니다.
    /// - Returns: 사용자에게 노출할 성공 상태 제목입니다.
    func successTitle() -> String {
        switch self {
        case .signupConfirmation:
            return "인증 메일을 보냈어요"
        case .passwordReset:
            return "재설정 메일을 보냈어요"
        case .emailChange:
            return "변경 확인 메일을 보냈어요"
        }
    }

    /// 액션 타입과 수신 이메일에 맞는 성공 안내 문구를 반환합니다.
    /// - Parameter email: 사용자가 확인할 메일함의 대상 이메일입니다.
    /// - Returns: 발송 성공 후 사용자에게 보여줄 설명 문구입니다.
    func successDescription(for email: String) -> String {
        switch self {
        case .signupConfirmation:
            return "\(email) 메일함을 확인한 뒤 프로필 입력을 계속하세요."
        case .passwordReset:
            return "\(email) 메일함에서 비밀번호 재설정 링크를 확인하세요."
        case .emailChange:
            return "\(email) 메일함에서 이메일 변경 확인 링크를 확인하세요."
        }
    }

    /// 액션 타입에 맞는 기본 실패 문구를 반환합니다.
    /// - Returns: 구체적인 서버 메시지가 없을 때 사용할 사용자 안내 문구입니다.
    func defaultFailureMessage() -> String {
        switch self {
        case .signupConfirmation:
            return "인증 메일을 보내지 못했습니다. 네트워크를 확인하고 다시 시도해주세요."
        case .passwordReset:
            return "재설정 메일을 보내지 못했습니다. 네트워크를 확인하고 다시 시도해주세요."
        case .emailChange:
            return "변경 확인 메일을 보내지 못했습니다. 잠시 후 다시 시도해주세요."
        }
    }
}

struct AuthMailActionKey: Hashable, Codable {
    let actionType: AuthMailActionType
    let recipient: String
    let context: String?

    /// 액션 타입/수신자/부가 문맥을 정규화해 고유 키를 생성합니다.
    /// - Parameters:
    ///   - actionType: 메일 상태를 분리할 액션 타입입니다.
    ///   - recipient: 메일을 받는 정규화 대상 이메일입니다.
    ///   - context: 같은 액션 안에서도 세부 흐름을 분리하고 싶을 때 사용하는 선택 문맥입니다.
    init(actionType: AuthMailActionType, recipient: String, context: String? = nil) {
        self.actionType = actionType
        self.recipient = recipient.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedContext = context?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        self.context = normalizedContext?.isEmpty == true ? nil : normalizedContext
    }

    var storageKey: String {
        if let context, context.isEmpty == false {
            return "\(actionType.rawValue)::\(recipient)::\(context)"
        }
        return "\(actionType.rawValue)::\(recipient)"
    }
}

enum AuthMailResendState: Equatable {
    case idle
    case sending
    case sent(remainingSeconds: Int)
    case cooldown(remainingSeconds: Int)
    case rateLimited(remainingSeconds: Int)
    case failed(message: String)

    var remainingSeconds: Int? {
        switch self {
        case .sent(let remainingSeconds), .cooldown(let remainingSeconds), .rateLimited(let remainingSeconds):
            return remainingSeconds
        case .idle, .sending, .failed:
            return nil
        }
    }

    var isRequestAllowed: Bool {
        switch self {
        case .idle, .failed:
            return true
        case .sending, .sent, .cooldown, .rateLimited:
            return false
        }
    }

    /// 현재 상태에 맞는 버튼 타이틀을 반환합니다.
    /// - Parameter actionType: 버튼 문구를 정할 메일 액션 타입입니다.
    /// - Returns: 사용자가 탭할 버튼의 상태별 제목입니다.
    func buttonTitle(for actionType: AuthMailActionType) -> String {
        switch self {
        case .idle, .failed:
            return actionType.resendButtonTitle
        case .sending:
            return actionType.sendingButtonTitle
        case .sent(let remainingSeconds), .cooldown(let remainingSeconds), .rateLimited(let remainingSeconds):
            return "\(remainingSeconds)초 후 다시 보내기"
        }
    }

    /// 현재 상태에 맞는 사용자 설명 문구를 반환합니다.
    /// - Parameters:
    ///   - actionType: 설명 문구를 정할 메일 액션 타입입니다.
    ///   - email: 안내 대상 이메일입니다.
    /// - Returns: 상태 카드나 보조 문구에 표시할 사용자 설명입니다.
    func message(for actionType: AuthMailActionType, email: String) -> String? {
        switch self {
        case .idle:
            return nil
        case .sending:
            return "응답을 기다리는 중이에요. 잠시만 기다려주세요."
        case .sent:
            return actionType.successDescription(for: email)
        case .cooldown(let remainingSeconds):
            return "방금 메일을 보냈어요. \(remainingSeconds)초 후 다시 보낼 수 있어요."
        case .rateLimited(let remainingSeconds):
            return "요청이 많아 잠시 기다린 뒤 다시 보낼 수 있어요. \(remainingSeconds)초 후 다시 시도해주세요."
        case .failed(let message):
            return message
        }
    }
}

struct AuthMailResendSnapshot: Codable, Equatable {
    let actionType: AuthMailActionType
    let recipient: String
    let context: String?
    let sentBannerUntil: TimeInterval
    let nextAllowedAt: TimeInterval
    let retryAfterSeconds: Int?
    let lastUpdatedAt: TimeInterval
    let wasRateLimited: Bool
}
