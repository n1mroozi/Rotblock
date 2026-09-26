//
//  SettingsView.swift
//  Rotblock
//

import StoreKit
import SwiftUI

private enum SettingsDestination: Hashable {
    case appCustomization
    case permissions
    case targets
    case whatsNew
}

struct SettingsView: View {
    @Environment(\.rbTabSwitcher) private var switchTab
    @Environment(\.requestReview) private var requestReview
    @AppStorage("rb.didCompleteOnboarding") private var didCompleteOnboarding = true
    @AppStorage("rb.pendingPostPresetOnboarding") private var pendingPostPresetOnboarding = false
    @AppStorage("rb.didSelectInitalGoals") private var didSelectInitialGoals = true
    @AppStorage("rb.appearance") private var appearanceRaw: Int = 1
    @AppStorage("rb.frictionStyle") private var frictionStyleRaw: Int = 1
    @AppStorage("dailyLimitMinutes", store: UserDefaults(suiteName: "group.com.n1labs.rotblock"))
    private var dailyLimitMinutes: Int = 240

    @State private var confirmResetOnboarding = false
    @State private var searchText = ""
    @State private var navigationPath: [SettingsDestination] = []
    @FocusState private var searchFocused: Bool
    @StateObject private var searchIndex = SettingSearchIndex(entries: SettingsView.makeEntries())
    @State private var searchUpdateTask: Task<Void, Never>?

