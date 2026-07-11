//
//  SelectSourceView.swift
//  Sphir
//
//  Step 2 of the "+Card" flow: choose where the content is coming from.
//

import SwiftUI

struct SelectSourceView: View {
    @EnvironmentObject private var flow: CardFlowCoordinator
    @EnvironmentObject private var appStore: AppStore

    private let sources: [CardSource] = [.photos, .camera, .url, .screenshots]

    var body: some View {
        VStack(spacing: 0) {
            // X close on Step 2 returns to Step 1.
            FlowModalHeader(title: "Where are you adding from?") {
                flow.showSource = false
            }

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(sources) { source in
                        CardOptionRow(
                            emoji: source.emoji,
                            title: source.title,
                            subtitle: source.subtitle,
                            minHeight: 72,
                            identifier: "cardSource_\(source.rawValue)"
                        ) {
                            switch source {
                            case .screenshots: flow.selectScreenshots()
                            case .photos:      flow.selectPhotos()
                            case .camera:      flow.selectCamera()
                            case .url:         flow.selectSource(source)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
        }
        .background(SphirColor.background.ignoresSafeArea())
        // Step 3 — Paste URL
        .fullScreenCover(isPresented: $flow.showForm) {
            URLCardView()
                .environmentObject(flow)
                .environmentObject(appStore)
        }
        // Screenshot + OCR flow
        .fullScreenCover(isPresented: $flow.showScreenshotForm) {
            ScreenshotCardView()
                .environmentObject(flow)
                .environmentObject(appStore)
        }
        // Photos / Camera flow
        .fullScreenCover(isPresented: $flow.showPhotoForm) {
            PhotoCardView()
                .environmentObject(flow)
                .environmentObject(appStore)
        }
    }
}

#Preview {
    SelectSourceView()
        .environmentObject(CardFlowCoordinator())
        .environmentObject(AppStore())
}
