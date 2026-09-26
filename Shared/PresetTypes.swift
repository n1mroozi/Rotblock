import FamilyControls
import Foundation

/// One kind of limit "block" that can be stacked onto a preset.
/// A preset holds any combination of these (at most one block per kind).
enum LimitType: String, Codable, CaseIterable, Identifiable {
    case open = "Open Limit"
    case timer = "Timer Limit"
    case location = "Location Limit"
    case allowedHour = "Allowed Hours"

    var id: Self {
        self
    }

    /// Compact label used when several block names are joined together.
    var shortLabel: String {
        switch self {
        case .open: return "Opens"
        case .timer: return "Timer"
        case .location: return "Location"
        case .allowedHour: return "Allowed Hours"
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        let raw = try c.decode(String.self)
        switch raw {
        case "Timer Limit", "timer", "Timer":
            self = .timer
        case "Open Limit", "open":
            self = .open
        case "Location Limit", "location":
            self = .location
        case "Allowed Hours", "allowedHour":
            self = .allowedHour
        default:
            self = .open
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(rawValue)
    }
}

struct PresetValues: Codable, Hashable, Equatable, Identifiable {
    var id: UUID
    var name: String
    var createdAt: Date
    var selectionData: Data

    /// The limit blocks stacked on this preset, in display order (at most one per kind).
    /// Legacy presets stored a single `limitType`; decoding migrates it to a one-element array.
    var blockKinds: [LimitType] = [.open]

    // Timer block fields
    var timerLimitStartHour: Int? = nil
    var timerLimitStartMinute: Int? = nil
    var timerLimitEndHour: Int? = nil
    var timerLimitDurationSeconds: Double? = nil

    // Allowed-hours block fields
    var timeLimitSeconds: Double? = nil
    var allowedStartHour: Int? = nil
    var allowedStartMinute: Int? = nil
    var allowedEndHour: Int? = nil
    var allowedEndMinute: Int? = nil

    // Location block fields
    var locationLatitude: Double? = nil
    var locationLongitude: Double? = nil
    var locationRadius: Double? = nil
    var locationMode: String? = nil

    // Open-limit block fields
    var openLimitCount: Int? = nil
    var openSessionSeconds: Double? = nil

    /// Optional encoded schedule blob (allowed-hours block)
    var scheduleData: Data? = nil

    var selection: FamilyActivitySelection {
        get {
            (try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: selectionData))
                ?? FamilyActivitySelection()
        }
        set {
            selectionData = (try? PropertyListEncoder().encode(newValue)) ?? Data()
        }
    }

    var decodedSchedule: LimitPresetSchedule? {
        guard let data = scheduleData else { return nil }
        return try? JSONDecoder().decode(LimitPresetSchedule.self, from: data)
    }

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        selection: FamilyActivitySelection = FamilyActivitySelection(),
        blockKinds: [LimitType] = [.open],
        // timer
        timerLimitDurationSeconds: Double? = nil,
        // allowedHours
        timeLimitSeconds: Double? = nil,
        allowedStartHour: Int? = nil,
        allowedStartMinute: Int? = nil,
        allowedEndHour: Int? = nil,
        allowedEndMinute: Int? = nil,
        // location
        locationLatitude: Double? = nil,
        locationLongitude: Double? = nil,
        locationRadius: Double? = nil,
        locationMode: String? = nil,
        // open limit
        openLimitCount: Int? = nil,
        openSessionSeconds: Double? = nil,
        scheduleData: Data? = nil
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.selectionData = (try? PropertyListEncoder().encode(selection)) ?? Data()
        self.blockKinds = Self.normalized(blockKinds)
        // timer
        self.timerLimitDurationSeconds = timerLimitDurationSeconds
        // allowedHours
        self.timeLimitSeconds = timeLimitSeconds
        self.allowedStartHour = allowedStartHour
        self.allowedStartMinute = allowedStartMinute
        self.allowedEndHour = allowedEndHour
        self.allowedEndMinute = allowedEndMinute
        // location
        self.locationLatitude = locationLatitude
        self.locationLongitude = locationLongitude
        self.locationRadius = locationRadius
        self.locationMode = locationMode
        // open limit
        self.openLimitCount = openLimitCount
        self.openSessionSeconds = openSessionSeconds
        self.scheduleData = scheduleData
    }

    // MARK: - Codable (legacy `limitType` migration)

    private enum CodingKeys: String, CodingKey {
        case id, name, createdAt, selectionData
        case blockKinds
        case limitType // legacy single-type field; still written so older builds can decode
        case timerLimitStartHour, timerLimitStartMinute, timerLimitEndHour, timerLimitDurationSeconds
        case timeLimitSeconds
        case allowedStartHour, allowedStartMinute, allowedEndHour, allowedEndMinute
        case locationLatitude, locationLongitude, locationRadius, locationMode
        case openLimitCount, openSessionSeconds
        case scheduleData
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        selectionData = try c.decode(Data.self, forKey: .selectionData)

        if let kinds = try c.decodeIfPresent([LimitType].self, forKey: .blockKinds),
           !kinds.isEmpty
        {
            blockKinds = Self.normalized(kinds)
        } else {
            let legacy = try c.decodeIfPresent(LimitType.self, forKey: .limitType) ?? .open
            blockKinds = [legacy]
        }

