//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2016 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//
//
// Exposing the API of NSString on Swift's String
// Note: this file is derived from the stdlib `public/SDK/Foundation/NSStringAPI.swift`
// Any changes should made should be considered to be made in unison to both files
// Some behavior here is different because of the bridge story on linux and
// a few methods have been omitted to be more in line with the swift-corelibs-foundation
// implementation
//
//===----------------------------------------------------------------------===//

// Open Issues
// ===========
//
// Property Lists need to be properly bridged
//


@warn_unused_result
func _toNSRange(_ r: Range<String.Index>) -> NSRange {
    return NSRange(
        location: r.startIndex._utf16Index,
                  length: r.endIndex._utf16Index - r.startIndex._utf16Index)
}

@warn_unused_result
func _countFormatSpecifiers(_ a: String) -> Int {
    // The implementation takes advantage of the fact that internal
    // representation of String is UTF-16.  Because we only care about the ASCII
    // percent character, we don't need to decode UTF-16.
    
    let percentUTF16  = UTF16.CodeUnit(("%" as UnicodeScalar).value)
    let notPercentUTF16: UTF16.CodeUnit = 0
    var lastChar = notPercentUTF16 // anything other than % would work here
    var count = 0
    
    for c in a.utf16 {
        if lastChar == percentUTF16 {
            if c == percentUTF16 {
                // a "%" following this one should not be taken as literal
                lastChar = notPercentUTF16
            }
            else {
                count += 1
                lastChar = c
            }
        } else {
            lastChar = c
        }
    }
    return count
}

// Random access for String.UTF16View, only when Foundation is
// imported.  Making this API dependent on Foundation decouples the
// Swift core from a UTF16 representation.
extension String.UTF16View.Index : RandomAccessIndex {
    /// Construct from an integer offset.
    public init(_ offset: Int) {
        _precondition(offset >= 0, "Negative UTF16 index offset not allowed")
        self.init(_offset: offset)
        // self._offset = offset
    }
}

extension String {
    
    //===--- Bridging Helpers -----------------------------------------------===//
    //===--------------------------------------------------------------------===//
    
    /// The corresponding `NSString` - a convenience for bridging code.
    var _ns: NSString {
        return _nsObject
    }
    
    /// Return an `Index` corresponding to the given offset in our UTF-16
    /// representation.
    @warn_unused_result
    func _index(_ utf16Index: Int) -> Index {
        return Index(_base: String.UnicodeScalarView.Index(utf16Index, _core))
    }
    
    /// Return a `Range<Index>` corresponding to the given `NSRange` of
    /// our UTF-16 representation.
    @warn_unused_result
    func _range(_ r: NSRange) -> Range<Index> {
        return _index(r.location)..<_index(r.location + r.length)
    }
    
    /// Return a `Range<Index>?` corresponding to the given `NSRange` of
    /// our UTF-16 representation.
    @warn_unused_result
    func _optionalRange(_ r: NSRange) -> Range<Index>? {
        if r.location == NSNotFound {
            return .none
        }
        return _range(r)
    }
    
    /// Invoke `body` on an `Int` buffer.  If `index` was converted from
    /// non-`nil`, convert the buffer to an `Index` and write it into the
    /// memory referred to by `index`
    func _withOptionalOutParameter<Result>(
        _ index: UnsafeMutablePointer<Index>?,
        @noescape body: (UnsafeMutablePointer<Int>?) -> Result
        ) -> Result {
        var utf16Index: Int = 0
        let result = (index != nil) ? body(&utf16Index) : body(nil)
        index?.pointee = self._index(utf16Index)
        return result
    }
    
    /// Invoke `body` on an `NSRange` buffer.  If `range` was converted
    /// from non-`nil`, convert the buffer to a `Range<Index>` and write
    /// it into the memory referred to by `range`
    func _withOptionalOutParameter<Result>(
        _ range: UnsafeMutablePointer<Range<Index>>?,
        @noescape body: (UnsafeMutablePointer<NSRange>?) -> Result
        ) -> Result {
        var nsRange = NSRange(location: 0, length: 0)
        let result = (range != nil) ? body(&nsRange) : body(nil)
        range?.pointee = self._range(nsRange)
        return result
    }
    
    //===--- Class Methods --------------------------------------------------===//
    //===--------------------------------------------------------------------===//
    
    // + (const NSStringEncoding *)availableStringEncodings
    
    /// Returns an Array of the encodings string objects support
    /// in the application’s environment.
    @warn_unused_result
    public static func availableStringEncodings() -> [NSStringEncoding] {
        var result = [NSStringEncoding]()
        var p = NSString.availableStringEncodings()
        while p.pointee != 0 {
            result.append(p.pointee)
            p += 1
        }
        return result
    }
    
    // + (NSStringEncoding)defaultCStringEncoding
    
    /// Returns the C-string encoding assumed for any method accepting
    /// a C string as an argument.
    @warn_unused_result
    public static func defaultCStringEncoding() -> NSStringEncoding {
        return NSString.defaultCStringEncoding()
    }
    
    // + (NSString *)localizedNameOfStringEncoding:(NSStringEncoding)encoding
    
    /// Returns a human-readable string giving the name of a given encoding.
    @warn_unused_result
    public static func localizedNameOfStringEncoding(
        _ encoding: NSStringEncoding
        ) -> String {
        return NSString.localizedNameOfStringEncoding(encoding)
    }
    
    // + (instancetype)localizedStringWithFormat:(NSString *)format, ...
    
    /// Returns a string created by using a given format string as a
    /// template into which the remaining argument values are substituted
    /// according to the user's default locale.
    @warn_unused_result
    public static func localizedStringWithFormat(
        _ format: String, _ arguments: CVarArg...
        ) -> String {
        return String(format: format, locale: NSLocale.currentLocale(),
                              arguments: arguments)
    }
    
    // + (NSString *)pathWithComponents:(NSArray *)components
    
    /// Returns a string built from the strings in a given array
    /// by concatenating them with a path separator between each pair.
    public static func pathWithComponents(_ components: [String]) -> String {
        return NSString.pathWithComponents(components)
    }
    
    //===--------------------------------------------------------------------===//
    // NSString factory functions that have a corresponding constructor
    // are omitted.
    //
    // + (instancetype)string
    //
    // + (instancetype)
    //     stringWithCharacters:(const unichar *)chars length:(NSUInteger)length
    //
    // + (instancetype)stringWithFormat:(NSString *)format, ...
    //
    // + (instancetype)
    //     stringWithContentsOfFile:(NSString *)path
    //     encoding:(NSStringEncoding)enc
    //     error:(NSError **)error
    //
    // + (instancetype)
    //     stringWithContentsOfFile:(NSString *)path
    //     usedEncoding:(NSStringEncoding *)enc
    //     error:(NSError **)error
    //
    // + (instancetype)
    //     stringWithContentsOfURL:(NSURL *)url
    //     encoding:(NSStringEncoding)enc
    //     error:(NSError **)error
    //
    // + (instancetype)
    //     stringWithContentsOfURL:(NSURL *)url
    //     usedEncoding:(NSStringEncoding *)enc
    //     error:(NSError **)error
    //
    // + (instancetype)
    //     stringWithCString:(const char *)cString
    //     encoding:(NSStringEncoding)enc
    //===--------------------------------------------------------------------===//
    
