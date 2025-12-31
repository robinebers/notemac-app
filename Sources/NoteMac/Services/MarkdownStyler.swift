import AppKit
import Markdown
import STTextView

// MARK: - Style Types

struct StyledRange {
    let range: NSRange
    let style: StyleType

    enum StyleType {
        case heading(level: Int)
        case bold
        case italic
        case inlineCode
        case link(url: String)
        case strikethrough
        case blockquote
        case listMarker
        case syntax  // Dimmed syntax characters
    }
}

// MARK: - Markdown Range Collector

/// Walks the Markdown AST and collects styled ranges for both content and syntax
struct MarkdownRangeCollector: MarkupWalker {
    let source: String
    private(set) var ranges: [StyledRange] = []

    init(source: String) {
        self.source = source
    }

    // MARK: - Headings

    mutating func visitHeading(_ heading: Heading) -> () {
        guard let sourceRange = heading.range else {
            descendInto(heading)
            return
        }

        let nsRange = nsRange(from: sourceRange)
        ranges.append(StyledRange(range: nsRange, style: .heading(level: heading.level)))

        // Dim the # prefix (level count + 1 for space)
        let prefixLength = heading.level + 1
        if nsRange.length >= prefixLength {
            let syntaxRange = NSRange(location: nsRange.location, length: prefixLength)
            ranges.append(StyledRange(range: syntaxRange, style: .syntax))
        }

        descendInto(heading)
    }

    // MARK: - Bold (Strong)

    mutating func visitStrong(_ strong: Strong) -> () {
        guard let sourceRange = strong.range else {
            descendInto(strong)
            return
        }

        let nsRange = nsRange(from: sourceRange)
        ranges.append(StyledRange(range: nsRange, style: .bold))

        // Dim ** or __ delimiters (2 chars on each side)
        if nsRange.length >= 4 {
            let openRange = NSRange(location: nsRange.location, length: 2)
            let closeRange = NSRange(location: nsRange.location + nsRange.length - 2, length: 2)
            ranges.append(StyledRange(range: openRange, style: .syntax))
            ranges.append(StyledRange(range: closeRange, style: .syntax))
        }

        descendInto(strong)
    }

    // MARK: - Italic (Emphasis)

    mutating func visitEmphasis(_ emphasis: Emphasis) -> () {
        guard let sourceRange = emphasis.range else {
            descendInto(emphasis)
            return
        }

        let nsRange = nsRange(from: sourceRange)
        ranges.append(StyledRange(range: nsRange, style: .italic))

        // Dim * or _ delimiters (1 char on each side)
        if nsRange.length >= 2 {
            let openRange = NSRange(location: nsRange.location, length: 1)
            let closeRange = NSRange(location: nsRange.location + nsRange.length - 1, length: 1)
            ranges.append(StyledRange(range: openRange, style: .syntax))
            ranges.append(StyledRange(range: closeRange, style: .syntax))
        }

        descendInto(emphasis)
    }

    // MARK: - Inline Code

    mutating func visitInlineCode(_ inlineCode: InlineCode) -> () {
        guard let sourceRange = inlineCode.range else { return }

        let nsRange = nsRange(from: sourceRange)
        ranges.append(StyledRange(range: nsRange, style: .inlineCode))

        // Dim ` delimiters
        if nsRange.length >= 2 {
            let openRange = NSRange(location: nsRange.location, length: 1)
            let closeRange = NSRange(location: nsRange.location + nsRange.length - 1, length: 1)
            ranges.append(StyledRange(range: openRange, style: .syntax))
            ranges.append(StyledRange(range: closeRange, style: .syntax))
        }
    }

    // MARK: - Links

    mutating func visitLink(_ link: Link) -> () {
        guard let sourceRange = link.range else {
            descendInto(link)
            return
        }

        let nsRange = nsRange(from: sourceRange)
        ranges.append(StyledRange(range: nsRange, style: .link(url: link.destination ?? "")))

        // Dim [ ] ( ) syntax - mark opening [ and everything from ]( to end
        if nsRange.length >= 4 {
            let openBracket = NSRange(location: nsRange.location, length: 1)
            ranges.append(StyledRange(range: openBracket, style: .syntax))

            // Find the ]( position - it's after the link text
            let text = (source as NSString).substring(with: nsRange)
            if let closeBracketIndex = text.firstIndex(of: "]") {
                let offset = text.distance(from: text.startIndex, to: closeBracketIndex)
                let urlPartRange = NSRange(
                    location: nsRange.location + offset,
                    length: nsRange.length - offset
                )
                ranges.append(StyledRange(range: urlPartRange, style: .syntax))
            }
        }

        descendInto(link)
    }

    // MARK: - Strikethrough

    mutating func visitStrikethrough(_ strikethrough: Strikethrough) -> () {
        guard let sourceRange = strikethrough.range else {
            descendInto(strikethrough)
            return
        }

        let nsRange = nsRange(from: sourceRange)
        ranges.append(StyledRange(range: nsRange, style: .strikethrough))

        // Dim ~~ delimiters
        if nsRange.length >= 4 {
            let openRange = NSRange(location: nsRange.location, length: 2)
            let closeRange = NSRange(location: nsRange.location + nsRange.length - 2, length: 2)
            ranges.append(StyledRange(range: openRange, style: .syntax))
            ranges.append(StyledRange(range: closeRange, style: .syntax))
        }

        descendInto(strikethrough)
    }

    // MARK: - Block Quote

