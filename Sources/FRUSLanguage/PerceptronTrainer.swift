// The averaged perceptron's training (PLAN's S29c), in integers, so that the same text and settings make
// the same model, byte for byte, on any machine: Honnibal's algorithm, its weights whole numbers, its
// sums 64-bit, its averages rounded to thousandths once, and its lines shuffled by SplitMix64 from a
// seed.

/// A line of training text: its tokens as printed and the place of each one's tag.
public struct TrainingLine: Sendable, Equatable {
    public var tokens: [Substring]
    public var tags: [UInt8]

    public init(tokens: [Substring], tags: [UInt8]) {
        precondition(tokens.count == tags.count, "a tag for each token")
        self.tokens = tokens
        self.tags = tags
    }
}

/// Trains an averaged perceptron over lines of tagged text (Honnibal 2013).
///
/// For each pass over the lines, in an order shuffled from the seed: each token its tag dictionary does
/// not hold is tagged by the current weights, given the tags guessed before it, and when the guess is
/// wrong every feature's weight for the right tag gains one and for the guess loses one. Each weight's
/// running sum over every token so far is kept by the step it last changed at, so the average costs
/// nothing until the end, when each sum is divided by the steps taken.
///
/// The tag dictionary is Honnibal's: a word printed at least ``dictionaryMinimumCount`` times in the
/// training text and tagged one way at least ``dictionaryMinimumShare`` of them is tagged that way,
/// unweighed.
///
/// Version history:
///   1.0 — 2026-11-24 (FRUS Explorer Light, S29c): initial implementation
public struct PerceptronTrainer {
    /// The fewest times a word is printed for the tag dictionary to hold it.
    public static let dictionaryMinimumCount = 20
    /// The least share, in thousandths, of a word's printings its commonest tag has for the dictionary
    /// to hold it.
    public static let dictionaryMinimumShare = 970

    /// The tags, by place.
    public let tags: [String]
    /// The class each tag gives.
    public let tagClasses: [LexicalClass]

    struct Cell {
        var tag: UInt8
        var weight: Int32 = 0
        var total: Int64 = 0
        var stamp: Int64 = 0
    }

    var slots: [UInt32: Int] = [:]
    var cells: [[Cell]] = []
    var steps: Int64 = 0
    var dictionary: [UInt32: UInt8] = [:]

    /// What the passes did: each pass's share of tokens tagged right as it was made, in thousandths.
    public private(set) var passAccuracy: [Int] = []

    /// Creates a trainer for a tag set.
    public init(tags: [String], tagClasses: [LexicalClass]) {
        precondition(!tags.isEmpty && tags.count <= 255 && tags.count == tagClasses.count)
        self.tags = tags
        self.tagClasses = tagClasses
    }

    /// Trains over `lines` for `passes` passes, in an order shuffled from `seed`.
    public mutating func train(_ lines: [TrainingLine], passes: Int, seed: UInt64) {
        makeDictionary(lines)
        var order = Array(lines.indices)
        var random = SplitMix64(seed: seed)
        var keys = [UInt32](repeating: 0, count: LineFeatures.keyCount)
        var scores = [Int64](repeating: 0, count: tags.count)
        for _ in 0..<passes {
            random.shuffle(&order)
            var right = 0, seen = 0
            for index in order {
                let line = lines[index]
                let features = LineFeatures(line.tokens)
                var previous = LineFeatures.startTag, beforeThat = LineFeatures.start2Tag
                for position in line.tokens.indices {
                    let truth = line.tags[position]
                    let guess: UInt8
                    if let known = dictionary[FeatureHash.fold(features.printed[position])] {
                        guess = known
                    } else {
                        features.keys(at: position, previous: previous, beforeThat: beforeThat, into: &keys)
                        guess = predict(keys, scores: &scores)
                        update(truth: truth, guess: guess, keys: keys)
                    }
                    if guess == truth { right += 1 }
                    seen += 1
                    beforeThat = previous
                    previous = UInt64(guess)
                }
            }
            passAccuracy.append(seen == 0 ? 0 : right * 1000 / seen)
        }
    }