    //===--- Adds nothing for String beyond what String(s) does -------------===//
    // + (instancetype)stringWithString:(NSString *)aString
    //===--------------------------------------------------------------------===//
    
    // + (instancetype)stringWithUTF8String:(const char *)bytes
    
    /// Produces a string created by copying the data from a given
    /// C array of UTF8-encoded bytes.
    public init?(UTF8String bytes: UnsafePointer<CChar>) {
        if let ns = NSString(UTF8String: bytes) {
            self = ns._swiftObject
        } else {
            return nil
        }
    }
    
    //===--- Instance Methods/Properties-------------------------------------===//
    //===--------------------------------------------------------------------===//
    
    //===--- Omitted by agreement during API review 5/20/2014 ---------------===//
    // @property BOOL boolValue;
    
    // - (BOOL)canBeConvertedToEncoding:(NSStringEncoding)encoding
    
    /// Returns a Boolean value that indicates whether the
    /// `String` can be converted to a given encoding without loss of
    /// information.
    @warn_unused_result
    public func canBeConvertedToEncoding(_ encoding: NSStringEncoding) -> Bool {
        return _ns.canBeConvertedToEncoding(encoding)
    }
    
    // @property NSString* capitalizedString
    
    /// Produce a string with the first character from each word changed
    /// to the corresponding uppercase value.
    public var capitalizedString: String {
        return _ns.capitalizedString as String
    }
    
    // @property (readonly, copy) NSString *localizedCapitalizedString NS_AVAILABLE(10_11, 9_0);
    
    /// A capitalized representation of the `String` that is produced
    /// using the current locale.
    public var localizedCapitalizedString: String {
        return _ns.localizedCapitalizedString
    }
    
    // - (NSString *)capitalizedStringWithLocale:(NSLocale *)locale
    
    /// Returns a capitalized representation of the `String`
    /// using the specified locale.
    @warn_unused_result
    public func capitalizedStringWithLocale(_ locale: NSLocale?) -> String {
        return _ns.capitalizedStringWithLocale(locale) as String
    }
    
    // - (NSComparisonResult)caseInsensitiveCompare:(NSString *)aString
    
    /// Returns the result of invoking `compare:options:` with
    /// `NSCaseInsensitiveSearch` as the only option.
    @warn_unused_result
    public func caseInsensitiveCompare(_ aString: String) -> NSComparisonResult {
        return _ns.caseInsensitiveCompare(aString)
    }
    
    //===--- Omitted by agreement during API review 5/20/2014 ---------------===//
    // - (unichar)characterAtIndex:(NSUInteger)index
    //
    // We have a different meaning for "Character" in Swift, and we are
    // trying not to expose error-prone UTF-16 integer indexes
    
    // - (NSString *)
    //     commonPrefixWithString:(NSString *)aString
    //     options:(NSStringCompareOptions)mask
    
    /// Returns a string containing characters the `String` and a
    /// given string have in common, starting from the beginning of each
    /// up to the first characters that aren’t equivalent.
    @warn_unused_result
    public func commonPrefixWithString(
        _ aString: String, options: NSStringCompareOptions) -> String {
        return _ns.commonPrefixWithString(aString, options: options)
    }
    
    // - (NSComparisonResult)
    //     compare:(NSString *)aString
    //
    // - (NSComparisonResult)
    //     compare:(NSString *)aString options:(NSStringCompareOptions)mask
    //
    // - (NSComparisonResult)
    //     compare:(NSString *)aString options:(NSStringCompareOptions)mask
    //     range:(NSRange)range
    //
    // - (NSComparisonResult)
    //     compare:(NSString *)aString options:(NSStringCompareOptions)mask
    //     range:(NSRange)range locale:(id)locale
    
    /// Compares the string using the specified options and
    /// returns the lexical ordering for the range.
    @warn_unused_result
    public func compare(
        _ aString: String,
        options mask: NSStringCompareOptions = [],
        range: Range<Index>? = nil,
        locale: NSLocale? = nil
        ) -> NSComparisonResult {
        // According to Ali Ozer, there may be some real advantage to
        // dispatching to the minimal selector for the supplied options.
        // So let's do that; the switch should compile away anyhow.
        return locale != nil ? _ns.compare(
            aString, options: mask,
            range: _toNSRange(range ?? self.characters.indices),
                   locale: locale)
            
            : range != nil ? _ns.compare(
                aString,
                options: mask,
                         range: _toNSRange(range ?? self.characters.indices))
                
            : !mask.isEmpty ? _ns.compare(aString, options: mask)
                
            : _ns.compare(aString)
    }
#if false // TODO: this needs an implementation that works for the swift-corelibs-foundation version of this API
    // - (NSUInteger)
    //     completePathIntoString:(NSString **)outputName
    //     caseSensitive:(BOOL)flag
    //     matchesIntoArray:(NSArray **)outputArray
    //     filterTypes:(NSArray *)filterTypes
    
    /// Interprets the `String` as a path in the file system and
    /// attempts to perform filename completion, returning a numeric
    /// value that indicates whether a match was possible, and by
    /// reference the longest path that matches the `String`.
    /// Returns the actual number of matching paths.
    @warn_unused_result
    public func completePathIntoString(
        _ outputName: UnsafeMutablePointer<String> = nil,
        caseSensitive: Bool,
        matchesIntoArray: UnsafeMutablePointer<[String]> = nil,
        filterTypes: [String]? = nil
        ) -> Int {
        var nsMatches: NSArray?
        var nsOutputName: NSString?
        
        let result = outputName._withBridgeObject(&nsOutputName) {
            outputName in matchesIntoArray._withBridgeObject(&nsMatches) {
                matchesIntoArray in
                self._ns.completePathIntoString(
                    outputName, caseSensitive: caseSensitive,
                    matchesIntoArray: matchesIntoArray, filterTypes: filterTypes
                )
            }
        }
        
        if let matches = nsMatches {
            // Since this function is effectively a bridge thunk, use the
            // bridge thunk semantics for the NSArray conversion
            matchesIntoArray._setIfNonNil { matches._swiftObject.map { ($0 as! NSString)._swiftObject } }
        }
        
        if let n = nsOutputName {
            outputName._setIfNonNil { n._swiftObject }
        }
        return result
    }
    #endif
    // - (NSArray *)
    //     componentsSeparatedByCharactersInSet:(NSCharacterSet *)separator
    
    /// Returns an array containing substrings from the `String`
    /// that have been divided by characters in a given set.
    @warn_unused_result
    public func componentsSeparatedByCharactersInSet(
        _ separator: NSCharacterSet
        ) -> [String] {
        return _ns.componentsSeparatedByCharactersInSet(separator)
    }
    
    
    // - (NSArray *)componentsSeparatedByString:(NSString *)separator
    
    /// Returns an array containing substrings from the `String`
    /// that have been divided by a given separator.
    public func componentsSeparatedByString(_ separator: String) -> [String] {
        return _ns.componentsSeparatedByString(separator)
    }
    