    mutating func visitBlockQuote(_ blockQuote: BlockQuote) -> () {
        guard let sourceRange = blockQuote.range else {
            descendInto(blockQuote)
            return
        }

        let nsRange = nsRange(from: sourceRange)
        ranges.append(StyledRange(range: nsRange, style: .blockquote))

        // Dim > characters at the start of each line
        let text = (source as NSString).substring(with: nsRange)
        var lineStart = 0
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            if line.hasPrefix(">") {
                let markerRange = NSRange(location: nsRange.location + lineStart, length: 1)
                ranges.append(StyledRange(range: markerRange, style: .syntax))
            }
            lineStart += line.count + 1  // +1 for newline
        }

        descendInto(blockQuote)
    }

    // MARK: - List Items

    mutating func visitListItem(_ listItem: ListItem) -> () {
        guard let sourceRange = listItem.range else {
            descendInto(listItem)
            return
        }

        // Find and dim the list marker (-, *, +, or 1., 2., etc.)
        let nsRange = nsRange(from: sourceRange)
        let text = (source as NSString).substring(with: nsRange)

        // Find marker length (bullet or number with period)
        var markerLength = 0
        for char in text {
            if char == "-" || char == "*" || char == "+" {
                markerLength = 1
                break
            } else if char.isNumber {
                markerLength += 1
            } else if char == "." && markerLength > 0 {
                markerLength += 1
                break
            } else if char == " " && markerLength > 0 {
                break
            } else if !char.isWhitespace {
                break
            } else {
                markerLength += 1
            }
        }

        if markerLength > 0 {
            let markerRange = NSRange(location: nsRange.location, length: markerLength)
            ranges.append(StyledRange(range: markerRange, style: .listMarker))
            ranges.append(StyledRange(range: markerRange, style: .syntax))
        }

        descendInto(listItem)
    }

    // MARK: - Helpers

    private func nsRange(from sourceRange: SourceRange) -> NSRange {
        let startOffset = offset(for: sourceRange.lowerBound)
        let endOffset = offset(for: sourceRange.upperBound)
        return NSRange(location: startOffset, length: endOffset - startOffset)
    }

    private func offset(for location: SourceLocation) -> Int {
        var offset = 0
        var line = 1
        var column = 1

        for char in source {
            if line == location.line && column == location.column {
                return offset
            }
            if char == "\n" {
                line += 1
                column = 1
            } else {
                column += 1
            }
            offset += 1
        }

        return offset
    }
}

// MARK: - Markdown Styling Plugin

/// STTextView plugin that applies markdown styling in response to text changes.
/// Uses the plugin event system to properly handle real-time styling without disrupting typing.
@MainActor
final class MarkdownStylingPlugin: STPlugin {
    private let baseFont: NSFont
    private var isApplyingStyles = false

    init(baseFont: NSFont) {
        self.baseFont = baseFont
    }

    func setUp(context: any Context) {
        let textView = context.textView
        let font = self.baseFont

        // Register for text change events - this is called after text is changed
        context.events.onDidChangeText { [weak self] _, _ in
            guard let self, !self.isApplyingStyles else { return }
            self.isApplyingStyles = true
            MarkdownStyler.apply(to: textView, baseFont: font)
            self.isApplyingStyles = false
        }

        // Apply initial styling
        isApplyingStyles = true
        MarkdownStyler.apply(to: textView, baseFont: font)
        isApplyingStyles = false
    }
}

// MARK: - Markdown Styler

struct MarkdownStyler {
    static let syntaxOpacity: CGFloat = 0.4

    /// Apply markdown styling to the text view using STTextView's native attribute methods
    @MainActor
    static func apply(to textView: STTextView, baseFont: NSFont?) {
        let content = textView.string
        guard !content.isEmpty else { return }

        let font = baseFont ?? NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        let textLength = (content as NSString).length
        let fullRange = NSRange(location: 0, length: textLength)

        // Reset to base attributes first
        textView.setAttributes([
            .font: font,
            .foregroundColor: NSColor.labelColor
        ], range: fullRange)

        // Parse markdown and collect ranges
        let markdownDoc = Markdown.Document(parsing: content)
        var collector = MarkdownRangeCollector(source: content)
        collector.visit(markdownDoc)

        // Apply collected styles using STTextView's native addAttributes
        for styledRange in collector.ranges {
            guard styledRange.range.location + styledRange.range.length <= textLength else {
                continue
            }

            switch styledRange.style {
            case .heading(let level):
                let scale: CGFloat = level == 1 ? 1.5 : (level == 2 ? 1.3 : 1.15)
                let headingFont = NSFont.monospacedSystemFont(
                    ofSize: font.pointSize * scale,
                    weight: .bold
                )
                textView.addAttributes([.font: headingFont], range: styledRange.range)

            case .bold:
                let boldFont = NSFont.monospacedSystemFont(
                    ofSize: font.pointSize,
                    weight: .bold
                )
                textView.addAttributes([.font: boldFont], range: styledRange.range)

            case .italic:
                let italicFont = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
                textView.addAttributes([.font: italicFont], range: styledRange.range)

            case .inlineCode:
                let codeFont = NSFont.monospacedSystemFont(ofSize: font.pointSize, weight: .regular)
                textView.addAttributes([
                    .font: codeFont,
                    .backgroundColor: NSColor.labelColor.withAlphaComponent(0.08)
                ], range: styledRange.range)

            case .link:
                textView.addAttributes([
                    .foregroundColor: NSColor.linkColor
                ], range: styledRange.range)

            case .strikethrough:
                textView.addAttributes([
                    .strikethroughStyle: NSUnderlineStyle.single.rawValue
                ], range: styledRange.range)

            case .blockquote:
                let italicFont = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
                textView.addAttributes([.font: italicFont], range: styledRange.range)

            case .listMarker:
                // List markers just get dimmed via .syntax
                break

            case .syntax:
                textView.addAttributes([
                    .foregroundColor: NSColor.labelColor.withAlphaComponent(syntaxOpacity)
                ], range: styledRange.range)
            }
        }
    }
}