    /// The model: each weight's average in thousandths, rounded half away from zero, and the features
    /// whose every weight rounds to nothing left out.
    public func model() -> PerceptronModel {
        var features: [UInt32: UInt32] = [:]
        var weightTags: [UInt8] = [], weightValues: [Int32] = []
        let divisor = max(steps, 1)
        for key in slots.keys.sorted() {
            var kept: [(UInt8, Int32)] = []
            for cell in cells[slots[key]!].sorted(by: { $0.tag < $1.tag }) {
                let total = cell.total + (steps - cell.stamp) * Int64(cell.weight)
                let scaled = total * 1000
                let rounded = scaled >= 0 ? (scaled + divisor / 2) / divisor : -((-scaled + divisor / 2) / divisor)
                if rounded != 0, let value = Int32(exactly: rounded) { kept.append((cell.tag, value)) }
            }
            guard !kept.isEmpty else { continue }
            precondition(weightValues.count < 1 << 24, "a model holds fewer than 2^24 weights, as its file can say")
            features[key] = UInt32(weightValues.count) << 8 | UInt32(kept.count)
            for (tag, value) in kept {
                weightTags.append(tag)
                weightValues.append(value)
            }
        }
        return PerceptronModel(tags: tags, tagClasses: tagClasses, tagDictionary: dictionary, features: features,
                               weightTags: weightTags, weightValues: weightValues)
    }

    /// The tag dictionary, from every line's words and tags, each word keyed as the tagger reads it, by its
    /// printed form with the typewriter's punctuation (`LineFeatures.typewriter`), so that `’s` and `'s` are
    /// one entry, counted together.
    mutating func makeDictionary(_ lines: [TrainingLine]) {
        var counts: [UInt32: [UInt8: Int]] = [:]
        for line in lines {
            for (token, tag) in zip(line.tokens, line.tags) {
                counts[FeatureHash.fold(FeatureHash.fnv(LineFeatures.typewriter(token))), default: [:]][tag, default: 0] += 1
            }
        }
        dictionary = [:]
        for (key, tagCounts) in counts {
            let total = tagCounts.values.reduce(0, +)
            guard total >= Self.dictionaryMinimumCount else { continue }
            // The commonest tag, a tie to the one that comes first, so the choice is the same whatever the
            // dictionary's order.
            let (tag, count) = tagCounts.max { $0.value < $1.value || ($0.value == $1.value && $0.key > $1.key) }!
            if count * 1000 >= total * Self.dictionaryMinimumShare { dictionary[key] = tag }
        }
    }

    /// The current weights' best tag over `keys`, a tie going to the tag that comes first.
    func predict(_ keys: [UInt32], scores: inout [Int64]) -> UInt8 {
        for t in scores.indices { scores[t] = 0 }
        for key in keys {
            guard let slot = slots[key] else { continue }
            for cell in cells[slot] { scores[Int(cell.tag)] &+= Int64(cell.weight) }
        }
        var best = 0
        for t in 1..<scores.count where scores[t] > scores[best] { best = t }
        return UInt8(best)
    }

    /// One step: when the guess is wrong, each feature's weight for the truth gains one and for the guess
    /// loses one, each weight's sum brought up to this step first.
    mutating func update(truth: UInt8, guess: UInt8, keys: [UInt32]) {
        steps += 1
        guard truth != guess else { return }
        for key in keys {
            let slot: Int
            if let known = slots[key] {
                slot = known
            } else {
                slot = cells.count
                slots[key] = slot
                cells.append([])
            }
            change(slot, tag: truth, by: 1)
            change(slot, tag: guess, by: -1)
        }
    }

    mutating func change(_ slot: Int, tag: UInt8, by delta: Int32) {
        if let index = cells[slot].firstIndex(where: { $0.tag == tag }) {
            cells[slot][index].total += (steps - cells[slot][index].stamp) * Int64(cells[slot][index].weight)
            cells[slot][index].stamp = steps
            cells[slot][index].weight += delta
        } else {
            cells[slot].append(Cell(tag: tag, weight: delta, total: 0, stamp: steps))
        }
    }
}

/// SplitMix64 (Steele, Lea and Flood 2014): a generator of 64-bit numbers from a seed, the same on every
/// machine, which the trainer shuffles its lines by.
public struct SplitMix64: RandomNumberGenerator {
    var state: UInt64

    public init(seed: UInt64) { state = seed }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Shuffles `values` by Fisher and Yates, each draw `next() % (i + 1)`, which Swift's own `shuffle`
    /// does not promise to keep from one release to the next.
    public mutating func shuffle<T>(_ values: inout [T]) {
        guard values.count > 1 else { return }
        for i in stride(from: values.count - 1, to: 0, by: -1) {
            let j = Int(next() % UInt64(i + 1))
            values.swapAt(i, j)
        }
    }
}
