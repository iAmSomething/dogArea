import Foundation
#if canImport(UIKit)
import UIKit
#endif

enum AppHapticFeedback {
    #if canImport(UIKit)
    private static var shouldReduceFeedbackForPowerMode: Bool {
        ProcessInfo.processInfo.isLowPowerModeEnabled
    }
    #endif

    static func questProgress() {
        #if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred(intensity: 0.6)
        #endif
    }

    static func questCompleted() {
        #if canImport(UIKit)
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
        #endif
    }

    static func questFailed() {
        #if canImport(UIKit)
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.warning)
        #endif
    }

    static func mapCaptureSuccess(reducedMotion: Bool) {
        #if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred(intensity: reducedMotion ? 0.45 : 0.75)
        #endif
    }

    static func mapWarning() {
        #if canImport(UIKit)
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.warning)
        #endif
    }

    static func seasonScoreTick(reducedMotion: Bool) {
        #if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        let intensity: CGFloat = reducedMotion || shouldReduceFeedbackForPowerMode ? 0.35 : 0.62
        generator.impactOccurred(intensity: intensity)
        #endif
    }

    static func seasonRankUp(reducedMotion: Bool) {
        #if canImport(UIKit)
        let notification = UINotificationFeedbackGenerator()
        notification.prepare()
        notification.notificationOccurred(.success)
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.prepare()
        let intensity: CGFloat = reducedMotion || shouldReduceFeedbackForPowerMode ? 0.45 : 0.85
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            impact.impactOccurred(intensity: intensity)
        }
        #endif
    }

    static func seasonShieldApplied(reducedMotion: Bool) {
        #if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: .rigid)
        generator.prepare()
        let intensity: CGFloat = reducedMotion || shouldReduceFeedbackForPowerMode ? 0.35 : 0.7
        generator.impactOccurred(intensity: intensity)
        #endif
    }

    static func seasonReset(reducedMotion: Bool) {
        #if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.prepare()
        let intensity: CGFloat = reducedMotion || shouldReduceFeedbackForPowerMode ? 0.28 : 0.5
        generator.impactOccurred(intensity: intensity)
        #endif
    }
}
