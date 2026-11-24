//
//  ClipFlowView.swift
//  SphirShare
//
//  Three-tap clip: share a page -> auto-filled preview card -> Save Card ->
//  saved-card screen (Figma s1-03 / s1-04, with the saved card and "Add to more
//  collections" Alissa asked for). Compiled into SphirShare and into the app,
//  where the +Card screen reuses it for a pasted link. In the extension the
//  older crop / extract-text flow (ShareView) stays reachable from the "..."
//  menu (`onCrop`); the app has no such menu.
//

import SwiftUI
import Combine

// MARK: - Model

@MainActor
final class ClipFlowModel: ObservableObject {
    enum Phase { case loading, preview, saving, saved }

    @Published var phase: Phase = .loading
    @Published var draft: ClipDraft
    @Published var coverData: Data?
    @Published var collections: [ClipCollection] = []
    @Published var selectedID: String?
    @Published var banner: String?

    // Saved screen
    @Published var savedServerID: String?
    @Published var savedLocalID: UUID?
    @Published var queuedMessage: String?
    @Published var extraIDs: Set<String> = []
    @Published var appliedExtraIDs: Set<String> = []
    @Published var folderError: String?
    @Published var updatingFolders = false
    /// "Already on Sphir · N people saved it" (S4); nil when nobody saved it.
    @Published var alreadyOnSphir: AlreadyOnSphir?
    /// The AI filled the card; the user can still edit it (S6).
    @Published var aiFilled = false
    /// Price field shown: the card came with a price or the AI filled it.
    @Published var showsPrice = false

    private let content: SharedContent
    private let sharedCollections: [SharedCollectionDTO]
    private let queue: @MainActor (SharePayload) -> UUID
    /// True inside the main app (light background, local-store queue).
    let inApp: Bool
    private var signedIn = KeychainService.hasCredentials
    private var started = false

    /// `queue` stores a clip that could not be created online: the App Group
    /// queue in the extension, the local store in the app.
    init(content: SharedContent, sharedCollections: [SharedCollectionDTO], inApp: Bool = false,
         queue: @escaping @MainActor (SharePayload) -> UUID) {
        self.content = content
        self.sharedCollections = sharedCollections
        self.inApp = inApp
        self.queue = queue
        draft = ClipDraft(fallbackURL: content.urlString ?? "")
    }

    var selected: ClipCollection? { collections.first { $0.id == selectedID } }
    var savedOnline: Bool { savedServerID != nil }
    var extrasChanged: Bool { extraIDs != appliedExtraIDs }

    /// Id for sphir://card/<id>: the API id after an online save (the app has
    /// not imported the card yet), else the queued card's local id.
    var viewCardID: String? { savedServerID ?? savedLocalID?.uuidString }

    private var queuedText: String {
        inApp ? "Saved — it will sync when you're back online" : ClipSavePath.queuedMessage
    }

    // MARK: Load

    func start() async {
        guard !started else { return }
        started = true
        let url = content.urlString ?? ""
        if !signedIn { banner = ClipSavePath.signInMessage }

        async let previewResult = loadPreview(url: url)
        async let folderResult = loadCollections()
        let (preview, folders) = await (previewResult, folderResult)

        collections = folders
        selectedID = FolderSelection.preselect(suggested: preview?.suggestedCollectionID,
                                               lastUsed: SharedInbox.lastClipCollection,
                                               available: folders.map(\.id))
        if let preview {
            draft = ClipDraft(preview: preview, fallbackURL: url)
            alreadyOnSphir = preview.alreadyOnSphir
            aiFilled = preview.ai
            showsPrice = !draft.price.isEmpty || preview.ai
        } else {
            let meta = await MetadataService.fetch(urlString: url)
            draft = ClipDraft(fallbackURL: url, title: meta?.title ?? "", description: meta?.description ?? "",
                              imageURL: meta?.imageURL)
            coverData = meta?.imageData
        }
        phase = .preview
    }

    private func loadPreview(url: String) async -> LinkPreview? {
        guard signedIn, !url.isEmpty else { return nil }
        do {
            return try await NetworkService.shared.preview(url: url, html: content.pageHTML)
        } catch {
            noteIfUnauthorized(error)
            return nil
        }
    }

    private func loadCollections() async -> [ClipCollection] {
        if signedIn {
            do {
                let folders = try await CollectionAPIService.fetchCollections()
                let list = ClipCollection.pickerList(folders: folders, shared: sharedCollections)
                if !list.isEmpty { return list }
            } catch {
                noteIfUnauthorized(error)
            }
        }
        let local = sharedCollections.isEmpty && !inApp ? SharedInbox.fallbackCollections : sharedCollections
        return ClipCollection.fromShared(local)
    }

