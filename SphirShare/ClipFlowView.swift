//
//  ClipFlowView.swift
//  SphirShare
//
//  Three-tap clip: share a page -> auto-filled preview card with collection
//  chips -> Save Card -> "Successfully clipped" screen (Alissa's "Sphir Clip
//  App - Simple Flow" mockup, panels 3 and 4). Compiled into SphirShare and into the app,
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
    /// Selected collection ids, in tap order: the first is the primary one.
    @Published var selectedIDs: [String] = []
    @Published var banner: String?
    /// "+ New collection" failed (nothing was changed).
    @Published var collectionError: String?

    // Saved screen
    @Published var savedServerID: String?
    @Published var savedLocalID: UUID?
    @Published var queuedMessage: String?
    /// Set when the card was saved but could not be added to the other collections.
    @Published var folderError: String?
    /// "Already on Sphir · N people saved it" (S4); nil when nobody saved it.
    @Published var alreadyOnSphir: AlreadyOnSphir?
    /// The AI filled the card; the user can still edit it (S6).
    @Published var aiFilled = false
    /// Price field shown: the card came with a price or the AI filled it.
    @Published var showsPrice = false

    private let content: SharedContent
    private let sharedCollections: [SharedCollectionDTO]
    private let queue: @MainActor (SharePayload) -> UUID
    /// Creates a collection (nil on failure). The app passes its store; the
    /// extension uses the API directly when signed in.
    private let createCollectionAction: (@MainActor (String) async -> ClipCollection?)?
    /// Uploads a JPEG and returns its URL (POST /api/v1/images). Tests pass a fake.
    private let uploadImage: @MainActor (Data) async throws -> String
    /// POST /api/v1/businesses. Tests pass a fake.
    private let createCardRequest: @MainActor (BusinessRequest) async throws -> BusinessDTO
    /// True inside the main app (light background, local-store queue).
    let inApp: Bool
    private var signedIn: Bool
    private var started = false
    /// The user picked an image for this clip (it still has to be uploaded on save).
    private(set) var hasPickedImage = false

    /// `queue` stores a clip that could not be created online: the App Group
    /// queue in the extension, the local store in the app.
    init(content: SharedContent, sharedCollections: [SharedCollectionDTO], inApp: Bool = false,
         signedIn: Bool = KeychainService.hasCredentials,
         queue: @escaping @MainActor (SharePayload) -> UUID,
         createCollection: (@MainActor (String) async -> ClipCollection?)? = nil,
         uploadImage: @escaping @MainActor (Data) async throws -> String = { try await CardAPIService.uploadImage($0) },
         createCardRequest: @escaping @MainActor (BusinessRequest) async throws -> BusinessDTO = { try await CardAPIService.createCard($0) }) {
        self.createCollectionAction = createCollection
        self.signedIn = signedIn
        self.uploadImage = uploadImage
        self.createCardRequest = createCardRequest
        self.content = content
        self.sharedCollections = sharedCollections
        self.inApp = inApp
        self.queue = queue
        draft = ClipDraft(fallbackURL: content.urlString ?? "")
    }

    var selectedID: String? { CollectionSelection.primary(of: selectedIDs) }
    /// The primary collection (the card is created in it).
    var selected: ClipCollection? { collections.first { $0.id == selectedID } }
    var savedOnline: Bool { savedServerID != nil }

    func isSelected(_ collection: ClipCollection) -> Bool { selectedIDs.contains(collection.id) }

    func toggle(_ collection: ClipCollection) {
        selectedIDs = CollectionSelection.toggle(collection.id, in: selectedIDs)
    }

    /// "+ New collection": creates it, adds it to the chips and selects it. The
    /// typed card fields (`draft`) are untouched. A name that already exists
    /// just selects that collection.
    func createCollection(named typed: String) async {
        collectionError = nil
        switch NewCollectionName.resolve(typed, existing: collections.map(\.name)) {
        case .invalid:
            return
        case .existing(let index):
            selectedIDs = CollectionSelection.afterCreate(id: collections[index].id)
        case .create(let name):
            guard let created = await makeCollection(name) else {
                collectionError = "Couldn't create the collection. Try again."
                return
            }
            collections.append(created)
            selectedIDs = CollectionSelection.afterCreate(id: created.id)
        }
    }

    private func makeCollection(_ name: String) async -> ClipCollection? {
        if let createCollectionAction { return await createCollectionAction(name) }
        guard signedIn else { return nil }
        do {
            let folder = try await CollectionAPIService.createCollection(name: name, description: "", privacy: "private")
            guard let sid = folder.serverID, !sid.isEmpty else { return nil }
            return ClipCollection(name: folder.name, serverID: sid, localID: nil)
        } catch {
            noteIfUnauthorized(error)
            return nil
        }
    }

    /// Id for sphir://collection/<id>: the primary collection's API id, else
    /// its local id; nil when no collection is selected.
    var viewCollectionID: String? {
        guard let selected else { return nil }
        return selected.serverID ?? selected.localID?.uuidString
    }

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
        selectedIDs = FolderSelection.preselect(suggested: preview?.suggestedCollectionID,
                                                lastUsed: SharedInbox.lastClipCollection,
                                                available: folders.map(\.id)).map { [$0] } ?? []
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

    // MARK: Image

    /// The user picked (or took) a photo: it becomes the cover right away, resized to a
    /// JPEG that fits the upload limit. Data that is not an image changes nothing.
    func pickImage(_ data: Data) {
        guard let jpeg = ImageCompression.jpegForUpload(data) else { return }
        coverData = jpeg
        hasPickedImage = true
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
                // A picked image is uploaded first; its URL becomes the card's og_image.
                if hasPickedImage, let picked = coverData {
                    draft.imageURL = try await uploadImage(picked)
                }
                let dto = try await createCardRequest(draft.request(folderServerID: folderID))
                savedServerID = dto.serverID
                if let cardID = dto.serverID { await addToOtherCollections(cardID: cardID) }
                phase = .saved
            } catch {
                noteIfUnauthorized(error)
                await enqueue(reason: ClipSavePath.queueReason(after: error))
            }
        case .queue(let reason):
            await enqueue(reason: reason)
        }
    }

    /// Online only: puts the saved card in every selected collection (primary
    /// first). The card stays saved when this fails.
    private func addToOtherCollections(cardID: String) async {
        let ids = selectedIDs.compactMap { id in collections.first { $0.id == id }?.serverID }
        guard ids.count > 1 else { return }
        do {
            _ = try await CardAPIService.setFolders(serverID: cardID, folderIDs: ids)
        } catch {
            noteIfUnauthorized(error)
            folderError = "Saved to \(selected?.name ?? "your collection"). Couldn't add it to the other collections."
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
}

// MARK: - Views

struct ClipFlowView: View {
    @ObservedObject var model: ClipFlowModel
    /// Extension only: opens the crop / extract-text flow from the "..." menu.
    let onCrop: (() -> Void)?
    /// Receives the id for sphir://card/<id> (nil: just open the app).
    let onView: (String?) -> Void
    /// Receives the id for sphir://collection/<id> (the primary collection).
    let onViewCollection: (String) -> Void
    /// "Clip Another": the app goes back to +Card, the extension closes.
    let onClipAnother: () -> Void
    let onDismiss: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            if model.phase == .saved {
                SavedCardView(model: model, onView: onView, onViewCollection: onViewCollection,
                              onClipAnother: onClipAnother, onDismiss: onDismiss)
                    .transition(.opacity)
            } else {
                PreviewCardView(model: model, onCrop: onCrop, onCancel: onCancel)
            }
        }
        .background(ShareColor.background.ignoresSafeArea())
        .animation(.easeInOut(duration: 0.25), value: model.phase == .saved)
        .task { await model.start() }
    }
}

