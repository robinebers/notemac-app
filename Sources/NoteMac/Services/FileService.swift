import Foundation

enum FileServiceError: Error {
    case unsupportedFileType
    case encodingDetectionFailed
    case readFailed(Error)
    case writeFailed(Error)
}

struct FileLoadResult {
    let content: String
    let encoding: String.Encoding
    let encodingName: String  // For display: "UTF-8", "UTF-16", etc.
    let lineEnding: LineEnding
}

enum FileService {

    // MARK: - Public API

    /// Load a file from a URL, detecting its encoding and line ending style.
    /// - Parameter url: The URL of the file to load
    /// - Returns: FileLoadResult containing content, encoding, and line ending info
    /// - Throws: FileServiceError if the file type is unsupported or cannot be read
    static func load(from url: URL) throws -> FileLoadResult {
        guard isSupportedFileType(url) else {
            throw FileServiceError.unsupportedFileType
        }

        // Try to detect encoding and read the file
        guard let (content, encoding) = try? detectEncodingAndRead(from: url) else {
            throw FileServiceError.encodingDetectionFailed
        }

        let encodingName = nameForEncoding(encoding)
        let lineEnding = detectLineEnding(in: content)

        return FileLoadResult(
            content: content,
            encoding: encoding,
            encodingName: encodingName,
            lineEnding: lineEnding
        )
    }

    /// Save content to a file URL as UTF-8.
    /// - Parameters:
    ///   - content: The string content to save
    ///   - url: The destination URL
    /// - Throws: FileServiceError.writeFailed if the file cannot be written
    static func save(content: String, to url: URL) throws {
        do {
            // Create intermediate directories if needed
            let directory = url.deletingLastPathComponent()
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: nil
            )

            // Always save as UTF-8
            try content.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            throw FileServiceError.writeFailed(error)
        }
    }

    /// Check if a file type is supported (must be .txt or .md)
    /// - Parameter url: The URL to check
    /// - Returns: true if the file extension is .txt, .md, or .markdown
    static func isSupportedFileType(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return ext == "txt" || ext == "md" || ext == "markdown"
    }

    // MARK: - Private Helpers

    /// Attempt to detect encoding and read file content.
    /// Tries encodings in order: UTF-8, UTF-16, ASCII, ISO Latin 1
    private static func detectEncodingAndRead(from url: URL) throws -> (String, String.Encoding) {
        let encodingsToTry: [String.Encoding] = [
            .utf8,
            .utf16,
            .ascii,
            .isoLatin1
        ]

        for encoding in encodingsToTry {
            if let content = try? String(contentsOf: url, encoding: encoding) {
                return (content, encoding)
            }
        }

        // If all else fails, try to let Foundation guess
        do {
            var usedEncoding: String.Encoding = .utf8
            let content = try String(contentsOf: url, usedEncoding: &usedEncoding)
            return (content, usedEncoding)
        } catch {
            throw FileServiceError.readFailed(error)
        }
    }

    /// Get a human-readable name for a String.Encoding
    private static func nameForEncoding(_ encoding: String.Encoding) -> String {
        switch encoding {
        case .utf8:
            return "UTF-8"
        case .utf16:
            return "UTF-16"
        case .utf16BigEndian:
            return "UTF-16 BE"
        case .utf16LittleEndian:
            return "UTF-16 LE"
        case .utf32:
            return "UTF-32"
        case .utf32BigEndian:
            return "UTF-32 BE"
        case .utf32LittleEndian:
            return "UTF-32 LE"
        case .ascii:
            return "ASCII"
        case .isoLatin1:
            return "ISO Latin 1"
        case .macOSRoman:
            return "Mac OS Roman"
        default:
            return "Unknown"
        }
    }

    /// Detect line ending style (LF vs CRLF) in content
    private static func detectLineEnding(in content: String) -> LineEnding {
        // Check for CRLF first (more specific)
        if content.contains("\r\n") {
            return .crlf
        }
        // Default to LF (Unix/Mac style)
        return .lf
    }
}
