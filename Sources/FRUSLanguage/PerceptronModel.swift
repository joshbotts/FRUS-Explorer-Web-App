// The lexical-class tagger's model (PLAN's S29c): an averaged perceptron with integer weights, its tags
// and the class each gives, a dictionary of the words its training text always tagged one way, and the
// file it is kept in. Scoring adds 32-bit integers into 64-bit sums and breaks a tie by the tag's place,
// so a model tags the same on every architecture.

/// An averaged perceptron's model: its tags, their classes, its tag dictionary and its weights.
///
/// ## The file
/// Little-endian, its integers LEB128 varints, a weight zigzagged first:
/// - the magic `FRUSPTG` and the format's version, `1`;
/// - the tags: their count, then each tag's name and its class's raw value, strings as a length and
///   UTF-8;
/// - the tag dictionary: its count, then each entry by its key's rise from the one before, in order,
///   and its tag's place;
/// - the weights: the features' count, then each feature by its key's rise from the one before, in
///   order, its weights' count, and each weight's tag and value.
///
/// A weight is the averaged weight in thousandths, rounded, as Honnibal's tagger rounds it to three
/// places; a feature whose every weight rounds to nothing is left out.
///
/// Version history:
///   1.0 — 2026-11-24 (FRUS Explorer Light, S29c): initial implementation
public struct PerceptronModel: Sendable, Equatable {
    /// The tags, in order: a tag is its place here.
    public let tags: [String]
    /// The class each tag gives, by place.
    public let tagClasses: [LexicalClass]
    /// The words the training text always tagged one way, by their printed form's key.
    let tagDictionary: [UInt32: UInt8]
    /// Each feature's weights: its first in `weightTags` and `weightValues`, shifted left 8, and their
    /// count in the low byte.
    let features: [UInt32: UInt32]
    let weightTags: [UInt8]
    let weightValues: [Int32]

    /// The file's first bytes.
    static let magic: [UInt8] = Array("FRUSPTG".utf8) + [1]

    /// The places of the tags the class rules read, when the model has them.
    let toTag: UInt8?, verbBaseTag: UInt8?, cardinalTag: UInt8?

    init(tags: [String], tagClasses: [LexicalClass], tagDictionary: [UInt32: UInt8],
         features: [UInt32: UInt32], weightTags: [UInt8], weightValues: [Int32]) {
        self.tags = tags
        self.tagClasses = tagClasses
        self.tagDictionary = tagDictionary
        self.features = features
        self.weightTags = weightTags
        self.weightValues = weightValues
        func place(_ name: String) -> UInt8? { tags.firstIndex(of: name).map { UInt8($0) } }
        toTag = place("TO")
        verbBaseTag = place("VB")
        cardinalTag = place("CD")
    }

    public static func == (lhs: PerceptronModel, rhs: PerceptronModel) -> Bool {
        lhs.tags == rhs.tags && lhs.tagClasses == rhs.tagClasses && lhs.tagDictionary == rhs.tagDictionary
            && lhs.features == rhs.features && lhs.weightTags == rhs.weightTags && lhs.weightValues == rhs.weightValues
    }

    /// How many features the model weighs.
    public var featureCount: Int { features.count }
    /// How many weights it holds.
    public var weightCount: Int { weightValues.count }
    /// How many words its tag dictionary holds.
    public var dictionaryCount: Int { tagDictionary.count }

    // MARK: - Tagging

    /// The tags of a line's tokens, in order: each word its tag dictionary holds by that tag, each
    /// other by the highest score of its features' weights, given the tags before it, a tie going to
    /// the tag that comes first.
    /// - Parameter tokens: The line's tokens as printed, punctuation among them.
    /// - Returns: Each token's tag's place.
    public func tag<Words: Collection>(line tokens: Words) -> [UInt8] where Words.Element == Substring {
        let line = LineFeatures(tokens)
        var tags = [UInt8](repeating: 0, count: tokens.count)
        var keys = [UInt32](repeating: 0, count: LineFeatures.keyCount)
        var scores = [Int64](repeating: 0, count: self.tags.count)
        var previous = LineFeatures.startTag, beforeThat = LineFeatures.start2Tag
        for index in 0..<tokens.count {
            let tag: UInt8
            if let known = tagDictionary[FeatureHash.fold(line.printed[index])] {
                tag = known
            } else {
                line.keys(at: index, previous: previous, beforeThat: beforeThat, into: &keys)
                tag = best(keys, scores: &scores)
            }
            tags[index] = tag
            beforeThat = previous
            previous = UInt64(tag)
        }
        return tags
    }