/// Sphir mark + "Sphir Clip" with optional leading / trailing controls.
private struct ClipHeader<Leading: View, Trailing: View>: View {
    @ViewBuilder let leading: Leading
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(spacing: 0) {
            leading.frame(width: 44, height: 32, alignment: .leading)
            Spacer()
            HStack(spacing: 8) {
                Image("SphirMark").resizable().scaledToFit().frame(height: 24).accessibilityHidden(true)
                Text("Sphir Clip").font(ShareFont.heading(20)).foregroundColor(ShareColor.brown)
            }
            .accessibilityElement(children: .combine)
            Spacer()
            trailing.frame(width: 44, height: 32, alignment: .trailing)
        }
    }
}

/// Wraps its children onto new lines, like the collection chips in the mockup.
private struct ChipFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(width: proposal.width ?? .infinity, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(width: bounds.width, subviews: subviews)
        for (index, origin) in result.origins.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y),
                                  proposal: .unspecified)
        }
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> (size: CGSize, origins: [CGPoint]) {
        var origins: [CGPoint] = []
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, maxX: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            origins.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            maxX = max(maxX, x - spacing)
        }
        return (CGSize(width: maxX, height: y + rowHeight), origins)
    }
}

private struct ClipButton: View {
    enum Style { case filled, outlined }
    let title: String
    var icon: String?
    let style: Style
    let id: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let icon { Image(systemName: icon).font(.system(size: 17, weight: .semibold)) }
                Text(title).font(ShareFont.body(17, weight: .semibold))
            }
            .foregroundColor(style == .filled ? .white : ShareColor.textPrimary)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(RoundedRectangle(cornerRadius: 14).fill(style == .filled ? ShareColor.brown : Color.white.opacity(0.6)))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(ShareColor.border, lineWidth: style == .filled ? 0 : 1.5))
        }
        .accessibilityIdentifier(id)
    }
}

