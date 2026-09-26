//
//  SettingsSearchIndex.swift
//  Rotblock
//
//  Created by n1 on 5/9/26.
//
import Combine
import Foundation

// MARK: - Route

enum SettingsRoute: Hashable {
    case notifications
    case focusMode
    case blockedApps
    case passcode
    case appearance
    case advancedLogs
    case dailyBudget
    case shieldMessage
    case permissions
    case privacyPolicy
    case whatsNew
}

// MARK: - Search Models

struct SettingSearchEntry: Identifiable {
    let id: String
    let title: String
    let subtitle: String?
    let section: String
    let keywords: [String] // manual aliases/synonyms
    let route: SettingsRoute
    let isAvailable: () -> Bool // runtime gating (device/features/permissions)
    let basePriority: Int // static tie-break boost
}

struct SettingSearchResult: Identifiable {
    let id: String
    let entry: SettingSearchEntry
    let score: Int
    let matchedFields: [MatchedField]

    enum MatchedField: Hashable {
        case titleExact
        case titlePrefix
        case titleContains
        case keywordExact
        case keywordContains
        case subtitleContains
        case sectionContains
        case fuzzyTitle
    }
}

// MARK: - Normalization

enum SearchText {
    private nonisolated static let foldingLocale = Locale(identifier: "en_US_POSIX")

    nonisolated static func normalize(_ text: String) -> String {
        text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: foldingLocale)
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "[^a-zA-Z0-9 ]", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(with: foldingLocale)
    }

    nonisolated static func tokens(_ text: String) -> [String] {
        normalize(text).split(separator: " ").map(String.init)
    }
}

// MARK: - Scorer

struct SettingSearchScorer {
    // Tune these with real usage data
    private let wTitleExact = 120
    private let wTitlePrefix = 90
    private let wTitleContains = 65
    private let wKeywordExact = 55
    private let wKeywordContains = 35
    private let wSubtitleContains = 25
    private let wSectionContains = 15
    private let wFuzzyBase = 30 // minus edit distance penalty

    /// Max typo distance to consider fuzzy hit.
    private let fuzzyDistanceThreshold = 2

    /// Optional runtime boosts
    var recentUsageBoost: (String) -> Int = { _ in 0 } // entry.id -> boost

    func score(query rawQuery: String, entry: SettingSearchEntry) -> SettingSearchResult? {
        guard entry.isAvailable() else { return nil }

        let query = SearchText.normalize(rawQuery)
        guard !query.isEmpty else { return nil }

        let queryTokens = Set(SearchText.tokens(query))
        let title = SearchText.normalize(entry.title)
        let subtitle = SearchText.normalize(entry.subtitle ?? "")
        let section = SearchText.normalize(entry.section)
        let keywords = entry.keywords.map(SearchText.normalize)

        var score = 0
        var matched: [SettingSearchResult.MatchedField] = []

        // Strong title matching
        if title == query {
            score += wTitleExact
            matched.append(.titleExact)
        } else if title.hasPrefix(query) {
            score += wTitlePrefix
            matched.append(.titlePrefix)
        } else if title.contains(query) {
            score += wTitleContains
            matched.append(.titleContains)
        }
        // Token-level field matching
        let subtitleTokens = Set(SearchText.tokens(subtitle))
        let sectionTokens = Set(SearchText.tokens(section))
        let keywordTokens = Set(keywords.flatMap(SearchText.tokens))

        let subtitleIntersections = queryTokens.intersection(subtitleTokens).count
        let sectionIntersections = queryTokens.intersection(sectionTokens).count
        let keywordIntersections = queryTokens.intersection(keywordTokens).count

        if keywordIntersections > 0 {
            score += wKeywordContains + (keywordIntersections * 8)
            matched.append(.keywordContains)
        }

        // Exact keyword phrase
        if keywords.contains(query) {
            score += wKeywordExact
            matched.append(.keywordExact)
        }

        if subtitleIntersections > 0 {
            score += wSubtitleContains + (subtitleIntersections * 5)
            matched.append(.subtitleContains)
        }

        if sectionIntersections > 0 {
            score += wSectionContains + (sectionIntersections * 3)
            matched.append(.sectionContains)
        }

        // Optional fuzzy fallback against title/keywords
        if score == 0 {
            let titleDistance = levenshtein(query, title)
            if titleDistance <= fuzzyDistanceThreshold {
                score += max(0, wFuzzyBase - titleDistance * 10)
                matched.append(.fuzzyTitle)
            } else {
                let bestKeywordDistance =
                    keywords
                        .map { levenshtein(query, $0) }
                        .min() ?? .max
                if bestKeywordDistance <= fuzzyDistanceThreshold {
                    score += max(0, (wFuzzyBase - 5) - bestKeywordDistance * 10)
                    matched.append(.keywordContains)
                }
            }
        }

        // Final boosts and thresholds
        score += entry.basePriority
        score += recentUsageBoost(entry.id)

        // Drop weak/noisy matches
        guard score >= 30 else { return nil }

        return SettingSearchResult(
            id: entry.id,
            entry: entry,
            score: score,
            matchedFields: Array(Set(matched))
        )
    }

    /// Simple O(n*m) distance; fine for short strings and small settings catalogs.
    private func levenshtein(_ a: String, _ b: String) -> Int {
        let aChars = Array(a)
        let bChars = Array(b)
        var dist = Array(
            repeating: Array(repeating: 0, count: bChars.count + 1), count: aChars.count + 1
        )

        for i in 0...aChars.count {
            dist[i][0] = i
        }
        for j in 0...bChars.count {
            dist[0][j] = j
        }

        for i in 1...aChars.count {
            for j in 1...bChars.count {
                let cost = (aChars[i - 1] == bChars[j - 1]) ? 0 : 1
                dist[i][j] = min(
                    dist[i - 1][j] + 1, // delete
                    dist[i][j - 1] + 1, // insert
                    dist[i - 1][j - 1] + cost // substitute
                )
            }
        }
        return dist[aChars.count][bChars.count]
    }
}

// MARK: - Index

final class SettingSearchIndex: ObservableObject {
    @Published private(set) var results: [SettingSearchResult] = []

    private let entries: [SettingSearchEntry]
    private var scorer: SettingSearchScorer

    init(entries: [SettingSearchEntry], scorer: SettingSearchScorer = .init()) {
        self.entries = entries
        self.scorer = scorer
    }

    func updateQuery(_ query: String, limit: Int = 12) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            results = []
            return
        }

        results =
            entries
                .compactMap { scorer.score(query: trimmed, entry: $0) }
                .sorted {
                    if $0.score != $1.score { return $0.score > $1.score }
                    return $0.entry.title < $1.entry.title
                }
                .prefix(limit)
                .map { $0 }
    }
}