    private var isSearchActive: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                titleBlock
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 16)
                SettingsSearchBar(text: $searchText, isFocused: $searchFocused)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 12)
                ScrollView {
                    VStack(spacing: 0) {
                        defaultsGroup
                            .padding(.horizontal, 24)
                            .padding(.bottom, 24)
                        appGroup
                            .padding(.horizontal, 24)
                            .padding(.bottom, 24)
                        aboutGroup
                            .padding(.horizontal, 24)
                            .padding(.bottom, 24)

                        Text(footerAttributedString)
                            .font(RBFont.sans(12))
                            .foregroundStyle(Color.rbCloud500)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 8)
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 120)
                }
                .scrollDismissesKeyboard(.immediately)
                .opacity(isSearchActive ? 0.48 : 1)
                .animation(.easeInOut(duration: 0.18), value: isSearchActive)
                .overlay(alignment: .top) {
                    if isSearchActive { searchOverlay }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.rbIvory100.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: SettingsDestination.self) { destination in
                switch destination {
                case .appCustomization: AppCustomizationView()
                case .permissions: PermissionsView()
                case .targets: TargetsView(mode: .settings)
                case .whatsNew: WhatsNewView()
                }
            }
            .onChange(of: searchText) { _, newValue in
                scheduleSearchQueryUpdate(newValue)
            }
            .onDisappear {
                searchUpdateTask?.cancel()
                searchUpdateTask = nil
            }
        }
        .alert("Reset onboarding?", isPresented: $confirmResetOnboarding) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                didCompleteOnboarding = false
                pendingPostPresetOnboarding = false
                didSelectInitialGoals = false
            }
        } message: {
            Text("You'll go through welcome and target setup again.")
        }
    }

    private var titleBlock: some View {
        Headline(text: "Settings", size: 36, weight: .regular)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var searchOverlay: some View {
        ZStack(alignment: .top) {
            Rectangle()
                .fill(Color.rbSlate900.opacity(0.07))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    searchText = ""
                    searchFocused = false
                }
            SettingsSearchResults(
                query: searchText,
                results: searchIndex.results,
                onSelect: navigate(to:)
            )
            .padding(.horizontal, 24)
            .padding(.top, 6)
        }
    }

    /// Coalesces search work while typing so the main thread stays responsive.
    private func scheduleSearchQueryUpdate(_ raw: String) {
        searchUpdateTask?.cancel()
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            searchIndex.updateQuery("")
            return
        }
        searchUpdateTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 110_000_000)
            guard !Task.isCancelled else { return }
            searchIndex.updateQuery(raw)
        }
    }

    // MARK: - Search Results

    private func navigate(to route: SettingsRoute) {
        searchUpdateTask?.cancel()
        searchUpdateTask = nil
        searchText = ""
        searchFocused = false
        switch route {
        case .dailyBudget:
            navigationPath.append(.targets)
        case .shieldMessage:
            navigationPath.append(.appCustomization)
        case .permissions:
            navigationPath.append(.permissions)
        case .privacyPolicy:
            openURL("https://n-n.dev/rotblock/privacy-policy/")
        case .whatsNew:
            navigationPath.append(.whatsNew)
        case .appearance, .notifications, .focusMode,
             .blockedApps, .passcode, .advancedLogs /* , .frictionStyle */:
            break
        }
    }

    // MARK: - Search Index Entries

    private static func makeEntries() -> [SettingSearchEntry] {
        [
            SettingSearchEntry(
                id: "daily-budget",
                title: "Daily budget",
                subtitle: "Set your daily focus time target",
                section: "Defaults",
                keywords: ["targets", "goals", "hours", "time", "limit", "focus", "session"],
                route: .dailyBudget,
                isAvailable: { true },
                basePriority: 10
            ),
            SettingSearchEntry(
                id: "messages",
                title: "Messages",
                subtitle: "Customize your blocking screen",
                section: "App",
                keywords: ["block", "screen", "splash", "message", "text", "customiz"],
                route: .shieldMessage,
                isAvailable: { true },
                basePriority: 8
            ),
            SettingSearchEntry(
                id: "permissions",
                title: "Permissions",
                subtitle: "Notification and screen time access",
                section: "App",
                keywords: ["notifications", "access", "allow", "screen time", "family controls"],
                route: .permissions,
                isAvailable: { true },
                basePriority: 8
            ),
            SettingSearchEntry(
                id: "appearance",
                title: "Appearance",
                subtitle: "Match system",
                section: "App",
                keywords: ["theme", "dark mode", "light mode", "display", "color scheme", "system", "app appearance", "appearance"],
                route: .appearance,
                isAvailable: { true },
                basePriority: 7
            ),
            SettingSearchEntry(
                id: "privacy-policy",
                title: "Privacy Policy",
                subtitle: "How we don't track you",
                section: "About",
                keywords: ["privacy", "data", "tracking", "gdpr", "policy"],
                route: .privacyPolicy,
                isAvailable: { true },
                basePriority: 5
            ),
            SettingSearchEntry(
                id: "whats-new",
                title: "What's new",
                subtitle: "Latest changes and improvements",
                section: "About",
                keywords: ["changelog", "updates", "version", "release", "notes"],
                route: .whatsNew,
                isAvailable: { true },
                basePriority: 5
            ),
        ]
    }

    // MARK: - Settings Groups

    private var defaultsGroup: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(text: "Defaults")
                .padding(.leading, 2)

            VStack(spacing: 0) {
                RBDividerRow()
                NavigationLink(value: SettingsDestination.targets) {
                    SettingRow(
                        icon: RBIcons.sparkle,
                        label: "Daily budget",
                        subtitle: dailyBudgetSubtitle,
                        isLast: false
                    ) {
                        chevronAccessory
                    }
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityIdentifier("settings.row.dailyBudget")

                #if DEBUG
                    RBDividerRow()

                    Button {
                        confirmResetOnboarding = true
                    } label: {
                        SettingRow(
                            icon: "arrow.counterclockwise",
                            label: "Reset onboarding",
                            isLast: true
                        ) {
                            EmptyView()
                        }
                    }
                    .buttonStyle(PressableButtonStyle())
                #endif
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

    private var appGroup: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(text: "App")
                .padding(.leading, 2)

            VStack(spacing: 0) {
                RBDividerRow()
                NavigationLink(value: SettingsDestination.appCustomization) {
                    SettingRow(
                        icon: RBIcons.shield,
                        label: "Messages",
                        isLast: false
                    ) {
                        chevronAccessory
                    }
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityIdentifier("settings.row.messages")

                RBDividerRow()

                NavigationLink(value: SettingsDestination.permissions) {
                    SettingRow(
                        icon: RBIcons.settings2,
                        label: "Permissions",
                        isLast: false
                    ) {
                        chevronAccessory
                    }
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityIdentifier("settings.row.permissions")

                RBDividerRow()

                SettingRow(
                    icon: "circle.lefthalf.filled",
                    label: "Appearance",
                    isLast: true
                ) {
                    AppearancePicker(selection: $appearanceRaw)
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

    private var aboutGroup: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(text: "About")
                .padding(.leading, 2)

            VStack(spacing: 0) {
                Button {
                    openURL("https://n-n.dev/rotblock/privacy-policy/")
                } label: {
                    SettingRow(
                        icon: RBIcons.shield,
                        label: "Privacy policy",
                        isLast: true
                    ) {
                        chevronAccessory
                    }
                }
                .buttonStyle(PressableButtonStyle())
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

    // MARK: - Accessories

    private var chevronAccessory: some View {
        Image(systemName: RBIcons.chevronRight)
            .font(.system(size: 12, weight: .regular))
            .foregroundStyle(Color.rbCloud500)
    }

    private func openURL(_ raw: String) {
        guard let url = URL(string: raw) else { return }
        #if canImport(UIKit)
            UIApplication.shared.open(url)
        #endif
    }

    private var dailyBudgetSubtitle: String {
        let total = dailyLimitMinutes
        let hours = total / 60
        let rem = total % 60
        if hours == 0 { return "\(total)m total" }
        if rem == 0 { return "\(hours)h total" }
        return "\(hours)h \(rem)m total"
    }

    private static var appVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0"
    }

    private var footerAttributedString: AttributedString {
        var result = AttributedString("By using RotBlock you agree to our ")

        var privacy = AttributedString("privacy policy")
        privacy.link = URL(string: "https://n-n.dev/rotblock/privacy-policy/")
        privacy.underlineStyle = .single

        var middle = AttributedString(" and our ")

        var conditions = AttributedString("conditions of use")
        conditions.link = URL(string: "https://n-n.dev/rotblock/conditions-of-use")
        conditions.underlineStyle = .single

        return result + privacy + middle + conditions
    }
}

private enum SearchResultTitleHighlight {
    @ViewBuilder
    static func titleText(title: String, query: String) -> some View {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !q.isEmpty, let range = title.range(of: q, options: [.caseInsensitive, .diacriticInsensitive]) {
            let before = String(title[..<range.lowerBound])
            let match = String(title[range])
            let after = String(title[range.upperBound...])
            HStack(spacing: 0) {
                Text(before)
                    .font(RBFont.sans(15, weight: .regular))
                    .foregroundStyle(Color.rbSlate900)
                Text(match)
                    .font(RBFont.sans(15, weight: .semibold))
                    .foregroundStyle(Color.rbSlate900)
                    .underline(true, color: Color.rbSlate900)
                Text(after)
                    .font(RBFont.sans(15, weight: .regular))
                    .foregroundStyle(Color.rbSlate900)
            }
        } else {
            Text(title)
                .font(RBFont.sans(15, weight: .semibold))
                .foregroundStyle(Color.rbSlate900)
        }
    }
}

// MARK: - SettingsSearchBar

private struct SettingsSearchBar: View {
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(Color.rbCloud500)

            TextField("Search settings", text: $text)
                .font(RBFont.sans(15))
                .foregroundStyle(Color.rbSlate900)
                .focused($isFocused)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .accessibilityIdentifier("settings.searchField")

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.rbCloud600)
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(Color.rbIvory200.opacity(0.85)))
                }
                .buttonStyle(.plain)
                .transition(.opacity)
                .accessibilityIdentifier("settings.searchClear")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Capsule(style: .continuous).fill(Color.rbIvory50))
        .overlay(
            Capsule(style: .continuous)
                .stroke(isFocused ? Color.rbSlate900.opacity(0.28) : Color.rbIvory300, lineWidth: 1)
        )
        .shadow(color: Color.rbSlate900.opacity(0.06), radius: 12, x: 0, y: 6)
        .animation(.easeInOut(duration: 0.15), value: isFocused)
        .animation(.easeInOut(duration: 0.15), value: text.isEmpty)
    }
}

