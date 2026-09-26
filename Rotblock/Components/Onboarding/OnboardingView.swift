//
//  OnboardingView.swift
//  Rotblock
//
//

import SwiftUI

struct OnboardingStepSpec {
    let eyebrow: String
    let title: String
    let body: String?
    let art: OnboardingArt.Kind
    var titleAboveArt: Bool = false
    var footerNote: String?
}

struct OnboardingView: View {
    private let privacyPolicyURL = URL(string: "https://n-n.dev/rotblock/privacy-policy/")!

    var onFinish: () -> Void = {}
    var onCreateFirstPreset: () -> Void = {}
    var startAtFirstPresetStep = false
    @State private var step = 0
    @State private var presentingNewPreset = false
    @StateObject private var presetStore = PresetStore.shared

    private let steps: [OnboardingStepSpec] = [
        .init(
            eyebrow: "Welcome",
            title: "Redirect your attention.",
            body:
            "Rotblock helps you stay present. Block distracting apps, set gentle limits, and get your attention back.",
            art: .hero
        ),
        .init(
            eyebrow: "How it works",
            title: "Built for\npeace of mind.",
            body: nil,
            art: .rules,
            titleAboveArt: true
        ),
        .init(
            eyebrow: "Permission",
            title: "Two taps to\nlet us in.",
            body:
            "iOS handles the actual blocking. Rotblock asks Apple's Screen Time API to enforce the rules you set.",
            art: .permissions,
            titleAboveArt: true,
            footerNote: "Apple doesn't share which apps you choose with us. We only see opaque tokens."
        ),
        .init(
            eyebrow: "First preset",
            title: "Create your\nfirst preset.",
            body:
            "Tap “New Preset” to pick apps and schedule your focus window. Then continue without an account.",
            art: .firstPreset
        ),
    ]

    private var isLast: Bool {
        step == steps.count - 1
    }

    private var current: OnboardingStepSpec {
        steps[step]
    }

