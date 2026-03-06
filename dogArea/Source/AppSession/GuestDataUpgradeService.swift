//
//  GuestDataUpgradeService.swift
//  dogArea
//

import Foundation
import CryptoKit

final class GuestDataUpgradeService {
    static let shared = GuestDataUpgradeService()

    private struct ReportSeed {
        let signature: String
        let sessionCount: Int
        let pointCount: Int
        let totalAreaM2: Double
        let totalDurationSec: Double
    }

    private let syncOutbox = SyncOutboxStore.shared
    private let syncTransport = SupabaseSyncOutboxTransport()
    private let walkRepository: WalkRepositoryProtocol
    private let reportStoragePrefix = "guest.data.upgrade.report.v1."
    private let acknowledgedSignaturePrefix = "guest.data.upgrade.signature.v1."

    private init(walkRepository: WalkRepositoryProtocol = WalkRepositoryContainer.shared) {
        self.walkRepository = walkRepository
    }

    func pendingPrompt(for userId: String) -> GuestDataUpgradePrompt? {
        guard let snapshot = localSnapshot(), snapshot.sessionCount > 0 else { return nil }
        let report = latestReport(for: userId)
        let acknowledgedSignature = UserDefaults.standard.string(forKey: signatureKey(for: userId))
        if acknowledgedSignature == snapshot.signature, report?.hasOutstandingWork == false {
            return nil
        }
        return GuestDataUpgradePrompt(
            snapshot: snapshot,
            shouldEmphasizeRetry: report?.hasOutstandingWork == true
        )
    }

    func latestReport(for userId: String) -> GuestDataUpgradeReport? {
        guard let data = UserDefaults.standard.data(forKey: reportKey(for: userId)),
              let decoded = try? JSONDecoder().decode(GuestDataUpgradeReport.self, from: data) else {
            #if DEBUG
            print("[GuestUpgrade] latestReport: no cached report user=\(userId)")
            #endif
            return nil
        }
        #if DEBUG
        print(
            "[GuestUpgrade] latestReport: user=\(userId) pending=\(decoded.pendingCount) permanent=\(decoded.permanentFailureCount) lastError=\(decoded.lastErrorCode ?? "none")"
        )
        #endif
        return decoded
    }

