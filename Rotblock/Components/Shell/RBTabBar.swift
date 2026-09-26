//
//  RBTabBar.swift
//  Rotblock
//
//

import SwiftUI

enum RBTab: String, CaseIterable, Hashable {
    case today, presets, settings

    var label: String {
        switch self {
        case .today: return "Today"
        case .presets: return "Presets"
        case .settings: return "Settings"
        }
    }

    var icon: String {
        switch self {
        case .today: return RBIcons.today
        case .presets: return RBIcons.presets
        case .settings: return RBIcons.settings2
        }
    }
}

struct RBTabBar: View {
    @Binding var active: RBTab

    var body: some View {
        HStack(spacing: 6) {
            ForEach(RBTab.allCases, id: \.self) { tab in
                tabButton(tab)
            }
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.rbIvory100)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.rbIvory300, lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
    }

    private func tabButton(_ tab: RBTab) -> some View {
        let isActive = tab == active
        return Button {
            withAnimation(.snappy(duration: 0.18)) { active = tab }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 16, weight: .regular))
                Text(tab.label)
                    .font(RBFont.sans(10, weight: .medium))
            }
            .foregroundStyle(isActive ? Color.rbSlate900 : Color.rbCloud500)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isActive ? Color.rbIvory50 : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isActive ? Color.rbIvory300 : Color.clear, lineWidth: 1)
            )
        }
        .accessibilityIdentifier("tab.\(tab.rawValue)")
        .buttonStyle(PressableButtonStyle())
    }
}

#Preview {
    @Previewable @State var active: RBTab = .today
    return ZStack {
        Color.rbCanvas.ignoresSafeArea()
        VStack {
            Spacer()
            RBTabBar(active: $active)
        }
    }
}
