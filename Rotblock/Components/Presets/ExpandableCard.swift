//
//  ExpandableCard.swift
//  Rotblock
//

import FamilyControls
import SwiftUI

struct ExpandableCard: View {
  let preset: PresetValues
  let isActive: Bool
  let onStart: () -> Void
  let onStop: () -> Void
  let onEdit: (() -> Void)?
  let onDelete: () -> Void

  @State private var isExpanded = false
  @State private var showDeleteConfirmation = false
  @State private var showEditTooltip = false

  // MARK: - Computed

  private var selection: FamilyActivitySelection {
    preset.selection
  }

  private var blockedCount: Int {
    selection.applicationTokens.count
      + selection.categoryTokens.count
      + selection.webDomainTokens.count
  }

  private var limitDetail: String {
    preset.blocksDetailSummary
  }

  private var typeIcon: String {
    switch preset.primaryBlockKind {
    case .open: return RBIcons.focus
    case .timer: return RBIcons.clock
    case .location: return RBIcons.location
    case .allowedHour: return RBIcons.moon
    }
  }

  /// Warm terracotta reserved for the destructive action; the rest of
  /// the palette stays in the ivory/slate family used by `PresetsView`.
  private let destructive = Color(.sRGB, red: 0.706, green: 0.318, blue: 0.239)

