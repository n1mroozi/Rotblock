import AppIntents
import Foundation
import WidgetKit

// MARK: - Preset Entity

struct PresetEntity: AppEntity {
    let id: String
    let name: String
    let limitType: String

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Preset")
    static var defaultQuery = PresetEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

// MARK: - Preset Entity Query

struct PresetEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [PresetEntity] {
        let idSet = Set(identifiers)
        return loadPresets().filter { idSet.contains($0.id) }
    }

    func suggestedEntities() async throws -> [PresetEntity] {
        loadPresets()
    }

    func defaultResult() async -> PresetEntity? {
        loadPresets().first
    }

    private func loadPresets() -> [PresetEntity] {
        let defaults = UserDefaults(suiteName: WidgetManager.Constants.appGroupSuite)
        guard let data = defaults?.data(forKey: WidgetManager.Constants.savedSelectionPresetsKey),
              let presets = try? JSONDecoder().decode([PresetValues].self, from: data)
        else { return [] }
        return presets
            // Pure open-limit presets can't be driven from the widget; combined ones can.
            .filter { $0.blockKinds != [.open] }
            .sorted { $0.createdAt > $1.createdAt }
            .map { PresetEntity(id: $0.id.uuidString, name: $0.name, limitType: $0.blocksLabel) }
    }
}

// MARK: - Widget Configuration Intent

struct PresetConfigIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select Preset"
    static var description = IntentDescription("Choose which preset to show in the widget")

    @Parameter(title: "Preset")
    var preset: PresetEntity?
}

// MARK: - Activate Preset Intent (opens app to run full activation logic)

struct ActivatePresetIntent: AppIntent {
    static var title: LocalizedStringResource = "Activate Preset"
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Preset ID")
    var presetID: String

    init() {}

    init(presetID: String) {
        self.presetID = presetID
    }

    func perform() async throws -> some IntentResult {
        await WidgetManager.enqueuePendingPresetToggle(presetIDString: presetID, activate: true)
        return .result()
    }
}

// MARK: - Stop Preset Intent (runs in background, no app launch)

struct StopPresetIntent: AppIntent {
    static var title: LocalizedStringResource = "Stop Preset"
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Preset ID")
    var presetID: String

    init() {}

    init(presetID: String) {
        self.presetID = presetID
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        guard let uuid = UUID(uuidString: presetID) else { return .result() }
        let dam = DeviceActivityManager()
        dam.stopMonitor(forPresetID: uuid)
        WidgetManager.clearPendingPresetAction()
        WidgetManager.reloadPresetWidgetTimelines()
        return .result()
    }
}
