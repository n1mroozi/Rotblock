import Combine
import Foundation

@MainActor 
final class PresetStore: ObservableObject {
    static let shared = PresetStore()

    @Published private(set) var presets: [PresetValues] = []

    private let defaults = UserDefaults(suiteName: WidgetManager.Constants.appGroupSuite)!
    private let storageKey = WidgetManager.Constants.savedSelectionPresetsKey
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {
        load()
    }

    // MARK: - Public API

    func allPresets() -> [PresetValues] {
        presets.sorted { $0.createdAt > $1.createdAt }
    }

    func preset(id: UUID) -> PresetValues? {
        presets.first { $0.id == id }
    }

    func preset(named name: String) -> PresetValues? {
        presets.first { $0.name == name }
    }

    func save(_ values: PresetValues) {
        if let index = presets.firstIndex(where: { $0.id == values.id }) {
            presets[index] = values
        } else {
            presets.append(values)
        }
        persist()
    }

    func delete(id: UUID) {
        presets.removeAll { $0.id == id }
        persist()
    }

    // MARK: - Internal persistence

    private func load() {
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? decoder.decode([PresetValues].self, from: data)
        else {
            presets = []
            return
        }
        presets = decoded
    }

    private func persist() {
        guard let data = try? encoder.encode(presets) else { return }
        defaults.set(data, forKey: storageKey)
    }
}
