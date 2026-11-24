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
    @EnvironmentObject private var router: NavigationRouter
    @EnvironmentObject private var session: AuthSession
    @State private var selectedTab: DashboardTab = .collections
    @State private var searchText: String = ""
    @State private var showCollectionFlow = false
    @State private var showSettings = false
    @State private var showNotifications = false
    @State private var showOnboarding = false
    @State private var didCheckOnboarding = false
    @StateObject private var cardFlow = CardFlowCoordinator()

    private let gridColumns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        NavigationStack(path: $router.path) {
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
                                collectionsContent
                                    .transition(.move(edge: .leading).combined(with: .opacity))
                            case .groups:
                                groupsContent
                                    .transition(.move(edge: .trailing).combined(with: .opacity))
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
                .scrollDismissesKeyboard(.interactively)
                .refreshable {
                    await appStore.syncFromAPI()
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
            // Test hook: simulate an incoming deep link at launch.
            .onAppear {
                if let deeplink = ProcessInfo.processInfo.environment["DEEPLINK"],
                   let url = URL(string: deeplink) {
                    router.handle(url, store: appStore)
                }
            }
        }
        // The one-screen "+Card" flow. When it closes, pull the new card (saved
        // online by the clip flow) and open it if "View card" was tapped.
        .sheet(isPresented: $cardFlow.showAdd, onDismiss: cardFlowDidClose) {
            AddCardView()
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
                .environmentObject(session)
        }
        // Notifications.
        .sheet(isPresented: $showNotifications) {
            NotificationsView()
        }
        // First-launch onboarding (shown once, after login).
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView {
                session.completeOnboarding()
                showOnboarding = false
            }
        }
        .onAppear {
            guard !didCheckOnboarding else { return }
            didCheckOnboarding = true
            showOnboarding = !session.hasSeenOnboarding
        }
        // Pull collections + cards from the API on login (no-op offline/mock).
        .task {
            await appStore.syncFromAPI()
        }
        // User-friendly error surface (e.g. storage failures).
        .alert(
            "Something went wrong",
            isPresented: Binding(
                get: { appStore.errorMessage != nil },
                set: { if !$0 { appStore.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { appStore.errorMessage = nil }
        } message: {
            Text(appStore.errorMessage ?? "")
        }
    }

    /// Groups have no backend yet: real accounts see an empty state; the
    /// sample groups exist only for the mock UI-test experience.
    @ViewBuilder
    private var groupsContent: some View {
        if ProcessInfo.processInfo.arguments.contains("UITEST") {
            GroupsView(groups: SphirGroup.mockGroups)
        } else {
            EmptyStateView(
                icon: "person.3",
                title: "No groups yet",
                message: "Groups you create or join will appear here."
            )
            .padding(.top, 40)
        }
    }

    // MARK: - Sticky Header

    private var header: some View {
        HStack(spacing: 12) {
            Image("SphirLogo")
                .resizable()
                .scaledToFit()
                .frame(height: 20)
                .layoutPriority(-1)
                .accessibilityLabel("Sphir")
                .accessibilityAddTraits(.isHeader)

            Spacer()

            addCardButton
            addCollectionButton

            Button {
                showNotifications = true
            } label: {
                Image(systemName: "bell")
                    .font(.system(size: 18))
                    .foregroundColor(SphirColor.textPrimary)
            }
            .accessibilityIdentifier("notificationsButton")
            .accessibilityLabel("Notifications")

            Button {
                showSettings = true
            } label: {
                Circle()
                    .fill(SphirColor.lightTaupe)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text(session.initial)
                            .font(SphirFont.body(14, weight: .semibold))
                            .foregroundColor(.white)
                    )
            }
            .accessibilityIdentifier("settingsButton")
            .accessibilityLabel("Settings")
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

    /// Runs when the +Card sheet is gone.
    private func cardFlowDidClose() {
        if let id = cardFlow.pendingCardLink, let url = Card.deepLinkURL(serverID: id) {
            cardFlow.pendingCardLink = nil
            router.handle(url, store: appStore)   // syncs first when the card is not local yet
        } else {
            Task { await appStore.syncFromAPI() }
        }
    }

    private var addCardButton: some View {
        Button {
            print("Card tapped")
            cardFlow.start()
        } label: {
            Text("+ Card")
                .font(SphirFont.body(13, weight: .semibold))
                .lineLimit(1)
                .fixedSize()
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
                .lineLimit(1)
                .fixedSize()
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
        Text("Good morning, \(session.displayName)")
            .font(SphirFont.heading(20, weight: .bold))
            .foregroundColor(SphirColor.textPrimary)
            .accessibilityAddTraits(.isHeader)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(SphirColor.mutedText)
            TextField("Search Sphirs and cards...", text: $searchText)
                .font(SphirFont.body(15))
                .foregroundColor(SphirColor.textPrimary)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .accessibilityIdentifier("searchField")
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

    // MARK: - Collections + Search

    private var trimmedQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isSearching: Bool { !trimmedQuery.isEmpty }

    private var filteredCollections: [Collection] {
        guard isSearching else { return appStore.collections }
        return appStore.collections.filter {
            $0.name.localizedCaseInsensitiveContains(trimmedQuery)
                || $0.description.localizedCaseInsensitiveContains(trimmedQuery)
        }
    }

    private var uncategorizedCards: [Card] {
        appStore.cards
            .filter { $0.collectionID == nil }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var matchingCards: [Card] {
        guard isSearching else { return [] }
        return appStore.cards
            .filter {
                $0.title.localizedCaseInsensitiveContains(trimmedQuery)
                    || $0.content.localizedCaseInsensitiveContains(trimmedQuery)
                    || $0.description.localizedCaseInsensitiveContains(trimmedQuery)
                    || $0.tags.contains { $0.localizedCaseInsensitiveContains(trimmedQuery) }
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var collectionsContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            if isSearching {
                searchResults
            } else if !filteredCollections.isEmpty {
                collectionsGrid
            } else {
                EmptyStateView(
                    icon: "square.stack.3d.up",
                    title: "No collections yet",
                    message: "Tap \"+Collection\" to create your first one."
                )
            }

            if !isSearching && !uncategorizedCards.isEmpty {
                uncategorizedSection
            }
        }
    }

    /// Cards first (what people usually look for), then matching Sphirs.
    /// The empty state only shows when nothing matches at all.
    @ViewBuilder
    private var searchResults: some View {
        if matchingCards.isEmpty && filteredCollections.isEmpty {
            EmptyStateView(
                icon: "magnifyingglass",
                title: "No results",
                message: "No Sphirs or cards match \"\(trimmedQuery)\"."
            )
        } else {
            if !matchingCards.isEmpty {
                matchingCardsSection
            }
            if !filteredCollections.isEmpty {
                Text("Sphirs")
                    .font(SphirFont.body(14, weight: .semibold))
                    .foregroundColor(SphirColor.mutedText)
                collectionsGrid
            }
        }
    }

    private var uncategorizedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Uncategorized")
                .font(SphirFont.body(14, weight: .semibold))
                .foregroundColor(SphirColor.mutedText)
            ForEach(uncategorizedCards) { card in
                NavigationLink(value: card) {
                    CardRowView(card: card)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var collectionsGrid: some View {
        LazyVGrid(columns: gridColumns, spacing: 16) {
            ForEach(filteredCollections) { collection in
                NavigationLink(value: collection) {
                    CollectionCardView(collection: collection)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var matchingCardsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cards")
                .font(SphirFont.body(14, weight: .semibold))
                .foregroundColor(SphirColor.mutedText)

            ForEach(matchingCards) { card in
                NavigationLink(value: card) {
                    CardRowView(card: card)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    DashboardView()
        .environmentObject(AppStore())
        .environmentObject(NavigationRouter())
        .environmentObject(AuthSession())
}