// MARK: - SettingsSearchResults

private struct SettingsSearchResults: View {
    let query: String
    let results: [SettingSearchResult]
    let onSelect: (SettingsRoute) -> Void

    private static let cardShape = RoundedRectangle(cornerRadius: 18, style: .continuous)

    var body: some View {
        if results.isEmpty {
            emptyState
        } else {
            resultsList
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("Nothing matches.")
                .font(RBFont.headline(18, weight: .regular))
                .italic()
                .foregroundStyle(Color.rbSlate900)

            Text("Try a different word — like “budget” or “block.”")
                .font(RBFont.sans(13))
                .foregroundStyle(Color.rbCloud600)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 32)
        .padding(.horizontal, 22)
        .frame(maxWidth: .infinity)
        .background(Self.cardShape.fill(Color.rbIvory50))
        .overlay(Self.cardShape.stroke(Color.rbIvory300, lineWidth: 1))
        .shadow(color: Color.rbSlate900.opacity(0.12), radius: 28, x: 0, y: 14)
    }

    private var resultsList: some View {
        let count = results.count
        return VStack(alignment: .leading, spacing: 8) {
            Text("\(count) MATCH\(count == 1 ? "" : "ES")")
                .font(RBFont.mono(10, weight: .regular))
                .tracking(2.2)
                .textCase(.uppercase)
                .foregroundStyle(Color.rbCloud500)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                ForEach(Array(results.enumerated()), id: \.element.id) { index, result in
                    if index > 0 {
                        Rectangle()
                            .fill(Color.rbIvory200)
                            .frame(height: 1)
                            .padding(.leading, 56)
                    }
                    Button {
                        onSelect(result.entry.route)
                    } label: {
                        SearchResultRow(query: query, result: result)
                    }
                    .buttonStyle(PressableButtonStyle())
                    .accessibilityIdentifier("settings.searchResult.\(result.entry.id)")
                }
            }
            .background(Self.cardShape.fill(Color.rbIvory50))
            .overlay(Self.cardShape.stroke(Color.rbIvory300, lineWidth: 1))
            .shadow(color: Color.rbSlate900.opacity(0.14), radius: 32, x: 0, y: 16)
        }
    }
}

