//
//  OnboardingPermissions.swift
//  Rotblock
//
//  Created by n1 on 5/9/26.
//

import CoreLocation
import Observation
import SwiftUI
import UserNotifications

// MARK: - Manager

@Observable
final class OnboardingPermissionsManager: NSObject, CLLocationManagerDelegate {
  var notificationsStatus: UNAuthorizationStatus = .notDetermined
  var locationStatus: CLAuthorizationStatus = .notDetermined

  private let locationManager = CLLocationManager()

  override init() {
    super.init()
    locationManager.delegate = self
  }

  func checkStatuses() async {
    let settings = await UNUserNotificationCenter.current().notificationSettings()
    notificationsStatus = settings.authorizationStatus
    locationStatus = locationManager.authorizationStatus
  }

  func requestNotifications() async {
    guard notificationsStatus == .notDetermined else {
      if notificationsStatus == .denied { await openSettings() }
      return
    }
    do {
      let granted = try await UNUserNotificationCenter.current()
        .requestAuthorization(options: [.alert, .badge, .sound])
      notificationsStatus = granted ? .authorized : .denied
    } catch {
      notificationsStatus = .denied
    }
  }

  func requestLocation() {
    guard locationStatus == .notDetermined else {
      if locationStatus == .denied || locationStatus == .restricted {
        Task { await openSettings() }
      }
      return
    }
    locationManager.requestAlwaysAuthorization()
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    locationStatus = manager.authorizationStatus
  }

  @MainActor
  private func openSettings() async {
    if let url = URL(string: UIApplication.openSettingsURLString) {
      await UIApplication.shared.open(url)
    }
  }
}

// MARK: - PermissionsArtView

struct PermissionsArtView: View {
  @State private var manager = OnboardingPermissionsManager()

  var body: some View {
    VStack(spacing: 10) {
      permissionRow(
        style: .granted,
        numeral: "i",
        icon: "hourglass",
        name: "Allow Screen Time access",
        description: "Required · grants the block capability",
        action: nil
      )
      permissionRow(
        style: rowStyle(for: manager.notificationsStatus),
        numeral: "ii",
        icon: "bell",
        name: "Allow notifications",
        description: "Optional · session-end summaries",
        action: manager.notificationsStatus != .authorized
          ? { Task { await manager.requestNotifications() } }
          : nil
      )
      permissionRow(
        style: rowStyle(for: manager.locationStatus),
        numeral: "iii",
        icon: "location.fill",
        name: "Allow location",
        description: "Optional · for place-based presets",
        action: (manager.locationStatus != .authorizedAlways && manager.locationStatus != .authorizedWhenInUse)
          ? { manager.requestLocation() }
          : nil
      )
    }
    .frame(width: 350)
    .task { await manager.checkStatuses() }
  }

  // MARK: Helpers

  private enum PermissionRowVisual { case granted, needsConsent, denied }

  private func rowStyle(for status: UNAuthorizationStatus) -> PermissionRowVisual {
    switch status {
    case .authorized, .provisional, .ephemeral: .granted
    case .denied: .denied
    default: .needsConsent
    }
  }

  private func rowStyle(for status: CLAuthorizationStatus) -> PermissionRowVisual {
    switch status {
    case .authorizedAlways, .authorizedWhenInUse: .granted
    case .denied, .restricted: .denied
    default: .needsConsent
    }
  }

  private func permissionRow(
    style: PermissionRowVisual,
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
