//
//  LocalizationTests.swift
//  SphirTests
//
//  Tests verifying that:
//  1. Every key in the String Catalog has a non-empty Spanish translation.
//  2. The compiled Spanish bundle resolves known keys to Spanish.
//  3. Collection.itemCountLabel supports plural localization in Spanish ("1 elemento" / "3 elementos")
//     while retaining English expectations.
//

import Testing
import Foundation
@testable import Sphir

private final class LocalizationTestsHelper {}

struct LocalizationTests {

    private struct CatalogRoot: Decodable {
        let sourceLanguage: String
        let strings: [String: CatalogEntry]
    }

    private struct CatalogEntry: Decodable {
        let localizations: [String: CatalogLocalization]?
    }

    private struct CatalogLocalization: Decodable {
        let stringUnit: CatalogStringUnit?
        let variations: CatalogVariations?
    }

    private struct CatalogStringUnit: Decodable {
        let state: String
        let value: String
    }

    private struct CatalogVariations: Decodable {
        let plural: CatalogPluralVariations?
    }

    private struct CatalogPluralVariations: Decodable {
        let one: CatalogVariationUnit?
        let other: CatalogVariationUnit?
    }

    private struct CatalogVariationUnit: Decodable {
        let stringUnit: CatalogStringUnit?
    }

    /// Locates the compiled es.lproj bundle in the app or test bundle.
    private func findSpanishBundle() -> Bundle? {
        if let path = Bundle.main.path(forResource: "es", ofType: "lproj"), let bundle = Bundle(path: path) {
            return bundle
        }
        if let path = Bundle(for: NetworkService.self).path(forResource: "es", ofType: "lproj"), let bundle = Bundle(path: path) {
            return bundle
        }
        let mainURL = Bundle.main.bundleURL
        let candidate = mainURL.appendingPathComponent("es.lproj")
        if FileManager.default.fileExists(atPath: candidate.path), let bundle = Bundle(url: candidate) {
            return bundle
        }
        let testBundle = Bundle(for: LocalizationTestsHelper.self)
        if let path = testBundle.path(forResource: "es", ofType: "lproj"), let bundle = Bundle(path: path) {
            return bundle
        }
        return nil
    }