private struct PreviewCardView: View {
    @ObservedObject var model: ClipFlowModel
    @State private var showNewCollection = false
    @State private var newCollectionName = ""
    @State private var showLibrary = false
    #if !SPHIR_SHARE_EXTENSION
    @State private var showCamera = false
    #endif
    let onCrop: (() -> Void)?
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ClipHeader {
                Button(action: onCancel) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(ShareColor.brown)
                        .frame(width: 44, height: 32, alignment: .leading)
                }
                .accessibilityLabel("Cancel")
                .accessibilityIdentifier("clipCancelButton")
            } trailing: {
                if let onCrop {
                    Menu {
                        Button { onCrop() } label: { Label("Crop or extract text…", systemImage: "crop") }
                        Button(role: .cancel, action: onCancel) { Text("Cancel") }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(ShareColor.brown)
                            .frame(width: 44, height: 32, alignment: .trailing)
                    }
                    .accessibilityLabel("More")
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 10)

            if model.phase == .loading {
                loading
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        notices
                        card
                        collectionChips
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 6)
                    .padding(.bottom, 12)
                }
            }

            saveButton
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 20)
        }
    }

    private var loading: some View {
        VStack(spacing: 10) {
            Spacer(minLength: 0)
            ProgressView().controlSize(.large).tint(ShareColor.brown)
            Text("Pulling content into card...")
                .font(ShareFont.body(18, weight: .bold)).foregroundColor(ShareColor.textPrimary)
            Text("Extracting the title, summary, and key details with AI...")
                .font(ShareFont.body(14)).foregroundColor(ShareColor.mutedText)
                .multilineTextAlignment(.center)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder private var notices: some View {
        if let saved = model.alreadyOnSphir {
            Label(saved.notice, systemImage: "person.2.fill")
                .accessibilityIdentifier("clipAlreadyOnSphir")
                .font(ShareFont.body(13, weight: .semibold))
                .foregroundColor(ShareColor.textPrimary)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Capsule().fill(Color.white))
                .overlay(Capsule().stroke(ShareColor.border, lineWidth: 1))
        }
        if let banner = model.banner {
            Text(banner)
                .font(ShareFont.body(13, weight: .semibold))
                .foregroundColor(ShareColor.textPrimary)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Capsule().fill(Color.white))
                .overlay(Capsule().stroke(ShareColor.border, lineWidth: 1))
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 12) {
            CoverView(urlString: model.draft.imageURL, data: model.coverData, type: model.draft.type)
                .overlay(alignment: .bottomTrailing) { imageButton }

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
                .font(ShareFont.body(22, weight: .bold))
                .foregroundColor(ShareColor.textPrimary)
                .lineLimit(1...4)

            if model.showsPrice {
                TextField("Price", text: $model.draft.price)
                    .accessibilityIdentifier("clipPrice")
                    .font(ShareFont.body(20, weight: .bold))
                    .foregroundColor(ShareColor.textPrimary)
            }

            TextField("Description", text: $model.draft.description, axis: .vertical)
                .font(ShareFont.body(15))
                .foregroundColor(ShareColor.textPrimary)
                .lineLimit(1...6)

            if !model.draft.sourceLine.isEmpty || !model.draft.tags.isEmpty {
                Divider().overlay(ShareColor.border)
            }

            if !model.draft.sourceLine.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "link").font(.system(size: 14)).frame(width: 18)
                    Text("Source").font(ShareFont.body(14, weight: .semibold))
                    Text(model.draft.sourceLine).font(ShareFont.body(14)).foregroundColor(ShareColor.mutedText).lineLimit(1)
                    Spacer(minLength: 0)
                }
                .foregroundColor(ShareColor.textPrimary)
            }

            if !model.draft.tags.isEmpty {
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: "tag").font(.system(size: 14)).frame(width: 18)
                    Text("Tags").font(ShareFont.body(14, weight: .semibold))
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(model.draft.tags, id: \.self) { tag in
                                Text(tag)
                                    .font(ShareFont.body(13, weight: .medium))
                                    .foregroundColor(ShareColor.textPrimary)
                                    .padding(.horizontal, 12).padding(.vertical, 6)
                                    .background(Capsule().fill(ShareColor.background))
                            }
                        }
                    }
                }
                .foregroundColor(ShareColor.textPrimary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color.white))
        .shadow(color: Color.black.opacity(0.08), radius: 10, y: 4)
    }

    private var hasImage: Bool { model.coverData != nil || model.draft.imageURL != nil }

    /// "Add image" / "Change image" over the cover: photo library, plus "Take photo" in the
    /// app (share extensions cannot use the camera; SPHIR_SHARE_EXTENSION is set for that target).
    private var imageButton: some View {
        let title = hasImage ? "Change image" : "Add image"
        let label = Label(title, systemImage: "photo.badge.plus")
            .font(ShareFont.body(13, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Capsule().fill(Color.black.opacity(0.6)))
            .padding(10)
        return imageSources(label)
            .accessibilityIdentifier("clipImageButton")
            .accessibilityLabel(title)
            .sheet(isPresented: $showLibrary) {
                PhotoPicker(onPick: { data in model.pickImage(data); showLibrary = false },
                            onCancel: { showLibrary = false })
            }
            #if !SPHIR_SHARE_EXTENSION
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker(
                    onCapture: { image, _ in
                        if let data = image.jpegData(compressionQuality: 0.9) { model.pickImage(data) }
                        showCamera = false
                    },
                    onCancel: { showCamera = false })
                    .ignoresSafeArea()
            }
            #endif
    }

    @ViewBuilder private func imageSources<L: View>(_ label: L) -> some View {
        #if SPHIR_SHARE_EXTENSION
        Button { showLibrary = true } label: { label }
        #else
        if CameraPicker.isAvailable {
            Menu {
                Button { showLibrary = true } label: { Label("Choose from library", systemImage: "photo.on.rectangle") }
                Button { showCamera = true } label: { Label("Take photo", systemImage: "camera") }
            } label: { label }
        } else {
            Button { showLibrary = true } label: { label }
        }
        #endif
    }

    private var collectionChips: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Add to Collections", systemImage: "square.stack.3d.up")
                .font(ShareFont.body(16, weight: .semibold))
                .foregroundColor(ShareColor.textPrimary)
            ChipFlowLayout(spacing: 8) {
                ForEach(model.collections) { col in chip(col) }
                newCollectionChip
            }
            if let error = model.collectionError {
                Text(error)
                    .font(ShareFont.body(13))
                    .foregroundColor(.red)
                    .accessibilityIdentifier("clipNewCollectionError")
            }
        }
        .padding(.top, 4)
        .alert("New collection", isPresented: $showNewCollection) {
            TextField("Collection name", text: $newCollectionName)
            Button("Cancel", role: .cancel) { newCollectionName = "" }
            Button("Create") {
                let name = newCollectionName
                newCollectionName = ""
                Task { await model.createCollection(named: name) }
            }
        }
    }

    private var newCollectionChip: some View {
        Button { showNewCollection = true } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus").font(.system(size: 12, weight: .bold))
                Text("New collection").font(ShareFont.body(15, weight: .medium)).lineLimit(1)
            }
            .foregroundColor(ShareColor.textPrimary)
            .padding(.horizontal, 16).padding(.vertical, 10)
            .overlay(Capsule().stroke(ShareColor.taupe.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])))
        }
        .accessibilityIdentifier("clipNewCollectionChip")
    }

    private func chip(_ col: ClipCollection) -> some View {
        let on = model.isSelected(col)
        return Button { model.toggle(col) } label: {
            HStack(spacing: 6) {
                if on { Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)) }
                Text(col.name).font(ShareFont.body(15, weight: on ? .semibold : .medium)).lineLimit(1)
            }
            .foregroundColor(on ? .white : ShareColor.textPrimary)
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(Capsule().fill(on ? ShareColor.brown : Color.clear))
            .overlay(Capsule().stroke(on ? ShareColor.brown : ShareColor.taupe.opacity(0.5), lineWidth: 1.5))
        }
        .accessibilityIdentifier("clipCollectionChip_\(col.name)")
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private var saveButton: some View {
        Button {
            Task { await model.save() }
        } label: {
            Group {
                if model.phase == .saving { ProgressView().tint(.white) }
                else { Text("Save Card").font(ShareFont.body(17, weight: .bold)) }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(RoundedRectangle(cornerRadius: 16).fill(ShareColor.brown.opacity(model.phase == .preview ? 1 : 0.6)))
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
                    else { placeholder(showsLogo: phase.error != nil) }
                }
            } else {
                placeholder()
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 190)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    /// A link without an image shows the Sphir logo; while an image loads the cover stays plain.
    private func placeholder(showsLogo: Bool = true) -> some View {
        ZStack {
            ShareColor.background
            if showsLogo {
                Image("SphirLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 200)
                    .padding(.horizontal, 40)
                    .accessibilityLabel("Sphir")
                    .accessibilityIdentifier("clipCoverPlaceholderLogo")
            }
        }
    }
}

private struct SavedCardView: View {
    @ObservedObject var model: ClipFlowModel
    let onView: (String?) -> Void
    let onViewCollection: (String) -> Void
    let onClipAnother: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ClipHeader { Color.clear } trailing: { Color.clear }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 10)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    ZStack {
                        Circle().fill(ShareColor.sageLight).frame(width: 104, height: 104)
                        Image(systemName: "checkmark").font(.system(size: 44, weight: .semibold)).foregroundColor(ShareColor.sage)
                    }
                    .padding(.top, 28)
                    .accessibilityHidden(true)

                    Text("Successfully clipped")
                        .font(ShareFont.heading(30)).foregroundColor(ShareColor.textPrimary)
                        .accessibilityIdentifier("cardSavedTitle")

                    Text(model.queuedMessage ?? "Your card has been created and saved to Sphir.")
                        .font(ShareFont.body(16)).foregroundColor(ShareColor.mutedText)
                        .multilineTextAlignment(.center)
                    if let error = model.folderError {
                        Text(error)
                            .font(ShareFont.body(14, weight: .semibold)).foregroundColor(ShareColor.textPrimary)
                            .multilineTextAlignment(.center)
                            .accessibilityIdentifier("clipFolderError")
                    }
                    if let banner = model.banner {
                        Text(banner).font(ShareFont.body(13, weight: .semibold)).foregroundColor(ShareColor.taupe)
                            .multilineTextAlignment(.center)
                    }

                    VStack(spacing: 12) {
                        ClipButton(title: "View Card", icon: "arrow.up.forward.app", style: .filled,
                                   id: "viewSavedCardButton") { onView(model.viewCardID) }
                        if let collectionID = model.viewCollectionID {
                            ClipButton(title: "View Collection(s)", icon: "square.stack.3d.up", style: .outlined,
                                       id: "viewCollectionButton") { onViewCollection(collectionID) }
                        }
                        ClipButton(title: "Clip Another", icon: "plus", style: .outlined,
                                   id: "clipAnotherButton", action: onClipAnother)
                        ClipButton(title: "Close", icon: nil, style: .outlined,
                                   id: "closeClipButton", action: onDismiss)
                    }
                    .padding(.top, 14)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
    }
}
