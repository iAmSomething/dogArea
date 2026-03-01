import Foundation

/// 라이벌 탭 네트워크 오류를 사용자 메시지/정책으로 해석합니다.
enum RivalNetworkErrorInterpreter {
    /// 익명 공유 설정 실패 오류를 사용자 안내 메시지로 변환합니다.
    /// - Parameter error: 변환할 원본 오류입니다.
    /// - Returns: 사용자에게 노출할 안내 문구입니다.
    static func visibilityFailureMessage(from error: Error) -> String {
        guard let supabaseError = error as? SupabaseHTTPError else {
            return "설정 반영 실패, 다시 시도해주세요."
        }
        switch supabaseError {
        case .notConfigured:
            return "Supabase 설정이 누락되어 있어요. 설정 파일을 확인해주세요."
        case .unexpectedStatusCode(let statusCode):
            switch statusCode {
            case 400, 401, 403:
                return "인증 세션 확인이 필요해요. 다시 로그인 후 시도해주세요."
            case 404:
                return "근처 공유 기능이 아직 서버에 배포되지 않았어요."
            case 500...599:
                return "서버 설정이 준비되지 않았어요. 잠시 후 다시 시도해주세요."
            default:
                return "설정 반영 실패(\(statusCode))"
            }
        case .invalidURL, .invalidBody, .invalidResponse:
            return "요청 형식 확인이 필요해요. 앱을 재시작 후 다시 시도해주세요."
        }
    }

    /// 오류가 연결성(오프라인/서버 가용성) 계열인지 판정합니다.
    /// - Parameter error: 판정할 오류입니다.
    /// - Returns: 연결성 오류면 `true`, 아니면 `false`입니다.
    static func isConnectivityError(_ error: Error) -> Bool {
        if error is URLError {
            return true
        }
        if let supabaseError = error as? SupabaseHTTPError {
            switch supabaseError {
            case .unexpectedStatusCode(let code):
                return code == 429 || (500...599).contains(code)
            default:
                return false
            }
        }
        return false
    }
}