    private func noteIfUnauthorized(_ error: Error) {
        if ClipSavePath.queueReason(after: error) == .signedOut {
            signedIn = false
            banner = ClipSavePath.signInMessage
        }
    }

    // MARK: Save

    func save() async {
        guard phase == .preview else { return }
        phase = .saving
        let path = ClipSavePath.choose(signedIn: signedIn, folderServerID: selected?.serverID)
        if let id = selectedID { SharedInbox.lastClipCollection = id }

        switch path {
        case .online(let folderID):
            do {
                let dto = try await CardAPIService.createCard(draft.request(folderServerID: folderID))
                savedServerID = dto.serverID
                phase = .saved
            } catch {
                noteIfUnauthorized(error)
                await enqueue(reason: ClipSavePath.queueReason(after: error))
            }
        case .queue(let reason):
            await enqueue(reason: reason)
        }
    }

    private func enqueue(reason: ClipSavePath.QueueReason) async {
        if coverData == nil, let image = draft.imageURL, let url = URL(string: image) {
            var request = URLRequest(url: url)
            request.timeoutInterval = 4
            coverData = try? await URLSession.shared.data(for: request).0
        }
        savedLocalID = queue(draft.payload(collectionID: selected?.localID, imageData: coverData))
        queuedMessage = reason == .signedOut && !inApp ? ClipSavePath.queuedMessage : queuedText
        if reason == .signedOut { banner = ClipSavePath.signInMessage }
        phase = .saved
    }

    // MARK: More collections (only after an online save)

    func toggleExtra(_ collection: ClipCollection) {
        guard let primary = selected?.serverID, let sid = collection.serverID else { return }
        extraIDs = FolderSelection.toggle(sid, primary: primary, extras: extraIDs)
    }

    func applyExtras() async {
        guard let cardID = savedServerID, let primary = selected?.serverID else { return }
        updatingFolders = true
        folderError = nil
        let ids = FolderSelection.compose(primary: primary, extras: extraIDs,
                                          order: collections.compactMap(\.serverID))
        do {
            let dto = try await CardAPIService.setFolders(serverID: cardID, folderIDs: ids)
            let confirmed = Set(dto.folderServerIDs).subtracting([primary])
            extraIDs = confirmed.isEmpty ? extraIDs : confirmed
            appliedExtraIDs = extraIDs
        } catch {
            noteIfUnauthorized(error)
            folderError = "Couldn't update collections. Try again."
        }
        updatingFolders = false
    }
}

// MARK: - Views

struct ClipFlowView: View {
    @ObservedObject var model: ClipFlowModel
    /// Extension only: opens the crop / extract-text flow from the "..." menu.
    let onCrop: (() -> Void)?
    /// Receives the id for sphir://card/<id> (nil: just open the app).
    let onView: (String?) -> Void
    let onDismiss: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            if model.phase == .saved {
                SavedCardView(model: model, onView: onView, onDismiss: onDismiss)
                    .transition(.opacity)
            } else {
                PreviewCardView(model: model, onCrop: onCrop, onCancel: onCancel)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: model.phase == .saved)
        .task { await model.start() }
    }
}

