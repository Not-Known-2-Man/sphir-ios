//
//  ShareView.swift
//  SphirShare
//
//  "Save to Sphir" share sheet. Handles the complete Figma prototype flow:
//   - Snippet Options Sheet (What do you want to snip?)
//   - Crop Tool (Extract specific part)
//   - Metadata Extraction Sheet (Animated scanning & staggered reveal)
//   - Success Screen (Spring checkmark, collection selector, auto-dismiss)
//

import SwiftUI
import WebKit

enum ExtensionScreen {
    case options
    case crop
    case extraction
    case success
}

struct SharedContent {
    var urlString: String?
    var text: String?
    var sharedImageData: Data?
    /// Cleaned <head> + JSON-LD of the page Safari already loaded (ClipPreprocess.js).
    var pageHTML: String?

    var isLink: Bool { !(urlString ?? "").isEmpty }
    var isImage: Bool { sharedImageData != nil }
}

struct SharePayload {
    let collectionID: UUID?
    let title: String
    let description: String
    let urlString: String?
    let bodyText: String?
    let imageData: Data?
    let tags: [String]
}

struct ShareView: View {
    let content: SharedContent
    let collections: [SharedCollectionDTO]
    let onSave: (SharePayload) -> UUID
    let onUpdateCollection: (UUID, UUID?) -> Void
    let onScreenChange: (ExtensionScreen) -> Void
    let onView: (UUID) -> Void
    let onDismiss: () -> Void
    let onCancel: () -> Void

    // View State Machine
    @State private var currentScreen: ExtensionScreen = .options
    @State private var snipType: String = "Whole page"

    // Metadata & Form Data
    @State private var selectedCollectionID: UUID?
    @State private var title: String = ""
    @State private var descriptionText: String = ""
    @State private var imageData: Data?
    @State private var tags: [String] = []
    
    // Extraction states
    @State private var isLoadingMetadata = false
    @State private var extractionPhase = 0
    @State private var scanOffset: CGFloat = -40

    // Success & Dismiss state
    @State private var savedCardID: UUID?
    /// Real time from opening the share sheet to saving, shown on success.
    @State private var startedAt = Date()
    @State private var elapsedSeconds = 0
    @State private var checkmarkScale: CGFloat = 0.3
    @State private var circlePulse: CGFloat = 1.0
    @State private var countdownRemaining = 3
    @State private var countdownActive = true

    // Crop interaction state
    @State private var cropWidth: CGFloat = 280
    @State private var cropHeight: CGFloat = 200
    @State private var cropOffset: CGSize = .zero
    @State private var dragStartSize: CGSize = CGSize(width: 280, height: 200)
    @State private var dragStartOffset: CGSize = .zero
    @State private var webViewInstance: WKWebView? = nil

    private var selectedCollection: SharedCollectionDTO? {
        collections.first { $0.id == selectedCollectionID }
    }

    var body: some View {
        ZStack {
            // Dark Backdrop - high opacity hides the system Share Sheet on non-crop screens
            Color.black.opacity(currentScreen == .crop ? 0.0 : 0.85)
                .ignoresSafeArea()
                .onTapGesture {
                    if currentScreen == .options {
                        onCancel()
                    } else if currentScreen == .success {
                        // Success screen backdrop tap doesn't dismiss
                    } else {
                        changeScreen(to: .options)
                    }
                }

            switch currentScreen {
            case .options:
                optionsSheet
                    .transition(.move(edge: .bottom))
            case .crop:
                cropToolView
                    .transition(.opacity)
            case .extraction:
                extractionSheet
                    .transition(.move(edge: .bottom))
            case .success:
                successView
                    .transition(.move(edge: .bottom))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: currentScreen)
        .onAppear {
            if selectedCollectionID == nil {
                selectedCollectionID = collections.first?.id
            }
            // Seed initial tags
            if content.isLink {
                // iOS does not tell the extension which app shared the link.
                tags = ["Web Link"]
            } else if content.isImage {
                tags = ["Image"]
            } else {
                tags = ["Text"]
            }
            
            // Start loading the crop tool's content now, while the user picks
            // an option.
            if webViewInstance == nil {
                webViewInstance = WebView.makeWebView(content: content)
            }

            // Pre-fetch webpage metadata in background
            if content.isLink, let urlString = content.urlString {
                Task {
                    let metadata = await MetadataService.fetch(urlString: urlString)
                    if currentScreen == .options || currentScreen == .crop {
                        if let fetchedTitle = metadata?.title, !fetchedTitle.isEmpty {
                            title = fetchedTitle
                        }
                        if let fetchedDescription = metadata?.description {
                            descriptionText = fetchedDescription
                        }
                        if snipType != "Cropped region" {
                            imageData = metadata?.imageData
                        }
                    }
                }
            }
        }
    }

    // MARK: - 1. Options Sheet
    private var optionsSheet: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 16) {
                // Drag Handle
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(red: 216/255, green: 207/255, blue: 194/255))
                    .frame(width: 36, height: 4)
                    .padding(.top, 10)

