//
//  RBPrimitives.swift
//  Rotblock
//
//

import SwiftUI

// MARK: - Eyebrow

/// Small monospaced uppercase label.
struct Eyebrow: View {
  let text: String
  var tint: Color = .rbCloud600

  var body: some View {
    Text(text)
      .font(RBFont.mono(10, weight: .regular))
      .tracking(2.4)
      .textCase(.uppercase)
      .foregroundStyle(tint)
  }
}

// MARK: - Headline

/// Serif display type.
struct Headline: View {
  let text: String
  var size: CGFloat = 32
  var weight: Font.Weight = .regular
  var tint: Color = .rbSlate900

  var body: some View {
    Text(text)
      .font(RBFont.headline(size, weight: weight))
      .foregroundStyle(tint)
      .lineSpacing(size * 0.1)
      .fixedSize(horizontal: false, vertical: true)
  }
}

// MARK: - RBButton

enum RBButtonStyle {
  case primary  // slate900 fill, ivory50 text
  case secondary  // ivory50 fill, ivory300 border, slate900 text
  case ghost  // transparent, cloud600 text
  case tint  // ivory200 fill, slate900 text (compact tag)
}

struct RBButton: View {
  let title: String
  let style: RBButtonStyle
  var icon: String?
  var fullWidth: Bool = true
  var height: CGFloat = 52
  var action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 10) {
        if let icon = icon {
          Image(systemName: icon)
            .font(.system(size: 15, weight: .semibold))
        }
        Text(title)
          .font(RBFont.sans(15, weight: .semibold))
      }
      .foregroundStyle(foreground)
      .frame(maxWidth: fullWidth ? .infinity : nil)
      .frame(height: height)
      .padding(.horizontal, fullWidth ? 0 : 18)
      .background(background)
      .overlay(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .stroke(borderColor, lineWidth: borderWidth)
      )
      .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
    .buttonStyle(PressableButtonStyle())
  }

  private var foreground: Color {
    switch style {
    case .primary: return .rbIvory50
    case .secondary: return .rbSlate900
    case .ghost: return .rbCloud600
    case .tint: return .rbSlate900
    }
  }

  private var background: Color {
    switch style {
    case .primary: return .rbSlate900
    case .secondary: return .rbIvory50
    case .ghost: return .clear
    case .tint: return .rbIvory200
    }
  }

  private var borderColor: Color {
    switch style {
    case .primary: return .clear
    case .secondary: return .rbIvory300
    case .ghost: return .clear
    case .tint: return .rbIvory300
    }
  }

  private var borderWidth: CGFloat {
    switch style {
    case .secondary, .tint: return 1
    default: return 0
    }
  }
}

// MARK: - RBCard

/// Ivory rounded card with ivory300 border; the default surface.
struct RBCard<Content: View>: View {
  var padding: CGFloat = 18
  var cornerRadius: CGFloat = 18
  var fill: Color = .rbIvory50
  var border: Color = .rbIvory300
  var borderWidth: CGFloat = 1
  @ViewBuilder var content: Content

  var body: some View {
    content
      .padding(padding)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          .fill(fill)
      )
      .overlay(
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          .stroke(border, lineWidth: borderWidth)
      )
  }
}

// MARK: - RBToggle

/// Pill toggle. Off = ivory200 track, slate700 thumb; on = slate900 track, ivory50 thumb.
struct RBToggle: View {
  @Binding var isOn: Bool

  var body: some View {
    Button {
      withAnimation(.snappy(duration: 0.18)) { isOn.toggle() }
    } label: {
      ZStack(alignment: isOn ? .trailing : .leading) {
        Capsule()
          .fill(isOn ? Color.rbSlate900 : Color.rbIvory200)
          .overlay(Capsule().stroke(Color.rbIvory300, lineWidth: 1))
          .frame(width: 44, height: 26)
        Circle()
          .fill(isOn ? Color.rbIvory50 : Color.rbSlate700)
          .frame(width: 20, height: 20)
          .padding(.horizontal, 3)
      }
    }
    .buttonStyle(PressableButtonStyle())
  }
}