  // MARK: - Body

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      header
      if isExpanded {
        expandedInfo
          .padding(.top, 14)
          .transition(.move(edge: .top).combined(with: .opacity))
      }
    }
    .padding(16)
    .frame(maxWidth: .infinity)
    .background(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .fill(Color.rbIvory50)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .stroke(isActive ? Color.rbOrange.opacity(0.45) : Color.rbIvory300, lineWidth: 1)
    )
    .contentShape(Rectangle())
    .onTapGesture {
      withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
        isExpanded.toggle()
      }
    }
    .accessibilityIdentifier("preset.card.\(preset.id.uuidString)")
  }

  // MARK: - Subviews

  private var header: some View {
    HStack(spacing: 14) {
      ZStack {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .fill(isActive ? Color.rbOrange : Color.rbIvory100)
          .frame(width: 44, height: 44)
          .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
              .stroke(isActive ? Color.clear : Color.rbIvory300, lineWidth: 1)
          )
        Image(systemName: typeIcon)
          .font(.system(size: 18, weight: .regular))
          .foregroundStyle(isActive ? Color.rbIvory100 : Color.rbSlate700)
      }

      VStack(alignment: .leading, spacing: 2) {
        Text(preset.name)
          .font(RBFont.sans(15, weight: .medium))
          .foregroundStyle(Color.rbSlate900)
          .lineLimit(1)
          .accessibilityIdentifier("preset.name.\(preset.name)")
        Text(subtitle)
          .font(RBFont.sans(12))
          .foregroundStyle(Color.rbCloud600)
          .lineLimit(1)
      }

      Spacer(minLength: 8)

      Button(action: isActive ? onStop : onStart) {
        Image(systemName: isActive ? "stop.fill" : "play.fill")
          .font(.system(size: 12, weight: .medium))
          .foregroundStyle(isActive ? Color.rbIvory100 : Color.rbSlate900)
          .frame(width: 32, height: 32)
          .background(
            Circle().fill(isActive ? Color.rbOrange : Color.rbIvory100)
          )
          .overlay(
            Circle().stroke(isActive ? Color.clear : Color.rbIvory300, lineWidth: 1)
          )
      }
      .buttonStyle(PressableButtonStyle())
      .accessibilityIdentifier(
        isActive
          ? "preset.action.stop.\(preset.id.uuidString)"
          : "preset.action.start.\(preset.id.uuidString)")
    }
  }

  private var subtitle: String {
    let blockedText = "\(blockedCount) app\(blockedCount == 1 ? "" : "s")"
    return "\(blockedText) · \(limitDetail)"
  }

  private var appIconsStrip: some View {
    let appTokens = Array(selection.applicationTokens)
    let catTokens = Array(selection.categoryTokens)
    let allCount = appTokens.count + catTokens.count
    let maxVisible = 12
    let overflowCount = max(0, allCount - maxVisible)
    let visibleApps = Array(appTokens.prefix(maxVisible))
    let visibleCats = Array(catTokens.prefix(max(0, maxVisible - visibleApps.count)))

    return ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 6) {
        ForEach(Array(visibleApps.enumerated()), id: \.offset) { _, token in
          Label(token)
            .labelStyle(.iconOnly)
            .frame(width: 32, height: 32)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        ForEach(Array(visibleCats.enumerated()), id: \.offset) { _, token in
          Label(token)
            .labelStyle(.iconOnly)
            .frame(width: 32, height: 32)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        if overflowCount > 0 {
          Text("+\(overflowCount)")
            .font(RBFont.mono(11))
            .foregroundStyle(Color.rbCloud500)
            .frame(width: 32, height: 32)
            .background(
              RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.rbIvory100)
                .overlay(
                  RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.rbIvory300, lineWidth: 1)
                )
            )
        }
      }
      .padding(.horizontal, 2)
    }
  }

  private var expandedInfo: some View {
    VStack(spacing: 12) {
      Rectangle()
        .fill(Color.rbIvory300)
        .frame(height: 1)

      if !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty {
        appIconsStrip
      }

      HStack(alignment: .top, spacing: 8) {
        infoTile(title: "Blocks", value: "\(blockedCount)")
        infoTile(title: "Limit", value: limitDetail)
        infoTile(title: "Created", value: Self.shortDate(preset.createdAt))
      }

      HStack(spacing: 8) {
        if let onEdit {
          Button {
            if isActive {
              withAnimation(.easeOut(duration: 0.15)) {
                showEditTooltip = true
              }
              Task {
                try? await Task.sleep(for: .seconds(2))
                withAnimation(.easeOut(duration: 0.15)) {
                  showEditTooltip = false
                }
              }
            } else {
              onEdit()
            }
          } label: {
            Label("Edit", systemImage: "pencil")
              .font(RBFont.sans(13, weight: .medium))
              .foregroundStyle(isActive ? Color.rbCloud600 : Color.rbIvory100)
              .frame(maxWidth: .infinity)
              .frame(height: 40)
              .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                  .fill(isActive ? Color.rbIvory200 : Color.rbSlate900)
              )
          }
          .buttonStyle(PressableButtonStyle())
          .accessibilityHint(isActive ? "Active presets cannot be edited. Stop the preset first." : "Edit this preset.")
          .accessibilityIdentifier("preset.action.edit.\(preset.id.uuidString)")
          .overlay(alignment: .top) {
            if showEditTooltip {
              Text("Active presets cannot be edited")
                .font(RBFont.sans(12, weight: .medium))
                .foregroundStyle(Color.rbIvory100)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                  RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.rbSlate900)
                    .shadow(color: .black.opacity(0.18), radius: 6, y: 2)
                )
                .fixedSize()
                .offset(y: -38)
                .transition(.opacity.combined(with: .scale(scale: 0.92, anchor: .bottom)))
                .allowsHitTesting(false)
            }
          }
          .zIndex(showEditTooltip ? 1 : 0)
        }

        Button {
          showDeleteConfirmation = true
        } label: {
          Label("Delete", systemImage: RBIcons.trash)
            .font(RBFont.sans(13, weight: .medium))
            .foregroundStyle(destructive)
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background(
              RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.rbIvory100)
            )
            .overlay(
              RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(destructive.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityIdentifier("preset.action.delete.\(preset.id.uuidString)")
      }
      .confirmationDialog(
        "Delete \"\(preset.name)\"?",
        isPresented: $showDeleteConfirmation,
        titleVisibility: .visible
      ) {
        Button("Delete", role: .destructive, action: onDelete)
        Button("Cancel", role: .cancel) {}
      } message: {
        Text("This preset will be permanently removed.")
      }
    }
  }

  private func infoTile(title: String, value: String) -> some View {
    VStack(spacing: 4) {
      Text(title.uppercased())
        .font(RBFont.mono(10, weight: .regular))
        .tracking(1.0)
        .foregroundStyle(Color.rbCloud500)
      Text(value)
        .font(RBFont.sans(13, weight: .medium))
        .foregroundStyle(Color.rbSlate900)
        .multilineTextAlignment(.center)
        .minimumScaleFactor(0.7)
        .lineLimit(2)
    }
    .padding(.vertical, 10)
    .padding(.horizontal, 8)
    .frame(maxWidth: .infinity, minHeight: 56)
    .background(
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .fill(Color.rbIvory100)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .stroke(Color.rbIvory300, lineWidth: 1)
    )
  }

  // MARK: - Helpers

  private static func shortDate(_ date: Date) -> String {
    DateFormatters.formatAbbrevMonthDay(date)
  }
}