    /// The tag whose weights over `keys` sum highest, a tie going to the tag that comes first.
    @inline(__always)
    func best(_ keys: [UInt32], scores: inout [Int64]) -> UInt8 {
        for t in scores.indices { scores[t] = 0 }
        for key in keys {
            guard let span = features[key] else { continue }
            let first = Int(span >> 8), count = Int(span & 0xFF)
            for w in first..<(first + count) {
                scores[Int(weightTags[w])] &+= Int64(weightValues[w])
            }
        }
        var best = 0
        for t in 1..<scores.count where scores[t] > scores[best] { best = t }
        return UInt8(best)
    }

    /// The class of the token at `index` of a line, given the line's tags and its tokens: its tag's class,
    /// but for two rules that read more, each as NaturalLanguage reads the words they cover:
    /// - `TO` is a particle before a verb's base form ("to go") and a preposition elsewhere ("to Paris");
    /// - `CD` holding a comma or a period ("1,500", "3.5") is another word, as NaturalLanguage tags it.
    public func lexicalClass<Words: Collection>(at index: Int, tags: [UInt8], tokens: Words) -> LexicalClass
    where Words.Element == Substring, Words.Index == Int {
        let tag = tags[index]
        if tag == toTag {
            return index + 1 < tags.count && tags[index + 1] == verbBaseTag ? .particle : .preposition
        }
        if tag == cardinalTag, tokens[index].contains(where: { $0 == "," || $0 == "." }) {
            return .otherWord
        }
        return tagClasses[Int(tag)]
    }

    // MARK: - The file

    /// The model's file, as the type's documentation lays it out.
    public func encoded() -> [UInt8] {
        var out = ByteWriter()
        out.bytes(Self.magic)
        out.varint(UInt64(tags.count))
        for (tag, tagClass) in zip(tags, tagClasses) {
            out.string(tag)
            out.string(tagClass.rawValue)
        }
        out.varint(UInt64(tagDictionary.count))
        var last: UInt32 = 0
        for key in tagDictionary.keys.sorted() {
            out.varint(UInt64(key - last))
            out.byte(tagDictionary[key]!)
            last = key
        }
        out.varint(UInt64(features.count))
        last = 0
        for key in features.keys.sorted() {
            let span = features[key]!
            let first = Int(span >> 8), count = Int(span & 0xFF)
            out.varint(UInt64(key - last))
            out.varint(UInt64(count))
            for w in first..<(first + count) {
                out.byte(weightTags[w])
                out.varint(ByteWriter.zigzag(Int64(weightValues[w])))
            }
            last = key
        }
        return out.data
    }

