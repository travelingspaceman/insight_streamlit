import Foundation

/// Maps source filenames to official Bahá'í library URLs
public enum BahaiLibraryURLMapper {
    private static let baseURL = "https://www.bahai.org/library/authoritative-texts"

    private static let urlMappings: [String: String] = [
        // Bahá'u'lláh
        "kitab-i-iqan": "/bahaullah/kitab-i-iqan",
        "hidden-words": "/bahaullah/hidden-words",
        "gleanings-writings-bahaullah": "/bahaullah/gleanings-writings-bahaullah",
        "kitab-i-aqdas": "/bahaullah/kitab-i-aqdas",
        "epistle-son-wolf": "/bahaullah/epistle-son-wolf",
        "gems-divine-mysteries": "/bahaullah/gems-divine-mysteries",
        "summons-lord-hosts": "/bahaullah/summons-lord-hosts",
        "tablets-bahaullah": "/bahaullah/tablets-bahaullah-revealed-after-kitab-i-aqdas",
        "tabernacle-unity": "/bahaullah/tabernacle-unity",
        "prayers-meditations": "/bahaullah/prayers-meditations",

        // 'Abdu'l-Bahá
        "some-answered-questions": "/abdul-baha/some-answered-questions",
        "paris-talks": "/abdul-baha/paris-talks",
        "promulgation-universal-peace": "/abdul-baha/promulgation-universal-peace",
        "memorials-faithful": "/abdul-baha/memorials-faithful",
        "selections-writings-abdul-baha": "/abdul-baha/selections-writings-abdul-baha",
        "secret-divine-civilization": "/abdul-baha/secret-divine-civilization",
        "travelers-narrative": "/abdul-baha/travelers-narrative",
        "will-testament-abdul-baha": "/abdul-baha/will-testament-abdul-baha",
        "tablets-divine-plan": "/abdul-baha/tablets-divine-plan",
        "tablet-auguste-forel": "/abdul-baha/tablet-auguste-forel",

        // The Báb
        "selections-writings-bab": "/the-bab/selections-writings-bab",

        // Shoghi Effendi
        "advent-divine-justice": "/shoghi-effendi/advent-divine-justice",
        "god-passes-by": "/shoghi-effendi/god-passes-by",
        "promised-day-come": "/shoghi-effendi/promised-day-come",
        "world-order-bahaullah": "/shoghi-effendi/world-order-bahaullah",

        // Universal House of Justice
        "institution-of-the-counsellors": "/the-universal-house-of-justice/institution-counsellors",
        "turning-point": "/the-universal-house-of-justice/turning-point-all-nations",

        // Compilations
        "days-remembrance": "/compilations/days-remembrance",
        "light-of-the-world": "/compilations/light-of-the-world"
    ]

    /// Get the Bahá'í library URL for a source file
    /// - Parameter sourceFile: The source filename
    /// - Returns: URL to the official Bahá'í library, or nil if not mapped
    public static func url(for sourceFile: String) -> URL? {
        let filename = sourceFile
            .lowercased()
            .replacingOccurrences(of: ".docx", with: "")
            .replacingOccurrences(of: ".txt", with: "")

        // Try to find a matching key
        for (key, path) in urlMappings {
            if filename.contains(key) {
                return URL(string: baseURL + path)
            }
        }

        // Default to the main library page
        return URL(string: "https://www.bahai.org/library")
    }

    /// Get a formatted title for display from the source file
    /// - Parameter sourceFile: The source filename
    /// - Returns: A human-readable title
    public static func displayTitle(for sourceFile: String) -> String {
        sourceFile
            .replacingOccurrences(of: ".docx", with: "")
            .replacingOccurrences(of: ".txt", with: "")
            .replacingOccurrences(of: "-", with: " ")
            .capitalized
    }
}
