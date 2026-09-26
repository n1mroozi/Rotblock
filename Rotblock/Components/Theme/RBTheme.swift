//
//  RBTheme.swift
//  Rotblock
//
//

import SwiftUI

#if canImport(UIKit)
  import UIKit
#endif

// MARK: - Color Hex Initializer

private func parseHex(_ hex: String) -> (Double, Double, Double) {
  let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
  var int: UInt64 = 0
  Scanner(string: hex).scanHexInt64(&int)
  switch hex.count {
  case 3:
    return (
      Double((int >> 8) * 17) / 255, Double((int >> 4 & 0xF) * 17) / 255,
      Double((int & 0xF) * 17) / 255
    )
  default:
    return (Double(int >> 16 & 0xFF) / 255, Double(int >> 8 & 0xFF) / 255, Double(int & 0xFF) / 255)
  }
}

private func adaptive(light: String, dark: String) -> Color {
  #if canImport(UIKit)
    return Color(
      UIColor(dynamicProvider: { trait in
        let (r, g, b) = parseHex(trait.userInterfaceStyle == .dark ? dark : light)
        return UIColor(red: r, green: g, blue: b, alpha: 1)
      }))
  #else
    let (r, g, b) = parseHex(light)
    return Color(.sRGB, red: r, green: g, blue: b)
  #endif
}

// MARK: - Rotblock Color Tokens

extension Color {
  static let rbIvory50 = adaptive(light: "FAFAF7", dark: "1A1A18")
  static let rbIvory100 = adaptive(light: "F5F4EF", dark: "222220")
  static let rbIvory200 = adaptive(light: "F0F0EB", dark: "2A2A28")
  static let rbIvory300 = adaptive(light: "E5E4DF", dark: "353532")

  static let rbCloud300 = adaptive(light: "D5D3CC", dark: "4A4A47")
  static let rbCloud400 = adaptive(light: "BFBFBA", dark: "5E5E5B")
  static let rbCloud500 = adaptive(light: "91918D", dark: "8A8A86")
  static let rbCloud600 = adaptive(light: "666663", dark: "D8D8D8")

  static let rbSlate700 = adaptive(light: "40403E", dark: "C8C8C4")
  static let rbSlate800 = adaptive(light: "262625", dark: "DEDEDD")
  static let rbSlate900 = adaptive(light: "191919", dark: "F0F0EE")

  // The orange accent is deliberately rendered as warm charcoal.
  static let rbOrange = adaptive(light: "40403E", dark: "C8C8C4")
  static let rbOrangeHover = adaptive(light: "262625", dark: "DEDEDD")
  static let rbOrangeTint = adaptive(light: "E5E4DF", dark: "353532")
  static let rbOrangeInk = adaptive(light: "262625", dark: "DEDEDD")

  /// Canvas background.
  static let rbCanvas = adaptive(light: "E8E6DF", dark: "141412")
  // Onboarding: permission granted row (Screen Time illustration)
  static let rbMintFill = adaptive(light: "E8F5E9", dark: "1A2520")
  static let rbMintStroke = adaptive(light: "C8E6C9", dark: "2A3D32")
  static let rbMintInk = adaptive(light: "2E7D32", dark: "A5D6A7")
}

// MARK: - Typography

/// Typography helpers. Fraunces is bundled in the app target (`UIAppFonts`);
/// monospace remains system monospaced.
enum RBFont {
  /// Display / headline serif (Fraunces).
  static func headline(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
    fraunces(size, weight: weight)
  }

  /// Fraunces roman. PostScript name `Fraunces` once `Fraunces.ttf` is registered.
  static func fraunces(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
    Font.custom("Fraunces", size: size).weight(weight)
  }

  /// Fraunces italic (`Fraunces-Italic.ttf`).
  static func frauncesItalic(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
    Font.custom("Fraunces-Italic", size: size).weight(weight)
  }

  /// Sans-serif body face (SF Pro Text via system sans).
  static func sans(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
    .system(size: size, weight: weight, design: .default)
  }

  /// Monospaced face (system monospaced).
  static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
    .system(size: size, weight: weight, design: .monospaced)
  }
}

// MARK: - Pressable Button Style (preserved)

struct PressableButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
      .animation(.snappy(duration: 0.15), value: configuration.isPressed)
  }
}
