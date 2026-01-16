//
//  HTMLTextExtractor.swift
//  SwiftSpeakCore
//
//  Extracts readable text content from HTML
//  Shared between iOS and macOS
//

import Foundation

// MARK: - HTML Text Extractor

/// Extracts and cleans text content from HTML
/// Removes scripts, styles, navigation, and other non-content elements
public final class HTMLTextExtractor: Sendable {

    public init() {}

    // MARK: - Public Methods

    /// Extract main text content from HTML
    /// - Parameter html: Raw HTML string
    /// - Returns: Cleaned text content
    public func extractMainContent(from html: String) -> String {
        var content = html

        // Remove script tags and their content
        content = removeTag(content, tag: "script")

        // Remove style tags and their content
        content = removeTag(content, tag: "style")

        // Remove noscript (fallback content)
        content = removeTag(content, tag: "noscript")

        // Remove SVG (icons, graphics)
        content = removeTag(content, tag: "svg")

        // Remove HTML comments
        content = removeHTMLComments(content)

        // Try to extract main content area
        // Strategy: Use body content with navigation elements removed
        // This captures all page content rather than just one section
        if let bodyContent = extractTagContent(content, tag: "body") {
            content = bodyContent
            // Remove navigation elements that don't contain main content
            content = removeTag(content, tag: "nav")
            content = removeTag(content, tag: "footer")
            content = removeTag(content, tag: "aside")
        }
        // If no body found, use full content (already cleaned of scripts/styles)

        // Strip remaining HTML tags
        content = stripTags(content)

        // Decode HTML entities
        content = decodeHTMLEntities(content)

        // Clean up whitespace
        content = cleanWhitespace(content)

        return content
    }

    /// Strip all HTML tags from string
    /// - Parameter html: HTML string
    /// - Returns: Plain text without tags
    public func stripTags(_ html: String) -> String {
        // Replace block elements with newlines
        var result = html
        let blockElements = ["</p>", "</div>", "</h1>", "</h2>", "</h3>", "</h4>", "</h5>", "</h6>",
                            "</li>", "</tr>", "</br>", "<br>", "<br/>", "<br />"]

        for element in blockElements {
            result = result.replacingOccurrences(of: element, with: "\n", options: .caseInsensitive)
        }

        // Remove all remaining tags
        let tagPattern = try? NSRegularExpression(pattern: "<[^>]+>", options: .caseInsensitive)
        result = tagPattern?.stringByReplacingMatches(
            in: result,
            options: [],
            range: NSRange(result.startIndex..., in: result),
            withTemplate: ""
        ) ?? result

        return result
    }

    /// Extract title from HTML
    /// - Parameter html: Raw HTML string
    /// - Returns: Title if found
    public func extractTitle(from html: String) -> String? {
        // Try <title> tag first
        if let title = extractTagContent(html, tag: "title") {
            let cleaned = stripTags(title).trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleaned.isEmpty {
                return cleaned
            }
        }

        // Try og:title meta tag
        let ogTitlePattern = try? NSRegularExpression(
            pattern: #"<meta[^>]*property=["\']og:title["\'][^>]*content=["\']([^"\']+)["\']"#,
            options: .caseInsensitive
        )
        if let match = ogTitlePattern?.firstMatch(in: html, options: [], range: NSRange(html.startIndex..., in: html)),
           let range = Range(match.range(at: 1), in: html) {
            return String(html[range])
        }

        // Try h1 tag
        if let h1 = extractTagContent(html, tag: "h1") {
            let cleaned = stripTags(h1).trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleaned.isEmpty {
                return cleaned
            }
        }

        return nil
    }

    // MARK: - Private Methods

