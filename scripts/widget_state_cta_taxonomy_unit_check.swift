import Foundation

@discardableResult
func require(_ condition: @autoclosure () -> Bool, _ message: String) -> Bool {
    if condition() == false {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
    return true
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

func read(_ relativePath: String) -> String {
    let url = root.appendingPathComponent(relativePath)
    guard let content = try? String(contentsOf: url, encoding: .utf8) else {
        fputs("FAIL: unable to read \(relativePath)\n", stderr)
        exit(1)
    }
    return content
}

let support = read("dogAreaWidgetExtension/Shared/WidgetPresentationSupport.swift")
let territory = read("dogAreaWidgetExtension/Widgets/TerritoryStatusWidget.swift")
let hotspot = read("dogAreaWidgetExtension/Widgets/HotspotStatusWidget.swift")
let quest = read("dogAreaWidgetExtension/Widgets/QuestRivalStatusWidget.swift")
let readme = read("README.md")
let prCheck = read("scripts/ios_pr_check.sh")
let doc = read("docs/widget-state-cta-taxonomy-v1.md")

require(support.contains("enum WidgetStateTaxonomy"), "widget 상태 taxonomy enum이 없습니다.")
require(support.contains("case guest"), "guest 상태 taxonomy가 없습니다.")
require(support.contains("case empty"), "empty 상태 taxonomy가 없습니다.")
require(support.contains("case offline"), "offline 상태 taxonomy가 없습니다.")
require(support.contains("case syncDelayed"), "syncDelayed 상태 taxonomy가 없습니다.")
require(support.contains("struct WidgetStateCTAContent"), "공통 CTA 모델이 없습니다.")
require(support.contains("struct WidgetStatePresentationContent"), "공통 상태 프레젠테이션 모델이 없습니다.")
require(support.contains("enum WidgetStatePresentationGuide"), "공통 상태 프레젠테이션 가이드가 없습니다.")
require(support.contains("struct WidgetStateCTAView"), "공통 CTA 뷰가 없습니다.")

require(territory.contains("WidgetStatePresentationGuide.presentation("), "Territory widget가 공통 상태 가이드를 사용하지 않습니다.")
require(hotspot.contains("WidgetStatePresentationGuide.presentation("), "Hotspot widget가 공통 상태 가이드를 사용하지 않습니다.")
require(quest.contains("WidgetStatePresentationGuide.presentation("), "Quest/Rival widget가 공통 상태 가이드를 사용하지 않습니다.")
require(quest.contains("return .openQuestRecovery"), "Quest/Rival widget offline/delayed 복구 CTA 우선 경로가 없습니다.")

require(doc.contains("## Taxonomy"), "문서에 taxonomy 섹션이 없습니다.")
require(doc.contains("## CTA rules"), "문서에 CTA rules 섹션이 없습니다.")
require(doc.contains("## Accessibility"), "문서에 Accessibility 섹션이 없습니다.")
require(doc.contains("앱에서 로그인"), "문서에 guest CTA 기준이 없습니다.")
require(doc.contains("연결 복구 대기 중"), "문서에 offline CTA 기준이 없습니다.")
require(doc.contains("앱에서 최신 상태 확인"), "문서에 delayed CTA 기준이 없습니다.")

require(readme.contains("docs/widget-state-cta-taxonomy-v1.md"), "README에 widget state CTA taxonomy 문서 링크가 없습니다.")
require(prCheck.contains("widget_state_cta_taxonomy_unit_check.swift"), "ios_pr_check에 widget state CTA taxonomy 체크가 없습니다.")

print("PASS: widget state CTA taxonomy unit checks")
