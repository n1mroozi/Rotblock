import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Timeline Entry

struct PresetWidgetEntry: TimelineEntry {
    let date: Date
    let presetID: String?
    let presetName: String
    let limitType: String
    let isActive: Bool
    let isPending: Bool
    let pendingLabel: String?
}

// MARK: - Timeline Provider

struct PresetWidgetProvider: AppIntentTimelineProvider {
    typealias Entry = PresetWidgetEntry
    typealias Intent = PresetConfigIntent

    func placeholder(in context: Context) -> PresetWidgetEntry {
        PresetWidgetEntry(
            date: Date(),
            presetID: nil,
            presetName: "Focus",
            limitType: "Timer Limit",
            isActive: false,
            isPending: false,
            pendingLabel: nil
        )
    }

    func snapshot(for configuration: PresetConfigIntent, in context: Context) async -> PresetWidgetEntry {
        makeEntry(for: configuration)
    }

    func timeline(for configuration: PresetConfigIntent, in context: Context) async -> Timeline<PresetWidgetEntry> {
        let entry = makeEntry(for: configuration)
        return Timeline(entries: [entry], policy: .never)
    }

    private func makeEntry(for configuration: PresetConfigIntent) -> PresetWidgetEntry {
        let defaults = UserDefaults(suiteName: WidgetManager.Constants.appGroupSuite)
        let activeIDs = WidgetManager.activePresetUUIDStrings(from: defaults)

        guard let entity = configuration.preset else {
            return PresetWidgetEntry(
                date: Date(),
                presetID: nil,
                presetName: "No Preset",
                limitType: "",
                isActive: false,
                isPending: false,
                pendingLabel: nil
            )
        }

        var isActive = activeIDs.contains(entity.id)
        var isPending = false
        var pendingLabel: String?

        if let pending = WidgetManager.pendingUISnapshot(from: defaults),
           pending.widgetPresetUUIDString == entity.id,
           WidgetManager.isFreshPending(snapshot: pending) {
            isActive = pending.showingActivateState
            isPending = true
            pendingLabel = pending.showingActivateState ? "Starting..." : "Stopping..."
        }

        return PresetWidgetEntry(
            date: Date(),
            presetID: entity.id,
            presetName: entity.name,
            limitType: entity.limitType,
            isActive: isActive,
            isPending: isPending,
            pendingLabel: pendingLabel
        )
    }
}

// MARK: - Widget