    // - (const char *)cStringUsingEncoding:(NSStringEncoding)encoding
    
    /// Returns a representation of the `String` as a C string
    /// using a given encoding.
    @warn_unused_result
    public func cStringUsingEncoding(_ encoding: NSStringEncoding) -> [CChar]? {
        return withExtendedLifetime(_ns) {
            (s: NSString) -> [CChar]? in
            _persistCString(s.cStringUsingEncoding(encoding))
        }
    }
    
    // - (NSData *)dataUsingEncoding:(NSStringEncoding)encoding
    //
    // - (NSData *)
    //     dataUsingEncoding:(NSStringEncoding)encoding
    //     allowLossyConversion:(BOOL)flag
    
    /// Returns an `NSData` object containing a representation of
    /// the `String` encoded using a given encoding.
    @warn_unused_result
    public func dataUsingEncoding(
        _ encoding: NSStringEncoding,
        allowLossyConversion: Bool = false
        ) -> NSData? {
        return _ns.dataUsingEncoding(
            encoding, allowLossyConversion: allowLossyConversion)
    }
    
    // @property NSString* decomposedStringWithCanonicalMapping;
    
    /// Returns a string made by normalizing the `String`’s
    /// contents using Form D.
    public var decomposedStringWithCanonicalMapping: String {
        return _ns.decomposedStringWithCanonicalMapping
    }
    
    // @property NSString* decomposedStringWithCompatibilityMapping;
    
    /// Returns a string made by normalizing the `String`’s
    /// contents using Form KD.
    public var decomposedStringWithCompatibilityMapping: String {
        return _ns.decomposedStringWithCompatibilityMapping
    }
    
    //===--- Importing Foundation should not affect String printing ---------===//
    // Therefore, we're not exposing this:
    //
    //   @property NSString* description
    
    
    //===--- Omitted for consistency with API review results 5/20/2014 -----===//
    // @property double doubleValue;
    
    // - (void)
    //     enumerateLinesUsingBlock:(void (^)(NSString *line, BOOL *stop))block
    
    /// Enumerates all the lines in a string.
    public func enumerateLines(_ body: (line: String, stop: inout Bool) -> ()) {
        _ns.enumerateLinesUsingBlock {
            (line: String, stop: UnsafeMutablePointer<ObjCBool>)
            in
            var stop_ = false
            body(line: line, stop: &stop_)
            if stop_ {
                UnsafeMutablePointer<ObjCBool>(stop).pointee = true
            }
        }
    }
    
    // - (void)
    //     enumerateSubstringsInRange:(NSRange)range
    //     options:(NSStringEnumerationOptions)opts
    //     usingBlock:(
    //       void (^)(
    //         NSString *substring,
    //         NSRange substringRange,
    //         NSRange enclosingRange,
    //         BOOL *stop)
    //       )block
    
    /// Enumerates the substrings of the specified type in the
    /// specified range of the string.
    public func enumerateSubstringsInRange(
        _ range: Range<Index>,
        options opts:NSStringEnumerationOptions,
        _ body: (
        substring: String?, substringRange: Range<Index>,
        enclosingRange: Range<Index>, inout Bool
        ) -> ()
        ) {
        _ns.enumerateSubstringsInRange(_toNSRange(range), options: opts) {
            var stop_ = false
            
            body(substring: $0,
                            substringRange: self._range($1),
                                            enclosingRange: self._range($2),
                                                            &stop_)
            
            if stop_ {
                UnsafeMutablePointer($3).pointee = true
            }
        }
    }
    
    // @property NSStringEncoding fastestEncoding;
    
    /// Returns the fastest encoding to which the `String` may be
    /// converted without loss of information.
    public var fastestEncoding: NSStringEncoding {
        return _ns.fastestEncoding
    }
    
    // - (const char *)fileSystemRepresentation
    
    /// Returns a file system-specific representation of the `String`.
    public func fileSystemRepresentation() -> [CChar] {
        return _persistCString(_ns.fileSystemRepresentation)!
    }
    
    //===--- Omitted for consistency with API review results 5/20/2014 ------===//
    // @property float floatValue;
    
    // - (BOOL)
    //     getBytes:(void *)buffer
    //     maxLength:(NSUInteger)maxBufferCount
    //     usedLength:(NSUInteger*)usedBufferCount
    //     encoding:(NSStringEncoding)encoding
    //     options:(NSStringEncodingConversionOptions)options
    //     range:(NSRange)range
    //     remainingRange:(NSRangePointer)leftover
    
    /// Writes the given `range` of characters into `buffer` in a given
    /// `encoding`, without any allocations.  Does not NULL-terminate.
    ///
    /// - Parameter buffer: A buffer into which to store the bytes from
    ///   the receiver. The returned bytes are not NUL-terminated.
    ///
    /// - Parameter maxBufferCount: The maximum number of bytes to write
    ///   to buffer.
    ///
    /// - Parameter usedBufferCount: The number of bytes used from
    ///   buffer. Pass `nil` if you do not need this value.
    ///
    /// - Parameter encoding: The encoding to use for the returned bytes.
    ///
    /// - Parameter options: A mask to specify options to use for
    ///   converting the receiver’s contents to `encoding` (if conversion
    ///   is necessary).
    ///
    /// - Parameter range: The range of characters in the receiver to get.
    ///
    /// - Parameter leftover: The remaining range. Pass `nil` If you do
    ///   not need this value.
    ///
    /// - Returns: `true` iff some characters were converted.
    ///
    /// - Note: Conversion stops when the buffer fills or when the
    ///   conversion isn't possible due to the chosen encoding.
    ///
    /// - Note: will get a maximum of `min(buffer.count, maxLength)` bytes.
    public func getBytes(
        _ buffer: inout [UInt8],
              maxLength maxBufferCount: Int,
              usedLength usedBufferCount: UnsafeMutablePointer<Int>,
              encoding: NSStringEncoding,
              options: NSStringEncodingConversionOptions,
              range: Range<Index>,
              remainingRange leftover: UnsafeMutablePointer<Range<Index>>
        ) -> Bool {
        return _withOptionalOutParameter(leftover) {
            self._ns.getBytes(
                &buffer,
                maxLength: min(buffer.count, maxBufferCount),
                           usedLength: usedBufferCount,
                                       encoding: encoding,
                                                 options: options,
                                                          range: _toNSRange(range),
                                                                 remainingRange: $0)
        }
    }
    
    // - (BOOL)
    //     getCString:(char *)buffer
    //     maxLength:(NSUInteger)maxBufferCount
    //     encoding:(NSStringEncoding)encoding
    
    /// Converts the `String`’s content to a given encoding and
    /// stores them in a buffer.
    /// - Note: will store a maximum of `min(buffer.count, maxLength)` bytes.
    public func getCString(
        _ buffer: inout [CChar], maxLength: Int, encoding: NSStringEncoding
        ) -> Bool {
        return _ns.getCString(&buffer, maxLength: min(buffer.count, maxLength),
                              encoding: encoding)
    }
    
