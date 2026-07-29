//
//  NodeWatchIdentifierTests.swift
//  Meshtastic
//

import Testing

@testable import Meshtastic

@Suite("NodeWatchIdentifier")
struct NodeWatchIdentifierTests {

	@Test("Parses explicit and unambiguous hexadecimal node IDs")
	func parsesHexNodeIDs() {
		#expect(NodeWatchIdentifier.parse("!74dc9f79") == Int64(0x74dc9f79))
		#expect(NodeWatchIdentifier.parse("74dc9f79") == Int64(0x74dc9f79))
		#expect(NodeWatchIdentifier.parse("!12345678") == Int64(0x12345678))
	}

	@Test("Prefers decimal for digits-only node numbers")
	func parsesDigitsOnlyNodeNumbersAsDecimal() {
		#expect(NodeWatchIdentifier.parse("12345678") == 12_345_678)
	}
}
