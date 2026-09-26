//
//  AppMessagesView.swift
//  Rotblock
//

import SwiftUI

private let userDefaults = UserDefaults(suiteName: "group.com.n1labs.rotblock")

struct AppCustomizationView: View {
  /// Splash — standard UserDefaults
  @AppStorage("SplashMessage")
  private var splashMessage: String = "Fix your focus."

  /// Shield — app-group UserDefaults so the extension can read them
  @AppStorage("rb.shield.subtitle", store: userDefaults)
  private var shieldSubtitle: String = "Shield Activated"

  @AppStorage("rb.shield.primaryButton", store: userDefaults)
  private var shieldPrimary: String = "Temporary access"

  @AppStorage("rb.shield.secondaryButton", store: userDefaults)
  private var shieldSecondary: String = "Accept redirection"

  @AppStorage(DashboardGreetingPreferences.shuffleKey, store: userDefaults)
  private var storedGreetingShuffle: Bool = true

  @AppStorage(DashboardGreetingPreferences.staticIndexKey, store: userDefaults)
  private var storedStaticGreetingIndex: Int = 0

  // Draft copies — edited locally, committed on Save
  @State private var draftSplash: String = ""
  @State private var draftSubtitle: String = ""
  @State private var draftPrimary: String = ""
  @State private var draftSecondary: String = ""
  @State private var draftGreetings: [String] = []
  @State private var draftGreetingShuffle: Bool = true
  @State private var draftStaticGreetingIndex: Int = 0

  @FocusState private var focusedField: AppMessageField?

  private func finishEditing() {
    focusedField = nil
  }

  private var normalizedDraftGreetings: [String] {
    DashboardGreetingPreferences.normalizedLines(draftGreetings)
  }

  private var persistedGreetings: [String] {
    DashboardGreetingPreferences.effectiveGreetings(using: userDefaults)
  }

  private var greetingDraftChanged: Bool {
    normalizedDraftGreetings != persistedGreetings
      || draftGreetingShuffle != storedGreetingShuffle
      || draftStaticGreetingIndex != storedStaticGreetingIndex
  }

  private var hasChanges: Bool {
    draftSplash != splashMessage
      || draftSubtitle != shieldSubtitle
      || draftPrimary != shieldPrimary
      || draftSecondary != shieldSecondary
      || greetingDraftChanged
  }