        timerLimitStartHour = try c.decodeIfPresent(Int.self, forKey: .timerLimitStartHour)
        timerLimitStartMinute = try c.decodeIfPresent(Int.self, forKey: .timerLimitStartMinute)
        timerLimitEndHour = try c.decodeIfPresent(Int.self, forKey: .timerLimitEndHour)
        timerLimitDurationSeconds = try c.decodeIfPresent(Double.self, forKey: .timerLimitDurationSeconds)
        timeLimitSeconds = try c.decodeIfPresent(Double.self, forKey: .timeLimitSeconds)
        allowedStartHour = try c.decodeIfPresent(Int.self, forKey: .allowedStartHour)
        allowedStartMinute = try c.decodeIfPresent(Int.self, forKey: .allowedStartMinute)
        allowedEndHour = try c.decodeIfPresent(Int.self, forKey: .allowedEndHour)
        allowedEndMinute = try c.decodeIfPresent(Int.self, forKey: .allowedEndMinute)
        locationLatitude = try c.decodeIfPresent(Double.self, forKey: .locationLatitude)
        locationLongitude = try c.decodeIfPresent(Double.self, forKey: .locationLongitude)
        locationRadius = try c.decodeIfPresent(Double.self, forKey: .locationRadius)
        locationMode = try c.decodeIfPresent(String.self, forKey: .locationMode)
        openLimitCount = try c.decodeIfPresent(Int.self, forKey: .openLimitCount)
        openSessionSeconds = try c.decodeIfPresent(Double.self, forKey: .openSessionSeconds)
        scheduleData = try c.decodeIfPresent(Data.self, forKey: .scheduleData)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(selectionData, forKey: .selectionData)
        try c.encode(blockKinds, forKey: .blockKinds)
        try c.encode(primaryBlockKind, forKey: .limitType)
        try c.encodeIfPresent(timerLimitStartHour, forKey: .timerLimitStartHour)
        try c.encodeIfPresent(timerLimitStartMinute, forKey: .timerLimitStartMinute)
        try c.encodeIfPresent(timerLimitEndHour, forKey: .timerLimitEndHour)
        try c.encodeIfPresent(timerLimitDurationSeconds, forKey: .timerLimitDurationSeconds)
        try c.encodeIfPresent(timeLimitSeconds, forKey: .timeLimitSeconds)
        try c.encodeIfPresent(allowedStartHour, forKey: .allowedStartHour)
        try c.encodeIfPresent(allowedStartMinute, forKey: .allowedStartMinute)
        try c.encodeIfPresent(allowedEndHour, forKey: .allowedEndHour)
        try c.encodeIfPresent(allowedEndMinute, forKey: .allowedEndMinute)
        try c.encodeIfPresent(locationLatitude, forKey: .locationLatitude)
        try c.encodeIfPresent(locationLongitude, forKey: .locationLongitude)
        try c.encodeIfPresent(locationRadius, forKey: .locationRadius)
        try c.encodeIfPresent(locationMode, forKey: .locationMode)
        try c.encodeIfPresent(openLimitCount, forKey: .openLimitCount)
        try c.encodeIfPresent(openSessionSeconds, forKey: .openSessionSeconds)
        try c.encodeIfPresent(scheduleData, forKey: .scheduleData)
    }

    /// Deduplicates while preserving order; falls back to `[.open]` when empty.
    private static func normalized(_ kinds: [LimitType]) -> [LimitType] {
        var seen = Set<LimitType>()
        let unique = kinds.filter { seen.insert($0).inserted }
        return unique.isEmpty ? [.open] : unique
    }
}

// MARK: - Block queries & display

extension PresetValues {
    func hasBlock(_ kind: LimitType) -> Bool {
        blockKinds.contains(kind)
    }

    /// First block, used where a single representative kind is needed (icons, legacy encoding).
    var primaryBlockKind: LimitType {
        blockKinds.first ?? .open
    }

    /// Whether the open block limits the number of launches (as opposed to session time only).
    var hasCountedOpenBlock: Bool {
        hasBlock(.open) && (openLimitCount ?? 0) > 0
    }

    /// Block names joined for display, e.g. "Location + Opens".
    var blocksLabel: String {
        blockKinds.map(\.shortLabel).joined(separator: " + ")
    }

    /// Compact one-line detail for a single block, e.g. "5 opens/day", "2h timer", "9:00–17:00".
    func blockDetail(_ kind: LimitType) -> String {
        switch kind {
        case .open:
            if let count = openLimitCount, count > 0 {
                if let secs = openSessionSeconds, secs > 0 {
                    return "\(count) opens/day · \(Int(secs / 60)) min/open"
                }
                return "\(count) opens/day"
            }
            if let secs = openSessionSeconds, secs > 0 { return "\(Int(secs / 60)) min/open" }
            return "Always blocked"
        case .timer:
            guard let secs = timerLimitDurationSeconds, secs > 0 else { return "Timer" }
            let mins = Int(secs / 60)
            if mins >= 60 {
                let rem = mins % 60
                return rem > 0 ? "\(mins / 60)h \(rem)m timer" : "\(mins / 60)h timer"
            }
            return "\(mins)m timer"
        case .allowedHour:
            let sh = allowedStartHour ?? 9
            let sm = allowedStartMinute ?? 0
            let eh = allowedEndHour ?? 17
            let em = allowedEndMinute ?? 0
            return String(format: "%d:%02d–%d:%02d", sh, sm, eh, em)
        case .location:
            if let r = locationRadius { return "Zone \(Int(r)) m" }
            return "Zone"
        }
    }

    /// All block details joined, e.g. "Zone 200 m · 5 opens/day".
    var blocksDetailSummary: String {
        blockKinds.map { blockDetail($0) }.joined(separator: " · ")
    }
}
