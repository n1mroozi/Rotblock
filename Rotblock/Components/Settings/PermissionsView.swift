//
//  PermissionsView.swift
//  Rotblock
//

import Combine
import CoreLocation
import FamilyControls
import SwiftUI
import UserNotifications

// MARK: - Location Manager

private final class LocationPermissionManager: NSObject, CLLocationManagerDelegate, ObservableObject {
  @Published var status: CLAuthorizationStatus = .notDetermined
  private let manager = CLLocationManager()

  override init() {
    super.init()
    manager.delegate = self
    status = manager.authorizationStatus
  }

  func request() {
    manager.requestAlwaysAuthorization()
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    status = manager.authorizationStatus
  }
}

// MARK: - PermissionsView

struct PermissionsView: View {
  @StateObject private var locationManager = LocationPermissionManager()
  @State private var screenTimeStatus: FamilyControls.AuthorizationStatus = AuthorizationCenter
    .shared.authorizationStatus
  @State private var notificationsStatus: UNAuthorizationStatus = .notDetermined

  var body: some View {
    ZStack {
      Color.rbIvory100.ignoresSafeArea()
      ScrollView {
        VStack(spacing: 10) {
          permissionRow(
            style: screenTimeStyle,
            numeral: "i",
            icon: "hourglass",
            name: "Screen Time",
            description: "Required · grants the block capability",
            action: screenTimeStyle != .granted ? { Task { await requestScreenTime() } } : nil
          )
          permissionRow(
            style: notificationsStyle,
            numeral: "ii",
            icon: "bell",
            name: "Notifications",
            description: "Optional · session-end summaries",
            action: notificationsStyle == .needsConsent
              ? { Task { await requestNotifications() } }
              : notificationsStyle == .denied ? { openSettings() } : nil
          )
          permissionRow(
            style: locationStyle,
            numeral: "iii",
            icon: "location.fill",
            name: "Location",
            description: "Optional · for place-based presets",
            action: locationStyle == .needsConsent
              ? { locationManager.request() }
              : locationStyle == .denied ? { openSettings() } : nil
          )
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 80)
      }
    }
    .navigationTitle("Permissions")
    .navigationBarTitleDisplayMode(.large)
    .toolbar(.visible, for: .navigationBar)
    .task { await refreshStatuses() }
  }

  // MARK: - Computed styles

  private enum RowStyle { case granted, needsConsent, denied }

  private var screenTimeStyle: RowStyle {
    switch screenTimeStatus {
    case .approved, .approvedWithDataAccess: .granted
    case .denied: .denied
    default: .needsConsent
    }
  }

  private var notificationsStyle: RowStyle {
    switch notificationsStatus {
    case .authorized, .provisional, .ephemeral: .granted
    case .denied: .denied
    default: .needsConsent
    }
  }

  private var locationStyle: RowStyle {
    switch locationManager.status {
    case .authorizedAlways: .granted
    case .denied, .restricted: .denied
    // WhenInUse insufficient — geofence monitoring requires Always
    case .authorizedWhenInUse, .notDetermined: .needsConsent
    @unknown default: .needsConsent
    }
  }

  // MARK: - Actions

  private func refreshStatuses() async {
    screenTimeStatus = AuthorizationCenter.shared.authorizationStatus
    let settings = await UNUserNotificationCenter.current().notificationSettings()
    notificationsStatus = settings.authorizationStatus
  }

  private func requestScreenTime() async {
    do { try await AuthorizationCenter.shared.requestAuthorization(for: .individual) } catch {}
    screenTimeStatus = AuthorizationCenter.shared.authorizationStatus
  }

  private func requestNotifications() async {
    do {
      let granted = try await UNUserNotificationCenter.current()
        .requestAuthorization(options: [.alert, .badge, .sound])
      notificationsStatus = granted ? .authorized : .denied
    } catch {
      notificationsStatus = .denied
    }
  }

  private func openSettings() {
    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
    UIApplication.shared.open(url)
  }

  // MARK: - Row

  private func permissionRow(
    style: RowStyle,
    numeral: String,
    icon: String,
    name: String,
    description: String,
    action: (() -> Void)?
  ) -> some View {
    let isGranted = style == .granted
    let cardShape = RoundedRectangle(cornerRadius: 14, style: .continuous)
    return HStack(alignment: .top, spacing: 10) {
      HStack(alignment: .center, spacing: 10) {
        Text("\(numeral).")
          .font(RBFont.frauncesItalic(18))
          .foregroundStyle(isGranted ? Color.rbMintInk : Color.rbCloud400)
          .frame(width: 22, alignment: .trailing)

        ZStack {
          RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(isGranted ? Color.rbMintFill.opacity(0.95) : Color.rbOrangeTint)
            .overlay(
              RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isGranted ? Color.rbMintStroke : Color.clear, lineWidth: 1)
            )
            .frame(width: 30, height: 30)
          Image(systemName: icon)
            .font(.system(size: 13, weight: .regular))
            .foregroundStyle(isGranted ? Color.rbMintInk : Color.rbOrange)
        }
      }

      VStack(alignment: .leading, spacing: 2) {
        Text(name)
          .font(RBFont.sans(13, weight: .semibold))
          .foregroundStyle(Color.rbSlate900)
        Text(description)
          .font(RBFont.sans(11))
          .foregroundStyle(Color.rbCloud600)
          .fixedSize(horizontal: false, vertical: true)
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      Group {
        if isGranted {
          Image(systemName: "checkmark")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(Color.white)
            .frame(width: 24, height: 24)
            .background(Circle().fill(Color.rbMintInk))
        } else if let action {
          Button(style == .denied ? "Open Settings" : "Allow", action: action)
            .font(RBFont.sans(12, weight: .semibold))
            .foregroundStyle(Color.rbIvory50)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule(style: .continuous).fill(Color.rbSlate900))
        }
      }
      .padding(.top, 2)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 14)
    .background(cardShape.fill(isGranted ? Color.rbMintFill : Color.rbIvory50))
    .overlay(
      cardShape.stroke(isGranted ? Color.rbMintStroke : Color.rbIvory300, lineWidth: 1)
    )
  }
}

// MARK: - Preview

#Preview {
  NavigationStack {
    PermissionsView()
  }
}