    /// Locates the source repository root directory.
    private func sourceRootURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // SphirTests
            .deletingLastPathComponent() // Repo root
    }

    @Test func everyKeyInAppCatalogHasSpanishTranslation() throws {
        let catalogURL = sourceRootURL().appendingPathComponent("Sphir/Localizable.xcstrings")
        #expect(FileManager.default.fileExists(atPath: catalogURL.path), "Sphir/Localizable.xcstrings must exist")

        let data = try Data(contentsOf: catalogURL)
        let catalog = try JSONDecoder().decode(CatalogRoot.self, from: data)

        #expect(!catalog.strings.isEmpty, "Catalog should contain localized strings")

        var missingOrEmptySpanishKeys: [String] = []

        for (key, entry) in catalog.strings {
            guard let esLoc = entry.localizations?["es"] else {
                missingOrEmptySpanishKeys.append("\(key): missing 'es' localization")
                continue
            }

            if let stringUnit = esLoc.stringUnit {
                if stringUnit.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    missingOrEmptySpanishKeys.append("\(key): empty Spanish value")
                }
            } else if let plural = esLoc.variations?.plural {
                let oneVal = plural.one?.stringUnit?.value.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let otherVal = plural.other?.stringUnit?.value.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if oneVal.isEmpty || otherVal.isEmpty {
                    missingOrEmptySpanishKeys.append("\(key): incomplete plural variation (one: '\(oneVal)', other: '\(otherVal)')")
                }
            } else {
                missingOrEmptySpanishKeys.append("\(key): neither stringUnit nor plural variation found in 'es'")
            }
        }

        #expect(missingOrEmptySpanishKeys.isEmpty, "All catalog keys must have valid Spanish translations: \(missingOrEmptySpanishKeys)")
    }

    @Test func everyKeyInShareExtensionCatalogHasSpanishTranslation() throws {
        let catalogURL = sourceRootURL().appendingPathComponent("SphirShare/Localizable.xcstrings")
        #expect(FileManager.default.fileExists(atPath: catalogURL.path), "SphirShare/Localizable.xcstrings must exist")

        let data = try Data(contentsOf: catalogURL)
        let catalog = try JSONDecoder().decode(CatalogRoot.self, from: data)

        #expect(!catalog.strings.isEmpty, "Share catalog should contain localized strings")

        var missingOrEmptySpanishKeys: [String] = []

        for (key, entry) in catalog.strings {
            guard let esLoc = entry.localizations?["es"] else {
                missingOrEmptySpanishKeys.append("\(key): missing 'es' localization")
                continue
            }

            if let stringUnit = esLoc.stringUnit {
                if stringUnit.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    missingOrEmptySpanishKeys.append("\(key): empty Spanish value")
                }
            } else if let plural = esLoc.variations?.plural {
                let oneVal = plural.one?.stringUnit?.value.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let otherVal = plural.other?.stringUnit?.value.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if oneVal.isEmpty || otherVal.isEmpty {
                    missingOrEmptySpanishKeys.append("\(key): incomplete plural variation (one: '\(oneVal)', other: '\(otherVal)')")
                }
            } else {
                missingOrEmptySpanishKeys.append("\(key): neither stringUnit nor plural variation found in 'es'")
            }
        }

        #expect(missingOrEmptySpanishKeys.isEmpty, "All share catalog keys must have valid Spanish translations: \(missingOrEmptySpanishKeys)")
    }

    @Test func infoPlistCatalogHasSpanishCameraUsage() throws {
        let infoPlistURL = sourceRootURL().appendingPathComponent("Sphir/InfoPlist.xcstrings")
        #expect(FileManager.default.fileExists(atPath: infoPlistURL.path), "Sphir/InfoPlist.xcstrings must exist")

        let data = try Data(contentsOf: infoPlistURL)
        let catalog = try JSONDecoder().decode(CatalogRoot.self, from: data)

        let entry = try #require(catalog.strings["NSCameraUsageDescription"])
        let esVal = try #require(entry.localizations?["es"]?.stringUnit?.value)
        #expect(!esVal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    @Test func spanishBundleResolvesKnownKeys() {
        guard let bundle = findSpanishBundle() else {
            Issue.record("es.lproj bundle could not be found in app bundle")
            return
        }

        let deletePrompt = bundle.localizedString(forKey: "Delete card?", value: nil, table: nil)
        #expect(deletePrompt == "¿Eliminar tarjeta?")

        let cancel = bundle.localizedString(forKey: "Cancel", value: nil, table: nil)
        #expect(cancel == "Cancelar")

        let settings = bundle.localizedString(forKey: "Settings", value: nil, table: nil)
        #expect(settings == "Configuración")
    }

    @Test func itemCountLabelPluralSpanish() throws {
        let esLocale = Locale(identifier: "es")
        let esBundle = try #require(findSpanishBundle())

        #expect(Collection.itemCountLabel(1, locale: esLocale, bundle: esBundle) == "1 elemento")
        #expect(Collection.itemCountLabel(2, locale: esLocale, bundle: esBundle) == "2 elementos")
        #expect(Collection.itemCountLabel(3, locale: esLocale, bundle: esBundle) == "3 elementos")
        #expect(Collection.itemCountLabel(0, locale: esLocale, bundle: esBundle) == "0 elementos")
    }

    @Test func itemCountLabelEnglishRemainsUnchanged() {
        let enLocale = Locale(identifier: "en_US")
        #expect(Collection.itemCountLabel(0, locale: enLocale) == "0 items")
        #expect(Collection.itemCountLabel(1, locale: enLocale) == "1 item")
        #expect(Collection.itemCountLabel(2, locale: enLocale) == "2 items")
        #expect(Collection.itemCountLabel(1234, locale: enLocale) == "1,234 items")
    }
}