                // Header
                HStack(spacing: 8) {
                    Image("SphirLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 20)
                        .accessibilityLabel("Sphir")
                    Text("snippet")
                        .font(ShareFont.body(12, weight: .bold))
                        .foregroundColor(ShareColor.textPrimary)
                    
                    Spacer()
                    
                    // Time Badge
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 8))
                        Text("~15 sec")
                            .font(ShareFont.body(10, weight: .bold))
                    }
                    .foregroundColor(ShareColor.taupe)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(ShareColor.background))
                }
                .padding(.horizontal, 20)

                // Context Info
                VStack(alignment: .leading, spacing: 4) {
                    if content.isImage {
                        Text("Received screenshot from iOS")
                            .font(ShareFont.body(12))
                            .foregroundColor(ShareColor.mutedText)
                        Text("Image capture data")
                            .font(ShareFont.body(11))
                            .foregroundColor(ShareColor.mutedText)
                    } else if content.isLink {
                        Text("Received link")
                            .font(ShareFont.body(12))
                            .foregroundColor(ShareColor.mutedText)
                        Text("URL: \(content.urlString ?? "")")
                            .font(ShareFont.body(11))
                            .foregroundColor(ShareColor.mutedText)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    } else {
                        Text("Received text content")
                            .font(ShareFont.body(12))
                            .foregroundColor(ShareColor.mutedText)
                        Text("Text clip (\(content.text?.count ?? 0) chars)")
                            .font(ShareFont.body(11))
                            .foregroundColor(ShareColor.mutedText)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)

                // Collection selector on the first screen
                HStack(spacing: 8) {
                    Text("Save to:")
                        .font(ShareFont.body(12))
                        .foregroundColor(ShareColor.mutedText)
                    
                    Menu {
                        ForEach(collections) { col in
                            Button {
                                selectedCollectionID = col.id
                            } label: {
                                Text(col.name)
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(selectedCollection?.name ?? "Select collection")
                                .font(ShareFont.body(12, weight: .bold))
                                .foregroundColor(ShareColor.taupe)
                                .underline()
                            Image(systemName: "chevron.down")
                                .font(.system(size: 8))
                                .foregroundColor(ShareColor.taupe)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity, alignment: .leading)

                // Separator
                Text(content.isImage ? "How do you want to snip it?" : "What do you want to snip?")
                    .font(ShareFont.body(13, weight: .bold))
                    .foregroundColor(ShareColor.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)

                // Options List
                VStack(spacing: 8) {
                    if content.isImage {
                        optionRow(icon: "📸", title: "Save whole screenshot", sub: "Full capture, all metadata") {
                            snipType = "Whole screenshot"
                            self.imageData = content.sharedImageData
                            self.title = "Screenshot"
                            startExtraction()
                        }

                        optionRow(icon: "⊡", title: "Select area", sub: "Crop a specific region", highlighted: true) {
                            snipType = "Cropped screenshot"
                            self.imageData = content.sharedImageData
                            changeScreen(to: .crop)
                        }

                        optionRow(icon: "🔤", title: "Extract text (OCR)", sub: "Auto-detects text in image") {
                            snipType = "Extract text (OCR)"
                            self.title = "Extracted Text"
                            self.imageData = content.sharedImageData
                            startExtraction()
                        }
                    } else {
                        optionRow(icon: "📄", title: "Whole page", sub: "URL, title, and cover image") {
                            snipType = "Whole page"
                            startExtraction()
                        }

                        optionRow(icon: "🖼️", title: "Just the image", sub: "Grab the hero graphic") {
                            snipType = "Just the image"
                            startExtraction()
                        }

                        optionRow(icon: "❝", title: "The content", sub: "Snip visible text into a card") {
                            snipType = "The content"
                            startExtraction()
                        }

                        optionRow(icon: "⊡", title: "Extract specific part", sub: "Choose which part to save", highlighted: true) {
                            changeScreen(to: .crop)
                        }
                    }
                }
                .padding(.horizontal, 20)

                // Cancel Button
                Button(action: onCancel) {
                    Text("Cancel")
                        .font(ShareFont.body(15, weight: .semibold))
                        .foregroundColor(ShareColor.mutedText)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                }
                .padding(.bottom, 24)
            }
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(ShareColor.background)
            )
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private func optionRow(icon: String, title: String, sub: String, highlighted: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(icon)
                    .font(.system(size: 18))
                    .frame(width: 38, height: 38)
                    .background(highlighted ? ShareColor.taupe : ShareColor.background)
                    .foregroundColor(highlighted ? .white : ShareColor.textPrimary)
                    .cornerRadius(10)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(ShareFont.body(13, weight: .bold))
                        .foregroundColor(ShareColor.textPrimary)
                    Text(sub)
                        .font(ShareFont.body(11))
                        .foregroundColor(ShareColor.mutedText)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(ShareColor.border)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(highlighted ? ShareColor.taupe : ShareColor.border, lineWidth: highlighted ? 2 : 1)
            )
            .shadow(color: Color.black.opacity(0.03), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 2. Crop Tool
    private var cropToolView: some View {
        GeometryReader { geo in
            let x = (geo.size.width - cropWidth) / 2 + cropOffset.width
            let y = (geo.size.height - cropHeight) / 2 + cropOffset.height
            let cutoutRect = CGRect(x: x, y: y, width: cropWidth, height: cropHeight)

            ZStack {
                // Interactive WebView in the background (renders webpage, text, or image dynamically)
                WebView(content: content, webViewRef: $webViewInstance)
                    .ignoresSafeArea()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)

                // Cutout dark overlay - dims the background image outside the crop bounds
                CutoutShape(cutoutRect: cutoutRect)
                    .fill(Color.black.opacity(0.55), style: FillStyle(eoFill: true))
                    .ignoresSafeArea()
                    .allowsHitTesting(false) // Allows touch events to pass through to scroll/pan webpage

                // Outline bounding box
                RoundedRectangle(cornerRadius: 8)
                    .stroke(ShareColor.taupe, lineWidth: 2)
                    .frame(width: cropWidth, height: cropHeight)
                    .position(x: geo.size.width / 2 + cropOffset.width, y: geo.size.height / 2 + cropOffset.height)
                    .allowsHitTesting(false) // Allows touch events to pass through to scroll/pan webpage

                // Translucent container inside the crop box to drag the entire frame around
                Color.white.opacity(0.01)
                    .frame(width: max(10, cropWidth - 20), height: max(10, cropHeight - 20))
                    .position(x: geo.size.width / 2 + cropOffset.width, y: geo.size.height / 2 + cropOffset.height)
                    .gesture(
                        DragGesture()
                            .onChanged { val in
                                cropOffset = CGSize(
                                    width: dragStartOffset.width + val.translation.width,
                                    height: dragStartOffset.height + val.translation.height
                                )
                            }
                            .onEnded { _ in
                                dragStartOffset = cropOffset
                            }
                    )

                // Bounding handles with resize drag gestures
                Group {
                    // Top-Left Handle
                    cornerHandle()
                        .position(x: x, y: y)
                        .gesture(
                            DragGesture()
                                .onChanged { val in
                                    let newWidth = max(100, dragStartSize.width - val.translation.width)
                                    let newHeight = max(80, dragStartSize.height - val.translation.height)
                                    let widthDiff = newWidth - cropWidth
                                    let heightDiff = newHeight - cropHeight
                                    cropWidth = newWidth
                                    cropHeight = newHeight
                                    cropOffset = CGSize(
                                        width: dragStartOffset.width - widthDiff / 2,
                                        height: dragStartOffset.height - heightDiff / 2
                                    )
                                }
                                .onEnded { _ in
                                    dragStartSize = CGSize(width: cropWidth, height: cropHeight)
                                    dragStartOffset = cropOffset
                                }
                        )

                    // Top-Right Handle
                    cornerHandle()
                        .position(x: x + cropWidth, y: y)
                        .gesture(
                            DragGesture()
                                .onChanged { val in
                                    let newWidth = max(100, dragStartSize.width + val.translation.width)
                                    let newHeight = max(80, dragStartSize.height - val.translation.height)
                                    let heightDiff = newHeight - cropHeight
                                    cropWidth = newWidth
                                    cropHeight = newHeight
                                    cropOffset = CGSize(
                                        width: dragStartOffset.width + (newWidth - dragStartSize.width) / 2,
                                        height: dragStartOffset.height - heightDiff / 2
                                    )
                                }
                                .onEnded { _ in
                                    dragStartSize = CGSize(width: cropWidth, height: cropHeight)
                                    dragStartOffset = cropOffset
                                }
                        )

                    // Bottom-Left Handle
                    cornerHandle()
                        .position(x: x, y: y + cropHeight)
                        .gesture(
                            DragGesture()
                                .onChanged { val in
                                    let newWidth = max(100, dragStartSize.width - val.translation.width)
                                    let newHeight = max(80, dragStartSize.height + val.translation.height)
                                    let widthDiff = newWidth - cropWidth
                                    cropWidth = newWidth
                                    cropHeight = newHeight
                                    cropOffset = CGSize(
                                        width: dragStartOffset.width - widthDiff / 2,
                                        height: dragStartOffset.height + (newHeight - dragStartSize.height) / 2
                                    )
                                }
                                .onEnded { _ in
                                    dragStartSize = CGSize(width: cropWidth, height: cropHeight)
                                    dragStartOffset = cropOffset
                                }
                        )

                    // Bottom-Right Handle
                    cornerHandle()
                        .position(x: x + cropWidth, y: y + cropHeight)
                        .gesture(
                            DragGesture()
                                .onChanged { val in
                                    let newWidth = max(100, dragStartSize.width + val.translation.width)
                                    let newHeight = max(80, dragStartSize.height + val.translation.height)
                                    cropWidth = newWidth
                                    cropHeight = newHeight
                                    cropOffset = CGSize(
                                        width: dragStartOffset.width + (newWidth - dragStartSize.width) / 2,
                                        height: dragStartOffset.height + (newHeight - dragStartSize.height) / 2
                                    )
                                }
                                .onEnded { _ in
                                    dragStartSize = CGSize(width: cropWidth, height: cropHeight)
                                    dragStartOffset = cropOffset
                                }
                        )
                }

                // Controls and buttons overlay
                VStack(spacing: 0) {
                    // Top Bar
                    HStack {
                        Button {
                            changeScreen(to: .options)
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                                .padding(8)
                        }

                        Spacer()

                        HStack(spacing: 6) {
                            Image("SphirMarkWhite")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 22, height: 22)
                            Text("Sphir snippet")
                                .font(ShareFont.body(14, weight: .bold))
                                .foregroundColor(.white)
                        }

                        Spacer()

                        Image(systemName: "ellipsis")
                            .foregroundColor(.white)
                            .padding(8)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 12)
                    .background(Color(red: 42/255, green: 40/255, blue: 37/255))

                    Spacer()

                    // Drag Indicator badge
                    Text("⊡ Drag to adjust")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(ShareColor.taupe.opacity(0.95))
                        .cornerRadius(14)
                        .padding(.bottom, 20)
                        .position(x: geo.size.width / 2 + cropOffset.width, y: geo.size.height / 2 + cropOffset.height + cropHeight / 2 + 25)

                    Spacer()

                    // Mode Selector
                    HStack(spacing: 20) {
                        Text("Auto")
                            .font(ShareFont.body(11, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(ShareColor.taupe)
                            .cornerRadius(8)
                        
                        Text("Image")
                        Text("Text")
                        Text("Free")
                    }
                    .font(ShareFont.body(11))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(4)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(10)
                    .padding(.bottom, 24)

                    // Bottom Actions Bar
                    HStack {
                        Button {
                            changeScreen(to: .options)
                        } label: {
                            Text("Cancel")
                                .font(ShareFont.body(14))
                                .foregroundColor(ShareColor.mutedText)
                                .padding(.vertical, 8)
                        }
                        .padding(.leading, 22)

                        Spacer()

                        Text("\(Int(cropWidth)) × \(Int(cropHeight)) px")
                            .font(ShareFont.body(12))
                            .foregroundColor(ShareColor.mutedText)

                        Spacer()

                        Button {
                            snipType = "Cropped region"
                            if let webView = webViewInstance {
                                let config = WKSnapshotConfiguration()
                                config.rect = cutoutRect
                                webView.takeSnapshot(with: config) { image, error in
                                    if let image = image, let data = image.jpegData(compressionQuality: 0.8) {
                                        self.imageData = data
                                    }
                                    startExtraction()
                                }
                            } else {
                                startExtraction()
                            }
                        } label: {
                            Text("Snip it")
                                .font(ShareFont.body(14, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 8)
                                .background(ShareColor.taupe)
                                .cornerRadius(10)
                        }
                        .padding(.trailing, 20)
                    }
                    .frame(height: 70)
                    .background(Color(red: 42/255, green: 40/255, blue: 37/255))
                }
            }
        }
    }

    private func cornerHandle() -> some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(Color.white)
            .frame(width: 14, height: 14)
            .overlay(RoundedRectangle(cornerRadius: 2).stroke(ShareColor.taupe, lineWidth: 2))
    }

    // MARK: - 3. Extraction & Scanning Sheet
    private var extractionSheet: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 14) {
                // Drag Handle
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(red: 216/255, green: 207/255, blue: 194/255))
                    .frame(width: 36, height: 4)
                    .padding(.top, 10)

                // Header
                HStack(spacing: 8) {
                    Image("SphirMark")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                    Text("Sphir snippet")
                        .font(ShareFont.heading(15, weight: .bold))
                        .foregroundColor(ShareColor.taupe)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill").font(.system(size: 8))
                        Text("~15 sec").font(ShareFont.body(10, weight: .bold))
                    }
                    .foregroundColor(ShareColor.taupe)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(ShareColor.background))
                }
                .padding(.horizontal, 20)

                // Loading Title
                HStack {
                    Text(extractionPhase == 5 ? "✓ Ready to save" : "Extracting metadata...")
                        .font(ShareFont.body(12, weight: .bold))
                        .foregroundColor(extractionPhase == 5 ? Color.green : ShareColor.mutedText)
                    Spacer()
                }
                .padding(.horizontal, 20)

                // Animated Scan Line
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(ShareColor.border)
                        .frame(height: 3)
                    
                    if extractionPhase < 5 {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(ShareColor.taupe)
                            .frame(width: 80, height: 3)
                            .opacity(0.8)
                            .offset(x: scanOffset)
                            .onAppear {
                                withAnimation(Animation.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                                    scanOffset = 270
                                }
                            }
                    }
                }
                .frame(width: 350)
                .padding(.horizontal, 20)

                // Card Preview Block (Light gradient)
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(red: 184/255, green: 207/255, blue: 232/255))
                            .frame(width: 80, height: 80)
                        
                        if let imageData, let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else {
                            Text(snipType == "Just the image" ? "🖼️" : "📄")
                                .font(.system(size: 24))
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title.isEmpty ? "Extracting..." : title)
                            .font(ShareFont.body(13, weight: .bold))
                            .foregroundColor(ShareColor.textPrimary)
                            .lineLimit(1)
                        Text(content.urlString ?? "")
                            .font(ShareFont.body(10))
                            .foregroundColor(ShareColor.mutedText)
                            .lineLimit(1)
                        Text(descriptionText.isEmpty ? "Reading page content..." : descriptionText)
                            .font(ShareFont.body(11))
                            .foregroundColor(Color(red: 90/255, green: 84/255, blue: 76/255))
                            .lineLimit(2)
                    }
                    Spacer()
                }
                .padding(12)
                .background(LinearGradient(gradient: Gradient(colors: [Color(red: 200/255, green: 223/255, blue: 240/255), Color(red: 232/255, green: 242/255, blue: 250/255)]), startPoint: .topLeading, endPoint: .bottomTrailing))
                .cornerRadius(12)
                .padding(.horizontal, 20)

                // Extracted Fields Staggered List
                ScrollView {
                    VStack(spacing: 6) {
                        fieldRow(label: "URL", value: content.urlString ?? (isLoadingMetadata ? "" : "None (not a web page)"), index: 1)
                        fieldRow(label: "TITLE", value: title, index: 2)
                        fieldRow(label: "COVER", value: imageData != nil ? "Cover loaded" : "No cover", index: 3)
                        fieldRow(label: "DESCRIPTION", value: descriptionText, index: 4)
                        fieldRow(label: "TYPE", value: snipType, index: 5)
                    }
                }
                .frame(maxHeight: 180)
                .padding(.horizontal, 20)

                // Tags Section
                VStack(alignment: .leading, spacing: 6) {
                    Text("TAGS")
                        .font(ShareFont.body(10, weight: .bold))
                        .foregroundColor(ShareColor.mutedText)
                    
                    HStack(spacing: 6) {
                        ForEach(tags, id: \.self) { tag in
                            HStack(spacing: 4) {
                                Text(tag)
                                Button {
                                    tags.removeAll { $0 == tag }
                                } label: {
                                    Text("×").font(.system(size: 14, weight: .bold))
                                }
                            }
                            .font(ShareFont.body(12))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color(red: 240/255, green: 237/255, blue: 232/255))
                            .cornerRadius(14)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)

                // Collection selector
                VStack(alignment: .leading, spacing: 6) {
                    Text("SAVE TO COLLECTION")
                        .font(ShareFont.body(10, weight: .bold))
                        .foregroundColor(ShareColor.mutedText)
                    
                    Menu {
                        ForEach(collections) { col in
                            Button {
                                selectedCollectionID = col.id
                            } label: {
                                Text(col.name)
                            }
                        }
                    } label: {
                        HStack {
                            Text(selectedCollection?.name ?? "Select collection")
                                .font(ShareFont.body(13, weight: .bold))
                                .foregroundColor(ShareColor.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.system(size: 12))
                                .foregroundColor(ShareColor.taupe)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(ShareColor.cardBackgroundAlt)
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(ShareColor.border, lineWidth: 1))
                    }
                }
                .padding(.horizontal, 20)

                // Bottom Save Action
                Button {
                    performSave()
                } label: {
                    Text("Save and send to Sphir")
                        .font(ShareFont.body(14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(ShareColor.taupe)
                        .cornerRadius(25)
                        .opacity(extractionPhase == 5 ? 1.0 : 0.45)
                        .shadow(color: ShareColor.taupe.opacity(extractionPhase == 5 ? 0.35 : 0.0), radius: 10, y: 4)
                }
                .disabled(extractionPhase < 5)
                .padding(.horizontal, 20)
                .padding(.top, 4)

                // Cancel Button
                Button {
                    changeScreen(to: .options)
                } label: {
                    Text("Cancel")
                        .font(ShareFont.body(13))
                        .foregroundColor(ShareColor.mutedText)
                        .padding(.vertical, 8)
                }
                .padding(.bottom, 24)
            }
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white)
            )
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private func fieldRow(label: String, value: String, index: Int) -> some View {
        Group {
            if extractionPhase >= index {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(label)
                            .font(ShareFont.body(9, weight: .bold))
                            .foregroundColor(ShareColor.mutedText)
                        Text(value.isEmpty ? (isLoadingMetadata ? "Scanning..." : "None") : value)
                            .font(ShareFont.body(11))
                            .foregroundColor(ShareColor.textPrimary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        Text("AUTO")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.green)
                            .cornerRadius(4)
                        
                        Text("✎")
                            .font(.system(size: 11))
                            .foregroundColor(ShareColor.mutedText)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(ShareColor.cardBackgroundAlt)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(ShareColor.border, lineWidth: 1))
                .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))
            }
        }
    }

    // MARK: - 4. Success View
    private var successView: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 20) {
                // Spring checkmark circle with gentle pulse animation
                ZStack {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 72, height: 72)
                        .scaleEffect(checkmarkScale)
                        .scaleEffect(circlePulse)
                        .shadow(color: Color.green.opacity(0.35), radius: 14, y: 6)
                    
                    Text("✓")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(.white)
                        .scaleEffect(checkmarkScale)
                }
                .onAppear {
                    // Spring bounce checkmark
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.6, blendDuration: 0)) {
                        checkmarkScale = 1.0
                    }
                    // Gentle pulse loop
                    withAnimation(Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                        circlePulse = 1.05
                    }
                }
                
                VStack(spacing: 6) {
                    Text("Snipped!")
                        .font(ShareFont.heading(20, weight: .bold))
                        .foregroundColor(ShareColor.textPrimary)
                    
                    HStack(spacing: 4) {
                        Text("Saved to")
                        
                        // Interactive Collection Menu
                        Menu {
                            ForEach(collections) { col in
                                Button {
                                    // Change the collection ID
                                    selectedCollectionID = col.id
                                    if let id = savedCardID {
                                        onUpdateCollection(id, col.id)
                                    }
                                    // Cancel auto-dismiss so they can review
                                    countdownActive = false
                                } label: {
                                    Text(col.name)
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(selectedCollection?.name ?? "Sphir")
                                    .fontWeight(.bold)
                                    .underline()
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 9))
                            }
                            .foregroundColor(ShareColor.taupe)
                        }
                    }
                    .font(ShareFont.body(13))
                    .foregroundColor(ShareColor.mutedText)
                }
                
                // Done Speed Badge
                HStack(spacing: 4) {
                    Image(systemName: "bolt.fill").font(.system(size: 10))
                    Text("Done in \(elapsedSeconds) second\(elapsedSeconds == 1 ? "" : "s")")
                        .font(ShareFont.body(11, weight: .bold))
                }
                .foregroundColor(ShareColor.taupe)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(Capsule().fill(ShareColor.background))

                // Saved Card Preview Block
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(red: 184/255, green: 207/255, blue: 232/255))
                            .frame(width: 52, height: 52)
                        if let imageData, let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 52, height: 52)
                                .cornerRadius(10)
                        } else {
                            Text("📄").font(.system(size: 20))
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title.isEmpty ? "New Card" : title)
                            .font(ShareFont.body(13, weight: .bold))
                            .foregroundColor(ShareColor.textPrimary)
                            .lineLimit(1)
                        Text(content.urlString ?? snipType)
                            .font(ShareFont.body(11))
                            .foregroundColor(ShareColor.mutedText)
                            .lineLimit(1)
                    }
                    Spacer()
                }
                .padding(12)
                .background(Color.white)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(ShareColor.border, lineWidth: 1))
                .padding(.horizontal, 20)
                
                // Action Buttons
                VStack(spacing: 8) {
                    // Auto-dismiss countdown / Done button
                    Button {
                        onDismiss()
                    } label: {
                        Text(countdownActive ? "Done (closing in \(countdownRemaining)s)" : "Done")
                            .font(ShareFont.body(14, weight: .semibold))
                            .foregroundColor(ShareColor.taupe)
                            .padding(.vertical, 8)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .padding(.top, 24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(ShareColor.background)
            )
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .onAppear {
            startDismissCountdown()
        }
    }

    private func startDismissCountdown() {
        Task {
            while countdownRemaining > 0 && countdownActive {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if countdownActive {
                    countdownRemaining -= 1
                }
            }
            if countdownActive {
                onDismiss()
            }
        }
    }

    // MARK: - Controller Integration Helpers
    private func changeScreen(to screen: ExtensionScreen) {
        currentScreen = screen
        onScreenChange(screen)
    }

    private func startExtraction() {
        changeScreen(to: .extraction)
        isLoadingMetadata = true
        
        Task {
            // Shared images (whole, cropped or OCR): read their text on-device
            // with Vision so the card gets real content, never placeholders.
            if content.isImage, let data = imageData, let image = UIImage(data: data) {
                let text = await OCRService.recognizeText(in: image)
                if descriptionText.isEmpty {
                    descriptionText = text.isEmpty ? "No text found in this image." : text
                }
                if title.isEmpty {
                    let firstLine = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
                    title = firstLine.isEmpty ? "Cropped image" : String(firstLine.prefix(80))
                }
            }
            // Trigger actual metadata extraction in background if not already pre-fetched
            if title.isEmpty {
                if content.isLink, let urlString = content.urlString {
                    let metadata = await MetadataService.fetch(urlString: urlString)
                    if let fetchedTitle = metadata?.title, !fetchedTitle.isEmpty {
                        title = fetchedTitle
                    } else {
                        title = "Shared Link"
                    }
                    if let fetchedDescription = metadata?.description {
                        descriptionText = fetchedDescription
                    }
                    if snipType != "Cropped region" {
                        imageData = metadata?.imageData
                    }
                } else if let text = content.text {
                    let firstLine = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
                    title = firstLine.isEmpty ? "Shared Text" : String(firstLine.prefix(80))
                    descriptionText = text
                }
            }
            isLoadingMetadata = false
            
            // Stagger animation reveal of fields
            for p in 1...5 {
                try? await Task.sleep(nanoseconds: 400_000_000)
                withAnimation(.easeOut(duration: 0.35)) {
                    extractionPhase = p
                }
            }
        }
    }

    private func performSave() {
        let payload = SharePayload(
            collectionID: selectedCollectionID,
            title: title.isEmpty ? "Shared Snippet" : title,
            description: descriptionText,
            urlString: content.urlString,
            bodyText: content.text,
            imageData: imageData,
            tags: tags
        )
        let id = onSave(payload)
        elapsedSeconds = max(1, Int(Date().timeIntervalSince(startedAt).rounded()))
        
        withAnimation {
            savedCardID = id
            changeScreen(to: .success)
        }
    }
}

