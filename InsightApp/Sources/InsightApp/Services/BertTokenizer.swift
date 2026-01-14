import Foundation

/// BERT WordPiece tokenizer for use with sentence transformer models
public final class BertTokenizer: Sendable {
    private let vocab: [String: Int32]
    private let idToToken: [Int32: String]
    private let maxLength: Int

    // Special tokens
    private let clsToken = "[CLS]"
    private let sepToken = "[SEP]"
    private let padToken = "[PAD]"
    private let unkToken = "[UNK]"

    private let clsId: Int32
    private let sepId: Int32
    private let padId: Int32
    private let unkId: Int32

    /// Initialize tokenizer with vocabulary file
    /// - Parameters:
    ///   - vocabURL: URL to vocab.txt file
    ///   - maxLength: Maximum sequence length (default: 128)
    public init(vocabURL: URL, maxLength: Int = 128) throws {
        let content = try String(contentsOf: vocabURL, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines)

        var vocab: [String: Int32] = [:]
        var idToToken: [Int32: String] = [:]

        for (index, line) in lines.enumerated() {
            guard !line.isEmpty else { continue }
            let id = Int32(index)
            vocab[line] = id
            idToToken[id] = line
        }

        self.vocab = vocab
        self.idToToken = idToToken
        self.maxLength = maxLength

        // Get special token IDs
        guard let clsId = vocab[clsToken],
              let sepId = vocab[sepToken],
              let padId = vocab[padToken],
              let unkId = vocab[unkToken] else {
            throw TokenizerError.missingSpecialTokens
        }

        self.clsId = clsId
        self.sepId = sepId
        self.padId = padId
        self.unkId = unkId
    }

    /// Initialize tokenizer from app bundle
    /// - Parameter maxLength: Maximum sequence length (default: 128)
    public convenience init(maxLength: Int = 128) throws {
        guard let url = Bundle.main.url(forResource: "vocab", withExtension: "txt") else {
            throw TokenizerError.vocabNotFound
        }
        try self.init(vocabURL: url, maxLength: maxLength)
    }

    /// Tokenize text and return input IDs and attention mask
    /// - Parameter text: Text to tokenize
    /// - Returns: Tuple of (inputIds, attentionMask) as Int32 arrays
    public func encode(_ text: String) -> (inputIds: [Int32], attentionMask: [Int32]) {
        // Tokenize using WordPiece
        let tokens = tokenize(text)

        // Convert to IDs with [CLS] and [SEP]
        var inputIds: [Int32] = [clsId]

        // Add token IDs (leaving room for [CLS] and [SEP])
        let maxTokens = maxLength - 2
        for token in tokens.prefix(maxTokens) {
            inputIds.append(vocab[token] ?? unkId)
        }

        inputIds.append(sepId)

        // Create attention mask (1 for real tokens, 0 for padding)
        var attentionMask = [Int32](repeating: 1, count: inputIds.count)

        // Pad to maxLength
        while inputIds.count < maxLength {
            inputIds.append(padId)
            attentionMask.append(0)
        }

        return (inputIds, attentionMask)
    }

    /// Tokenize text using WordPiece algorithm
    private func tokenize(_ text: String) -> [String] {
        var tokens: [String] = []

        // Basic preprocessing: lowercase and split on whitespace/punctuation
        let normalized = text.lowercased()
        let words = splitOnWhitespaceAndPunctuation(normalized)

        for word in words {
            let wordTokens = wordPieceTokenize(word)
            tokens.append(contentsOf: wordTokens)
        }

        return tokens
    }

    /// Split text on whitespace and punctuation, keeping punctuation as separate tokens
    private func splitOnWhitespaceAndPunctuation(_ text: String) -> [String] {
        var words: [String] = []
        var currentWord = ""

        for char in text {
            if char.isWhitespace {
                if !currentWord.isEmpty {
                    words.append(currentWord)
                    currentWord = ""
                }
            } else if char.isPunctuation || char.isSymbol {
                if !currentWord.isEmpty {
                    words.append(currentWord)
                    currentWord = ""
                }
                words.append(String(char))
            } else {
                currentWord.append(char)
            }
        }

        if !currentWord.isEmpty {
            words.append(currentWord)
        }

        return words
    }

    /// Apply WordPiece tokenization to a single word
    private func wordPieceTokenize(_ word: String) -> [String] {
        guard !word.isEmpty else { return [] }

        // Check if entire word is in vocab
        if vocab[word] != nil {
            return [word]
        }

        var tokens: [String] = []
        var start = word.startIndex

        while start < word.endIndex {
            var end = word.endIndex
            var found = false

            while start < end {
                let substring = String(word[start..<end])
                let candidate = start == word.startIndex ? substring : "##\(substring)"

                if vocab[candidate] != nil {
                    tokens.append(candidate)
                    found = true
                    break
                }

                // Try shorter substring
                end = word.index(before: end)
            }

            if !found {
                // Character not in vocab, use [UNK]
                tokens.append(unkToken)
                start = word.index(after: start)
            } else {
                start = end
            }
        }

        return tokens
    }
}

/// Tokenizer errors
public enum TokenizerError: Error, LocalizedError {
    case vocabNotFound
    case missingSpecialTokens

    public var errorDescription: String? {
        switch self {
        case .vocabNotFound:
            return "Could not find vocab.txt in app bundle"
        case .missingSpecialTokens:
            return "Vocabulary is missing required special tokens ([CLS], [SEP], [PAD], [UNK])"
        }
    }
}
