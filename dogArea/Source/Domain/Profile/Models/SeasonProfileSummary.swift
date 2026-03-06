import Foundation

struct SeasonProfileSummary: Equatable {
    let weekKey: String
    let score: Int
    let rankTier: SeasonRankTier
    let contributionCount: Int
}
