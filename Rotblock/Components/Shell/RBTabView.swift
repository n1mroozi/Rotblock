//
//  RBTabView.swift
//  Rotblock
//
//

import SwiftUI

// MARK: - Tab Switcher Environment

/// Injected action that lets any child flip the active tab programmatically
/// (e.g. the dashboard's "active preset" card jumping to the Presets tab).
struct RBTabSwitcherKey: EnvironmentKey {
    static let defaultValue: (RBTab) -> Void = { _ in }
}

extension EnvironmentValues {
    var rbTabSwitcher: (RBTab) -> Void {
        get { self[RBTabSwitcherKey.self] }
        set { self[RBTabSwitcherKey.self] = newValue }
    }
}

// MARK: - RBTabView

struct RBTabView: View {
    @State private var active: RBTab = .today

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.rbIvory100.ignoresSafeArea()

            ZStack {
                tabPane(.today) { DashboardView() }
                tabPane(.presets) { PresetsView() }
                tabPane(.settings) { SettingsView() }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .environment(\.rbTabSwitcher) { newTab in
                withAnimation(.snappy(duration: 0.18)) { active = newTab }
            }

            RBTabBar(active: $active)
        }
    }

    /// Keeps every tab mounted so extension-hosted views (e.g. `DeviceActivityReport`)
    /// are not torn down when switching tabs.
    @ViewBuilder
    private func tabPane<Content: View>(_ tab: RBTab, @ViewBuilder content: () -> Content) -> some View {
        content()
            .opacity(active == tab ? 1 : 0)
            .allowsHitTesting(active == tab)
            .accessibilityHidden(active != tab)
    }
}
