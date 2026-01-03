# Status Bar Counts Design

## Goal
Replace the status bar encoding, line ending, and document type labels with localized character and word counts. Counts update after a 1000ms debounce.

## UI Behavior
- Left side remains: "Ln X, Col Y".
- Right side becomes: "<characters> chars / <words> words".
- Numbers use system locale formatting (grouping separators, etc.).

## Counting Rules
- Characters: use Swift String.count (grapheme clusters), include whitespace and newlines.
- Words: use localized word boundaries via String.enumerateSubstrings(..., .byWords).

## Debounce
- Debounce updates for 1000ms after content changes.
- Initial render computes counts immediately.
- Use a cancelable Task in StatusBar to avoid extra state in Document.

## Data Flow
- MainWindow passes active document content into StatusBar.
- StatusBar computes counts and formats display text.

## Testing
- Unit tests for count function:
  - Empty string -> 0 chars, 0 words.
  - "Hello world" -> 11 chars, 2 words.
  - Newlines and multiple spaces are counted as characters.