struct CutoutShape: Shape {
    let cutoutRect: CGRect

    func path(in rect: CGRect) -> Path {
        var path = Path()
        // Outer bounds
        path.addRect(rect)
        // Inner transparent hole
        path.addRect(cutoutRect)
        return path
    }
}

struct WebView: UIViewRepresentable {
    let content: SharedContent
    @Binding var webViewRef: WKWebView?

    func makeUIView(context: Context) -> WKWebView {
        // Reuse the web view preloaded when the share sheet opened, so the
        // crop tool shows the content right away instead of a black screen.
        let webView = webViewRef ?? Self.makeWebView(content: content)
        DispatchQueue.main.async {
            webViewRef = webView
        }
        return webView
    }

    /// Create a web view and start loading the shared content into it.
    static func makeWebView(content: SharedContent) -> WKWebView {
        // Screen-sized from the start so the page lays out at its final width.
        let webView = WKWebView(frame: UIScreen.main.bounds)
        webView.allowsBackForwardNavigationGestures = true
        
        if content.isLink, let urlString = content.urlString, let url = URL(string: urlString) {
            webView.load(URLRequest(url: url))
        } else if content.isImage, let data = content.sharedImageData {
            let base64 = data.base64EncodedString()
            let html = """
            <html>
            <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
              body {
                margin: 0;
                padding: 0;
                background-color: #000000;
                display: flex;
                justify-content: center;
                align-items: center;
                height: 100vh;
                width: 100vw;
                overflow: hidden;
              }
              img {
                max-width: 100%;
                max-height: 100%;
                object-fit: contain;
              }
            </style>
            </head>
            <body>
              <img src="data:image/png;base64,\(base64)" />
            </body>
            </html>
            """
            webView.loadHTMLString(html, baseURL: nil)
        } else if let text = content.text {
            let html = """
            <html>
            <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
              body {
                font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
                font-size: 17px;
                line-height: 1.6;
                color: #1c1c1e;
                background-color: #ffffff;
                padding: 24px;
                margin: 0;
                word-wrap: break-word;
              }
              .title {
                font-size: 22px;
                font-weight: 700;
                margin-bottom: 12px;
                color: #000;
              }
            </style>
            </head>
            <body>
              <div class="title">Shared Content</div>
              \(text.replacingOccurrences(of: "\n", with: "<br>"))
            </body>
            </html>
            """
            webView.loadHTMLString(html, baseURL: nil)
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // No-op
    }
}