    func runUpgrade(for userId: String, forceRetry: Bool = false) async -> GuestDataUpgradeReport? {
        let snapshot = localSnapshot()
        let previousReport = latestReport(for: userId)

        if forceRetry {
            if let snapshot, snapshot.sessionIds.isEmpty == false {
                syncOutbox.requeuePermanentFailures(walkSessionIds: Set(snapshot.sessionIds))
                #if DEBUG
                print("[GuestUpgrade] requeue permanent failures for \(snapshot.sessionIds.count) local sessions")
                #endif
            } else {
                syncOutbox.requeuePermanentFailures()
                #if DEBUG
                print("[GuestUpgrade] requeue permanent failures for all outbox sessions")
                #endif
            }
        }

        if let snapshot, snapshot.sessionCount > 0 {
            #if DEBUG
            print(
                "[GuestUpgrade] runUpgrade start user=\(userId) forceRetry=\(forceRetry) sessions=\(snapshot.sessionCount) points=\(snapshot.pointCount)"
            )
            #endif
            var enqueuedSessionCount = 0
            for polygon in walkRepository.fetchPolygons() {
                guard let sessionDTO = WalkBackfillDTOConverter.makeSessionDTO(
                    from: polygon,
                    ownerUserId: userId,
                    petId: nil,
                    sourceDevice: "ios"
                ) else { continue }
                syncOutbox.enqueueWalkStages(sessionDTO: sessionDTO)
                enqueuedSessionCount += 1
            }
            #if DEBUG
            print("[GuestUpgrade] enqueue completed: \(enqueuedSessionCount) sessions queued")
            #endif
        } else {
            #if DEBUG
            print("[GuestUpgrade] runUpgrade continue without local sessions user=\(userId)")
            #endif
        }

        let summary = await syncOutbox.flush(using: syncTransport, now: Date())
        #if DEBUG
        print(
            "[GuestUpgrade] flush summary pending=\(summary.pendingCount) permanent=\(summary.permanentFailureCount) lastError=\(summary.lastErrorCode?.rawValue ?? "none")"
        )
        #endif

        let hasOutstanding = summary.pendingCount > 0 || summary.permanentFailureCount > 0
        guard hasOutstanding || snapshot != nil || previousReport != nil else {
            clearPersistedReport(for: userId)
            #if DEBUG
            print("[GuestUpgrade] runUpgrade done: no local sessions and no outbox work user=\(userId)")
            #endif
            return nil
        }

        let seed = reportSeed(snapshot: snapshot, fallback: previousReport)
        var remoteSummary: SyncBackfillValidationSummary? = nil
        var validation: (passed: Bool?, message: String?) = (nil, hasOutstanding ? "local_snapshot_unavailable" : nil)

        if let snapshot {
            remoteSummary = await syncTransport.fetchBackfillValidationSummary(sessionIds: snapshot.sessionIds)
            #if DEBUG
            if let remoteSummary {
                print(
                    "[GuestUpgrade] remote summary sessions=\(remoteSummary.sessionCount) points=\(remoteSummary.pointCount) area=\(remoteSummary.totalAreaM2) duration=\(remoteSummary.totalDurationSec)"
                )
            } else {
                print("[GuestUpgrade] remote summary unavailable")
            }
            #endif
            validation = validate(local: snapshot, remote: remoteSummary)
        }

        let report = GuestDataUpgradeReport(
            userId: userId,
            signature: seed.signature,
            sessionCount: seed.sessionCount,
            pointCount: seed.pointCount,
            totalAreaM2: seed.totalAreaM2,
            totalDurationSec: seed.totalDurationSec,
            pendingCount: summary.pendingCount,
            permanentFailureCount: summary.permanentFailureCount,
            lastErrorCode: summary.lastErrorCode?.rawValue,
            remoteSessionCount: remoteSummary?.sessionCount ?? previousReport?.remoteSessionCount,
            remotePointCount: remoteSummary?.pointCount ?? previousReport?.remotePointCount,
            remoteTotalAreaM2: remoteSummary?.totalAreaM2 ?? previousReport?.remoteTotalAreaM2,
            remoteTotalDurationSec: remoteSummary?.totalDurationSec ?? previousReport?.remoteTotalDurationSec,
            validationPassed: validation.passed,
            validationMessage: validation.message,
            executedAt: Date().timeIntervalSince1970
        )

        persist(report: report, for: userId)
        if report.hasOutstandingWork == false {
            UserDefaults.standard.set(seed.signature, forKey: signatureKey(for: userId))
            if seed.sessionCount == 0, seed.pointCount == 0 {
                clearPersistedReport(for: userId)
            }
        }
        #if DEBUG
        let validationText: String = {
            guard let passed = report.validationPassed else { return "nil" }
            return passed ? "true" : "false"
        }()
        print(
            "[GuestUpgrade] runUpgrade done user=\(userId) outstanding=\(report.hasOutstandingWork) validation=\(validationText) message=\(report.validationMessage ?? "none")"
        )
        #endif
        return report
    }

    private func localSnapshot() -> GuestDataUpgradeSnapshot? {
        let polygons = walkRepository.fetchPolygons()
        guard polygons.isEmpty == false else { return nil }

        let sessionIds = polygons.map { $0.id.uuidString.lowercased() }.sorted()
        let pointCount = polygons.reduce(0) { $0 + $1.locations.count }
        let totalArea = polygons.reduce(0.0) { $0 + $1.walkingArea }
        let totalDuration = polygons.reduce(0.0) { $0 + $1.walkingTime }
        let signature = signatureForSnapshot(
            sessionIds: sessionIds,
            pointCount: pointCount,
            totalAreaM2: totalArea,
            totalDurationSec: totalDuration
        )
        return GuestDataUpgradeSnapshot(
            sessionCount: sessionIds.count,
            pointCount: pointCount,
            totalAreaM2: totalArea,
            totalDurationSec: totalDuration,
            sessionIds: sessionIds,
            signature: signature
        )
    }

