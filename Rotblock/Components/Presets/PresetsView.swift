import FamilyControls
import SwiftUI

struct PresetsView: View {
  @Environment(\.rbTabSwitcher) private var switchTab
  @Environment(DeviceActivityManager.self) private var deviceActivity
  @Environment(PresetActivationService.self) private var activationService
  @ObservedObject private var presetStore = PresetStore.shared
  @State private var editingPreset: PresetValues?
  @State private var creatingNew = false
  @State private var activationError: String?

  private var activeIDs: Set<UUID> {
    deviceActivity.activePresetIDs
  }

  private var presets: [PresetValues] {
    presetStore.allPresets()
  }

  private var activePresets: [PresetValues] {
    presets.filter { activeIDs.contains($0.id) }
  }

  private var others: [PresetValues] {
    presets.filter { !activeIDs.contains($0.id) }
  }

  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        titleBlock
          .padding(.horizontal, 24)
          .padding(.bottom, 24)

        if !activePresets.isEmpty {
          Eyebrow(text: "Active presets")
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 4)

          LazyVStack(spacing: 8) {
            ForEach(activePresets, id: \.id) { active in
              ExpandableCard(
                preset: active,
                isActive: true,
                onStart: { activate(active) },
                onStop: { deactivate(active) },
                onEdit: { editingPreset = active },
                onDelete: { deletePreset(active) }
              )
            }
          }
          .padding(.horizontal, 24)
          .padding(.bottom, 20)
        }

        if !others.isEmpty {
          Eyebrow(text: "All presets")
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 4)

          LazyVStack(spacing: 8) {
            ForEach(others, id: \.id) { preset in
              ExpandableCard(
                preset: preset,
                isActive: false,
                onStart: { activate(preset) },
                onStop: { deactivate(preset) },
                onEdit: { editingPreset = preset },
                onDelete: { deletePreset(preset) }
              )
            }
          }
          .padding(.horizontal, 24)
          .padding(.bottom, 20)
        }

        newPresetButton
          .padding(.horizontal, 24)
          .padding(.bottom, 40)
      }
      .padding(.top, 12)
      .padding(.bottom, 120)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.rbIvory100.ignoresSafeArea())
    .accessibilityIdentifier("presets.screen")
    .sheet(item: $editingPreset) { preset in
      NavigationStack {
        LimitConfigView(presetID: preset.id)
      }
    }
    .sheet(isPresented: $creatingNew) {
      NavigationStack {
        LimitConfigView(presetID: nil)
      }
    }
    .alert(
      "Couldn't start preset",
      isPresented: Binding(
        get: { activationError != nil },
        set: { if !$0 { activationError = nil } }
      ),
      presenting: activationError
    ) { _ in
      Button("OK", role: .cancel) { activationError = nil }
    } message: { error in
      Text(error)
    }
  }

  // MARK: - Activation

  private func activate(_ preset: PresetValues) {
    if let conflict = PresetsView.conflictingPreset(activating: preset, against: activePresets) {
      activationError =
        "\"\(preset.name)\" shares apps with the active preset \"\(conflict.name)\". Stop \"\(conflict.name)\" first."
      return
    }
    if let error = activationService.activate(preset) {
      activationError = error
    }
  }

  private func deactivate(_ preset: PresetValues) {
    activationService.deactivate(preset)
  }

  private func deletePreset(_ preset: PresetValues) {
    if activeIDs.contains(preset.id) {
      activationService.deactivate(preset)
    }
    presetStore.delete(id: preset.id)
  }

  private var titleBlock: some View {
    VStack(alignment: .leading, spacing: 8) {
      Eyebrow(text: "Your library")
      Headline(text: "Presets", size: 36, weight: .regular)
      Text("Rules you've set, ready when you need them.")
        .font(RBFont.sans(15))
        .foregroundStyle(Color.rbCloud600)
        .lineSpacing(2)
        .frame(maxWidth: 300, alignment: .leading)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.top, 4)
  }

  // MARK: - Featured card

  private func featuredCard(_ preset: PresetValues) -> some View {
    Button {
      editingPreset = preset
    } label: {
      VStack(alignment: .leading, spacing: 0) {
        Text("ACTIVE NOW")
          .font(RBFont.mono(10, weight: .regular))
          .tracking(1.0)
          .foregroundStyle(Color.rbOrangeTint)
          .padding(.horizontal, 10)
          .padding(.vertical, 4)
          .background(Capsule().fill(Color.rbOrangeInk))
          .padding(.bottom, 10)

        Headline(text: preset.name, size: 28, weight: .regular)
          .foregroundStyle(Color.rbIvory100)
          .padding(.bottom, 4)

        Text(Self.limitTypeLabel(for: preset))
          .font(RBFont.sans(13))
          .foregroundStyle(Color.rbCloud500)
          .padding(.bottom, 20)

        Rectangle()
          .fill(Color.rbSlate700)
          .frame(height: 1)
          .padding(.bottom, 16)

        HStack(alignment: .top, spacing: 20) {
          VStack(alignment: .leading, spacing: 4) {
            Text("Blocks")
              .font(RBFont.sans(11))
              .foregroundStyle(Color.rbCloud500)
            Text("\(Self.blockedCount(for: preset)) apps")
              .font(RBFont.mono(16))
              .foregroundStyle(Color.rbIvory100)
          }
          Rectangle()
            .fill(Color.rbSlate700)
            .frame(width: 1, height: 44)
          VStack(alignment: .leading, spacing: 4) {
            Text("Schedule")
              .font(RBFont.sans(11))
              .foregroundStyle(Color.rbCloud500)
            Text(Self.scheduleLabel(for: preset))
              .font(RBFont.mono(16))
              .foregroundStyle(Color.rbIvory100)
          }
        }
      }
      .padding(22)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        RoundedRectangle(cornerRadius: 20, style: .continuous)
          .fill(Color.rbSlate900)
      )
      .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
    .buttonStyle(PressableButtonStyle())
  }

  // MARK: - New preset CTA

  private var newPresetButton: some View {
    Button {
      creatingNew = true
    } label: {
      HStack(spacing: 8) {
        Image(systemName: RBIcons.plus)
          .font(.system(size: 14, weight: .regular))
        Text("New preset")
          .font(RBFont.sans(15, weight: .medium))
      }
      .foregroundStyle(Color.rbSlate900)
      .frame(maxWidth: .infinity)
      .frame(height: 52)
      .background(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
          .foregroundStyle(Color.rbCloud400)
      )
    }
    .buttonStyle(PressableButtonStyle())
    .accessibilityIdentifier("presets.newPreset")
  }
}