private struct PreviewCardView: View {
    @ObservedObject var model: ClipFlowModel
    let onCrop: (() -> Void)?
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 0)
            if let saved = model.alreadyOnSphir {
                Label(saved.notice, systemImage: "person.2.fill")
                    .accessibilityIdentifier("clipAlreadyOnSphir")
                    .font(ShareFont.body(13, weight: .semibold))
                    .foregroundColor(ShareColor.textPrimary)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Capsule().fill(ShareColor.background))
            }
            if let banner = model.banner {
                Text(banner)
                    .font(ShareFont.body(13, weight: .semibold))
                    .foregroundColor(ShareColor.textPrimary)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Capsule().fill(ShareColor.background))
            }
            card
            collectionPicker
            saveButton
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        .padding(.top, 12)
        .background { if model.inApp { ShareColor.background.ignoresSafeArea() } }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button(action: onCancel) {
                    Text("‹ Cancel").font(ShareFont.body(14)).foregroundColor(ShareColor.taupe)
                }
                Spacer()
                Image("SphirMark").resizable().scaledToFit().frame(height: 26).accessibilityLabel("Sphir")
                Spacer()
                if let onCrop {
                    Menu {
                        Button { onCrop() } label: { Label("Crop or extract text…", systemImage: "crop") }
                        Button(role: .cancel, action: onCancel) { Text("Cancel") }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(ShareColor.taupe)
                            .frame(width: 44, height: 28, alignment: .trailing)
                    }
                    .accessibilityLabel("More")
                } else {
                    Color.clear.frame(width: 44, height: 28)
                }
            }

            if model.phase == .loading {
                VStack(spacing: 10) {
                    ProgressView()
                    Text("Reading the page…").font(ShareFont.body(13)).foregroundColor(ShareColor.mutedText)
                }
                .frame(maxWidth: .infinity, minHeight: 240)
            } else {
                ScrollView(showsIndicators: false) { details }
                    .frame(maxHeight: 420)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.white))
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(model.draft.typeLabel)
                    .accessibilityIdentifier("clipTypeLabel")
                    .font(ShareFont.body(11, weight: .bold)).tracking(1.2)
                    .foregroundColor(ShareColor.taupe)
                if model.aiFilled {
                    Spacer()
                    Label("Filled by AI · edit anything", systemImage: "sparkles")
                        .accessibilityIdentifier("clipAiFilled")
                        .font(ShareFont.body(11, weight: .medium))
                        .foregroundColor(ShareColor.mutedText)
                }
            }

            TextField("Title", text: $model.draft.title, axis: .vertical)
                .accessibilityIdentifier("clipTitleField")
                .font(ShareFont.heading(20))
                .foregroundColor(ShareColor.textPrimary)
                .lineLimit(1...4)

            CoverView(urlString: model.draft.imageURL, data: model.coverData, type: model.draft.type)

            if !model.draft.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(model.draft.tags, id: \.self) { tag in
                            Text(tag)
                                .font(ShareFont.body(12, weight: .medium))
                                .foregroundColor(ShareColor.textPrimary)
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(Capsule().fill(ShareColor.background))
                                .overlay(Capsule().stroke(ShareColor.border, lineWidth: 1))
                        }
                    }
                }
            }

            if model.showsPrice {
                TextField("Price", text: $model.draft.price)
                    .accessibilityIdentifier("clipPrice")
                    .font(ShareFont.body(20, weight: .bold))
                    .foregroundColor(ShareColor.textPrimary)
            }

            TextField("Description", text: $model.draft.description, axis: .vertical)
                .font(ShareFont.body(14))
                .foregroundColor(ShareColor.textPrimary)
                .lineLimit(1...6)

            if !model.draft.sourceLine.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "link").font(.system(size: 11))
                    Text(model.draft.sourceLine).font(ShareFont.body(12))
                }
                .foregroundColor(ShareColor.mutedText)
            }
        }
    }

    private var collectionPicker: some View {
        VStack(spacing: 6) {
            Text("Save to Collection")
                .font(ShareFont.body(13, weight: .semibold))
                .foregroundColor(model.inApp ? ShareColor.mutedText : .white)
            Menu {
                ForEach(model.collections) { col in
                    Button(col.name) { model.selectedID = col.id }
                }
            } label: {
                HStack {
                    Text(model.selected?.name ?? "No collection")
                        .font(ShareFont.body(15, weight: .semibold))
                        .foregroundColor(ShareColor.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.down").font(.system(size: 12, weight: .bold))
                        .foregroundColor(ShareColor.taupe)
                }
                .padding(.horizontal, 16).padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.white))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(model.inApp ? ShareColor.border : .clear, lineWidth: 1))
            }
            .accessibilityIdentifier("clipCollectionPicker")
            .disabled(model.collections.isEmpty)
        }
    }

    private var saveButton: some View {
        Button {
            Task { await model.save() }
        } label: {
            Group {
                if model.phase == .saving { ProgressView().tint(.white) }
                else { Text("SAVE CARD").font(ShareFont.body(16, weight: .bold)).tracking(0.8) }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(Capsule().fill(ShareColor.taupe.opacity(model.phase == .preview ? 1 : 0.6)))
        }
        .accessibilityIdentifier("saveCardButton")
        .disabled(model.phase != .preview)
    }
}

private struct CoverView: View {
    let urlString: String?
    let data: Data?
    let type: CardType

    var body: some View {
        Group {
            if let data, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else if let urlString, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() }
                    else { placeholder }
                }
            } else {
                placeholder
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 190)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var placeholder: some View {
        ZStack {
            ShareColor.background
            Image(systemName: type.iconName).font(.system(size: 30)).foregroundColor(ShareColor.taupe)
        }
    }
}

