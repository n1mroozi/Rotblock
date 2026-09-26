//
//  PresetsViewHelpers.swift
//  Rotblock
//
//  Created by n1 on 5/5/26.
//
import FamilyControls
import Foundation
import SwiftUI

extension PresetsView {
    static func blockedCount(for preset: PresetValues) -> Int {
        let s = preset.selection
        return s.applicationTokens.count + s.categoryTokens.count + s.webDomainTokens.count
    }

    static func limitTypeLabel(for preset: PresetValues) -> String {
        preset.blocksLabel
    }

    static func scheduleLabel(for preset: PresetValues) -> String {
        if let sched = preset.decodedSchedule, sched.isActive {
            return sched.summaryText
        }
        return preset.blockDetail(preset.primaryBlockKind)
    }

    /// Returns the first active preset whose selection overlaps with `preset`.
    static func conflictingPreset(
        activating preset: PresetValues,
        against activePresets: [PresetValues]
    ) -> PresetValues? {
        let incoming = preset.selection
        for active in activePresets where active.id != preset.id {
            let existing = active.selection
            if !incoming.applicationTokens.isDisjoint(with: existing.applicationTokens)
                || !incoming.categoryTokens.isDisjoint(with: existing.categoryTokens)
                || !incoming.webDomainTokens.isDisjoint(with: existing.webDomainTokens) {
                return active
            }
        }
        return nil
    }

}