    var body: some View {
        ZStack {
            Color.rbIvory100.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                if current.titleAboveArt {
                    copyBlock(aboveArt: true)
                        .padding(.top, 16)
                        .padding(.bottom, 20)
                }
                if !current.titleAboveArt { Spacer(minLength: 0) }
                OnboardingArt(kind: current.art)
                    .frame(maxHeight: 280)
                    .padding(.vertical, current.titleAboveArt ? 0 : 24)
                if let note = current.footerNote {
                    onboardingPrivacyCallout(text: note)
                        .padding(.bottom, 12)
                }
                Spacer(minLength: 0)
                if !current.titleAboveArt {
                    copyBlock(aboveArt: false)
                        .padding(.bottom, 28)
                } else {
                    Color.clear.frame(height: 28)
                }
                stepDots
                    .padding(.bottom, 20)
                ctas
            }
            .padding(EdgeInsets(top: 12, leading: 28, bottom: 44, trailing: 28))
        }
        .onAppear {
            if startAtFirstPresetStep {
                step = max(0, steps.count - 1)
            }
        }
        .sheet(isPresented: $presentingNewPreset) {
            NavigationStack {
                LimitConfigView(presetID: nil)
            }
        }
    }

    // MARK: - Sections

    private var topBar: some View {
        HStack {
            // Back button (only when not on first step)
            if step > 0 {
                Button {
                    withAnimation(.snappy(duration: 0.28)) {
                        step = max(step - 1, 0)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: RBIcons.chevronLeft)
                        Text("Back")
                    }
                }
                .font(RBFont.sans(15, weight: .regular))
                .foregroundStyle(Color.rbCloud600)
                .accessibilityIdentifier("onboarding.back")
            } else {
                // Keep layout balanced when back is hidden
                Color.clear.frame(width: 44, height: 24)
            }

            Spacer()

            Button("Skip") { onFinish() }
                .font(RBFont.sans(15, weight: .regular))
                .foregroundStyle(Color.rbCloud600)
                .accessibilityIdentifier("onboarding.skip")
        }
    }

    private func copyBlock(aboveArt: Bool) -> some View {
        VStack(alignment: .leading, spacing: aboveArt ? 8 : 14) {
            Eyebrow(text: current.eyebrow)
            Headline(text: current.title, size: aboveArt ? 34 : 38, weight: .regular)
            if let body = current.body {
                if aboveArt {
                    Text(body)
                        .font(RBFont.sans(14))
                        .foregroundStyle(Color.rbCloud600)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(body)
                        .font(RBFont.sans(16))
                        .foregroundStyle(Color.rbCloud600)
                        .lineSpacing(3)
                        .frame(maxWidth: 320, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .transition(.opacity.combined(with: .move(edge: .trailing)))
        .id("\(aboveArt ? "artTitle" : "copy")-\(step)")
    }

    private var stepDots: some View {
        HStack(spacing: 6) {
            ForEach(0 ..< steps.count, id: \.self) { i in
                Capsule()
                    .fill(i == step ? Color.rbSlate900 : Color.rbCloud300)
                    .frame(height: 3)
                    .frame(maxWidth: .infinity)
                    .layoutPriority(i == step ? 2 : 1)
                    .accessibilityIdentifier("onboarding.dot.\(i)")
            }
        }
    }

    @ViewBuilder
    private var ctas: some View {
        if isLast {
            VStack(spacing: 10) {
                RBButton(
                    title: "Make first preset",
                    style: .primary,
                    icon: RBIcons.chevronRight
                ) {
                    onCreateFirstPreset()
                    presentingNewPreset = true
                }
                .accessibilityIdentifier("onboarding.makeFirstPreset")

                Button("Continue without an account") {
                    onFinish()
                }
                .font(RBFont.sans(14))
                .foregroundStyle(Color.rbCloud600)
                .padding(.top, 2)
                .frame(height: 40)
                .accessibilityIdentifier("onboarding.continueWithoutAccount")

                HStack(spacing: 0) {
                    Text("By continuing you agree to our ")
                        .foregroundStyle(Color.rbCloud600)
                    Link("privacy policy", destination: privacyPolicyURL)
                        .foregroundStyle(Color.rbCloud600)
                        .underline()
                }
                .font(RBFont.sans(12))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
            }
        } else {
            RBButton(
                title: "Continue",
                style: .secondary,
                icon: RBIcons.chevronRight
            ) {
                withAnimation(.snappy(duration: 0.28)) {
                    step = min(step + 1, steps.count - 1)
                }
            }
            .accessibilityIdentifier("onboarding.continue")
        }
    }

    private func onboardingPrivacyCallout(text: String) -> some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lock.fill")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.rbCloud500)
                .padding(.top, 2)
            Text(text)
                .font(RBFont.sans(11))
                .foregroundStyle(Color.rbCloud600)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(shape.fill(Color(red: 0xf0/255.0, green: 0xf0/255.0, blue: 0xeb/255.0)))
        .overlay(shape.stroke(Color.clear, lineWidth: 0))
    }
}

// MARK: - OnboardingArt

struct OnboardingArt: View {
    enum Kind { case hero, rules, permissions, firstPreset }

    let kind: Kind

    var body: some View {
        switch kind {
        case .hero: hero
        case .rules: rules
        case .permissions: PermissionsArtView()
        case .firstPreset: firstPreset
        }
    }

    // MARK: Hero — concentric rings + center shield + orbit dot

    @State private var orbit = 0.0

    private var hero: some View {
        ZStack {
            // Concentric rings (radii 120/95/70/45 pt)
            ForEach(Array([120.0, 95.0, 70.0, 45.0].enumerated()), id: \.offset) { pair in
                Circle()
                    .stroke(pair.offset == 0 ? Color.rbCloud400 : Color.rbCloud300, lineWidth: 1)
                    .frame(width: pair.element * 2, height: pair.element * 2)
                    .opacity(1.0 - Double(pair.offset) * 0.2)
            }

            // Center disc with shield
            Circle()
                .fill(Color.rbSlate900)
                .frame(width: 60, height: 60)
                .overlay(
                    Image(systemName: RBIcons.shield)
                        .font(.system(size: 22, weight: .regular))
                        .foregroundStyle(Color.white)
                )

            // Orbit dot — rotates around the outer ring
            Circle()
                .fill(Color.rbSlate900)
                .frame(width: 8, height: 8)
                .offset(y: -120)
                .rotationEffect(.degrees(orbit))
        }
        .frame(width: 260, height: 260)
        .onAppear {
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                orbit = 360
            }
        }
    }

    // MARK: Rules — three philosophy tiles

    private var rules: some View {
        VStack(spacing: 10) {
            philosophyRow(
                icon: "lock", title: "Your data stays here.",
                body: "No account. No telemetry. App names never leave the device."
            )
            philosophyRow(
                icon: "leaf", title: "No streaks to break.",
                body: "Slipping a day doesn't reset anything. Tomorrow is just tomorrow."
            )
            philosophyRow(
                icon: "bubble.left", title: "Extensive control.",
                body: "Customize messages, blocking shields, and limits. Full control."
            )
        }
        .frame(width: 350)
    }

    private func philosophyRow(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.rbOrangeTint)
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(Color.rbOrange)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(RBFont.sans(14, weight: .medium))
                    .foregroundStyle(Color.rbSlate900)
                Text(body)
                    .font(RBFont.sans(12))
                    .foregroundStyle(Color.rbCloud600)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.rbIvory50)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.rbIvory300, lineWidth: 1)
        )
    }

    private var firstPreset: some View {
        VStack(spacing: 10) {
            ruleRow(icon: RBIcons.plus, label: "New Preset")
            ruleRow(icon: RBIcons.presets, label: "Select apps")
            ruleRow(icon: RBIcons.clock, label: "Block how you want")
        }
        .frame(width: 280)
    }

    private func ruleRow(icon: String, label: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.rbOrangeTint)
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(Color.rbOrange)
            }
            Text(label)
                .font(RBFont.sans(15, weight: .medium))
                .foregroundStyle(Color.rbSlate900)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.rbIvory50)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.rbIvory300, lineWidth: 1)
        )
    }
}

#Preview {
    OnboardingView()
        .environment(DeviceActivityManager())
}
