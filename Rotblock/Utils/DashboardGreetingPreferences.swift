//
//  DashboardGreetingPreferences.swift
//  Rotblock
//
//  Created by n1 on 5/10/26.
//
import Foundation

enum DashboardGreetingPreferences {
    static let greetingsKey = "rb.dashboard.greetings"
    static let shuffleKey = "rb.dashboard.greetingShuffle"
    static let staticIndexKey = "rb.dashboard.staticGreetingIndex"

    static let defaultGreetings: [String] = [
        "A clearer day ahead.",
        "Get off your phone please.",
        "Your eyes don't hurt yet?",
        "Protect your attention.",
        "wake up wake up",
        "Meow.",
        "Calm mind. Clear priorities.",
    ]

    static func effectiveGreetings(using store: UserDefaults?) -> [String] {
        guard let store else { return defaultGreetings }
        guard let data = store.data(forKey: greetingsKey),
              let decoded = try? JSONDecoder().decode([String].self, from: data)
        else {
            return defaultGreetings
        }
        let trimmed = decoded.map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }.filter { !$0.isEmpty }
        return trimmed.isEmpty ? defaultGreetings : trimmed
    }

    static func normalizedLines(_ lines: [String]) -> [String] {
        let trimmed = lines.map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }.filter { !$0.isEmpty }
        return trimmed.isEmpty ? defaultGreetings : trimmed
    }

    static func saveGreetings(lines: [String], to store: UserDefaults?) {
        guard let store else { return }
        let normalized = normalizedLines(lines)
        if let data = try? JSONEncoder().encode(normalized) {
            store.set(data, forKey: greetingsKey)
        }
    }

    static func resolvedHeadline(greetings effective: [String], shuffle: Bool, staticIndex: Int) -> String {
        guard let first = effective.first else { return defaultGreetings[0] }
        guard effective.count > 1 else { return first }
        if shuffle {
            return effective.randomElement() ?? first
        }
        let capped = max(0, min(staticIndex, effective.count - 1))
        return effective[capped]
    }
}
