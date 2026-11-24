//
//  CardPaginationTests.swift
//  SphirTests
//
//  GET /api/v1/users/get_businesses returns at most `per_page` cards (API
//  default 50, max 100). The app must read every page, or a sync deletes the
//  local copies of cards that did not fit on page 1.
//

import Testing
import Foundation
@testable import Sphir

struct CardPaginationTests {

    private func dtos(_ ids: ClosedRange<Int>) -> [BusinessDTO] {
        ids.map { id in
            try! JSONDecoder().decode(BusinessDTO.self, from: Data(#"{"id":\#(id),"title":"Card \#(id)"}"#.utf8))
        }
    }

    @Test func readsPagesUntilOneComesBackShort() async throws {
        let server = dtos(1...250)
        var requested: [(Int, Int)] = []

        let all = try await CardAPIService.fetchAllCards(perPage: 100) { page, perPage in
            requested.append((page, perPage))
            let start = (page - 1) * perPage
            return Array(server.dropFirst(start).prefix(perPage))
        }

        #expect(all.map(\.serverID) == server.map(\.serverID))
        #expect(requested.map(\.0) == [1, 2, 3])
        #expect(requested.allSatisfy { $0.1 == 100 })
    }

    @Test func exactMultipleStopsOnTheEmptyPage() async throws {
        let server = dtos(1...200)
        var pages: [Int] = []

        let all = try await CardAPIService.fetchAllCards(perPage: 100) { page, perPage in
            pages.append(page)
            return Array(server.dropFirst((page - 1) * perPage).prefix(perPage))
        }

        #expect(all.count == 200)
        #expect(pages == [1, 2, 3])
    }

    @Test func cardCreatedBetweenPagesIsNotDuplicated() async throws {
        // Newest first: a card created after page 1 shifts every later card
        // down by one, so the last card of page 1 shows up again on page 2.
        let page1 = dtos(1...3)
        let page2 = dtos(3...4)

        let all = try await CardAPIService.fetchAllCards(perPage: 3) { page, _ in
            page == 1 ? page1 : page2
        }

        #expect(all.map(\.serverID) == ["1", "2", "3", "4"])
    }

    @Test func pageErrorFailsTheWholeFetch() async {
        struct Offline: Error {}
        await #expect(throws: Offline.self) {
            _ = try await CardAPIService.fetchAllCards(perPage: 2) { page, _ in
                if page == 2 { throw Offline() }
                return self.dtos(1...2)
            }
        }
    }
}