private struct SavedCardView: View {
    @ObservedObject var model: ClipFlowModel
    let onView: (String?) -> Void
    let onDismiss: () -> Void
    @State private var showMore = false

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 18) {
                    ZStack {
                        Circle().fill(Color.green.opacity(0.15)).frame(width: 64, height: 64)
                        Image(systemName: "checkmark").font(.system(size: 26, weight: .bold)).foregroundColor(.green)
                    }
                    .padding(.top, 36)
                    Text("Card Saved!").font(ShareFont.heading(30)).foregroundColor(ShareColor.textPrimary)
                        .accessibilityIdentifier("cardSavedTitle")

                    if let message = model.queuedMessage {
                        Text(message).font(ShareFont.body(13)).foregroundColor(ShareColor.mutedText)
                            .multilineTextAlignment(.center)
                    }
                    if let banner = model.banner {
                        Text(banner).font(ShareFont.body(13, weight: .semibold)).foregroundColor(ShareColor.taupe)
                    }

                    savedCard

                    if let name = model.selected?.name {
                        VStack(spacing: 2) {
                            Text("Collection").font(ShareFont.body(12, weight: .semibold)).foregroundColor(ShareColor.mutedText)
                            Text(name).font(ShareFont.body(16, weight: .bold)).foregroundColor(ShareColor.textPrimary)
                        }
                    }

                    if model.savedOnline { moreCollections }

                    VStack(spacing: 10) {
                        linkButton("VIEW CARD", id: "viewSavedCardButton") { onView(model.viewCardID) }
                        Button(action: onDismiss) {
                            Text("Done").font(ShareFont.body(16, weight: .bold)).foregroundColor(.white)
                                .frame(maxWidth: .infinity, minHeight: 52)
                                .background(Capsule().fill(ShareColor.taupe))
                        }
                    }
                    .padding(.top, 6)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
    }

    /// Vertical card (cover on top, text below), matching the collection grid tile.
    private var savedCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            CoverView(urlString: model.draft.imageURL, data: model.coverData, type: model.draft.type)
                .padding([.horizontal, .top], 8)
            VStack(alignment: .leading, spacing: 8) {
                Text(model.draft.typeLabel).font(ShareFont.body(10, weight: .bold)).tracking(1).foregroundColor(ShareColor.taupe)
                Text(model.draft.card().title).font(ShareFont.body(16, weight: .bold)).foregroundColor(ShareColor.textPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                if !model.draft.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(model.draft.tags, id: \.self) { tag in
                                Text(tag)
                                    .font(ShareFont.body(11, weight: .medium))
                                    .foregroundColor(ShareColor.textPrimary)
                                    .padding(.horizontal, 10).padding(.vertical, 4)
                                    .background(Capsule().fill(ShareColor.background))
                                    .overlay(Capsule().stroke(ShareColor.border, lineWidth: 1))
                            }
                        }
                    }
                }
                if !model.draft.price.isEmpty {
                    Text(model.draft.price).font(ShareFont.body(18, weight: .bold)).foregroundColor(ShareColor.textPrimary)
                }
                if !model.draft.description.isEmpty {
                    Text(model.draft.description).font(ShareFont.body(13)).foregroundColor(ShareColor.textPrimary)
                        .lineLimit(5)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !model.draft.sourceLine.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "link").font(.system(size: 11))
                        Text(model.draft.sourceLine).font(ShareFont.body(12)).lineLimit(1)
                    }
                    .foregroundColor(ShareColor.mutedText)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(ShareColor.border, lineWidth: 1))
        .shadow(color: Color.black.opacity(0.08), radius: 8, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("savedCardPreview")
    }

    private var moreCollections: some View {
        VStack(spacing: 10) {
            linkButton(showMore ? "HIDE COLLECTIONS" : "ADD TO MORE COLLECTIONS", id: "addToMoreCollectionsButton") { showMore.toggle() }
            if showMore {
                VStack(spacing: 0) {
                    ForEach(model.collections.filter { $0.serverID != nil && $0.id != model.selectedID }) { col in
                        Button { model.toggleExtra(col) } label: {
                            HStack {
                                Text(col.name).font(ShareFont.body(15)).foregroundColor(ShareColor.textPrimary)
                                Spacer()
                                Image(systemName: model.extraIDs.contains(col.serverID ?? "") ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(ShareColor.taupe)
                            }
                            .padding(.vertical, 12).padding(.horizontal, 14)
                        }
                        Divider()
                    }
                }
                .background(RoundedRectangle(cornerRadius: 12).fill(ShareColor.cardBackgroundAlt))
                if let error = model.folderError {
                    Text(error).font(ShareFont.body(12)).foregroundColor(.red)
                }
                Button {
                    Task { await model.applyExtras() }
                } label: {
                    Group {
                        if model.updatingFolders { ProgressView() } else { Text("Update collections") }
                    }
                    .font(ShareFont.body(14, weight: .semibold))
                    .foregroundColor(ShareColor.taupe)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .overlay(Capsule().stroke(ShareColor.taupe, lineWidth: 1.5))
                }
                .disabled(!model.extrasChanged || model.updatingFolders)
                .opacity(model.extrasChanged ? 1 : 0.5)
            }
        }
    }

    private func linkButton(_ title: String, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(ShareFont.body(14, weight: .bold)).foregroundColor(Color(red: 0, green: 0.4, blue: 0.8))
                .frame(maxWidth: .infinity, minHeight: 36)
        }
        .accessibilityIdentifier(id)
    }
}
