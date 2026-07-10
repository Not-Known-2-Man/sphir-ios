//
//  SelectCardTypeView.swift
//  Sphir
//
//  Step 1 of the "+Card" flow: choose the kind of card.
//

import SwiftUI

struct SelectCardTypeView: View {
    @EnvironmentObject private var flow: CardFlowCoordinator
    @EnvironmentObject private var appStore: AppStore

    private let types: [CardType] = [.text, .media, .business, .product, .originalScribe]

    var body: some View {
        VStack(spacing: 0) {
            FlowModalHeader(title: "Select Card Type") {
                flow.dismissAll()
            }

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(types, id: \.self) { type in
                        CardOptionRow(
                            emoji: type.emoji,
                            title: type.title,
                            subtitle: type.subtitle,
                            identifier: "cardType_\(type.rawValue)"
                        ) {
                            flow.selectType(type)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
        }
        .background(SphirColor.background.ignoresSafeArea())
        // Step 2
        .sheet(isPresented: $flow.showSource) {
            SelectSourceView()
                .environmentObject(flow)
                .environmentObject(appStore)
        }
    }
}

#Preview {
    SelectCardTypeView()
        .environmentObject(CardFlowCoordinator())
        .environmentObject(AppStore())
}
