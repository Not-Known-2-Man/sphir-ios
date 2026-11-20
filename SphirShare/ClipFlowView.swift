//
//  ClipFlowView.swift
//  SphirShare
//
//  Three-tap clip: share a page -> auto-filled preview card -> Save Card ->
//  saved-card screen (Figma s1-03 / s1-04, with the saved card and "Add to more
//  collections" Alissa asked for). The older crop / extract-text flow
//  (ShareView) stays reachable from the "..." menu.
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

    private let content: SharedContent
    private let sharedCollections: [SharedCollectionDTO]
    private let queue: (SharePayload) -> UUID
    private var signedIn = KeychainService.hasCredentials
    private var started = false

    init(content: SharedContent, sharedCollections: [SharedCollectionDTO], queue: @escaping (SharePayload) -> UUID) {
        self.content = content
        self.sharedCollections = sharedCollections
        self.queue = queue
        draft = ClipDraft(fallbackURL: content.urlString ?? "")
    }

    var selected: ClipCollection? { collections.first { $0.id == selectedID } }
    var savedOnline: Bool { savedServerID != nil }
    var extrasChanged: Bool { extraIDs != appliedExtraIDs }

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
        selectedID = FolderSelection.preselect(lastUsed: SharedInbox.lastClipCollection, available: folders.map(\.id))
        if let preview {
            draft = ClipDraft(preview: preview, fallbackURL: url)
        } else {
            let meta = await MetadataService.fetch(urlString: url)
            draft = ClipDraft(fallbackURL: url, title: meta?.title ?? "", description: meta?.description ?? "")
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
        let local = sharedCollections.isEmpty ? SharedInbox.fallbackCollections : sharedCollections
        return local.map { ClipCollection(name: $0.name, serverID: nil, localID: $0.id) }
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
        let payload = SharePayload(
            collectionID: selected?.localID, title: draft.card().title, description: draft.description,
            urlString: draft.url, bodyText: nil, imageData: coverData, tags: draft.tags)
        savedLocalID = queue(payload)
        queuedMessage = ClipSavePath.queuedMessage
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

// MARK: - Root (clip flow, with the crop flow one tap away)

struct ShareRoot: View {
    let content: SharedContent
    let collections: [SharedCollectionDTO]
    let storedCollections: [SharedCollectionDTO]
    let onSave: (SharePayload) -> UUID
    let onUpdateCollection: (UUID, UUID?) -> Void
    let onScreenChange: (ExtensionScreen) -> Void
    let onView: (UUID) -> Void
    let onOpenApp: () -> Void
    let onDismiss: () -> Void
    let onCancel: () -> Void

    @State private var showCropFlow = false
    @StateObject private var model: ClipFlowModel

    init(content: SharedContent, collections: [SharedCollectionDTO], storedCollections: [SharedCollectionDTO],
         onSave: @escaping (SharePayload) -> UUID,
         onUpdateCollection: @escaping (UUID, UUID?) -> Void,
         onScreenChange: @escaping (ExtensionScreen) -> Void,
         onView: @escaping (UUID) -> Void, onOpenApp: @escaping () -> Void,
         onDismiss: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.content = content; self.collections = collections; self.storedCollections = storedCollections
        self.onSave = onSave; self.onUpdateCollection = onUpdateCollection
        self.onScreenChange = onScreenChange; self.onView = onView; self.onOpenApp = onOpenApp
        self.onDismiss = onDismiss; self.onCancel = onCancel
        _model = StateObject(wrappedValue: ClipFlowModel(content: content, sharedCollections: storedCollections, queue: onSave))
    }

    var body: some View {
        if content.isLink && !showCropFlow {
            ClipFlowView(model: model, onCrop: { showCropFlow = true },
                         onView: { id in id.map(onView) ?? onOpenApp() },
                         onDismiss: onDismiss, onCancel: onCancel)
        } else {
            ShareView(content: content, collections: collections, onSave: onSave,
                      onUpdateCollection: onUpdateCollection, onScreenChange: onScreenChange,
                      onView: onView, onDismiss: onDismiss, onCancel: onCancel)
        }
    }
}

// MARK: - Views

struct ClipFlowView: View {
    @ObservedObject var model: ClipFlowModel
    let onCrop: () -> Void
    let onView: (UUID?) -> Void
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
    let onCrop: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 0)
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
            Text(model.draft.typeLabel)
                .font(ShareFont.body(11, weight: .bold)).tracking(1.2)
                .foregroundColor(ShareColor.taupe)

            TextField("Title", text: $model.draft.title, axis: .vertical)
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

            if !model.draft.price.isEmpty {
                Text(model.draft.price)
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
                .foregroundColor(.white)
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
            }
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
    let onView: (UUID?) -> Void
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
                        linkButton("VIEW CARD") { onView(model.savedLocalID) }
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

    private var savedCard: some View {
        HStack(spacing: 12) {
            CoverView(urlString: model.draft.imageURL, data: model.coverData, type: model.draft.type)
                .frame(width: 84, height: 84)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 4) {
                Text(model.draft.typeLabel).font(ShareFont.body(10, weight: .bold)).tracking(1).foregroundColor(ShareColor.taupe)
                Text(model.draft.card().title).font(ShareFont.body(15, weight: .bold)).foregroundColor(ShareColor.textPrimary).lineLimit(2)
                Text(model.draft.site).font(ShareFont.body(12)).foregroundColor(ShareColor.mutedText).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(ShareColor.border, lineWidth: 1))
    }

    private var moreCollections: some View {
        VStack(spacing: 10) {
            linkButton(showMore ? "HIDE COLLECTIONS" : "ADD TO MORE COLLECTIONS") { showMore.toggle() }
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

    private func linkButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(ShareFont.body(14, weight: .bold)).foregroundColor(Color(red: 0, green: 0.4, blue: 0.8))
                .frame(maxWidth: .infinity, minHeight: 36)
        }
    }
}
