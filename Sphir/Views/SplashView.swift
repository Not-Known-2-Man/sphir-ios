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

            Image("SphirLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 240)
            .accessibilityHidden(true)
        }
    }
}

#Preview {
    SplashView()
}
