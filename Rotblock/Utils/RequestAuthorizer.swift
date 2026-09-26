import Combine
import DeviceActivity
import FamilyControls
import ManagedSettings
import SwiftUI

extension AuthorizationStatus {
    /// Screen Time is authorized for blocking and standard Family Controls APIs.
    var isApprovedForFamilyControls: Bool {
        switch self {
        case .approved, .approvedWithDataAccess: true
        default: false
        }
    }
}

#if os(iOS)
    class RequestAuthorizer: ObservableObject {
        @Published var isAuthorized = false

        func requestAuthorization() {
            Task {
                do {
                    try await AuthorizationCenter.shared.requestAuthorization(for: .individual)

                    // Dispatch the update to the main thread
                    await MainActor.run {
                        self.isAuthorized = true
                    }
                } catch {
                    await MainActor.run {
                        self.isAuthorized = false
                    }
                }
            }
        }

        func getAuthorizationStatus() -> AuthorizationStatus {
            return AuthorizationCenter.shared.authorizationStatus
        }
    }
#else
    class RequestAuthorizer: ObservableObject {
        @Published var isAuthorized = false

        func requestAuthorization() {
            // FamilyControls authorization is only supported on iOS.
            isAuthorized = false
        }
    }
#endif

// MARK: - FamilyControlsSupport

/// Observable wrapper around FamilyControls authorization for use as an EnvironmentObject.
@MainActor
final class FamilyControlsSupport: ObservableObject {
    @Published private(set) var isAuthorized = false
    @Published private(set) var authorizationStatus: AuthorizationStatus = .notDetermined

    var authorizationStatusLabel: String {
        #if os(iOS)
            switch authorizationStatus {
            case .approved, .approvedWithDataAccess: return "Authorized"
            case .denied: return "Denied"
            case .notDetermined: return "Not requested"
            default: return "Unknown"
            }
        #else
            return "Not supported"
        #endif
    }

    init() {
        refreshAuthorizationStatus()
    }

    func requestAuthorization() async {
        #if os(iOS)
            do {
                try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            } catch {
                AppLog.ui.error(
                    "FamilyControls authorization failed",
                    metadata: ["error": error.localizedDescription]
                )
            }
            refreshAuthorizationStatus()
        #endif
    }

    func refreshAuthorizationStatus() {
        #if os(iOS)
            let status = AuthorizationCenter.shared.authorizationStatus
            authorizationStatus = status
            isAuthorized = status.isApprovedForFamilyControls
        #else
            authorizationStatus = .notDetermined
            isAuthorized = false
        #endif
    }
}