    /// 게스트 이관 리포트 작성을 위한 기준 값을 계산합니다.
    /// - Parameters:
    ///   - snapshot: 현재 로컬 산책 스냅샷입니다.
    ///   - fallback: 기존에 저장된 마지막 리포트입니다.
    /// - Returns: 로컬 스냅샷이 있으면 우선 사용하고, 없으면 기존 리포트 기반으로 복원한 기준 값입니다.
    private func reportSeed(
        snapshot: GuestDataUpgradeSnapshot?,
        fallback: GuestDataUpgradeReport?
    ) -> ReportSeed {
        if let snapshot {
            return ReportSeed(
                signature: snapshot.signature,
                sessionCount: snapshot.sessionCount,
                pointCount: snapshot.pointCount,
                totalAreaM2: snapshot.totalAreaM2,
                totalDurationSec: snapshot.totalDurationSec
            )
        }
        return ReportSeed(
            signature: fallback?.signature ?? "outbox-only",
            sessionCount: fallback?.sessionCount ?? 0,
            pointCount: fallback?.pointCount ?? 0,
            totalAreaM2: fallback?.totalAreaM2 ?? 0,
            totalDurationSec: fallback?.totalDurationSec ?? 0
        )
    }

    private func persist(report: GuestDataUpgradeReport, for userId: String) {
        guard let data = try? JSONEncoder().encode(report) else { return }
        UserDefaults.standard.set(data, forKey: reportKey(for: userId))
        #if DEBUG
        print("[GuestUpgrade] report persisted user=\(userId) key=\(reportKey(for: userId))")
        #endif
    }

    /// 저장된 게스트 이관 리포트를 제거해 stale 카드 노출을 방지합니다.
    /// - Parameter userId: 리포트를 삭제할 멤버 사용자 식별자입니다.
    /// - Returns: 없음. 지정 사용자의 로컬 리포트 캐시를 삭제합니다.
    private func clearPersistedReport(for userId: String) {
        UserDefaults.standard.removeObject(forKey: reportKey(for: userId))
        #if DEBUG
        print("[GuestUpgrade] report cleared user=\(userId) key=\(reportKey(for: userId))")
        #endif
    }

    private func validate(
        local: GuestDataUpgradeSnapshot,
        remote: SyncBackfillValidationSummary?
    ) -> (passed: Bool?, message: String?) {
        guard let remote else {
            return (nil, "remote_summary_unavailable")
        }
        let areaTolerance = max(1.0, local.totalAreaM2 * 0.01)
        let durationTolerance = max(3.0, local.totalDurationSec * 0.01)

        let sessionMatched = local.sessionCount == remote.sessionCount
        let pointMatched = local.pointCount == remote.pointCount
        let areaMatched = abs(local.totalAreaM2 - remote.totalAreaM2) <= areaTolerance
        let durationMatched = abs(local.totalDurationSec - remote.totalDurationSec) <= durationTolerance
        let passed = sessionMatched && pointMatched && areaMatched && durationMatched

        let message = passed
        ? "validated"
        : [
            sessionMatched ? nil : "session_mismatch",
            pointMatched ? nil : "point_mismatch",
            areaMatched ? nil : "area_mismatch",
            durationMatched ? nil : "duration_mismatch"
        ].compactMap { $0 }.joined(separator: ",")

        return (passed, message)
    }

    private func reportKey(for userId: String) -> String {
        reportStoragePrefix + stableKey(from: userId)
    }

    private func signatureKey(for userId: String) -> String {
        acknowledgedSignaturePrefix + stableKey(from: userId)
    }

    private func signatureForSnapshot(
        sessionIds: [String],
        pointCount: Int,
        totalAreaM2: Double,
        totalDurationSec: Double
    ) -> String {
        let payload = sessionIds.joined(separator: "|")
        + "|p:\(pointCount)"
        + "|a:\(totalAreaM2)"
        + "|t:\(totalDurationSec)"
        return stableKey(from: payload)
    }

    private func stableKey(from raw: String) -> String {
        let digest = SHA256.hash(data: Data(raw.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