    // - (BOOL)
    //     getFileSystemRepresentation:(char *)buffer
    //     maxLength:(NSUInteger)maxLength
    
    /// Interprets the `String` as a system-independent path and
    /// fills a buffer with a C-string in a format and encoding suitable
    /// for use with file-system calls.
    /// - Note: will store a maximum of `min(buffer.count, maxLength)` bytes.
    public func getFileSystemRepresentation(
        _ buffer: inout [CChar], maxLength: Int) -> Bool {
        return _ns.getFileSystemRepresentation(
            &buffer, maxLength: min(buffer.count, maxLength))
    }
    
    // - (void)
    //     getLineStart:(NSUInteger *)startIndex
    //     end:(NSUInteger *)lineEndIndex
    //     contentsEnd:(NSUInteger *)contentsEndIndex
    //     forRange:(NSRange)aRange
    
    /// Returns by reference the beginning of the first line and
    /// the end of the last line touched by the given range.
    public func getLineStart(
        _ start: UnsafeMutablePointer<Index>,
        end: UnsafeMutablePointer<Index>,
        contentsEnd: UnsafeMutablePointer<Index>,
        forRange: Range<Index>
        ) {
        _withOptionalOutParameter(start) {
            start in self._withOptionalOutParameter(end) {
                end in self._withOptionalOutParameter(contentsEnd) {
                    contentsEnd in self._ns.getLineStart(
                        start, end: end,
                        contentsEnd: contentsEnd,
                                     forRange: _toNSRange(forRange))
                }
            }
        }
    }
    
    // - (void)
    //     getParagraphStart:(NSUInteger *)startIndex
    //     end:(NSUInteger *)endIndex
    //     contentsEnd:(NSUInteger *)contentsEndIndex
    //     forRange:(NSRange)aRange
    
    /// Returns by reference the beginning of the first paragraph
    /// and the end of the last paragraph touched by the given range.
    public func getParagraphStart(
        _ start: UnsafeMutablePointer<Index>,
        end: UnsafeMutablePointer<Index>,
        contentsEnd: UnsafeMutablePointer<Index>,
        forRange: Range<Index>
        ) {
        _withOptionalOutParameter(start) {
            start in self._withOptionalOutParameter(end) {
                end in self._withOptionalOutParameter(contentsEnd) {
                    contentsEnd in self._ns.getParagraphStart(
                        start, end: end,
                        contentsEnd: contentsEnd,
                                     forRange: _toNSRange(forRange))
                }
            }
        }
    }
    
    // - (NSUInteger)hash
    
    /// An unsigned integer that can be used as a hash table address.
    public var hash: Int {
        return _ns.hash
    }
    
    //===--- Already provided by String's core ------------------------------===//
    // - (instancetype)init
    
    //===--- Initializers that can fail -------------------------------------===//
    // - (instancetype)
    //     initWithBytes:(const void *)bytes
    //     length:(NSUInteger)length
    //     encoding:(NSStringEncoding)encoding
    
    /// Produces an initialized `NSString` object equivalent to the given
    /// `bytes` interpreted in the given `encoding`.
    public init? <
        S: Sequence where S.Iterator.Element == UInt8
        >(
        bytes: S, encoding: NSStringEncoding
        ) {
        let byteArray = Array(bytes)
        if let ns = NSString(
            bytes: byteArray, length: byteArray.count, encoding: encoding) {
            
            self = ns._swiftObject
        } else {
            return nil
        }
    }
    
    // - (instancetype)
    //     initWithBytesNoCopy:(void *)bytes
    //     length:(NSUInteger)length
    //     encoding:(NSStringEncoding)encoding
    //     freeWhenDone:(BOOL)flag
    
    /// Produces an initialized `String` object that contains a
    /// given number of bytes from a given buffer of bytes interpreted
    /// in a given encoding, and optionally frees the buffer.  WARNING:
    /// this initializer is not memory-safe!
    public init?(
        bytesNoCopy bytes: UnsafeMutablePointer<Void>, length: Int,
        encoding: NSStringEncoding, freeWhenDone flag: Bool
        ) {
        if let ns = NSString(
            bytesNoCopy: bytes, length: length, encoding: encoding,
                         freeWhenDone: flag) {
            
            self = ns._swiftObject
        } else {
            return nil
        }
    }
    
    
    // - (instancetype)
    //     initWithCharacters:(const unichar *)characters
    //     length:(NSUInteger)length
    
    /// Returns an initialized `String` object that contains a
    /// given number of characters from a given array of Unicode
    /// characters.
    public init(
        utf16CodeUnits: UnsafePointer<unichar>,
        count: Int
        ) {
        self = NSString(characters: utf16CodeUnits, length: count)._swiftObject
    }
    
    // - (instancetype)
    //     initWithCharactersNoCopy:(unichar *)characters
    //     length:(NSUInteger)length
    //     freeWhenDone:(BOOL)flag
    
    /// Returns an initialized `String` object that contains a given
    /// number of characters from a given array of UTF-16 Code Units
    public init(
        utf16CodeUnitsNoCopy: UnsafePointer<unichar>,
        count: Int,
        freeWhenDone flag: Bool
        ) {
        self = NSString(
            charactersNoCopy: UnsafeMutablePointer(utf16CodeUnitsNoCopy),
                              length: count,
                                      freeWhenDone: flag)._swiftObject
    }
    
    //===--- Initializers that can fail -------------------------------------===//
    
    // - (instancetype)
    //     initWithContentsOfFile:(NSString *)path
    //     encoding:(NSStringEncoding)enc
    //     error:(NSError **)error
    //
    
    /// Produces a string created by reading data from the file at a
    /// given path interpreted using a given encoding.
    public init(
        contentsOfFile path: String,
        encoding enc: NSStringEncoding
        ) throws {
        let ns = try NSString(contentsOfFile: path, encoding: enc)
        self = ns._swiftObject
    }
    
    // - (instancetype)
    //     initWithContentsOfFile:(NSString *)path
    //     usedEncoding:(NSStringEncoding *)enc
    //     error:(NSError **)error
    
    /// Produces a string created by reading data from the file at
    /// a given path and returns by reference the encoding used to
    /// interpret the file.
    public init(
        contentsOfFile path: String,
        usedEncoding: UnsafeMutablePointer<NSStringEncoding>? = nil
        ) throws {
        let ns = try NSString(contentsOfFile: path, usedEncoding: usedEncoding)
        self = ns._swiftObject
    }
    
    // - (instancetype)
    //     initWithContentsOfURL:(NSURL *)url
    //     encoding:(NSStringEncoding)enc
    //     error:(NSError**)error
    
    /// Produces a string created by reading data from a given URL
    /// interpreted using a given encoding.  Errors are written into the
    /// inout `error` argument.
    public init(
        contentsOfURL url: NSURL,
        encoding enc: NSStringEncoding
        ) throws {
        let ns = try NSString(contentsOfURL: url, encoding: enc)
        self = ns._swiftObject
    }
    
    // - (instancetype)
    //     initWithContentsOfURL:(NSURL *)url
    //     usedEncoding:(NSStringEncoding *)enc
    //     error:(NSError **)error
    
