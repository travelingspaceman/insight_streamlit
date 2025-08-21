import Foundation

struct SearchResult: Identifiable, Codable {
    let id = UUID()
    let text: String
    let sourceFile: String
    let paragraphId: Int
    let score: Double
    let author: String
    
    enum CodingKeys: String, CodingKey {
        case text
        case sourceFile = "source_file"
        case paragraphId = "paragraph_id"
        case score
        case author
    }
    
    var bahaiLibraryURL: URL? {
        let baseURL = "https://www.bahai.org/library/authoritative-texts"
        let filename = sourceFile.replacingOccurrences(of: ".docx", with: "").lowercased()
        
        let urlMappings: [String: String] = [
            // Bahá'u'lláh
            "kitab-i-iqan": "\(baseURL)/bahaullah/kitab-i-iqan/",
            "hidden-words": "\(baseURL)/bahaullah/hidden-words/",
            "gleanings-writings-bahaullah": "\(baseURL)/bahaullah/gleanings-writings-bahaullah/",
            "kitab-i-aqdas-2": "\(baseURL)/bahaullah/kitab-i-aqdas/",
            "epistle-son-wolf": "\(baseURL)/bahaullah/epistle-son-wolf/",
            "gems-divine-mysteries": "\(baseURL)/bahaullah/gems-divine-mysteries/",
            "summons-lord-hosts": "\(baseURL)/bahaullah/summons-lord-hosts/",
            "tablets-bahaullah": "\(baseURL)/bahaullah/tablets-bahaullah/",
            "tabernacle-unity": "\(baseURL)/bahaullah/tabernacle-unity/",
            
            // 'Abdu'l-Bahá
            "some-answered-questions": "\(baseURL)/abdul-baha/some-answered-questions/",
            "paris-talks": "\(baseURL)/abdul-baha/paris-talks/",
            "promulgation-universal-peace": "\(baseURL)/abdul-baha/promulgation-universal-peace/",
            "memorials-faithful": "\(baseURL)/abdul-baha/memorials-faithful/",
            "selections-writings-abdul-baha": "\(baseURL)/abdul-baha/selections-writings-abdul-baha/",
            "secret-divine-civilization": "\(baseURL)/abdul-baha/secret-divine-civilization/",
            "travelers-narrative": "\(baseURL)/abdul-baha/travelers-narrative/",
            "will-testament-abdul-baha": "\(baseURL)/abdul-baha/will-testament-abdul-baha/",
            "tablets-divine-plan": "\(baseURL)/abdul-baha/tablets-divine-plan/",
            "tablet-auguste-forel": "\(baseURL)/abdul-baha/tablet-auguste-forel/",
            
            // The Báb
            "selections-writings-bab": "\(baseURL)/the-bab/selections-writings-bab/",
            
            // Shoghi Effendi
            "advent-divine-justice": "\(baseURL)/shoghi-effendi/advent-divine-justice/",
            "god-passes-by": "\(baseURL)/shoghi-effendi/god-passes-by/",
            "promised-day-come": "\(baseURL)/shoghi-effendi/promised-day-come/",
            "world-order-bahaullah": "\(baseURL)/shoghi-effendi/world-order-bahaullah/",
            
            // Compilations and other works
            "prayers-meditations": "\(baseURL)/bahaullah/prayers-meditations/",
            "days-remembrance": "\(baseURL)/compilations/days-remembrance/",
            "light-of-the-world": "\(baseURL)/compilations/light-of-the-world/",
            "turning-point": "\(baseURL)/compilations/turning-point/"
        ]
        
        let urlString = urlMappings[filename] ?? "https://www.bahai.org/library/"
        return URL(string: urlString)
    }
}

enum SearchMode: String, CaseIterable {
    case quote = "quote"
    case journal = "journal"
    
    var displayName: String {
        switch self {
        case .quote:
            return "🔍 Find a Quote"
        case .journal:
            return "📝 Journal Entry"
        }
    }
    
    var description: String {
        switch self {
        case .quote:
            return "🔍 **Find a Quote Mode**: Search directly for relevant passages"
        case .journal:
            return "📝 **Journal Entry Mode**: Share your thoughts and get guidance from the Writings"
        }
    }
    
    var placeholder: String {
        switch self {
        case .quote:
            return "e.g., spiritual development, unity of mankind, prayer..."
        case .journal:
            return "e.g., I'm struggling with patience today, or I feel grateful for..."
        }
    }
}

enum Author: String, CaseIterable {
    case all = "All Authors"
    case bahaullah = "Bahá'u'lláh"
    case abdulBaha = "'Abdu'l-Bahá"
    case theBab = "The Báb"
    case shoghiEffendi = "Shoghi Effendi"
    case universalHouseOfJustice = "Universal House of Justice"
    case compilations = "Compilations"
    
    var displayName: String {
        return self.rawValue
    }
}