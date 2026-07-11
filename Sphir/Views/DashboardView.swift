//
//  DashboardView.swift
//  Sphir
//
//  Main Collections dashboard.
//

import SwiftUI

struct DashboardView: View {

    /// Which top-level tab is active.
    private enum DashboardTab: String, CaseIterable {
        case collections = "Collections"
        case groups = "Groups"
    }

    @EnvironmentObject private var appStore: AppStore
    @State private var selectedTab: DashboardTab = .collections
    @State private var searchText: String = ""
    @State private var showCollectionFlow = false
    @State private var showSettings = false
    @StateObject private var cardFlow = CardFlowCoordinator()

    private let gridColumns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        greeting
                        searchBar
                        tabSelector

                        ZStack {
                            switch selectedTab {
                            case .collections:
                                collectionsGrid
                                    .transition(.move(edge: .leading).combined(with: .opacity))
                            case .groups:
                                GroupsView(groups: SphirGroup.mockGroups)
                                    .transition(.move(edge: .trailing).combined(with: .opacity))
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
            }
            .background(SphirColor.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Collection.self) { collection in
                CollectionDetailView(collection: collection)
            }
            .navigationDestination(for: Card.self) { card in
                CardDetailView(card: card)
            }
        }
        // Step 1 of the "+Card" flow.
        .sheet(isPresented: $cardFlow.showType) {
            SelectCardTypeView()
                .environmentObject(cardFlow)
                .environmentObject(appStore)
        }
        // "+Collection" flow.
        .sheet(isPresented: $showCollectionFlow) {
            CreateCollectionView()
                .environmentObject(appStore)
        }
        // Settings.
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }

    // MARK: - Sticky Header

    private var header: some View {
        HStack(spacing: 12) {
            Text("SPHIR")
                .font(SphirFont.heading(22, weight: .bold))
                .foregroundColor(SphirColor.textPrimary)

            Spacer()

            addCardButton
            addCollectionButton

            Button {
                print("Notifications tapped")
            } label: {
                Image(systemName: "bell")
                    .font(.system(size: 18))
                    .foregroundColor(SphirColor.textPrimary)
            }

            Button {
                showSettings = true
            } label: {
                Circle()
                    .fill(SphirColor.lightTaupe)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text("A")
                            .font(SphirFont.body(14, weight: .semibold))
                            .foregroundColor(.white)
                    )
            }
            .accessibilityIdentifier("settingsButton")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            SphirColor.background
                .overlay(
                    Rectangle()
                        .fill(SphirColor.border)
                        .frame(height: 1),
                    alignment: .bottom
                )
        )
    }

    private var addCardButton: some View {
        Button {
            print("Card tapped")
            cardFlow.start()
        } label: {
            Text("+ Card")
                .font(SphirFont.body(13, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Capsule().fill(SphirColor.taupe))
        }
        .accessibilityIdentifier("addCardButton")
    }

    private var addCollectionButton: some View {
        Button {
            print("Collection tapped")
            showCollectionFlow = true
        } label: {
            Text("+ Collection")
                .font(SphirFont.body(13, weight: .semibold))
                .foregroundColor(SphirColor.taupe)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(SphirColor.cardBackground)
                        .overlay(Capsule().stroke(SphirColor.taupe, lineWidth: 1))
                )
        }
        .accessibilityIdentifier("addCollectionButton")
    }

    // MARK: - Greeting

    private var greeting: some View {
        Text("Good morning, Alex")
            .font(SphirFont.heading(20, weight: .bold))
            .foregroundColor(SphirColor.textPrimary)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(SphirColor.mutedText)
            TextField("Search collections...", text: $searchText)
                .font(SphirFont.body(15))
                .foregroundColor(SphirColor.textPrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(SphirColor.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(SphirColor.border, lineWidth: 1)
        )
    }

    // MARK: - Tabs

    private var tabSelector: some View {
        HStack(spacing: 4) {
            ForEach(DashboardTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        selectedTab = tab
                    }
                } label: {
                    Text(tab.rawValue)
                        .font(SphirFont.body(14, weight: .semibold))
                        .foregroundColor(selectedTab == tab ? SphirColor.textPrimary : SphirColor.mutedText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(selectedTab == tab ? SphirColor.cardBackground : Color.clear)
                        )
                }
            }
        }
        .padding(4)
        .background(
            Capsule().fill(SphirColor.cardBackgroundAlt)
        )
        .overlay(
            Capsule().stroke(SphirColor.border, lineWidth: 1)
        )
    }

    // MARK: - Collections Grid

    private var collectionsGrid: some View {
        LazyVGrid(columns: gridColumns, spacing: 16) {
            ForEach(appStore.collections) { collection in
                NavigationLink(value: collection) {
                    CollectionCardView(collection: collection)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview {
    DashboardView()
        .environmentObject(AppStore())
}
