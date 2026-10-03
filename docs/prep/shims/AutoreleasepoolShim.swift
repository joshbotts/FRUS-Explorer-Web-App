#if !canImport(ObjectiveC)
// Linux has no Objective-C runtime and so no autoreleasepool; the body just runs.
@inline(__always)
func autoreleasepool<Result>(invoking body: () throws -> Result) rethrows -> Result { try body() }
#endif