    /// Produces a string created by reading data from a given URL
    /// and returns by reference the encoding used to interpret the
    /// data.  Errors are written into the inout `error` argument.
    public init(
        contentsOfURL url: NSURL,
        usedEncoding enc: UnsafeMutablePointer<NSStringEncoding>? = nil
        ) throws {
        let ns = try NSString(contentsOfURL: url, usedEncoding: enc)
        self = ns._swiftObject
    }
    
    // - (instancetype)
    //     initWithCString:(const char *)nullTerminatedCString
    //     encoding:(NSStringEncoding)encoding
    
    /// Produces a string containing the bytes in a given C array,
    /// interpreted according to a given encoding.
    public init?(
        CString: UnsafePointer<CChar>,
        encoding enc: NSStringEncoding
        ) {
        if let ns = NSString(CString: CString, encoding: enc) {
            self = ns._swiftObject
        } else {
            return nil
        }
    }
    
    // FIXME: handle optional locale with default arguments
    
    // - (instancetype)
    //     initWithData:(NSData *)data
    //     encoding:(NSStringEncoding)encoding
    
    /// Returns a `String` initialized by converting given `data` into
    /// Unicode characters using a given `encoding`.
    public init?(data: NSData, encoding: NSStringEncoding) {
        guard let s = NSString(data: data, encoding: encoding) else { return nil }
        self = s._swiftObject
    }
    
    // - (instancetype)initWithFormat:(NSString *)format, ...
    
    /// Returns a `String` object initialized by using a given
    /// format string as a template into which the remaining argument
    /// values are substituted.
    public init(format: String, _ arguments: CVarArg...) {
        self = String(format: format, arguments: arguments)
    }
    
    // - (instancetype)
    //     initWithFormat:(NSString *)format
    //     arguments:(va_list)argList
    
    /// Returns a `String` object initialized by using a given
    /// format string as a template into which the remaining argument
    /// values are substituted according to the user’s default locale.
    public init(format: String, arguments: [CVarArg]) {
        self = String(format: format, locale: nil, arguments: arguments)
    }
    
    // - (instancetype)initWithFormat:(NSString *)format locale:(id)locale, ...
    
    /// Returns a `String` object initialized by using a given
    /// format string as a template into which the remaining argument
    /// values are substituted according to given locale information.
    public init(format: String, locale: NSLocale?, _ args: CVarArg...) {
        self = String(format: format, locale: locale, arguments: args)
    }
    
    // - (instancetype)
    //     initWithFormat:(NSString *)format
    //     locale:(id)locale
    //     arguments:(va_list)argList
    
    /// Returns a `String` object initialized by using a given
    /// format string as a template into which the remaining argument
    /// values are substituted according to given locale information.
    public init(format: String, locale: NSLocale?, arguments: [CVarArg]) {
        _precondition(
            _countFormatSpecifiers(format) <= arguments.count,
            "Too many format specifiers (%<letter>) provided for the argument list"
        )
        self = withVaList(arguments) {
            NSString(format: format, locale: locale, arguments: $0)._swiftObject
        }
    }
    
    //===--- Already provided by core Swift ---------------------------------===//
    // - (instancetype)initWithString:(NSString *)aString
    
    //===--- Initializers that can fail dropped for factory functions -------===//
    // - (instancetype)initWithUTF8String:(const char *)bytes
    
    //===--- Omitted for consistency with API review results 5/20/2014 ------===//
    // @property NSInteger integerValue;
    // @property Int intValue;
    
    //===--- Omitted by apparent agreement during API review 5/20/2014 ------===//
    // @property BOOL absolutePath;
    // - (BOOL)isEqualToString:(NSString *)aString
    
    //===--- Kept for consistency with API review results 5/20/2014 ---------===//
    // We decided to keep pathWithComponents, so keeping this too
    // @property NSString lastPathComponent;
    
    /// Returns the last path component of the `String`.
    public var lastPathComponent: String {
        return _ns.lastPathComponent
    }
    
    //===--- Renamed by agreement during API review 5/20/2014 ---------------===//
    // @property NSUInteger length;
    
    /// Returns the number of Unicode characters in the `String`.
    public var utf16Count: Int {
        return _ns.length
    }
    
    // - (NSUInteger)lengthOfBytesUsingEncoding:(NSStringEncoding)enc
    
    /// Returns the number of bytes required to store the
    /// `String` in a given encoding.
    @warn_unused_result
    public func lengthOfBytesUsingEncoding(_ encoding: NSStringEncoding) -> Int {
        return _ns.lengthOfBytesUsingEncoding(encoding)
    }
    
    // - (NSRange)lineRangeForRange:(NSRange)aRange
    
    /// Returns the range of characters representing the line or lines
    /// containing a given range.
    @warn_unused_result
    public func lineRangeForRange(_ aRange: Range<Index>) -> Range<Index> {
        return _range(_ns.lineRangeForRange(_toNSRange(aRange)))
    }
    
    // - (NSComparisonResult)localizedCaseInsensitiveCompare:(NSString *)aString
    
    /// Compares the string and a given string using a
    /// case-insensitive, localized, comparison.
    @warn_unused_result
    public
    func localizedCaseInsensitiveCompare(_ aString: String) -> NSComparisonResult {
        return _ns.localizedCaseInsensitiveCompare(aString)
    }
    
    // - (NSComparisonResult)localizedCompare:(NSString *)aString
    
    /// Compares the string and a given string using a localized
    /// comparison.
    @warn_unused_result
    public func localizedCompare(_ aString: String) -> NSComparisonResult {
        return _ns.localizedCompare(aString)
    }
    
    /// Compares strings as sorted by the Finder.
    @warn_unused_result
    public func localizedStandardCompare(_ string: String) -> NSComparisonResult {
        return _ns.localizedStandardCompare(string)
    }
    
    //===--- Omitted for consistency with API review results 5/20/2014 ------===//
    // @property long long longLongValue
    
    // @property (readonly, copy) NSString *localizedLowercaseString NS_AVAILABLE(10_11, 9_0);
    
    /// A lowercase version of the string that is produced using the current
    /// locale.
    public var localizedLowercaseString: String {
        return _ns.localizedLowercaseString
    }
    
    // - (NSString *)lowercaseStringWithLocale:(NSLocale *)locale
    
    /// Returns a version of the string with all letters
    /// converted to lowercase, taking into account the specified
    /// locale.
    @warn_unused_result
    public func lowercaseStringWithLocale(_ locale: NSLocale?) -> String {
        return _ns.lowercaseStringWithLocale(locale)
    }
    
    // - (NSUInteger)maximumLengthOfBytesUsingEncoding:(NSStringEncoding)enc
    
    /// Returns the maximum number of bytes needed to store the
    /// `String` in a given encoding.
    @warn_unused_result
    public
    func maximumLengthOfBytesUsingEncoding(_ encoding: NSStringEncoding) -> Int {
        return _ns.maximumLengthOfBytesUsingEncoding(encoding)
    }
    
    // - (NSRange)paragraphRangeForRange:(NSRange)aRange
    
