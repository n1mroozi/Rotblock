import FamilyControls
import ManagedSettings
import ManagedSettingsUI
import UIKit

final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
  private let defaults = UserDefaults(suiteName: "group.com.n1labs.rotblock")
  private func defaultRestrictedTitle(displayName: String) -> String {
    "\(displayName) is restricted by Rotblock"
  }

  private struct PresetShieldConfiguration {
    let subtitle: String
    let primaryText: String
    let secondaryText: String
    let primaryBackground: UIColor
    let primaryForeground: UIColor
    let secondaryForeground: UIColor
  }

  /// Apps
  override func configuration(shielding application: Application) -> ShieldConfiguration {
    let activePresets = loadActivePresets()
    let owner = application.token.flatMap { token in
      ShieldConfigManager.owningPreset(for: token, in: activePresets)
    }

    let name = application.localizedDisplayName ?? "This app"
    return makeConfiguration(displayName: name, owningPreset: owner)
  }

  /// Apps+Category
  override func configuration(
    shielding application: Application,
    in category: ActivityCategory
  ) -> ShieldConfiguration {
    let activePresets = loadActivePresets()

    let appOwner = application.token.flatMap { token in
      ShieldConfigManager.owningPreset(for: token, in: activePresets)
    }

    let owner =
      appOwner
      ?? category.token.flatMap { token in
        ShieldConfigManager.owningPreset(for: token, in: activePresets)
      }

    let name = application.localizedDisplayName ?? "This app"
    return makeConfiguration(displayName: name, owningPreset: owner)
  }

  /// Websites
  override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
    let activePresets = loadActivePresets()
    let owner = webDomain.token.flatMap { token in
      ShieldConfigManager.owningPreset(for: token, in: activePresets)
    }

    let name = webDomain.domain ?? "This website"
    return makeConfiguration(displayName: name, owningPreset: owner)
  }

  private func makeConfiguration(displayName: String, owningPreset: PresetValues?)
    -> ShieldConfiguration {
    let count = ShieldOpenLimit.currentOpenCount(defaults: defaults)
    let max =
      owningPreset.flatMap { preset -> Int? in
        guard preset.hasBlock(.open), let cap = preset.openLimitCount, cap > 0 else {
          return nil
        }
        return cap
      }
      ?? ShieldOpenLimit.maxOpenCount(defaults: defaults)
    let limitReached = count >= max

    let baseSubtitle = defaults?.string(forKey: "rb.shield.subtitle") ?? "Fix your focus."
    let presetConfig = loadPresetShieldConfiguration(
      baseSubtitle: baseSubtitle,
      openCount: count,
      openMax: max,
      owningPreset: owningPreset
    )

    let primaryText: String =
      limitReached
      ? "Limit reached"
      : presetConfig.primaryText

    let primaryBg: UIColor = limitReached ? .systemGray3 : presetConfig.primaryBackground
    let primaryFg: UIColor = limitReached ? .rbCloud600 : presetConfig.primaryForeground

    let foreground = UIColor.rbSlate900
    let titleText = defaultRestrictedTitle(displayName: displayName)

    return ShieldConfiguration(
      backgroundBlurStyle: .systemUltraThinMaterialLight,
      backgroundColor: .rbIvory100,
      icon: UIImage(systemName: "shield"),
      title: ShieldConfiguration.Label(text: titleText, color: foreground),
      subtitle: ShieldConfiguration.Label(
        text: presetConfig.subtitle,
        color: presetConfig.secondaryForeground
      ),
      primaryButtonLabel: ShieldConfiguration.Label(text: primaryText, color: primaryFg),
      primaryButtonBackgroundColor: primaryBg,
      secondaryButtonLabel: ShieldConfiguration.Label(
        text: presetConfig.secondaryText,
        color: limitReached ? .white : presetConfig.primaryForeground
      )
    )
  }

  private func loadActivePresetIDs() -> Set<UUID> {
    guard
      let defaults,
      let data = defaults.data(forKey: "DeviceActivityManager.activePresetIDs.v1"),
      let strings = try? JSONDecoder().decode([String].self, from: data)
    else { return [] }

    return Set(strings.compactMap(UUID.init))
  }

  private func loadPresetShieldConfiguration(
    baseSubtitle: String,
    openCount: Int,
    openMax: Int,
    owningPreset: PresetValues?
  ) -> PresetShieldConfiguration {
    let defaultPrimaryText =
      defaults?.string(forKey: "rb.shield.primaryButton") ?? "Temporary access"
    let defaultSecondaryText =
      defaults?.string(forKey: "rb.shield.secondaryButton") ?? "Accept redirection"

    guard let preset = owningPreset else {
      return PresetShieldConfiguration(
        subtitle: baseSubtitle,
        primaryText: defaultPrimaryText,
        secondaryText: defaultSecondaryText,
        primaryBackground: .rbSlate900,
        primaryForeground: .rbIvory50,
        secondaryForeground: .rbCloud600
      )
    }

    let locationBlocked =
      preset.hasBlock(.location)
      && LocationZoneState.isBlocked(presetID: preset.id, defaults: defaults)

    // One line per block so combined presets explain every rule that applies right now.
    var lines: [String] = []
    for kind in preset.blockKinds {
      switch kind {
      case .allowedHour:
        lines.append(
          allowedHourLine(for: preset)
            ?? ShieldConfigManager.shieldMessageDetail(for: preset, kind: .allowedHour)
        )
      case .timer:
        if let remaining = timerRemainingText(for: preset.id) {
          lines.append("Timer: \(remaining)")
        } else {
          lines.append(ShieldConfigManager.shieldMessageDetail(for: preset, kind: .timer))
        }
      case .open:
        var countLine = "Open limit: \(openCount)/\(openMax) opens today"
        if let minutesLine = perOpenMinutesLine(for: preset) {
          countLine += "\n\(minutesLine)"
        }
        lines.append(countLine)
      case .location:
        lines.append(
          locationBlocked
            ? "Outside your allowed zone (\(preset.name))"
            : ShieldConfigManager.shieldMessageDetail(for: preset, kind: .location)
        )
      }
    }
    let subtitle = lines.joined(separator: "\n")

    // Opens can only be granted when the preset has an open block and — for presets that also
    // carry a location block — the user is on the allowed side of the geofence.
    let canGrantOpen = preset.hasBlock(.open) && !locationBlocked
    let primaryText = canGrantOpen ? "Grant Open" : "Restrictions Active"

    return PresetShieldConfiguration(
      subtitle: subtitle,
      primaryText: primaryText,
      secondaryText: defaultSecondaryText,
      primaryBackground: .rbSlate900,
      primaryForeground: .rbIvory50,
      secondaryForeground: .rbCloud600
    )
  }

  private func perOpenMinutesLine(for preset: PresetValues) -> String? {
    guard let seconds = preset.openSessionSeconds, seconds > 0 else { return nil }
    let minutes = max(1, Int(seconds / 60))
    return "\(minutes) min per open"
  }

  private func loadActivePresets() -> [PresetValues] {
    guard
      let defaults,
      let data = defaults.data(forKey: "saved_selection_presets"),
      let allPresets = try? JSONDecoder().decode([PresetValues].self, from: data)
    else { return [] }

    let activeIDs = loadActivePresetIDs()
    return
      allPresets
      .filter { activeIDs.contains($0.id) }
      .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
  }

  private func allowedHourLine(for preset: PresetValues) -> String? {
    let sh = preset.allowedStartHour ?? 9
    let sm = preset.allowedStartMinute ?? 0
    let eh = preset.allowedEndHour ?? 17
    let em = preset.allowedEndMinute ?? 0

    let now = Date()
    let cal = Calendar.current
    let nowMinutes = (cal.component(.hour, from: now) * 60) + cal.component(.minute, from: now)
    let startMinutes = sh * 60 + sm
    let endMinutes = eh * 60 + em

    let isInsideAllowedWindow: Bool = {
      if startMinutes == endMinutes { return true }
      if startMinutes < endMinutes {
        return nowMinutes >= startMinutes && nowMinutes < endMinutes
      } else {
        return nowMinutes >= startMinutes || nowMinutes < endMinutes
      }
    }()

    guard !isInsideAllowedWindow else { return nil }
    return "Allowed hours (\(preset.name)): outside \(hhmm(sh, sm))-\(hhmm(eh, em))"
  }

  private func perOpenSubtitleSuffix(defaults: UserDefaults?) -> String {
    let seconds = defaults?.integer(forKey: "rb.open.sessionSeconds") ?? 0
    guard seconds > 0 else { return "" }

    if seconds % 60 == 0 {
      let minutes = seconds / 60
      return " (\(minutes)m each)"
    } else {
      return " (\(seconds)s each)"
    }
  }

  private func timerRemainingText(for presetID: UUID) -> String? {
    let perPresetKey = "rb.timer.endEpoch.\(presetID.uuidString)"
    let legacyKey = "rb.timer.endEpoch"
    let perPreset = defaults?.double(forKey: perPresetKey) ?? 0
    let endEpoch = perPreset > 0 ? perPreset : (defaults?.double(forKey: legacyKey) ?? 0)
    guard endEpoch > Date().timeIntervalSince1970 else { return nil }

    let remaining = max(0, endEpoch - Date().timeIntervalSince1970)
    let totalMinutes = Int(remaining / 60)
    let hours = totalMinutes / 60
    let minutes = totalMinutes % 60

    if hours > 0 {
      return
        "\(hours) hour\(hours == 1 ? "" : "s") and \(minutes) minute\(minutes == 1 ? "" : "s") remaining"
    } else {
      return "\(minutes) minute\(minutes == 1 ? "" : "s") remaining"
    }
  }

  private func hhmm(_ hour: Int, _ minute: Int) -> String {
    String(format: "%02d:%02d", hour, minute)
  }
}

extension UIColor {
  fileprivate static let rbIvory50 = UIColor(hex: "FAFAF7")
  fileprivate static let rbIvory100 = UIColor(hex: "F1F1EC")
  fileprivate static let rbCloud600 = UIColor(hex: "7B7B74")
  fileprivate static let rbSlate900 = UIColor(hex: "191919")

  fileprivate convenience init(hex: String) {
    let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    var int: UInt64 = 0
    Scanner(string: cleaned).scanHexInt64(&int)

    let r: UInt64
    let g: UInt64
    let b: UInt64

    switch cleaned.count {
    case 3:
      r = ((int >> 8) & 0xF) * 17
      g = ((int >> 4) & 0xF) * 17
      b = (int & 0xF) * 17
    case 6:
      r = (int >> 16) & 0xFF
      g = (int >> 8) & 0xFF
      b = int & 0xFF
    default:
      r = 0
      g = 0
      b = 0
    }

    self.init(
      red: CGFloat(r) / 255.0,
      green: CGFloat(g) / 255.0,
      blue: CGFloat(b) / 255.0,
      alpha: 1.0
    )
  }
}