struct PresetWidget: Widget {
    let kind = WidgetManager.Constants.presetWidgetKind

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: PresetConfigIntent.self,
            provider: PresetWidgetProvider()
        ) { entry in
            PresetWidgetView(entry: entry)
        }
        .configurationDisplayName("Preset")
        .description("Start and stop a Rotblock preset from your home screen.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Widget View

struct PresetWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PresetWidgetEntry

    var body: some View {
        Group {
            if entry.presetID == nil {
                unconfiguredView
            } else if family == .systemMedium {
                mediumView
            } else {
                smallView
            }
        }
        .containerBackground(for: .widget) {
            entry.isActive ? PW.slate900 : PW.ivory50
        }
    }

    // MARK: Unconfigured

    private var unconfiguredView: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(systemName: "square.stack")
                .font(.system(size: 20, weight: .light))
                .foregroundStyle(PW.cloud400)
            Spacer()
            Text("No preset\nselected")
                .font(PW.serif(16))
                .foregroundStyle(PW.slate900)
                .lineSpacing(3)
            Text("Hold to configure")
                .font(PW.mono(9))
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(PW.cloud400)
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(16)
    }

    // MARK: Small

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                Image(systemName: limitTypeIcon)
                    .font(.system(size: 16, weight: .light))
                    .foregroundStyle(entry.isActive ? PW.ivory50.opacity(0.4) : PW.cloud400)
                Spacer()
                if entry.isActive {
                    Circle()
                        .fill(PW.green)
                        .frame(width: 7, height: 7)
                        .padding(.top, 4)
                }
            }
            Spacer()
            Text(entry.presetName)
                .font(PW.serif(19, weight: .medium))
                .foregroundStyle(entry.isActive ? PW.ivory50 : PW.slate900)
                .lineLimit(2)
                .minimumScaleFactor(0.72)
                .fixedSize(horizontal: false, vertical: false)
            toggleButton
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(14)
    }

    // MARK: Medium

    private var mediumView: some View {
        HStack(alignment: .bottom, spacing: 14) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    Image(systemName: limitTypeIcon)
                        .font(.system(size: 12, weight: .light))
                        .foregroundStyle(entry.isActive ? PW.ivory50.opacity(0.4) : PW.cloud400)
                    Text(
                        entry.isPending
                            ? (entry.pendingLabel ?? "Updating")
                            : (entry.isActive ? "Active" : entry.limitType)
                    )
                    .font(PW.mono(9))
                    .tracking(1.4)
                    .textCase(.uppercase)
                    .foregroundStyle(
                        entry.isActive ? PW.green : PW.cloud500
                    )
                }
                Spacer()
                Text(entry.presetName)
                    .font(PW.serif(24, weight: .medium))
                    .foregroundStyle(entry.isActive ? PW.ivory50 : PW.slate900)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
                    .fixedSize(horizontal: false, vertical: false)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

            squareButton
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(16)
    }

    // MARK: Buttons

    private var toggleButtonLabel: some View {
        HStack(spacing: 5) {
            Image(systemName: entry.isActive ? "stop.fill" : "play.fill")
                .font(.system(size: 9, weight: .bold))
            Text(entry.isPending ? (entry.pendingLabel ?? "…") : (entry.isActive ? "Stop" : "Start"))
                .font(PW.sans(12, weight: .semibold))
        }
        .foregroundStyle(entry.isActive ? PW.slate900 : PW.ivory50)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(entry.isActive ? PW.ivory50 : PW.slate900)
        )
    }

    @ViewBuilder
    private var toggleButton: some View {
        if entry.isActive {
            Button(intent: StopPresetIntent(presetID: entry.presetID ?? "")) {
                toggleButtonLabel
            }
            .buttonStyle(.plain)
        } else {
            Button(intent: ActivatePresetIntent(presetID: entry.presetID ?? "")) {
                toggleButtonLabel
            }
            .buttonStyle(.plain)
        }
    }

    private var squareButtonLabel: some View {
        VStack(spacing: 6) {
            Image(systemName: entry.isActive ? "stop.fill" : "play.fill")
                .font(.system(size: 18, weight: .semibold))
            Text(entry.isPending ? "…" : (entry.isActive ? "Stop" : "Start"))
                .font(PW.sans(11, weight: .semibold))
        }
        .foregroundStyle(entry.isActive ? PW.slate900 : PW.ivory50)
        .frame(width: 70, height: 70)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(entry.isActive ? PW.ivory50 : PW.slate900)
        )
    }

    @ViewBuilder
    private var squareButton: some View {
        if entry.isActive {
            Button(intent: StopPresetIntent(presetID: entry.presetID ?? "")) {
                squareButtonLabel
            }
            .buttonStyle(.plain)
        } else {
            Button(intent: ActivatePresetIntent(presetID: entry.presetID ?? "")) {
                squareButtonLabel
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Helpers

    /// `entry.limitType` is a joined block label (e.g. "Timer + Location"); the first match wins.
    private var limitTypeIcon: String {
        let label = entry.limitType
        if label.contains("Timer") { return "hourglass" }
        if label.contains("Allowed Hours") || label.contains("Allowed hours") { return "clock" }
        if label.contains("Location") { return "location.fill" }
        return "apps.iphone"
    }
}

// MARK: - Theme tokens

private enum PW {
    static let slate900 = Color(red: 0.098, green: 0.098, blue: 0.094)
    static let cloud600 = Color(red: 0.400, green: 0.400, blue: 0.388)
    static let cloud500 = Color(red: 0.569, green: 0.569, blue: 0.553)
    static let cloud400 = Color(red: 0.690, green: 0.690, blue: 0.678)
    static let cloud100 = Color(red: 0.922, green: 0.922, blue: 0.914)
    static let ivory50 = Color(red: 0.980, green: 0.980, blue: 0.969)
    static let green = Color(red: 0.180, green: 0.690, blue: 0.310)

    static func serif(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom("Fraunces", size: size).weight(weight)
    }

    static func sans(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    static func mono(_ size: CGFloat) -> Font {
        .system(size: size, weight: .regular, design: .monospaced)
    }
}

// MARK: - Previews

#Preview("Small — unconfigured", as: .systemSmall) {
    PresetWidget()
} timeline: {
    PresetWidgetEntry(date: .now, presetID: nil, presetName: "", limitType: "", isActive: false, isPending: false, pendingLabel: nil)
}

#Preview("Small — inactive", as: .systemSmall) {
    PresetWidget()
} timeline: {
    PresetWidgetEntry(date: .now, presetID: "1", presetName: "Focus", limitType: "Timer Limit", isActive: false, isPending: false, pendingLabel: nil)
}

#Preview("Small — active", as: .systemSmall) {
    PresetWidget()
} timeline: {
    PresetWidgetEntry(date: .now, presetID: "1", presetName: "Focus", limitType: "Timer Limit", isActive: true, isPending: false, pendingLabel: nil)
}

#Preview("Medium — unconfigured", as: .systemMedium) {
    PresetWidget()
} timeline: {
    PresetWidgetEntry(date: .now, presetID: nil, presetName: "", limitType: "", isActive: false, isPending: false, pendingLabel: nil)
}

#Preview("Medium — inactive", as: .systemMedium) {
    PresetWidget()
} timeline: {
    PresetWidgetEntry(date: .now, presetID: "2", presetName: "Evening Wind-down", limitType: "Allowed Hours", isActive: false, isPending: false, pendingLabel: nil)
}

#Preview("Medium — active", as: .systemMedium) {
    PresetWidget()
} timeline: {
    PresetWidgetEntry(date: .now, presetID: "2", presetName: "Evening Wind-down", limitType: "Allowed Hours", isActive: true, isPending: false, pendingLabel: nil)
}

#Preview("Medium — starting", as: .systemMedium) {
    PresetWidget()
} timeline: {
    PresetWidgetEntry(date: .now, presetID: "3", presetName: "Location Focus", limitType: "Location", isActive: true, isPending: true, pendingLabel: "Starting...")
}

#Preview("Medium — stopping", as: .systemMedium) {
    PresetWidget()
} timeline: {
    PresetWidgetEntry(date: .now, presetID: "3", presetName: "Location Focus", limitType: "Location", isActive: false, isPending: true, pendingLabel: "Stopping...")
}