    /// Returns the range of characters representing the
    /// paragraph or paragraphs containing a given range.
    @warn_unused_result
    public func paragraphRangeForRange(_ aRange: Range<Index>) -> Range<Index> {
        return _range(_ns.paragraphRangeForRange(_toNSRange(aRange)))
    }
    
    // @property NSArray* pathComponents
    
    /// Returns an array of NSString objects containing, in
    /// order, each path component of the `String`.
    public var pathComponents: [String] {
        return _ns.pathComponents
    }
    
    // @property NSString* pathExtension;
    
    /// Interprets the `String` as a path and returns the
    /// `String`’s extension, if any.
    public var pathExtension: String {
        return _ns.pathExtension
    }
    
    // @property NSString* precomposedStringWithCanonicalMapping;
    
    /// Returns a string made by normalizing the `String`’s
    /// contents using Form C.
    public var precomposedStringWithCanonicalMapping: String {
        return _ns.precomposedStringWithCanonicalMapping
    }
    
    // @property NSString * precomposedStringWithCompatibilityMapping;
    
    /// Returns a string made by normalizing the `String`’s
    /// contents using Form KC.
    public var precomposedStringWithCompatibilityMapping: String {
        return _ns.precomposedStringWithCompatibilityMapping
    }
#if false // TODO: this needs an implementation that works for the swift-corelibs-foundation version of this API
    // - (id)propertyList
    
    /// Parses the `String` as a text representation of a
    /// property list, returning an NSString, NSData, NSArray, or
    /// NSDictionary object, according to the topmost element.
    @warn_unused_result
    public func propertyList() -> AnyObject {
        return _ns.propertyList()
    }
    
    // - (NSDictionary *)propertyListFromStringsFileFormat
    
    /// Returns a dictionary object initialized with the keys and
    /// values found in the `String`.
    @warn_unused_result
    public
    func propertyListFromStringsFileFormat() -> [String : String] {
        return _ns.propertyListFromStringsFileFormat() as! [String : String]
    }
#endif
    
    // - (NSRange)rangeOfCharacterFromSet:(NSCharacterSet *)aSet
    //
    // - (NSRange)
    //     rangeOfCharacterFromSet:(NSCharacterSet *)aSet
    //     options:(NSStringCompareOptions)mask
    //
    // - (NSRange)
    //     rangeOfCharacterFromSet:(NSCharacterSet *)aSet
    //     options:(NSStringCompareOptions)mask
    //     range:(NSRange)aRange
    
    /// Finds and returns the range in the `String` of the first
    /// character from a given character set found in a given range with
    /// given options.
    @warn_unused_result
    public func rangeOfCharacterFromSet(
        _ aSet: NSCharacterSet,
        options mask:NSStringCompareOptions = [],
        range aRange: Range<Index>? = nil
        ) -> Range<Index>? {
        return _optionalRange(
            _ns.rangeOfCharacterFromSet(
                aSet, options: mask,
                range: _toNSRange(aRange ?? self.characters.indices)))
    }
    
    // - (NSRange)rangeOfComposedCharacterSequenceAtIndex:(NSUInteger)anIndex
    
    /// Returns the range in the `String` of the composed
    /// character sequence located at a given index.
    @warn_unused_result
    public
    func rangeOfComposedCharacterSequenceAtIndex(_ anIndex: Index) -> Range<Index> {
        return _range(
            _ns.rangeOfComposedCharacterSequenceAtIndex(anIndex._utf16Index))
    }
    
    // - (NSRange)rangeOfComposedCharacterSequencesForRange:(NSRange)range
    
    /// Returns the range in the string of the composed character
    /// sequences for a given range.
    @warn_unused_result
    public func rangeOfComposedCharacterSequencesForRange(
        _ range: Range<Index>
        ) -> Range<Index> {
        // Theoretically, this will be the identity function.  In practice
        // I think users will be able to observe differences in the input
        // and output ranges due (if nothing else) to locale changes
        return _range(
            _ns.rangeOfComposedCharacterSequencesForRange(_toNSRange(range)))
    }
    
    // - (NSRange)rangeOfString:(NSString *)aString
    //
    // - (NSRange)
    //     rangeOfString:(NSString *)aString options:(NSStringCompareOptions)mask
    //
    // - (NSRange)
    //     rangeOfString:(NSString *)aString
    //     options:(NSStringCompareOptions)mask
    //     range:(NSRange)aRange
    //
    // - (NSRange)
    //     rangeOfString:(NSString *)aString
    //     options:(NSStringCompareOptions)mask
    //     range:(NSRange)searchRange
    //     locale:(NSLocale *)locale
    
    /// Finds and returns the range of the first occurrence of a
    /// given string within a given range of the `String`, subject to
    /// given options, using the specified locale, if any.
    @warn_unused_result
    public func rangeOfString(
        _ aString: String,
        options mask: NSStringCompareOptions = [],
        range searchRange: Range<Index>? = nil,
        locale: NSLocale? = nil
        ) -> Range<Index>? {
        return _optionalRange(
            locale != nil ? _ns.rangeOfString(
                aString, options: mask,
                range: _toNSRange(searchRange ?? self.characters.indices),
                locale: locale
                )
                : searchRange != nil ? _ns.rangeOfString(
                    aString, options: mask, range: _toNSRange(searchRange!)
                    )
                : !mask.isEmpty ? _ns.rangeOfString(aString, options: mask)
                : _ns.rangeOfString(aString)
        )
    }
    
    // - (BOOL)localizedStandardContainsString:(NSString *)str NS_AVAILABLE(10_11, 9_0);
    
    /// Returns `true` if `self` contains `string`, taking the current locale
    /// into account.
    ///
    /// This is the most appropriate method for doing user-level string searches,
    /// similar to how searches are done generally in the system.  The search is
    /// locale-aware, case and diacritic insensitive.  The exact list of search
    /// options applied may change over time.
    @warn_unused_result
    public func localizedStandardContainsString(_ string: String) -> Bool {
        return _ns.localizedStandardContainsString(string)
    }
    
    // - (NSRange)localizedStandardRangeOfString:(NSString *)str NS_AVAILABLE(10_11, 9_0);
    
    /// Finds and returns the range of the first occurrence of a given string,
    /// taking the current locale into account.  Returns `nil` if the string was
    /// not found.
    ///
    /// This is the most appropriate method for doing user-level string searches,
    /// similar to how searches are done generally in the system.  The search is
    /// locale-aware, case and diacritic insensitive.  The exact list of search
    /// options applied may change over time.
    @warn_unused_result
    public func localizedStandardRangeOfString(_ string: String) -> Range<Index>? {
        return _optionalRange(_ns.localizedStandardRangeOfString(string))
    }
    
    // @property NSStringEncoding smallestEncoding;
    
    /// Returns the smallest encoding to which the `String` can
    /// be converted without loss of information.
    public var smallestEncoding: NSStringEncoding {
        return _ns.smallestEncoding
    }
    
#if false // TODO: this needs an implementation that works for the swift-corelibs-foundation version of this API
    // @property NSString *stringByAbbreviatingWithTildeInPath;
    