    private func removeTag(_ html: String, tag: String) -> String {
        // Pattern to match opening tag through closing tag (non-greedy)
        let pattern = "<\(tag)[^>]*>.*?</\(tag)>"
        let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators])
        return regex?.stringByReplacingMatches(
            in: html,
            options: [],
            range: NSRange(html.startIndex..., in: html),
            withTemplate: ""
        ) ?? html
    }

    private func extractTagContent(_ html: String, tag: String) -> String? {
        // Use a greedy pattern to get the full content between tags
        // We need to handle nested tags properly
        let openTag = "<\(tag)[^>]*>"
        let closeTag = "</\(tag)>"

        guard let openRegex = try? NSRegularExpression(pattern: openTag, options: .caseInsensitive),
              let openMatch = openRegex.firstMatch(in: html, options: [], range: NSRange(html.startIndex..., in: html)),
              let openRange = Range(openMatch.range, in: html) else {
            return nil
        }

        let contentStart = openRange.upperBound
        let searchRange = html[contentStart...]

        // Find the matching close tag (accounting for nesting)
        var depth = 1
        var currentIndex = searchRange.startIndex

        while depth > 0 && currentIndex < searchRange.endIndex {
            let remainingString = String(searchRange[currentIndex...])

            // Check for opening tag
            if let nextOpen = try? NSRegularExpression(pattern: openTag, options: .caseInsensitive)
                .firstMatch(in: remainingString, options: [], range: NSRange(remainingString.startIndex..., in: remainingString)),
               let nextClose = remainingString.range(of: closeTag, options: .caseInsensitive) {

                let openPos = remainingString.distance(from: remainingString.startIndex, to: Range(nextOpen.range, in: remainingString)?.lowerBound ?? remainingString.endIndex)
                let closePos = remainingString.distance(from: remainingString.startIndex, to: nextClose.lowerBound)

                if openPos < closePos {
                    depth += 1
                    currentIndex = searchRange.index(currentIndex, offsetBy: openPos + 1)
                } else {
                    depth -= 1
                    if depth == 0 {
                        let contentEnd = searchRange.index(currentIndex, offsetBy: closePos)
                        return String(html[contentStart..<contentEnd])
                    }
                    currentIndex = searchRange.index(currentIndex, offsetBy: closePos + closeTag.count)
                }
            } else if let nextClose = remainingString.range(of: closeTag, options: .caseInsensitive) {
                depth -= 1
                if depth == 0 {
                    let closePos = remainingString.distance(from: remainingString.startIndex, to: nextClose.lowerBound)
                    let contentEnd = searchRange.index(currentIndex, offsetBy: closePos)
                    return String(html[contentStart..<contentEnd])
                }
                currentIndex = searchRange.index(currentIndex, offsetBy: remainingString.distance(from: remainingString.startIndex, to: nextClose.upperBound))
            } else {
                break
            }
        }

        return nil
    }

    /// Extract all occurrences of a tag and return the largest one
    private func extractLargestTagContent(_ html: String, tag: String) -> String? {
        var results: [String] = []
        var searchHtml = html

        while let content = extractTagContent(searchHtml, tag: tag) {
            results.append(content)
            // Remove this occurrence and search for more
            if let range = searchHtml.range(of: "<\(tag)", options: .caseInsensitive) {
                searchHtml = String(searchHtml[range.upperBound...])
            } else {
                break
            }
        }

        // Return the largest content
        return results.max(by: { stripTags($0).count < stripTags($1).count })
    }

    private func removeHTMLComments(_ html: String) -> String {
        let pattern = "<!--.*?-->"
        let regex = try? NSRegularExpression(pattern: pattern, options: .dotMatchesLineSeparators)
        return regex?.stringByReplacingMatches(
            in: html,
            options: [],
            range: NSRange(html.startIndex..., in: html),
            withTemplate: ""
        ) ?? html
    }

    private func decodeHTMLEntities(_ text: String) -> String {
        var result = text

        // Common HTML entities
        let entities: [(String, String)] = [
            ("&nbsp;", " "),
            ("&amp;", "&"),
            ("&lt;", "<"),
            ("&gt;", ">"),
            ("&quot;", "\""),
            ("&apos;", "'"),
            ("&#39;", "'"),
            ("&mdash;", "—"),
            ("&ndash;", "–"),
            ("&hellip;", "..."),
            ("&copy;", "©"),
            ("&reg;", "®"),
            ("&trade;", "™"),
            ("&bull;", "•"),
            ("&lsquo;", "\u{2018}"),  // '
            ("&rsquo;", "\u{2019}"),  // '
            ("&ldquo;", "\u{201C}"),  // "
            ("&rdquo;", "\u{201D}"),  // "
        ]

        for (entity, replacement) in entities {
            result = result.replacingOccurrences(of: entity, with: replacement, options: .caseInsensitive)
        }

        // Numeric entities (&#123; or &#x1F;)
        let numericPattern = try? NSRegularExpression(pattern: "&#(x?[0-9a-fA-F]+);", options: [])
        if let regex = numericPattern {
            let matches = regex.matches(in: result, options: [], range: NSRange(result.startIndex..., in: result))
            for match in matches.reversed() {
                if let range = Range(match.range, in: result),
                   let codeRange = Range(match.range(at: 1), in: result) {
                    let codeStr = String(result[codeRange])
                    var codePoint: Int?
                    if codeStr.hasPrefix("x") || codeStr.hasPrefix("X") {
                        codePoint = Int(codeStr.dropFirst(), radix: 16)
                    } else {
                        codePoint = Int(codeStr)
                    }
                    if let cp = codePoint, let scalar = Unicode.Scalar(cp) {
                        result.replaceSubrange(range, with: String(Character(scalar)))
                    }
                }
            }
        }

        return result
    }

    private func cleanWhitespace(_ text: String) -> String {
        var result = text

        // Replace multiple spaces with single space
        let multipleSpaces = try? NSRegularExpression(pattern: "[ \\t]+", options: [])
        result = multipleSpaces?.stringByReplacingMatches(
            in: result,
            options: [],
            range: NSRange(result.startIndex..., in: result),
            withTemplate: " "
        ) ?? result

        // Replace multiple newlines with double newline
        let multipleNewlines = try? NSRegularExpression(pattern: "\\n{3,}", options: [])
        result = multipleNewlines?.stringByReplacingMatches(
            in: result,
            options: [],
            range: NSRange(result.startIndex..., in: result),
            withTemplate: "\n\n"
        ) ?? result

        // Trim each line
        let lines = result.components(separatedBy: "\n")
        let trimmedLines = lines.map { $0.trimmingCharacters(in: .whitespaces) }
        result = trimmedLines.joined(separator: "\n")

        // Trim overall
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)

        return result
    }
}

// MARK: - Static Convenience Methods

public extension HTMLTextExtractor {
    /// Static convenience method to extract main content
    static func extractMainContent(from html: String) -> String {
        HTMLTextExtractor().extractMainContent(from: html)
    }

    /// Static convenience method to strip tags
    static func stripTags(_ html: String) -> String {
        HTMLTextExtractor().stripTags(html)
    }

    /// Static convenience method to extract title
    static func extractTitle(from html: String) -> String? {
        HTMLTextExtractor().extractTitle(from: html)
    }
}
