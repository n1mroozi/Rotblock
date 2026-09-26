//
//  rotblockApp.swift
//  rotblock
//
//  Created by n1 on 3/28/26.
//
import Combine
import FamilyControls
import SwiftUI

// MARK: - Darwin Notification Bridge

extension Notification.Name {
    static let presetChanged = Notification.Name("com.n1labs.rotblock.presetChanged")
}

final class DarwinNotificationBridge {
    static let shared = DarwinNotificationBridge()

    private init() {
        // passRetained keeps self alive forever — intentional for this singleton
        let ptr = Unmanaged.passRetained(self).toOpaque()
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            ptr,
            { _, _, _, _, _ in
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .presetChanged, object: nil)
                }
            },
            Notification.Name.presetChanged.rawValue as CFString,
            nil,
            .deliverImmediately
        )
    }

    static func post() {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(Notification.Name.presetChanged.rawValue as CFString),
            nil, nil, true
        )
    }
}

@MainActor
final class AuthManager: ObservableObject {
    @Published var authorizationStatus: FamilyControls.AuthorizationStatus = .notDetermined
    init() {
        // Check initial status if needed when the app starts
        Task {
            await self.checkAuthorization()
        }
    }

    func requestAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            self.authorizationStatus = AuthorizationCenter.shared.authorizationStatus
        } catch {
            self.authorizationStatus = .denied
        }
    }

    func checkAuthorization() async {
        self.authorizationStatus = AuthorizationCenter.shared.authorizationStatus
    }
}

struct ScreenTimeRequestView: View {
    @ObservedObject var authManager: AuthManager

    var body: some View {
        ZStack {
            Color.rbIvory100.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 20) {
                Eyebrow(text: "One more step")
                Headline(text: "Allow Screen\nTime access.", size: 36, weight: .regular)
                Text(self.bodyCopy)
                    .font(RBFont.sans(15))
                    .foregroundStyle(Color.rbCloud600)
                    .lineSpacing(2)
                    .frame(maxWidth: 320, alignment: .leading)

                Spacer(minLength: 24)

                if self.authManager.authorizationStatus == .notDetermined {
                    RBButton(title: "Allow Screen Time", style: .primary, icon: RBIcons.shield) {
                        Task { await self.authManager.requestAuthorization() }
                    }
                } else {
                    RBButton(title: "Open Settings", style: .primary, icon: RBIcons.open) {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    RBButton(title: "Try again", style: .secondary) {
                        Task { await self.authManager.checkAuthorization() }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(EdgeInsets(top: 72, leading: 28, bottom: 44, trailing: 28))
        }
    }

    private var bodyCopy: String {
        switch self.authManager.authorizationStatus {
        case .notDetermined:
            return
                "Rotblock needs Screen Time to apply limits on your apps. Your usage data stays on your device — we never see it."
        default:
            return
                "Screen Time is required for Rotblock to work. Please enable it in Settings → Screen Time."
        }
    }
}

@main
struct RotblockApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("rb.didCompleteOnboarding") private var didCompleteOnboarding = false
    @AppStorage("rb.didSelectInitalGoals") private var didSetInitialGoals = false
    @AppStorage("rb.pendingPostPresetOnboarding") private var pendingPostPresetOnboarding = false
    @AppStorage("rb.appearance") private var appearanceRaw: Int = 1

    private var preferredColorScheme: ColorScheme? {
        switch self.appearanceRaw {
        case 1: return .light
        case 2: return .dark
        default: return nil
        }
    }

    @State private var showingSplash = true
    @StateObject private var familyControls = FamilyControlsSupport()
    @State private var presetActivationService = PresetActivationService()
    @StateObject var authManager = AuthManager()

    /// Launch arg set by RBUITests: skip Screen Time gate and onboarding.
    private var isUITestMode: Bool {
        ProcessInfo.processInfo.arguments.contains("-UITEST_MODE")
    }

    init() {
        _ = DarwinNotificationBridge.shared // register Darwin observer
        LocalNotificationManager.registerCategoriesIfNeeded()

        AppLog.ui.info(
            "App launched",
            metadata: [
                "version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?",
                "build": Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?",
            ]
        )
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if self.isUITestMode {
                    RBTabView()
                        .environment(self.presetActivationService)
                        .environment(self.presetActivationService.deviceActivity)
                        .environment(self.presetActivationService.locationRestriction)
                        .environmentObject(self.familyControls)
                } else if self.showingSplash {
                    SplashView(onFinish: {
                        withAnimation(.easeOut(duration: 0.35)) { self.showingSplash = false }
                    })
                    .transition(.opacity)

                } else if !self.authManager.authorizationStatus.isApprovedForFamilyControls {
                    ScreenTimeRequestView(authManager: self.authManager)
                        .transition(.opacity)

                } else if !self.didCompleteOnboarding || self.pendingPostPresetOnboarding {
                    OnboardingView(
                        onFinish: {
                            withAnimation(.easeOut(duration: 0.35)) {
                                self.didCompleteOnboarding = true
                                self.pendingPostPresetOnboarding = false
                            }
                        },
                        onCreateFirstPreset: {
                            withAnimation(.easeOut(duration: 0.35)) {
                                self.didCompleteOnboarding = true
                                self.pendingPostPresetOnboarding = true
                            }
                        },
                        startAtFirstPresetStep: self.pendingPostPresetOnboarding
                    )
                    .environment(self.presetActivationService.deviceActivity)
                    .transition(.opacity)

                } else if !self.didSetInitialGoals {
                    NavigationStack {
                        TargetsView(
                            mode: .onboarding(onFinish: {
                                self.didSetInitialGoals = true
                                if self.pendingPostPresetOnboarding {
                                    self.didCompleteOnboarding = false
                                }
                            })
                        )
                    }
                    .transition(.opacity)
                } else {
                    RBTabView()
                        .environment(self.presetActivationService)
                        .environment(self.presetActivationService.deviceActivity)
                        .environment(self.presetActivationService.locationRestriction)
                        .environmentObject(self.familyControls)
                        .transition(.opacity)
                }
            }
            .preferredColorScheme(self.preferredColorScheme)
            .task { @MainActor in
                guard !self.isUITestMode else { return }
                await self.authManager.checkAuthorization()
                self.presetActivationService.locationRestriction.refreshState()
                self.presetActivationService.deviceActivity.refreshActivePresetIDs(
                    geofenceHint: self.presetActivationService.locationRestriction.activeGeofencePresetID
                )
            }
            .onChange(of: self.scenePhase) { _, phase in
                #if DEBUG
                UIApplication.shared.isIdleTimerDisabled = (phase == .active)
                #endif
                guard phase == .active, !self.isUITestMode else { return }
                Task { @MainActor in
                    self.presetActivationService.locationRestriction.refreshState()
                    self.presetActivationService.deviceActivity.refreshActivePresetIDs(
                        geofenceHint: self.presetActivationService.locationRestriction.activeGeofencePresetID
                    )
                }
            }
        }
    }
}