    /// Returns a new string that replaces the current home
    /// directory portion of the current path with a tilde (`~`)
    /// character.
    public var stringByAbbreviatingWithTildeInPath: String {
        return _ns.stringByAbbreviatingWithTildeInPath
    }
#endif
    // - (NSString *)
    //     stringByAddingPercentEncodingWithAllowedCharacters:
    //       (NSCharacterSet *)allowedCharacters
    
    /// Returns a new string made from the `String` by replacing
    /// all characters not in the specified set with percent encoded
    /// characters.
    @warn_unused_result
    public func stringByAddingPercentEncodingWithAllowedCharacters(
        _ allowedCharacters: NSCharacterSet
        ) -> String? {
        // FIXME: the documentation states that this method can return nil if the
        // transformation is not possible, without going into further details.  The
        // implementation can only return nil if malloc() returns nil, so in
        // practice this is not possible.  Still, to be consistent with
        // documentation, we declare the method as returning an optional String.
        //
        // <rdar://problem/17901698> Docs for -[NSString
        // stringByAddingPercentEncodingWithAllowedCharacters] don't precisely
        // describe when return value is nil
        return _ns.stringByAddingPercentEncodingWithAllowedCharacters(
            allowedCharacters
        )
    }
    
    // - (NSString *)
    //     stringByAddingPercentEscapesUsingEncoding:(NSStringEncoding)encoding
#if false // TODO: this needs an implementation that works for the swift-corelibs-foundation version of this API
    /// Returns a representation of the `String` using a given
    /// encoding to determine the percent escapes necessary to convert
    /// the `String` into a legal URL string.
    public func stringByAddingPercentEscapesUsingEncoding(
        _ encoding: NSStringEncoding
        ) -> String? {
        return _ns.stringByAddingPercentEscapesUsingEncoding(encoding)
    }
#endif
    
    // - (NSString *)stringByAppendingFormat:(NSString *)format, ...
    
    /// Returns a string made by appending to the `String` a
    /// string constructed from a given format string and the following
    /// arguments.
    @warn_unused_result
    public func stringByAppendingFormat(
        _ format: String, _ arguments: CVarArg...
        ) -> String {
        return _ns.stringByAppendingString(
            String(format: format, arguments: arguments))
    }
    
    // - (NSString *)stringByAppendingPathComponent:(NSString *)aString
    
    /// Returns a new string made by appending to the `String` a given string.
    public func stringByAppendingPathComponent(_ aString: String) -> String {
        return _ns.stringByAppendingPathComponent(aString)
    }
    
    // - (NSString *)stringByAppendingPathExtension:(NSString *)ext
    
    /// Returns a new string made by appending to the `String` an
    /// extension separator followed by a given extension.
    public func stringByAppendingPathExtension(_ ext: String) -> String? {
        // FIXME: This method can return nil in practice, for example when self is
        // an empty string.  OTOH, this is not documented, documentation says that
        // it always returns a string.
        //
        // <rdar://problem/17902469> -[NSString stringByAppendingPathExtension] can
        // return nil
        return _ns.stringByAppendingPathExtension(ext)
    }
    
    // - (NSString *)stringByAppendingString:(NSString *)aString
    
    /// Returns a new string made by appending a given string to
    /// the `String`.
    @warn_unused_result
    public func stringByAppendingString(_ aString: String) -> String {
        return _ns.stringByAppendingString(aString)
    }
    
    // @property NSString* stringByDeletingLastPathComponent;
    
    /// Returns a new string made by deleting the last path
    /// component from the `String`, along with any final path
    /// separator.
    public var stringByDeletingLastPathComponent: String {
        return _ns.stringByDeletingLastPathComponent
    }
    
    // @property NSString* stringByDeletingPathExtension;
    
    /// Returns a new string made by deleting the extension (if
    /// any, and only the last) from the `String`.
    public var stringByDeletingPathExtension: String {
        return _ns.stringByDeletingPathExtension
    }
    
    // @property NSString* stringByExpandingTildeInPath;
    
    /// Returns a new string made by expanding the initial
    /// component of the `String` to its full path value.
    public var stringByExpandingTildeInPath: String {
        return _ns.stringByExpandingTildeInPath
    }
    
    // - (NSString *)
    //     stringByFoldingWithOptions:(NSStringCompareOptions)options
    //     locale:(NSLocale *)locale
    
    /// Returns a string with the given character folding options
    /// applied.
    @warn_unused_result
    public func stringByFoldingWithOptions(
        _ options: NSStringCompareOptions, locale: NSLocale?
        ) -> String {
        return _ns.stringByFoldingWithOptions(options, locale: locale)
    }
    
    // - (NSString *)stringByPaddingToLength:(NSUInteger)newLength
    //     withString:(NSString *)padString
    //     startingAtIndex:(NSUInteger)padIndex
    
    /// Returns a new string formed from the `String` by either
    /// removing characters from the end, or by appending as many
    /// occurrences as necessary of a given pad string.
    @warn_unused_result
    public func stringByPaddingToLength(
        _ newLength: Int, withString padString: String, startingAtIndex padIndex: Int
        ) -> String {
        return _ns.stringByPaddingToLength(
            newLength, withString: padString, startingAtIndex: padIndex)
    }
    
    // @property NSString* stringByRemovingPercentEncoding;
    
    /// Returns a new string made from the `String` by replacing
    /// all percent encoded sequences with the matching UTF-8
    /// characters.
    public var stringByRemovingPercentEncoding: String? {
        return _ns.stringByRemovingPercentEncoding
    }
    
    // - (NSString *)
    //     stringByReplacingCharactersInRange:(NSRange)range
    //     withString:(NSString *)replacement
    
    /// Returns a new string in which the characters in a
    /// specified range of the `String` are replaced by a given string.
    @warn_unused_result
    public func stringByReplacingCharactersInRange(
        _ range: Range<Index>, withString replacement: String
        ) -> String {
        return _ns.stringByReplacingCharactersInRange(
            _toNSRange(range), withString: replacement)
    }
    
    // - (NSString *)
    //     stringByReplacingOccurrencesOfString:(NSString *)target
    //     withString:(NSString *)replacement
    //
    // - (NSString *)
    //     stringByReplacingOccurrencesOfString:(NSString *)target
    //     withString:(NSString *)replacement
    //     options:(NSStringCompareOptions)options
    //     range:(NSRange)searchRange
    
    /// Returns a new string in which all occurrences of a target
    /// string in a specified range of the `String` are replaced by
    /// another given string.
    @warn_unused_result
    public func stringByReplacingOccurrencesOfString(
        _ target: String,
        withString replacement: String,
        options: NSStringCompareOptions = [],
        range searchRange: Range<Index>? = nil
        ) -> String {
        return (searchRange != nil) || (!options.isEmpty)
            ? _ns.stringByReplacingOccurrencesOfString(
                target,
                withString: replacement, options: options,
                            range: _toNSRange(searchRange ?? self.characters.indices)
                )
            : _ns.stringByReplacingOccurrencesOfString(target, withString: replacement)
    }
    
