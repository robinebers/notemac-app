import Testing
import Foundation
@testable import NoteMac

@Suite("FileService Tests")
struct FileServiceTests {

    // Helper to create a temporary directory for each test
    func withTempDirectory(_ test: (URL) throws -> Void) throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        defer {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        try test(tempDirectory)
    }

    // MARK: - Load Tests

    @Test("Load UTF-8 file")
    func loadUTF8File() throws {
        try withTempDirectory { tempDirectory in
            // Given: A UTF-8 encoded text file
            let testContent = "Hello, World!\nThis is a test."
            let fileURL = tempDirectory.appendingPathComponent("test.txt")
            try testContent.write(to: fileURL, atomically: true, encoding: .utf8)

            // When: Loading the file
            let result = try FileService.load(from: fileURL)

            // Then: Content should match and encoding should be UTF-8
            #expect(result.content == testContent)
            #expect(result.encoding == .utf8)
            #expect(result.encodingName == "UTF-8")
            #expect(result.lineEnding == .lf)
        }
    }

    @Test("Load markdown file")
    func loadMarkdownFile() throws {
        try withTempDirectory { tempDirectory in
            // Given: A markdown file
            let testContent = "# Heading\n\nSome content."
            let fileURL = tempDirectory.appendingPathComponent("test.md")
            try testContent.write(to: fileURL, atomically: true, encoding: .utf8)

            // When: Loading the file
            let result = try FileService.load(from: fileURL)

            // Then: File should load successfully
            #expect(result.content == testContent)
            #expect(result.encoding == .utf8)
        }
    }

    @Test("Load file with .markdown extension")
    func loadFileWithMarkdownExtension() throws {
        try withTempDirectory { tempDirectory in
            // Given: A file with .markdown extension
            let testContent = "Test content"
            let fileURL = tempDirectory.appendingPathComponent("test.markdown")
            try testContent.write(to: fileURL, atomically: true, encoding: .utf8)

            // When: Loading the file
            let result = try FileService.load(from: fileURL)

            // Then: File should load successfully
            #expect(result.content == testContent)
        }
    }

    @Test("Load UTF-16 file")
    func loadUTF16File() throws {
        try withTempDirectory { tempDirectory in
            // Given: A UTF-16 encoded file
            let testContent = "UTF-16 content"
            let fileURL = tempDirectory.appendingPathComponent("test.txt")
            try testContent.write(to: fileURL, atomically: true, encoding: .utf16)

            // When: Loading the file
            let result = try FileService.load(from: fileURL)

            // Then: Content should match and encoding should be UTF-16
            #expect(result.content == testContent)
            #expect(result.encoding == .utf16)
            #expect(result.encodingName == "UTF-16")
        }
    }

    @Test("Load ASCII file")
    func loadASCIIFile() throws {
        try withTempDirectory { tempDirectory in
            // Given: An ASCII file
            let testContent = "ASCII content"
            let fileURL = tempDirectory.appendingPathComponent("test.txt")
            try testContent.write(to: fileURL, atomically: true, encoding: .ascii)

            // When: Loading the file
            let result = try FileService.load(from: fileURL)

            // Then: Content should match and encoding should be detected
            #expect(result.content == testContent)
            // Note: ASCII might be detected as UTF-8 since UTF-8 is backward compatible
            #expect(result.encoding == .ascii || result.encoding == .utf8)
        }
    }

    // MARK: - Save Tests

    @Test("Save and reload file")
    func saveAndReloadFile() throws {
        try withTempDirectory { tempDirectory in
            // Given: Content to save
            let testContent = "Save test content\nLine 2"
            let fileURL = tempDirectory.appendingPathComponent("save_test.txt")

            // When: Saving the file
            try FileService.save(content: testContent, to: fileURL)

            // Then: File should exist and be reloadable
            #expect(FileManager.default.fileExists(atPath: fileURL.path))

            let result = try FileService.load(from: fileURL)
            #expect(result.content == testContent)
            #expect(result.encoding == .utf8)
            #expect(result.encodingName == "UTF-8")
        }
    }

    @Test("Save creates intermediate directories")
    func saveCreatesIntermediateDirectories() throws {
        try withTempDirectory { tempDirectory in
            // Given: A file path with non-existent intermediate directories
            let testContent = "Nested save test"
            let nestedURL = tempDirectory
                .appendingPathComponent("nested", isDirectory: true)
                .appendingPathComponent("deep", isDirectory: true)
                .appendingPathComponent("test.txt")

            // When: Saving the file
            try FileService.save(content: testContent, to: nestedURL)

            // Then: File and directories should be created
            #expect(FileManager.default.fileExists(atPath: nestedURL.path))

            let result = try FileService.load(from: nestedURL)
            #expect(result.content == testContent)
        }
    }

    @Test("Save overwrites existing file")
    func saveOverwritesExistingFile() throws {
        try withTempDirectory { tempDirectory in
            // Given: An existing file
            let fileURL = tempDirectory.appendingPathComponent("overwrite.txt")
            let originalContent = "Original content"
            try originalContent.write(to: fileURL, atomically: true, encoding: .utf8)

            // When: Saving new content
            let newContent = "New content"
            try FileService.save(content: newContent, to: fileURL)

            // Then: File should contain new content
            let result = try FileService.load(from: fileURL)
            #expect(result.content == newContent)
        }
    }