    /// Reads a model's file.
    /// - Throws: `PerceptronModelError` for a file that is not one, or is cut short.
    public init(decoding bytes: [UInt8]) throws {
        var input = ByteReader(bytes)
        guard try input.bytes(Self.magic.count) == Self.magic else { throw PerceptronModelError("not a model file, or another format's version") }
        let tagCount = try input.count(limit: 255)
        var tags: [String] = [], classes: [LexicalClass] = []
        for _ in 0..<tagCount {
            tags.append(try input.string())
            let raw = try input.string()
            guard let tagClass = LexicalClass(rawValue: raw) else { throw PerceptronModelError("unknown class \(raw)") }
            classes.append(tagClass)
        }
        guard !tags.isEmpty, Set(tags).count == tags.count else { throw PerceptronModelError("no tags, or a tag twice") }
        let dictionaryCount = try input.count(limit: 1 << 24)
        var dictionary: [UInt32: UInt8] = [:]
        dictionary.reserveCapacity(dictionaryCount)
        var key: UInt64 = 0
        for _ in 0..<dictionaryCount {
            key += try input.varint()
            let tag = try input.byte()
            guard key <= UInt64(UInt32.max), Int(tag) < tagCount, dictionary.updateValue(tag, forKey: UInt32(key)) == nil else {
                throw PerceptronModelError("a tag dictionary entry out of range or out of order")
            }
        }
        let featureCount = try input.count(limit: 1 << 24)
        var features: [UInt32: UInt32] = [:]
        features.reserveCapacity(featureCount)
        var weightTags: [UInt8] = [], weightValues: [Int32] = []
        key = 0
        for index in 0..<featureCount {
            let rise = try input.varint()
            guard index == 0 || rise > 0 else { throw PerceptronModelError("features out of order") }
            key += rise
            let count = try input.count(limit: tagCount)
            guard key <= UInt64(UInt32.max), count > 0, weightValues.count < 1 << 24 else {
                throw PerceptronModelError("a feature out of range")
            }
            features[UInt32(key)] = UInt32(weightValues.count) << 8 | UInt32(count)
            for _ in 0..<count {
                let tag = try input.byte()
                let value = ByteReader.unzigzag(try input.varint())
                guard Int(tag) < tagCount, let weight = Int32(exactly: value) else { throw PerceptronModelError("a weight out of range") }
                weightTags.append(tag)
                weightValues.append(weight)
            }
        }
        guard input.atEnd else { throw PerceptronModelError("bytes after the weights") }
        self.init(tags: tags, tagClasses: classes, tagDictionary: dictionary, features: features,
                  weightTags: weightTags, weightValues: weightValues)
    }
}

/// Why a model's file could not be read.
public struct PerceptronModelError: Error, CustomStringConvertible, Equatable {
    public let description: String
    public init(_ description: String) { self.description = description }
}

extension FeatureHash {
    /// A 64-bit hash folded to the 32 bits a model keys its tag dictionary by.
    @inline(__always)
    static func fold(_ hash: UInt64) -> UInt32 {
        UInt32(truncatingIfNeeded: hash) ^ UInt32(truncatingIfNeeded: hash >> 32)
    }
}

// MARK: - Bytes

/// Writes a model's bytes.
struct ByteWriter {
    var data: [UInt8] = []

    mutating func byte(_ value: UInt8) { data.append(value) }
    mutating func bytes(_ values: [UInt8]) { data += values }

    mutating func varint(_ value: UInt64) {
        var rest = value
        while rest >= 0x80 {
            data.append(UInt8(rest & 0x7F) | 0x80)
            rest >>= 7
        }
        data.append(UInt8(rest))
    }

    mutating func string(_ text: String) {
        let utf8 = Array(text.utf8)
        varint(UInt64(utf8.count))
        data += utf8
    }

    static func zigzag(_ value: Int64) -> UInt64 {
        UInt64(bitPattern: (value << 1) ^ (value >> 63))
    }
}

/// Reads a model's bytes.
struct ByteReader {
    let data: [UInt8]
    var offset = 0

    init(_ data: [UInt8]) { self.data = data }

    var atEnd: Bool { offset == data.count }

    mutating func byte() throws -> UInt8 {
        guard offset < data.count else { throw PerceptronModelError("the file ends early") }
        defer { offset += 1 }
        return data[offset]
    }

    mutating func bytes(_ count: Int) throws -> [UInt8] {
        guard count <= data.count - offset else { throw PerceptronModelError("the file ends early") }
        defer { offset += count }
        return Array(data[offset..<offset + count])
    }

    mutating func varint() throws -> UInt64 {
        var value: UInt64 = 0
        var shift: UInt64 = 0
        while true {
            let next = try byte()
            guard shift < 64 else { throw PerceptronModelError("a number too long") }
            value |= UInt64(next & 0x7F) << shift
            if next < 0x80 { return value }
            shift += 7
        }
    }

    mutating func count(limit: Int) throws -> Int {
        let value = try varint()
        guard value <= UInt64(limit) else { throw PerceptronModelError("a count of \(value), past \(limit)") }
        return Int(value)
    }

    mutating func string() throws -> String {
        let length = try count(limit: 1 << 16)
        return String(decoding: try bytes(length), as: UTF8.self)
    }

    static func unzigzag(_ value: UInt64) -> Int64 {
        Int64(bitPattern: value >> 1) ^ -Int64(bitPattern: value & 1)
    }
}