    // - (NSString *)
    //     stringByReplacingPercentEscapesUsingEncoding:(NSStringEncoding)encoding
#if false // TODO: this needs an implementation that works for the swift-corelibs-foundation version of this API
    /// Returns a new string made by replacing in the `String`
    /// all percent escapes with the matching characters as determined
    /// by a given encoding.
    public func stringByReplacingPercentEscapesUsingEncoding(
        _ encoding: NSStringEncoding
        ) -> String? {
        return _ns.stringByReplacingPercentEscapesUsingEncoding(encoding)
    }
#endif
    
    // @property NSString* stringByResolvingSymlinksInPath;
    
    /// Returns a new string made from the `String` by resolving
    /// all symbolic links and standardizing path.
    public var stringByResolvingSymlinksInPath: String {
        return _ns.stringByResolvingSymlinksInPath
    }
    
    // @property NSString* stringByStandardizingPath;
    
    /// Returns a new string made by removing extraneous path
    /// components from the `String`.
    public var stringByStandardizingPath: String {
        return _ns.stringByStandardizingPath
    }
    
    // - (NSString *)stringByTrimmingCharactersInSet:(NSCharacterSet *)set
    
    /// Returns a new string made by removing from both ends of
    /// the `String` characters contained in a given character set.
    @warn_unused_result
    public func stringByTrimmingCharactersInSet(_ set: NSCharacterSet) -> String {
        return _ns.stringByTrimmingCharactersInSet(set)
    }
    
    // - (NSArray *)stringsByAppendingPaths:(NSArray *)paths
    
    /// Returns an array of strings made by separately appending
    /// to the `String` each string in a given array.
    public func stringsByAppendingPaths(_ paths: [String]) -> [String] {
        return _ns.stringsByAppendingPaths(paths)
    }
    
    // - (NSString *)substringFromIndex:(NSUInteger)anIndex
    
    /// Returns a new string containing the characters of the
    /// `String` from the one at a given index to the end.
    @warn_unused_result
    public func substringFromIndex(_ index: Index) -> String {
        return _ns.substringFromIndex(index._utf16Index)
    }
    
    // - (NSString *)substringToIndex:(NSUInteger)anIndex
    
    /// Returns a new string containing the characters of the
    /// `String` up to, but not including, the one at a given index.
    @warn_unused_result
    public func substringToIndex(_ index: Index) -> String {
        return _ns.substringToIndex(index._utf16Index)
    }
    
    // - (NSString *)substringWithRange:(NSRange)aRange
    
    /// Returns a string object containing the characters of the
    /// `String` that lie within a given range.
    @warn_unused_result
    public func substringWithRange(_ aRange: Range<Index>) -> String {
        return _ns.substringWithRange(_toNSRange(aRange))
    }
    
    // @property (readonly, copy) NSString *localizedUppercaseString NS_AVAILABLE(10_11, 9_0);
    
    /// An uppercase version of the string that is produced using the current
    /// locale.
    public var localizedUppercaseString: String {
        return _ns.localizedUppercaseString as String
    }
    
    // - (NSString *)uppercaseStringWithLocale:(NSLocale *)locale
    
    /// Returns a version of the string with all letters
    /// converted to uppercase, taking into account the specified
    /// locale.
    @warn_unused_result
    public func uppercaseStringWithLocale(_ locale: NSLocale?) -> String {
        return _ns.uppercaseStringWithLocale(locale)
    }
    
    //===--- Omitted due to redundancy with "utf8" property -----------------===//
    // - (const char *)UTF8String
    
    // - (BOOL)
    //     writeToFile:(NSString *)path
    //     atomically:(BOOL)useAuxiliaryFile
    //     encoding:(NSStringEncoding)enc
    //     error:(NSError **)error
    
    /// Writes the contents of the `String` to a file at a given
    /// path using a given encoding.
    public func writeToFile(
        _ path: String, atomically useAuxiliaryFile:Bool,
        encoding enc: NSStringEncoding
        ) throws {
        try self._ns.writeToFile(
            path, atomically: useAuxiliaryFile, encoding: enc)
    }
    
    // - (BOOL)
    //     writeToURL:(NSURL *)url
    //     atomically:(BOOL)useAuxiliaryFile
    //     encoding:(NSStringEncoding)enc
    //     error:(NSError **)error
    
    /// Writes the contents of the `String` to the URL specified
    /// by url using the specified encoding.
    public func writeToURL(
        _ url: NSURL, atomically useAuxiliaryFile: Bool,
        encoding enc: NSStringEncoding
        ) throws {
        try self._ns.writeToURL(
            url, atomically: useAuxiliaryFile, encoding: enc)
    }
    
    // - (nullable NSString *)stringByApplyingTransform:(NSString *)transform reverse:(BOOL)reverse NS_AVAILABLE(10_11, 9_0);
    
    /// Perform string transliteration.
    @warn_unused_result
    public func stringByApplyingTransform(
        _ transform: String, reverse: Bool
        ) -> String? {
        return _ns.stringByApplyingTransform(transform, reverse: reverse)
    }
    
    //===--- From the 10.10 release notes; not in public documentation ------===//
    // No need to make these unavailable on earlier OSes, since they can
    // forward trivially to rangeOfString.
    
    /// Returns `true` iff `other` is non-empty and contained within
    /// `self` by case-sensitive, non-literal search.
    ///
    /// Equivalent to `self.rangeOfString(other) != nil`
    @warn_unused_result
    public func containsString(_ other: String) -> Bool {
        let r = self.rangeOfString(other) != nil
        return r
    }
    
    /// Returns `true` iff `other` is non-empty and contained within
    /// `self` by case-insensitive, non-literal search, taking into
    /// account the current locale.
    ///
    /// Locale-independent case-insensitive operation, and other needs,
    /// can be achieved by calling
    /// `rangeOfString(_:options:_,range:_locale:_)`.
    ///
    /// Equivalent to
    ///
    ///     self.rangeOfString(
    ///       other, options: .CaseInsensitiveSearch,
    ///       locale: NSLocale.currentLocale()) != nil
    @warn_unused_result
    public func localizedCaseInsensitiveContainsString(_ other: String) -> Bool {
        let r = self.rangeOfString(
            other, options: .CaseInsensitiveSearch, locale: NSLocale.currentLocale()
            ) != nil
        return r
    }
}

#if !_runtime(_ObjC)
import CoreFoundation

extension String {
    public func hasPrefix(_ prefix: String) -> Bool {
        let cfstring = self._cfObject
        let range = CFRangeMake(0, CFStringGetLength(cfstring))
        let opts = CFStringCompareFlags(
            kCFCompareAnchored | kCFCompareNonliteral)

        return CFStringFindWithOptions(cfstring, prefix._cfObject,
            range, opts, nil)
    }

    public func hasSuffix(_ suffix: String) -> Bool {
        let cfstring = self._cfObject
        let range = CFRangeMake(0, CFStringGetLength(cfstring))
        let opts = CFStringCompareFlags(
            kCFCompareAnchored | kCFCompareBackwards | kCFCompareNonliteral)

        return CFStringFindWithOptions(cfstring, suffix._cfObject,
            range, opts, nil)
    }
}
#endif