  var body: some View {
    ZStack {
      Color.rbIvory100.ignoresSafeArea()

      ScrollView {
        VStack(spacing: 24) {
          Color.clear.frame(height: 4)
          splashCard
          todayHeadlineCard
          shieldCard
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 40)
      }
    }
    Headline(text: "App Customization")
      .onAppear { syncDrafts() }
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") { save() }
            .font(RBFont.sans(15, weight: .semibold))
            .disabled(!hasChanges)
            .accessibilityIdentifier("customization.save")
        }
      }
  }

  // MARK: - Splash Card

  private var splashCard: some View {
    MessageSection(eyebrow: "Splash Screen", footer: "Shown below the logo on launch.") {
      MessageField(
        label: "Message",
        placeholder: "Fix your focus.",
        text: $draftSplash,
        field: .splash,
        focusedField: $focusedField,
        isLast: true,
        onSubmit: finishEditing
      )
    }
  }

  // MARK: - Today headline

  private var todayHeadlineCard: some View {
    MessageSection(
      eyebrow: "Today headline",
      footer:
        "Lines shown under “Today” on the dashboard. Shuffle picks one at random when you open Today; Static always shows the line you pin."
    ) {
      VStack(alignment: .leading, spacing: 12) {
        Text("Rotation")
          .font(RBFont.sans(12))
          .foregroundStyle(Color.rbCloud600)
          .padding(.horizontal, 16)
          .padding(.top, 16)

        Picker("", selection: $draftGreetingShuffle) {
          Text("Shuffle").tag(true)
          Text("Static").tag(false)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)

        if !draftGreetingShuffle {
          Text("Pinned line")
            .font(RBFont.sans(12))
            .foregroundStyle(Color.rbCloud600)
            .padding(.horizontal, 16)

          Picker("Pinned line", selection: $draftStaticGreetingIndex) {
            ForEach(draftGreetings.indices, id: \.self) { idx in
              Text(pinLabel(for: idx)).tag(idx)
            }
          }
          .pickerStyle(.menu)
          .padding(.horizontal, 16)
          .padding(.bottom, 4)
        }

        ForEach(draftGreetings.indices, id: \.self) { idx in
          if idx > 0 {
            Divider()
              .overlay(Color.rbIvory200)
              .padding(.leading, 16)
          }

          HStack(alignment: .firstTextBaseline, spacing: 10) {
            DashboardGreetingLineField(
              label: greetingLineTitle(index: idx),
              placeholder: "Headline…",
              text: $draftGreetings[idx],
              index: idx,
              focusedField: $focusedField,
              isLast: idx == draftGreetings.count - 1,
              onSubmit: submitFromGreetingLine(idx)
            )

            Button {
              removeGreetingLine(at: idx)
            } label: {
              Image(systemName: "trash")
                .foregroundStyle(Color.rbCloud600)
                .opacity(draftGreetings.count > 1 ? 1 : 0.25)
                .accessibilityLabel("Remove headline")
            }
            .disabled(draftGreetings.count <= 1)
            .padding(.trailing, 8)
          }
          .padding(.leading, 4)
        }

        Button {
          appendGreetingLine()
        } label: {
          Text("Add headline")
            .font(RBFont.sans(15, weight: .semibold))
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(Color.rbSlate900)
        .padding(16)
      }
    }
  }

  // MARK: - Shield Card

  private var shieldCard: some View {
    MessageSection(eyebrow: "Shield Screen", footer: "Shown when an app is blocked.") {
      MessageField(
        label: "Subtitle",
        placeholder: "Shield activated",
        text: $draftSubtitle,
        field: .subtitle,
        focusedField: $focusedField,
        isLast: false,
        onSubmit: { focusedField = .primary }
      )

      Divider()
        .overlay(Color.rbIvory200)
        .padding(.leading, 16)

      MessageField(
        label: "Primary Button",
        placeholder: "Temporary access",
        text: $draftPrimary,
        field: .primary,
        focusedField: $focusedField,
        isLast: false,
        onSubmit: { focusedField = .secondary }
      )

      Divider()
        .overlay(Color.rbIvory200)
        .padding(.leading, 16)

      MessageField(
        label: "Secondary Button",
        placeholder: "Accept redirection",
        text: $draftSecondary,
        field: .secondary,
        focusedField: $focusedField,
        isLast: true,
        onSubmit: finishEditing
      )
    }
  }

  // MARK: - Today headline helpers

  private func greetingLineTitle(index: Int) -> String {
    "Headline \(index + 1)"
  }

  private func pinLabel(for index: Int) -> String {
    let raw = draftGreetings[index].trimmingCharacters(in: .whitespacesAndNewlines)
    if raw.isEmpty { return "(line \(index + 1))" }
    if raw.count <= 52 { return raw }
    return String(raw.prefix(49)) + "…"
  }

  private func submitFromGreetingLine(_ index: Int) -> () -> Void {
    {
      let last = draftGreetings.count - 1
      if index < last {
        focusedField = .greetingLine(index + 1)
      } else {
        finishEditing()
      }
    }
  }

  private func appendGreetingLine() {
    draftGreetings.append("")
    focusedField = .greetingLine(draftGreetings.count - 1)
  }

  private func removeGreetingLine(at index: Int) {
    guard draftGreetings.count > 1 else { return }
    draftGreetings.remove(at: index)
    clampStaticGreetingIndexForDraftCount()
    if case .greetingLine(let idx) = focusedField, idx >= draftGreetings.count {
      focusedField = .greetingLine(max(0, draftGreetings.count - 1))
    }
  }

  private func clampStaticGreetingIndexForDraftCount() {
    guard !draftGreetings.isEmpty else { return }
    draftStaticGreetingIndex = max(0, min(draftStaticGreetingIndex, draftGreetings.count - 1))
  }

  // MARK: - Actions

  private func syncDrafts() {
    draftSplash = splashMessage
    draftSubtitle = shieldSubtitle
    draftPrimary = shieldPrimary
    draftSecondary = shieldSecondary
    draftGreetings = DashboardGreetingPreferences.effectiveGreetings(using: userDefaults)
    draftGreetingShuffle = storedGreetingShuffle
    draftStaticGreetingIndex = storedStaticGreetingIndex
    clampStaticGreetingIndexForDraftCount()
  }

  private func save() {
    splashMessage = draftSplash
    shieldSubtitle = draftSubtitle
    shieldPrimary = draftPrimary
    shieldSecondary = draftSecondary

    DashboardGreetingPreferences.saveGreetings(lines: draftGreetings, to: userDefaults)
    let effective = DashboardGreetingPreferences.effectiveGreetings(using: userDefaults)
    let cappedStatic = max(0, min(draftStaticGreetingIndex, effective.count - 1))
    draftStaticGreetingIndex = cappedStatic
    storedStaticGreetingIndex = cappedStatic
    storedGreetingShuffle = draftGreetingShuffle

    focusedField = nil
  }
}