// MARK: - SearchResultRow

private struct SearchResultRow: View {
    let query: String
    let result: SettingSearchResult

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.rbIvory100)
                    .frame(width: 30, height: 30)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.rbIvory300, lineWidth: 1)
                    )
                Image(systemName: iconName(for: result.entry.route))
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color.rbSlate900)
            }

            VStack(alignment: .leading, spacing: 3) {
                SearchResultTitleHighlight.titleText(title: result.entry.title, query: query)

                HStack(spacing: 4) {
                    Text(result.entry.section.uppercased())
                        .font(RBFont.mono(10))
                        .foregroundStyle(Color.rbCloud500)
                        .tracking(0.3)

                    if let subtitle = result.entry.subtitle {
                        Text("·")
                            .font(RBFont.sans(11))
                            .foregroundStyle(Color.rbCloud400)
                        Text(subtitle)
                            .font(RBFont.sans(11))
                            .foregroundStyle(Color.rbCloud600)
                            .lineLimit(1)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "return.left")
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(Color.rbCloud500)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func iconName(for route: SettingsRoute) -> String {
        switch route {
        case .dailyBudget: return RBIcons.sparkle
        case .shieldMessage: return RBIcons.shield
        case .permissions: return RBIcons.settings2
        case .appearance: return "circle.lefthalf.filled"
        case .privacyPolicy: return RBIcons.shield
        case .whatsNew: return "sparkles"
        case .notifications: return RBIcons.bell
        case .focusMode: return RBIcons.focus
        case .blockedApps: return "app.badge"
        case .passcode: return RBIcons.lock
        case .advancedLogs: return "list.bullet"
        }
    }
}

// MARK: - SettingRow

/// A horizontal row inside a settings group: icon tile + label + trailing accessory.
private struct SettingRow<Accessory: View>: View {
    let icon: String
    let label: String
    var subtitle: String?
    var isLast: Bool
    @ViewBuilder var accessory: Accessory

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.rbIvory100)
                    .frame(width: 34, height: 34)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.rbIvory300, lineWidth: 1)
                    )
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(Color.rbSlate900)
            }

            VStack(alignment: .leading, spacing: subtitle == nil ? 0 : 3) {
                Text(label)
                    .font(RBFont.sans(15))
                    .foregroundStyle(Color.rbSlate900)
                if let subtitle {
                    Text(subtitle)
                        .font(RBFont.sans(12))
                        .foregroundStyle(Color.rbCloud600)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            accessory
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

/// Thin ivory200 divider between stacked `SettingRow`s, inset past the 34pt icon tile.
private struct RBDividerRow: View {
    var body: some View {
        Rectangle()
            .fill(Color.rbIvory200)
            .frame(height: 1)
            .padding(.leading, 64)
    }
}

// MARK: - AppearancePicker

private struct AppearancePicker: View {
    @Binding var selection: Int

    private let options: [(Int, String)] = [(1, "Light"), (2, "Dark"), (0, "System")]

    private var currentLabel: String {
        options.first(where: { $0.0 == selection })?.1 ?? "Light"
    }

    var body: some View {
        Menu {
            ForEach(options, id: \.0) { value, label in
                Button {
                    withAnimation(.snappy(duration: 0.18)) { selection = value }
                } label: {
                    if selection == value {
                        Label(label, systemImage: "checkmark")
                    } else {
                        Text(label)
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(currentLabel)
                    .font(RBFont.sans(14))
                    .foregroundStyle(Color.rbSlate900)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(Color.rbCloud500)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.rbIvory100)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.rbIvory300, lineWidth: 1)
            )
        }
    }
}

// MARK: - FrictionStylePicker

private struct FrictionStylePicker: View {
    @Binding var selection: Int

    private let options: [(Int, String)] = [(0, "Gentle"), (1, "Standard"), (2, "Strict")]

    private var currentLabel: String {
        options.first(where: { $0.0 == selection })?.1 ?? "Standard"
    }

    var body: some View {
        Menu {
            ForEach(options, id: \.0) { value, label in
                Button {
                    withAnimation(.snappy(duration: 0.18)) { selection = value }
                } label: {
                    if selection == value {
                        Label(label, systemImage: "checkmark")
                    } else {
                        Text(label)
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(currentLabel)
                    .font(RBFont.sans(14))
                    .foregroundStyle(Color.rbSlate900)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(Color.rbCloud500)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.rbIvory100)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.rbIvory300, lineWidth: 1)
            )
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
