import Foundation
import Testing

struct GlyphStyleTests {
    @Test
    func defaultIsBoltFill() {
        #expect(GlyphStyle.default == .boltFill)
    }

    @Test
    func allCasesPreserveExpectedOrder() {
        #expect(GlyphStyle.allCases == [.boltFill, .ring, .text])
    }

    @Test
    func rawValuesAreStable() {
        #expect(GlyphStyle.boltFill.rawValue == "boltFill")
        #expect(GlyphStyle.ring.rawValue == "ring")
        #expect(GlyphStyle.text.rawValue == "text")
    }

    @Test
    func codableRoundTrip() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for style in GlyphStyle.allCases {
            let data = try encoder.encode(style)
            let decoded = try decoder.decode(GlyphStyle.self, from: data)
            #expect(decoded == style)
        }
    }
}
