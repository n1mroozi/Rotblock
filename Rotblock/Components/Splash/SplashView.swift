//
//  SplashView.swift
//  Rotblock
//
//

import SwiftUI

struct SplashView: View {
    /// Called after the 2.8s dwell completes.
    @AppStorage("SplashMessage") var splashMessage: String = "Fix your focus."
    var onFinish: () -> Void = {}

    @State private var pulsing = false
    @State private var dotPhase = 0

    var body: some View {
        ZStack {
            Color.rbIvory100.ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()
                shield
                VStack(spacing: 10) {
                    Headline(text: "Rotblock", size: 42, weight: .regular)
                    Eyebrow(text: splashMessage)
                }
                Spacer()
                dots
                    .padding(.bottom, 44)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: false)) {
                pulsing = true
            }
            Task { await cycleDots() }
            Task {
                try? await Task.sleep(nanoseconds: 2_800_000_000)
                await MainActor.run { onFinish() }
            }
        }
    }

    // MARK: - Shield

    private var shield: some View {
        ZStack {
            // Outer pulse ring
            Circle()
                .stroke(Color.rbSlate900.opacity(pulsing ? 0.0 : 0.18), lineWidth: 1)
                .frame(width: 168, height: 168)
                .scaleEffect(pulsing ? 1.25 : 0.8)

            // Inner pulse halo
            Circle()
                .fill(Color.rbSlate900.opacity(pulsing ? 0.0 : 0.08))
                .frame(width: 140, height: 140)
                .scaleEffect(pulsing ? 1.15 : 0.9)

            // Shield tile
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.rbSlate900)
                .frame(width: 96, height: 96)
                .overlay(
                    Image(systemName: RBIcons.shield)
                        .font(.system(size: 38, weight: .regular))
                        .foregroundStyle(Color.rbIvory50)
                )
                .shadow(color: Color.rbSlate900.opacity(0.22), radius: 24, x: 0, y: 16)
        }
    }

    // MARK: - Dots

    private var dots: some View {
        HStack(spacing: 10) {
            ForEach(0 ..< 3, id: \.self) { i in
                Circle()
                    .fill(Color.rbSlate900.opacity(dotPhase == i ? 0.85 : 0.22))
                    .frame(width: 7, height: 7)
                    .scaleEffect(dotPhase == i ? 1.15 : 1.0)
                    .animation(.easeInOut(duration: 0.32), value: dotPhase)
            }
        }
    }

    private func cycleDots() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 280_000_000)
            await MainActor.run {
                dotPhase = (dotPhase + 1) % 3
            }
        }
    }
}

#Preview {
    SplashView()
}
