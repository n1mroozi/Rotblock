//
//  WhatsNewView.swift
//  Rotblock
//
//  Created by n1 on 5/9/26.
//

import SwiftUI

struct WhatsNewView: View {
    var body: some View {
        ZStack {
            Color.rbIvory100.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    ForEach(ReleaseNote.all) { release in
                        ReleaseNoteSection(release: release)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 80)
            }
        }
        .navigationTitle("What's new")
        .navigationBarTitleDisplayMode(.large)
        .toolbar(.visible, for: .navigationBar)
    }
}

// MARK: - Section

private struct ReleaseNoteSection: View {
    let release: ReleaseNote

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Headline(text: release.version, size: 22, weight: .regular)
                Text(release.date)
                    .font(RBFont.sans(13))
                    .foregroundStyle(Color.rbCloud500)
            }

            VStack(spacing: 0) {
                ForEach(Array(release.entries.enumerated()), id: \.offset) { index, entry in
                    if index > 0 {
                        Rectangle()
                            .fill(Color.rbIvory200)
                            .frame(height: 1)
                            .padding(.leading, 44)
                    }
                    ChangeRow(entry: entry, isLast: index == release.entries.count - 1)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.rbIvory50)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.rbIvory300, lineWidth: 1)
            )
        }
    }
}

// MARK: - Row

private struct ChangeRow: View {
    let entry: ChangeEntry
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(entry.kind.tint)
                    .frame(width: 28, height: 28)
                Image(systemName: entry.kind.icon)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(entry.kind.ink)
            }
            .padding(.top, 1)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(RBFont.sans(14, weight: .medium))
                    .foregroundStyle(Color.rbSlate900)
                if let detail = entry.detail {
                    Text(detail)
                        .font(RBFont.sans(12))
                        .foregroundStyle(Color.rbCloud600)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

// MARK: - Models

private struct ReleaseNote: Identifiable {
    let id = UUID()
    let version: String
    let date: String
    let entries: [ChangeEntry]

    static let all: [ReleaseNote] = [
        .init(
            version: "1.2",
            date: "May 2026",
            entries: [
                .init(kind: .new, title: "Onboarding permissions", detail: "Allow notifications and location directly from the welcome flow."),
                .init(kind: .new, title: "Settings search", detail: "Find any setting instantly with the new search bar."),
                .init(kind: .improved, title: "Preset creation flow", detail: "Smoother steps and clearer copy throughout."),
                .init(kind: .improved, title: "What's new screen", detail: "You're looking at it."),
            ]
        ),
        .init(
            version: "1.101",
            date: "Apr 2026",
            entries: [
                .init(kind: .new, title: "Location-based presets", detail: "Activate a preset automatically when you arrive at a place."),
                .init(kind: .new, title: "Live Activity", detail: "See your active preset on the Dynamic Island and Lock Screen."),
                .init(kind: .improved, title: "Block shield messages", detail: "Customize what you see when an app is blocked."),
                .init(kind: .fix, title: "Widget not refreshing", detail: "Fixed an issue where the home screen widget showed stale preset data."),
            ]
        ),
        .init(
            version: "1.0",
            date: "Mar 2026",
            entries: [
                .init(kind: .new, title: "Rotblock is here", detail: "Block distracting apps, set gentle limits, and get your attention back."),
                .init(kind: .new, title: "Presets", detail: "Save and switch between different sets of blocked apps and schedules."),
                .init(kind: .new, title: "Screen Time integration", detail: "Apple's Screen Time API enforces the rules — your app list stays private."),
            ]
        ),
    ]
}

private struct ChangeEntry {
    let kind: ChangeKind
    let title: String
    var detail: String?
}

private enum ChangeKind {
    case new, improved, fix

    var icon: String {
        switch self {
        case .new: "plus"
        case .improved: "arrow.up"
        case .fix: "wrench"
        }
    }

    var tint: Color {
        switch self {
        case .new: Color.rbMintFill
        case .improved: Color.rbOrangeTint
        case .fix: Color(red: 0xEF/255.0, green: 0xF0/255.0, blue: 0xF8/255.0)
        }
    }

    var ink: Color {
        switch self {
        case .new: Color.rbMintInk
        case .improved: Color.rbOrange
        case .fix: Color(red: 0x5C/255.0, green: 0x6B/255.0, blue: 0xC8/255.0)
        }
    }
}