// MARK: - RBSlider

/// Horizontal slider with ivory300 track, slate900 fill, 24pt white thumb.
struct RBSlider: View {
  @Binding var value: Double
  var range: ClosedRange<Double> = 0...1
  var step: Double?

  var body: some View {
    GeometryReader { geo in
      let progress = CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))
      let width = geo.size.width
      let filled = max(0, min(width, width * progress))

      ZStack(alignment: .leading) {
        Capsule()
          .fill(Color.rbIvory300)
          .frame(height: 6)
        Capsule()
          .fill(Color.rbSlate900)
          .frame(width: filled, height: 6)
        Circle()
          .fill(Color.white)
          .frame(width: 24, height: 24)
          .overlay(Circle().stroke(Color.rbIvory300, lineWidth: 1))
          .shadow(color: Color.black.opacity(0.06), radius: 2, x: 0, y: 1)
          .offset(x: filled - 12)
          .gesture(
            DragGesture(minimumDistance: 0)
              .onChanged { drag in
                let pct = max(0, min(1, drag.location.x / width))
                let raw = range.lowerBound + Double(pct) * (range.upperBound - range.lowerBound)
                if let step = step {
                  value = (raw / step).rounded() * step
                } else {
                  value = raw
                }
              }
          )
      }
      .contentShape(Rectangle())
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { drag in
            let pct = max(0, min(1, drag.location.x / width))
            let raw = range.lowerBound + Double(pct) * (range.upperBound - range.lowerBound)
            if let step = step {
              value = (raw / step).rounded() * step
            } else {
              value = raw
            }
          }
      )
    }
    .frame(height: 24)
  }
}

// MARK: - ConfigRow

/// Row with left icon tile, title/subtitle stack, and a trailing accessory.
struct ConfigRow<Accessory: View>: View {
  let icon: String
  let title: String
  var subtitle: String?
  @ViewBuilder var accessory: Accessory

  var body: some View {
    HStack(spacing: 14) {
      ZStack {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
          .fill(Color.rbIvory100)
          .frame(width: 36, height: 36)
          .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
              .stroke(Color.rbIvory300, lineWidth: 1)
          )
        Image(systemName: icon)
          .font(.system(size: 14, weight: .regular))
          .foregroundStyle(Color.rbSlate900)
      }

      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(RBFont.sans(14, weight: .medium))
          .foregroundStyle(Color.rbSlate900)
        if let subtitle = subtitle {
          Text(subtitle)
            .font(RBFont.sans(12))
            .foregroundStyle(Color.rbCloud600)
            .lineLimit(1)
        }
      }

      Spacer(minLength: 8)

      accessory
    }
    .padding(.vertical, 12)
    .padding(.horizontal, 16)
  }
}

// MARK: - SectionHeader

struct SectionHeader: View {
  let title: String

  var body: some View {
    Text(title.uppercased())
      .font(RBFont.mono(10, weight: .regular))
      .tracking(2.4)
      .foregroundStyle(Color.rbCloud600)
      .padding(.horizontal, 4)
      .padding(.bottom, 6)
  }
}

// MARK: - SettingGroup

/// Stacked list of rows wrapped as a single card.
struct SettingGroup<Content: View>: View {
  let title: String
  @ViewBuilder var content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      SectionHeader(title: title)
        .padding(.leading, 6)
      VStack(spacing: 0) {
        content
      }
      .background(
        RoundedRectangle(cornerRadius: 18, style: .continuous)
          .fill(Color.rbIvory50)
      )
      .overlay(
        RoundedRectangle(cornerRadius: 18, style: .continuous)
          .stroke(Color.rbIvory300, lineWidth: 1)
      )
    }
  }
}

/// Thin ivory200 divider between stacked rows.
struct RBDivider: View {
  var body: some View {
    Rectangle()
      .fill(Color.rbIvory200)
      .frame(height: 1)
      .padding(.leading, 66)
  }
}