    // MARK: - File Type Tests

    @Test("Reject unsupported file type")
    func unsupportedFileTypeRejection() throws {
        try withTempDirectory { tempDirectory in
            // Given: An unsupported file type
            let fileURL = tempDirectory.appendingPathComponent("test.pdf")
            try "content".write(to: fileURL, atomically: true, encoding: .utf8)

            // When/Then: Loading should throw unsupportedFileType error
            #expect(throws: FileServiceError.self) {
                try FileService.load(from: fileURL)
            }
        }
    }

    @Test("Supported file types")
    func isSupportedFileType() {
        // Given: Various file URLs
        let txtURL = URL(fileURLWithPath: "/path/to/file.txt")
        let mdURL = URL(fileURLWithPath: "/path/to/file.md")
        let markdownURL = URL(fileURLWithPath: "/path/to/file.markdown")
        let pdfURL = URL(fileURLWithPath: "/path/to/file.pdf")
        let docURL = URL(fileURLWithPath: "/path/to/file.doc")

        // Then: Only .txt, .md, and .markdown should be supported
        #expect(FileService.isSupportedFileType(txtURL))
        #expect(FileService.isSupportedFileType(mdURL))
        #expect(FileService.isSupportedFileType(markdownURL))
        #expect(!FileService.isSupportedFileType(pdfURL))
        #expect(!FileService.isSupportedFileType(docURL))
    }

    @Test("Supported file types are case insensitive")
    func isSupportedFileTypeCaseInsensitive() {
        // Given: File URLs with mixed case extensions
        let upperTxtURL = URL(fileURLWithPath: "/path/to/file.TXT")
        let upperMdURL = URL(fileURLWithPath: "/path/to/file.MD")
        let mixedURL = URL(fileURLWithPath: "/path/to/file.MaRkDoWn")

        // Then: Should be supported regardless of case
        #expect(FileService.isSupportedFileType(upperTxtURL))
        #expect(FileService.isSupportedFileType(upperMdURL))
        #expect(FileService.isSupportedFileType(mixedURL))
    }

    // MARK: - Line Ending Tests

    @Test("Detect LF line ending")
    func detectLFLineEnding() throws {
        try withTempDirectory { tempDirectory in
            // Given: A file with LF line endings
            let testContent = "Line 1\nLine 2\nLine 3"
            let fileURL = tempDirectory.appendingPathComponent("lf.txt")
            try testContent.write(to: fileURL, atomically: true, encoding: .utf8)

            // When: Loading the file
            let result = try FileService.load(from: fileURL)

            // Then: Line ending should be detected as LF
            #expect(result.lineEnding == .lf)
            #expect(result.lineEnding.displayName == "LF")
        }
    }

    @Test("Detect CRLF line ending")
    func detectCRLFLineEnding() throws {
        try withTempDirectory { tempDirectory in
            // Given: A file with CRLF line endings
            let testContent = "Line 1\r\nLine 2\r\nLine 3"
            let fileURL = tempDirectory.appendingPathComponent("crlf.txt")
            try testContent.write(to: fileURL, atomically: true, encoding: .utf8)

            // When: Loading the file
            let result = try FileService.load(from: fileURL)

            // Then: Line ending should be detected as CRLF
            #expect(result.lineEnding == .crlf)
            #expect(result.lineEnding.displayName == "CRLF")
        }
    }

    @Test("Default line ending for no newlines")
    func defaultLineEndingForNoNewlines() throws {
        try withTempDirectory { tempDirectory in
            // Given: A file with no line endings
            let testContent = "Single line with no newline"
            let fileURL = tempDirectory.appendingPathComponent("single.txt")
            try testContent.write(to: fileURL, atomically: true, encoding: .utf8)

            // When: Loading the file
            let result = try FileService.load(from: fileURL)

            // Then: Should default to LF
            #expect(result.lineEnding == .lf)
        }
    }

    @Test("Mixed line endings detect CRLF")
    func mixedLineEndingsDetectCRLF() throws {
        try withTempDirectory { tempDirectory in
            // Given: A file with both LF and CRLF (CRLF should take precedence)
            let testContent = "Line 1\r\nLine 2\nLine 3\r\n"
            let fileURL = tempDirectory.appendingPathComponent("mixed.txt")
            try testContent.write(to: fileURL, atomically: true, encoding: .utf8)

            // When: Loading the file
            let result = try FileService.load(from: fileURL)

            // Then: Should detect CRLF (more specific)
            #expect(result.lineEnding == .crlf)
        }
    }

    // MARK: - Error Handling Tests

    @Test("Load non-existent file throws error")
    func loadNonExistentFile() throws {
        try withTempDirectory { tempDirectory in
            // Given: A non-existent file URL
            let fileURL = tempDirectory.appendingPathComponent("nonexistent.txt")

            // When/Then: Loading should throw an error
            #expect(throws: Error.self) {
                try FileService.load(from: fileURL)
            }
        }
    }
}
