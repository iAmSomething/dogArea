import Foundation

struct Check {
    static var failed = false

    static func assertTrue(_ condition: @autoclosure () -> Bool, _ message: String) {
        if condition() {
            print("[PASS] \(message)")
        } else {
            failed = true
            print("[FAIL] \(message)")
        }
    }
}

func read(_ path: String) -> String {
    (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
}

let function = read("supabase/functions/caricature/index.ts")
let functionReadme = read("supabase/functions/caricature/README.md")
let imageVM = read("dogArea/Views/ImageGeneratorView/ImageGenerateViewModel.swift")
let imageView = read("dogArea/Views/ImageGeneratorView/TextToImageView.swift")
let signingVM = read("dogArea/Views/SigningView/SigningViewModel.swift")
let supabaseInfrastructure = read("dogArea/Source/Infrastructure/Supabase/SupabaseInfrastructure.swift")
let infoPlist = read("dogArea/Info.plist")
let pbxproj = read("dogArea.xcodeproj/project.pbxproj")
let migration = read("supabase/migrations/20260226234500_caricature_jobs_observability_columns.sql")

Check.assertTrue(function.contains("const SCHEMA_VERSION = \"2026-02-26.v1\""), "edge function should define request schema version")
Check.assertTrue(function.contains("requestId"), "edge function should track requestId")
Check.assertTrue(function.contains("sourceImagePath or sourceImageUrl is required"), "edge function should validate source image")
Check.assertTrue(function.contains("Deno.env.get(\"GEMINI_API_KEY\") ?? Deno.env.get(\"GEMINI_KEY\")"), "edge function should support GEMINI_API_KEY and GEMINI_KEY")
Check.assertTrue(function.contains("caricature_url"), "edge function should update pets caricature_url")
Check.assertTrue(function.contains("ALL_PROVIDERS_FAILED"), "edge function should expose recoverable provider failure")
Check.assertTrue(functionReadme.contains("Request Schema"), "README should define request schema")
Check.assertTrue(functionReadme.contains("Error Codes"), "README should define error codes")

Check.assertTrue(supabaseInfrastructure.contains("struct CaricatureEdgeClient"), "app should use shared caricature edge client")
Check.assertTrue(supabaseInfrastructure.contains("case functionUnavailable"), "edge client should classify function unavailable")
Check.assertTrue(supabaseInfrastructure.contains("caricature.edge.unavailable.until.v1"), "edge client should persist temporary unavailable marker")
Check.assertTrue(supabaseInfrastructure.contains("캐리커처 서버 기능이 아직 배포되지 않았습니다"), "edge client should expose user-friendly unavailable message")
Check.assertTrue(imageVM.contains("CaricatureEdgeClient"), "image generator vm should call edge client")
Check.assertTrue(imageVM.contains("retryLastRequest"), "image generator vm should support retry")
Check.assertTrue(imageVM.contains("AppFeatureGate.isAllowed(.aiGeneration"), "image vm should enforce ai feature gate")
Check.assertTrue(imageView.contains("다시 시도"), "image view should expose retry action")
Check.assertTrue(imageView.contains("requestAccess(feature: .aiGeneration)"), "image view should request gated access")

Check.assertTrue(signingVM.contains("petId: petInfo.petId"), "signing flow should request caricature with persisted pet id")
Check.assertTrue(!signingVM.contains("petId: UUID().uuidString"), "signing flow should not use random pet id")

Check.assertTrue(!imageVM.contains("import OpenAIClient"), "image vm should not import direct OpenAI client")
Check.assertTrue(!infoPlist.contains("<key>OpenAI</key>"), "Info.plist should not store OpenAI key binding")
Check.assertTrue(!pbxproj.contains("OpenAIKey = \"sk-"), "project settings should not contain hardcoded OpenAI key")

Check.assertTrue(migration.contains("request_id"), "migration should add request_id observability column")
Check.assertTrue(migration.contains("provider_used"), "migration should add provider_used observability column")
Check.assertTrue(migration.contains("latency_ms"), "migration should add latency_ms observability column")

if Check.failed {
    exit(1)
}

print("All caricature proxy checks passed.")
