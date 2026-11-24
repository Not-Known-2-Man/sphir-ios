//
//  ItemCountLabelTests.swift
//  SphirTests
//
//  Collection counts read "1 item" for one and "N items" otherwise.
//

import Testing
import Foundation
@testable import Sphir

struct ItemCountLabelTests {

    @Test func zeroIsPlural() {
        #expect(Collection.itemCountLabel(0) == "0 items")
    }

    @Test func oneIsSingular() {
        #expect(Collection.itemCountLabel(1) == "1 item")
    }

    @Test func twoIsPlural() {
        #expect(Collection.itemCountLabel(2) == "2 items")
    }

    @Test func largeNumberIsPlural() {
        #expect(Collection.itemCountLabel(1234) == "1234 items")
    }
}