// MARK: - Supporting Types

private enum AppMessageField: Hashable {
  case splash, subtitle, primary, secondary
  case greetingLine(Int)
}

// MARK: - MessageSection

private struct MessageSection<Content: View>: View {
  let eyebrow: String
  let footer: String
  @ViewBuilder var content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Eyebrow(text: eyebrow)
        .padding(.leading, 2)

      VStack(spacing: 0) {
        content
      }
      .background(Color.rbIvory50)
      .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 18, style: .continuous)
          .stroke(Color.rbIvory300, lineWidth: 1)
      )

      Text(footer)
        .font(RBFont.sans(12))
        .foregroundStyle(Color.rbCloud500)
        .padding(.leading, 2)
    }
  }
}

// MARK: - MessageField

private struct MessageField: View {
  let label: String
  let placeholder: String
  @Binding var text: String
  let field: AppMessageField
  @FocusState.Binding var focusedField: AppMessageField?
  let isLast: Bool
  let onSubmit: () -> Void

  private var isFocused: Bool {
    focusedField == field
  }

  private var accessibilityID: String {
    switch field {
    case .splash: return "customization.field.message"
    case .subtitle: return "customization.field.subtitle"
    case .primary: return "customization.field.primaryButton"
    case .secondary: return "customization.field.secondaryButton"
    case .greetingLine(let i): return "customization.field.greeting.\(i)"
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(label)
        .font(RBFont.sans(12))
        .foregroundStyle(Color.rbCloud600)

      TextField(placeholder, text: $text)
        .font(RBFont.sans(15))
        .foregroundStyle(Color.rbSlate900)
        .focused($focusedField, equals: field)
        .submitLabel(isLast ? .done : .next)
        .onSubmit(onSubmit)
        .accessibilityIdentifier(accessibilityID)
    }
    .padding(16)
    .background(
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .stroke(isFocused ? Color.rbSlate900.opacity(0.35) : Color.clear, lineWidth: 1)
    )
    .animation(.easeInOut(duration: 0.18), value: isFocused)
  }
}

// MARK: - Dashboard headline line editor

private struct DashboardGreetingLineField: View {
  let label: String
  let placeholder: String
  @Binding var text: String
  let index: Int
  @FocusState.Binding var focusedField: AppMessageField?
  let isLast: Bool
  let onSubmit: () -> Void

  private var field: AppMessageField {
    .greetingLine(index)
  }

  private var isFocused: Bool {
    focusedField == field
  }

  var body: some View {
    MessageField(
      label: label,
      placeholder: placeholder,
      text: $text,
      field: field,
      focusedField: $focusedField,
      isLast: isLast,
      onSubmit: onSubmit
    )
    .padding(.leading, -4)
  }
}

#Preview {
  NavigationStack {
    AppCustomizationView()
  }
}
