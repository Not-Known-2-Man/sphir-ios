//
//  SplashView.swift
//  Sphir
//
//  Brief launch screen shown while the app decides where to route.
//

import SwiftUI

struct SplashView: View {
    var body: some View {
        ZStack {
            SphirColor.background.ignoresSafeArea()

            VStack(spacing: 16) {
                Circle()
                    .fill(SphirColor.taupe)
                    .frame(width: 88, height: 88)
                    .overlay(
                        Text("S")
                            .font(SphirFont.heading(44, weight: .bold))
                            .foregroundColor(.white)
                    )
                Text("SPHIR")
                    .font(SphirFont.heading(22, weight: .bold))
                    .foregroundColor(SphirColor.textPrimary)
            }
            .accessibilityHidden(true)
        }
    }
}

#Preview {
    SplashView()
}
