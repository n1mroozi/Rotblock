import FamilyControls
import ManagedSettings
import SwiftUI

// MARK: - Color Tokens (extension-local copy)

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a: UInt64
        let r: UInt64
        let g: UInt64
        let b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    static let rbSurface = Color(hex: "1E1F22")
    static let rbSurfaceContainerHigh = Color(hex: "282A2F")
    static let rbOnSurfaceVariant = Color(hex: "C4C6D0")
    static let rbOutline = Color(hex: "8B919E")
    static let rbGoldDim = Color(hex: "EFBF04")
}

// MARK: - Gold Progress Bar

struct GoldProgressBar: View {
    let progress: Double
    var height: CGFloat = 6

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(Color(white: 0.15))
            Capsule()
                .fill(Color.rbGoldDim)
                .scaleEffect(x: max(0.001, min(1.0, progress)), anchor: .leading)
        }
        .frame(height: height)
    }
}

// MARK: - Shield Card

struct ShieldCard: View {
    let icon: String
    let label: String
    let subtitle: String
    let isActive: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundStyle(isActive ? Color.rbGoldDim : Color.white.opacity(0.5))
                Spacer()
                Capsule()
                    .fill(isActive ? Color.rbGoldDim : Color.rbSurfaceContainerHigh)
                    .frame(width: 40, height: 22)
                    .overlay(
                        Circle()
                            .fill(Color.black)
                            .frame(width: 18, height: 18)
                            .offset(x: isActive ? 9 : -9)
                    )
                    .shadow(color: isActive ? Color.rbGoldDim.opacity(0.3) : .clear, radius: 10)
            }
            .padding(.bottom, 16)

            Text(label)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.white)
            Text(subtitle)
                .font(.system(size: 11, weight: .semibold))
                .tracking(2)
                .foregroundStyle(Color.rbOutline)
                .padding(.top, 4)
        }
        .padding(20)
        .background(Color.rbSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    isActive ? Color.rbGoldDim.opacity(0.5) : Color.white.opacity(0.1),
                    lineWidth: isActive ? 2 : 1
                )
        )
    }
}

// MARK: - Preset Summary (mirrors SharedData.PresetSummary for extension use)

struct PresetSummary: Codable, Equatable, Identifiable {
    let id: UUID
    let name: String
    let lastUsed: Date

    static func load() -> [PresetSummary] {
        guard
            let suite = UserDefaults(suiteName: "group.com.n1labs.rotblock"),
            let data = suite.data(forKey: "recentPresets"),
            let decoded = try? JSONDecoder().decode([PresetSummary].self, from: data)
        else { return [] }
        return decoded
    }
}

// MARK: - Active preset (Today dashboard device-activity UI)

/// Minimal preset snapshot for the embedded dashboard (name + id).
struct DashboardActivePresetInfo: Equatable {
    let id: UUID
    let name: String
}

// MARK: - Dashboard Active Shield (actual active preset only)

struct DashboardActiveShields: View {
    let activePreset: DashboardActivePresetInfo?

    var body: some View {
        Group {
            if let activePreset {
                VStack(spacing: 0) {
                    HStack {
                        Text("Active Shield")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(Color.white)
                        Spacer()
                    }
                    .padding(.bottom, 20)

                    ShieldCard(
                        icon: "shield.fill",
                        label: activePreset.name,
                        subtitle: "CURRENTLY ACTIVE",
                        isActive: true
                    )
                }
            }
        }
    }
}

// MARK: - App Usage Entry

struct AppUsageEntry: Identifiable {
    let id = UUID()
    let name: String
    let minutes: Double
    let category: String
    let token: ApplicationToken?
}

// MARK: - Dashboard Most Used

struct DashboardMostUsed: View {
    let apps: [AppUsageEntry]
    var onShowAppLimit: () -> Void = {}

    private var maxMinutes: Double {
        apps.first?.minutes ?? 1
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Most Used")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color.white)
                Spacer()
            }
            .padding(.bottom, 20)

            VStack(spacing: 10) {
                ForEach(Array(apps.prefix(5))) { app in
                    Button(action: onShowAppLimit) {
                        HStack(spacing: 8) {
                            appIcon(for: app.token)
                                .frame(width: 64, height: 64)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            VStack(alignment: .leading, spacing: 6) {
                                Text(app.name)
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(Color.white)
                                GoldProgressBar(progress: app.minutes / maxMinutes)
                            }
                            Text(formatMinutes(app.minutes))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color.white)
                                .fixedSize()
                        }
                        .padding(14)
                        .background(Color.rbSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.05), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private func appIcon(for token: ApplicationToken?) -> some View {
        if let token {
            Label(token)
                .labelStyle(.iconOnly)
        } else {
            Color.rbSurface
                .overlay(
                    Image(systemName: "app.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.rbOnSurfaceVariant)
                )
        }
    }

    private func formatMinutes(_ minutes: Double) -> String {
        let m = Int(minutes)
        return m >= 60 ? "\(m / 60)h \(m % 60)m" : "\(m)m"
    }
}
