//
//  WebReaderView.swift
//  Sphir
//
//  Full-screen in-app reader. Loads a card's URL in a WKWebView so the user
//  can read the full page inside Sphir. Native iOS text selection (long-press
//  to select/copy) works automatically in WKWebView — no custom handling.
//

import SwiftUI
import WebKit

struct WebReaderView: View {
    let url: URL
    let fallbackTitle: String

    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = true
    @State private var pageTitle = ""

    private var displayTitle: String {
        pageTitle.isEmpty ? fallbackTitle : pageTitle
    }

    var body: some View {
        VStack(spacing: 0) {
            navBar

            if isLoading {
                ProgressView()
                    .progressViewStyle(.linear)
                    .tint(SphirColor.taupe)
            }

            WebView(url: url, isLoading: $isLoading, pageTitle: $pageTitle)
        }
        .background(SphirColor.background.ignoresSafeArea())
    }

    private var navBar: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
                .font(SphirFont.body(16, weight: .semibold))
                .foregroundColor(SphirColor.taupe)
            }
            .accessibilityIdentifier("readerBackButton")
            .accessibilityLabel("Back")

            Spacer(minLength: 8)

            Text(displayTitle)
                .font(SphirFont.body(15, weight: .semibold))
                .foregroundColor(SphirColor.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 8)

            ShareLink(item: url) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 17))
                    .foregroundColor(SphirColor.taupe)
            }
            .accessibilityLabel("Share")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            SphirColor.background
                .overlay(
                    Rectangle().fill(SphirColor.border).frame(height: 1),
                    alignment: .bottom
                )
        )
    }
}

/// Minimal WKWebView wrapper. Text selection is provided natively by WebKit.
private struct WebView: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    @Binding var pageTitle: String

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        // Show the app background (not an empty dark view) until the page paints.
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(isLoading: $isLoading, pageTitle: $pageTitle)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        @Binding var isLoading: Bool
        @Binding var pageTitle: String

        init(isLoading: Binding<Bool>, pageTitle: Binding<String>) {
            _isLoading = isLoading
            _pageTitle = pageTitle
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            isLoading = true
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoading = false
            if let title = webView.title, !title.isEmpty {
                pageTitle = title
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            isLoading = false
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            isLoading = false
        }
    }
}
