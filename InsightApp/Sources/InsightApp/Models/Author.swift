import Foundation

/// Represents the author categories for Bahá'í writings
public enum Author: String, CaseIterable, Codable, Identifiable, Sendable {
    case bahaullah = "Bahá'u'lláh"
    case abdulBaha = "'Abdu'l-Bahá"
    case theBab = "The Báb"
    case shoghiEffendi = "Shoghi Effendi"
    case universalHouseOfJustice = "Universal House of Justice"
    case compilations = "Compilations"
    case other = "Other"

    public var id: String { rawValue }

    public var displayName: String { rawValue }

    /// Maps a source filename to its corresponding author
    public static func from(filename: String) -> Author {
        let lowercased = filename.lowercased()

        // Bahá'u'lláh's writings
        let bahaullahWorks = [
            "kitab-i-iqan", "hidden-words", "gleanings-writings-bahaullah",
            "kitab-i-aqdas", "epistle-son-wolf", "gems-divine-mysteries",
            "summons-lord-hosts", "tablets-bahaullah", "tabernacle-unity",
            "prayers-meditations"
        ]

        // 'Abdu'l-Bahá's writings
        let abdulBahaWorks = [
            "some-answered-questions", "paris-talks", "promulgation-universal-peace",
            "memorials-faithful", "selections-writings-abdul-baha",
            "secret-divine-civilization", "travelers-narrative",
            "will-testament-abdul-baha", "tablets-divine-plan",
            "tablet-auguste-forel"
        ]

        // The Báb's writings
        let babWorks = ["selections-writings-bab"]

        // Shoghi Effendi's writings
        let shoghiEffendiWorks = [
            "advent-divine-justice", "god-passes-by",
            "promised-day-come", "world-order-bahaullah"
        ]

        // Universal House of Justice documents
        let uhjWorks = [
            "institution-of-the-counsellors", "turning-point", "muhj"
        ]

        // Compilations
        let compilationWorks = ["days-remembrance", "light-of-the-world"]

        for work in bahaullahWorks where lowercased.contains(work) {
            return .bahaullah
        }

        for work in abdulBahaWorks where lowercased.contains(work) {
            return .abdulBaha
        }

        for work in babWorks where lowercased.contains(work) {
            return .theBab
        }

        for work in shoghiEffendiWorks where lowercased.contains(work) {
            return .shoghiEffendi
        }

        for work in uhjWorks where lowercased.contains(work) {
            return .universalHouseOfJustice
        }

        for work in compilationWorks where lowercased.contains(work) {
            return .compilations
        }

        // Check for dated documents (Universal House of Justice)
        if lowercased.hasPrefix("19") || lowercased.hasPrefix("20") {
            return .universalHouseOfJustice
        }

        return .other
    }
}
