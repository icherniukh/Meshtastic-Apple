import Testing
@testable import Meshtastic

@Suite("WriteCsvFile")
struct WriteCsvFileTests {

	@Test func csvField_leavesPlainValueUnquoted() {
		#expect(csvField("Meshtastic") == "Meshtastic")
	}

	@Test func csvField_quotesValueWithComma() {
		#expect(csvField("AccessoryManager.connect(to: Meshtastic_9f79, withConnection: false)") == "\"AccessoryManager.connect(to: Meshtastic_9f79, withConnection: false)\"")
	}

	@Test func csvField_escapesQuotes() {
		#expect(csvField("Code=6 \"timeout\"") == "\"Code=6 \"\"timeout\"\"\"")
	}

	@Test func csvField_quotesMultilineValue() {
		#expect(csvField("first\nsecond") == "\"first\nsecond\"")
	}
}
