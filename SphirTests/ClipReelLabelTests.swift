//
//  ClipReelLabelTests.swift
//  SphirTests
//
//  S9 "INSTAGRAM REEL" label and S10 on-device fallback cover image.
//

import Testing
import Foundation
@testable import Sphir

struct ClipReelLabelTests {

    @Test func instagramReelPathIsLabeledReel() {
        #expect(CardType.label(for: .social, url: "https://www.instagram.com/reel/DfxT1KYOrxr/") == "INSTAGRAM REEL")
        #expect(CardType.label(for: .social, url: "https://instagram.com/reel/abc") == "INSTAGRAM REEL")
        #expect(CardType.label(for: .social, url: "https://m.instagram.com/reel/abc/") == "INSTAGRAM REEL")
    }

    @Test func instagramReelsPathIsLabeledReel() {
        #expect(CardType.label(for: .social, url: "https://www.instagram.com/reels/abc/") == "INSTAGRAM REEL")
    }

    @Test func instagramPostStaysSocial() {
        #expect(CardType.label(for: .social, url: "https://www.instagram.com/p/abc/") == "SOCIAL")
    }

    @Test func otherSocialHostsStaySocial() {
        #expect(CardType.label(for: .social, url: "https://x.com/someone/status/1") == "SOCIAL")
        #expect(CardType.label(for: .social, url: "https://notinstagram.com/reel/abc") == "SOCIAL")
    }

    @Test func nonSocialTypeWithInstagramURLIsUnchanged() {
        #expect(CardType.label(for: .article, url: "https://www.instagram.com/reel/abc/") == "ARTICLE")
        #expect(CardType.label(for: .text, url: "https://www.instagram.com/reel/abc/") == "LINK")
    }

    @Test func draftLabelUsesTheSharedRule() {
        let reel = ClipDraft(fallbackURL: "https://www.instagram.com/reel/abc/")
        #expect(reel.type == .social)
        #expect(reel.typeLabel == "INSTAGRAM REEL")
        #expect(ClipDraft(fallbackURL: "https://www.instagram.com/p/abc/").typeLabel == "SOCIAL")
    }

    @Test func fallbackDraftKeepsHttpsImage() {
        let d = ClipDraft(fallbackURL: "https://a.example.com/x", title: "T", description: "D",
                          imageURL: "https://cdn.example.com/c.jpg")
        #expect(d.imageURL == "https://cdn.example.com/c.jpg")
    }

    @Test func fallbackDraftUpgradesHttpImageToHttps() {
        let d = ClipDraft(fallbackURL: "https://a.example.com/x", imageURL: "http://cdn.example.com/c.jpg")
        #expect(d.imageURL == "https://cdn.example.com/c.jpg")
    }

    @Test func fallbackDraftDropsNonHttpImage() {
        #expect(ClipDraft(fallbackURL: "https://a.example.com/x", imageURL: "data:image/png;base64,AA").imageURL == nil)
        #expect(ClipDraft(fallbackURL: "https://a.example.com/x", imageURL: "").imageURL == nil)
    }
}
