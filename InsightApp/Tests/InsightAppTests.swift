import XCTest
@testable import InsightApp

final class InsightAppTests: XCTestCase {

    func testAuthorFromFilename() throws {
        // Test Bahá'u'lláh works
        XCTAssertEqual(Author.from(filename: "gleanings-writings-bahaullah.docx"), .bahaullah)
        XCTAssertEqual(Author.from(filename: "kitab-i-iqan.txt"), .bahaullah)
        XCTAssertEqual(Author.from(filename: "hidden-words.docx"), .bahaullah)

        // Test 'Abdu'l-Bahá works
        XCTAssertEqual(Author.from(filename: "some-answered-questions.docx"), .abdulBaha)
        XCTAssertEqual(Author.from(filename: "paris-talks.txt"), .abdulBaha)

        // Test The Báb
        XCTAssertEqual(Author.from(filename: "selections-writings-bab.docx"), .theBab)

        // Test Shoghi Effendi
        XCTAssertEqual(Author.from(filename: "god-passes-by.docx"), .shoghiEffendi)
        XCTAssertEqual(Author.from(filename: "world-order-bahaullah.txt"), .shoghiEffendi)

        // Test dated documents (Universal House of Justice)
        XCTAssertEqual(Author.from(filename: "1999-04-ridvan.docx"), .universalHouseOfJustice)
        XCTAssertEqual(Author.from(filename: "2021-11-message.txt"), .universalHouseOfJustice)

        // Test unknown files
        XCTAssertEqual(Author.from(filename: "unknown-document.docx"), .other)
    }

    func testBahaiLibraryURLMapper() throws {
        // Test known mappings
        let gleaningsURL = BahaiLibraryURLMapper.url(for: "gleanings-writings-bahaullah.docx")
        XCTAssertNotNil(gleaningsURL)
        XCTAssertTrue(gleaningsURL?.absoluteString.contains("bahaullah/gleanings") ?? false)

        // Test display title
        let title = BahaiLibraryURLMapper.displayTitle(for: "kitab-i-iqan.docx")
        XCTAssertEqual(title, "Kitab I Iqan")
    }

    func testEmbeddingServiceCosineSimilarity() throws {
        // Test identical vectors
        let a: [Float] = [1.0, 0.0, 0.0]
        let b: [Float] = [1.0, 0.0, 0.0]
        XCTAssertEqual(EmbeddingService.cosineSimilarity(a, b), 1.0, accuracy: 0.0001)

        // Test orthogonal vectors
        let c: [Float] = [1.0, 0.0, 0.0]
        let d: [Float] = [0.0, 1.0, 0.0]
        XCTAssertEqual(EmbeddingService.cosineSimilarity(c, d), 0.0, accuracy: 0.0001)

        // Test opposite vectors
        let e: [Float] = [1.0, 0.0, 0.0]
        let f: [Float] = [-1.0, 0.0, 0.0]
        XCTAssertEqual(EmbeddingService.cosineSimilarity(e, f), -1.0, accuracy: 0.0001)
    }

    func testParagraphResult() throws {
        let result = ParagraphResult(
            id: "test_para_1",
            text: "Test paragraph text",
            sourceFile: "gleanings-writings-bahaullah.docx",
            paragraphId: 1,
            author: .bahaullah,
            score: 0.95
        )

        XCTAssertEqual(result.id, "test_para_1")
        XCTAssertEqual(result.author, .bahaullah)
        XCTAssertNotNil(result.libraryURL)
    }
}
