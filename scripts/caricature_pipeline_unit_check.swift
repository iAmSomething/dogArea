import Foundation

enum CaricatureStatus: String {
    case queued
    case processing
    case ready
    case failed
}

enum ProviderHint: String {
    case auto
    case gemini
    case openai
}

func nextStatus(from current: CaricatureStatus, event: String) -> CaricatureStatus? {
    switch (current, event) {
    case (.queued, "start"):
        return .processing
    case (.processing, "success"):
        return .ready
    case (.processing, "fail"):
        return .failed
    default:
        return nil
    }
}

func providerOrder(_ hint: ProviderHint) -> [String] {
    switch hint {
    case .gemini:
        return ["gemini", "openai"]
    case .openai:
        return ["openai", "gemini"]
    case .auto:
        return ["gemini", "openai"]
    }
}

@inline(__always)
func assertTrue(_ condition: Bool, _ message: String) {
    if !condition {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let processing = nextStatus(from: .queued, event: "start")
let ready = nextStatus(from: processing ?? .queued, event: "success")
let failed = nextStatus(from: processing ?? .queued, event: "fail")
let invalid = nextStatus(from: .ready, event: "start")

assertTrue(processing == .processing, "queued -> processing transition")
assertTrue(ready == .ready, "processing -> ready transition")
assertTrue(failed == .failed, "processing -> failed transition")
assertTrue(invalid == nil, "invalid transition should be rejected")

assertTrue(providerOrder(.auto) == ["gemini", "openai"], "auto provider fallback order")
assertTrue(providerOrder(.openai) == ["openai", "gemini"], "openai hint order")
assertTrue(providerOrder(.gemini) == ["gemini", "openai"], "gemini hint order")

print("PASS: caricature pipeline unit checks")
