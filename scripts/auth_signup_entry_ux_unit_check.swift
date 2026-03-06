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

assertTrue(
    signInView.contains("@State private var isSignUpSheetPresented: Bool = false"),
    "signin should keep dedicated signup sheet presentation state"
)
assertTrue(
    signInView.contains(".sheet(isPresented: $isSignUpSheetPresented)"),
    "signin should present a dedicated signup sheet instead of inline signup submission"
)
assertTrue(
    signInView.contains("EmailSignUpSheetView("),
    "signin should route signup CTA to dedicated signup view"
)
assertTrue(
    !signInView.contains("runEmailAuth(isSignup: true)"),
    "signup CTA should no longer trigger combined login/signup handler"
)
assertTrue(
    signInView.contains("private func runEmailSignIn()"),
    "signin view should keep explicit email login action"
)
assertTrue(
    signInView.contains(".buttonStyle(.plain)") && signInView.contains(".accessibilityIdentifier(\"signin.signup\")"),
    "signup CTA should be rendered as secondary text-style action"
)
assertTrue(
    signInView.contains(".tint(Color.appTextDarkGray)") && signInView.contains("signin.dismiss"),
    "dismiss action should use design token tint instead of default system blue"
)
assertTrue(
    signInView.contains("screen.signup") && signInView.contains(".emailSignUp(email: normalizedEmail, password: normalizedPassword)"),
    "signup sheet should submit through explicit emailSignUp request"
)

print("PASS: auth signup entry ux unit checks")
