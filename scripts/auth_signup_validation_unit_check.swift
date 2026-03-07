import Foundation

@inline(__always)
func assertTrue(_ condition: Bool, _ message: String) {
    if !condition {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

func load(_ relativePath: String) -> String {
    let data = try! Data(contentsOf: root.appendingPathComponent(relativePath))
    return String(decoding: data, as: UTF8.self)
}

func loadMany(_ relativePaths: [String]) -> String {
    relativePaths.map(load).joined(separator: "\n")
}

let signInView = loadMany([
    "dogArea/Views/SigningView/SignInView.swift",
    "dogArea/Views/SigningView/Components/AuthUserInfo.swift",
    "dogArea/Views/SigningView/Components/EmailSignUpSheetView.swift"
])
let infra = loadMany([
    "dogArea/Source/Infrastructure/Supabase/SupabaseInfrastructure.swift",
    "dogArea/Source/Infrastructure/Supabase/Services/SupabaseAuthAndAssetServices.swift"
])

assertTrue(
    signInView.contains("@State private var confirmPassword: String = \"\""),
    "signup sheet should keep password confirmation state"
)
assertTrue(
    signInView.contains("SecureField(\"비밀번호 확인\", text: $confirmPassword)"),
    "signup sheet should render confirm password input field"
)
assertTrue(
    signInView.contains(".accessibilityIdentifier(\"signup.passwordConfirm\")"),
    "signup confirm password input should expose accessibility identifier"
)
assertTrue(
    signInView.contains("private func validateSignUpInput(") && signInView.contains("password == confirmPassword"),
    "signup should validate password confirmation match before request"
)
assertTrue(
    signInView.contains("private func isValidEmailFormat(_ email: String) -> Bool"),
    "signup should include email format validator"
)
assertTrue(
    signInView.contains("if let validationError = validateSignUpInput("),
    "signup submit should fail fast on local validation error"
)

assertTrue(
    infra.contains("if isDuplicateEmailErrorDescription(description)"),
    "auth error mapping should prioritize duplicate-email detection"
)
assertTrue(
    infra.contains("private func isDuplicateEmailErrorDescription(_ description: String) -> Bool"),
    "supabase auth service should define duplicate-email detector helper"
)

print("PASS: auth signup validation unit checks")
