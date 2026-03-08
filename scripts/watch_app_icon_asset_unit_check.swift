#!/usr/bin/env swift
import Foundation

/// 메시지를 출력하고 스크립트를 실패 종료합니다.
/// - Parameter message: 실패 원인을 설명하는 문자열입니다.
func fail(_ message: String) -> Never {
    fputs("FAIL: \(message)\n", stderr)
    exit(1)
}

/// UTF-8 텍스트 파일을 읽어 반환합니다.
/// - Parameter path: 읽을 파일의 저장소 상대 경로입니다.
/// - Returns: 파일의 UTF-8 문자열 내용입니다.
func read(_ path: String) -> String {
    let url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(path)
    guard let text = try? String(contentsOf: url, encoding: .utf8) else {
        fail("missing file: \(path)")
    }
    return text
}

/// JSON 파일을 역직렬화해 딕셔너리로 반환합니다.
/// - Parameter path: 읽을 JSON 파일의 저장소 상대 경로입니다.
/// - Returns: JSON 최상위 딕셔너리입니다.
func readJSON(_ path: String) -> [String: Any] {
    let url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(path)
    guard let data = try? Data(contentsOf: url) else {
        fail("missing json file: \(path)")
    }
    guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        fail("invalid json: \(path)")
    }
    return json
}

/// PNG 파일의 IHDR 너비와 높이를 읽어 반환합니다.
/// - Parameter path: 검사할 PNG 파일의 저장소 상대 경로입니다.
/// - Returns: `(width, height)` 튜플입니다.
func readPNGSize(_ path: String) -> (Int, Int) {
    let url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(path)
    guard let data = try? Data(contentsOf: url), data.count >= 24 else {
        fail("invalid png data: \(path)")
    }
    let pngSignature = Data([137, 80, 78, 71, 13, 10, 26, 10])
    guard data.prefix(8) == pngSignature else {
        fail("file is not png: \(path)")
    }
    let width = data.subdata(in: 16..<20).reduce(0) { ($0 << 8) | Int($1) }
    let height = data.subdata(in: 20..<24).reduce(0) { ($0 << 8) | Int($1) }
    return (width, height)
}

let jsonPath = "dogAreaWatch Watch App/Assets.xcassets/AppIcon.appiconset/Contents.json"
let iconPath = "dogAreaWatch Watch App/Assets.xcassets/AppIcon.appiconset/watchAppIcon1024.png"
let json = readJSON(jsonPath)

guard let images = json["images"] as? [[String: Any]], images.count == 1 else {
    fail("watch app icon json should define exactly one image entry")
}

let image = images[0]
guard image["filename"] as? String == "watchAppIcon1024.png" else {
    fail("watch app icon json should reference watchAppIcon1024.png")
}
guard image["idiom"] as? String == "universal" else {
    fail("watch app icon idiom should be universal")
}
guard image["platform"] as? String == "watchos" else {
    fail("watch app icon platform should be watchos")
}
guard image["size"] as? String == "1024x1024" else {
    fail("watch app icon size should be 1024x1024")
}

guard FileManager.default.fileExists(atPath: iconPath) else {
    fail("watch app icon png should exist")
}

let (width, height) = readPNGSize(iconPath)
guard width == 1024 && height == 1024 else {
    fail("watch app icon png should be 1024x1024, got \(width)x\(height)")
}

let pbxproj = read("dogArea.xcodeproj/project.pbxproj")
guard pbxproj.contains("PRODUCT_BUNDLE_IDENTIFIER = com.th.dogArea.watchkitapp;") else {
    fail("watch target bundle identifier should remain com.th.dogArea.watchkitapp")
}
guard pbxproj.contains("ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;") else {
    fail("project should keep AppIcon asset binding")
}

let readme = read("README.md")
guard readme.contains("Watch AppIcon asset fix v1") else {
    fail("README should index watch AppIcon doc")
}

let prCheck = read("scripts/ios_pr_check.sh")
guard prCheck.contains("swift scripts/watch_app_icon_asset_unit_check.swift") else {
    fail("ios_pr_check should run watch AppIcon asset unit check")
}

print("PASS: watch AppIcon asset references a real 1024x1024 png and is wired into checks")
