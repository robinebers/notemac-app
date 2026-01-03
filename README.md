# NoteMac

A modern TextEdit replacement for macOS. Write in Markdown, paste anything, keep it simple.

![NoteMac Screenshot](notemac.png)

## Why NoteMac?

- **Markdown that stays readable** — Live styling without hiding your syntax
- **Paste formatted text** — HTML and rich text convert to clean Markdown automatically
- **Multiple scratch files** — Tabbed interface with drag-to-reorder
- **Session memory** — Reopens everything where you left off
- **Word and character counts** — Always visible in the status bar

Think of it as a scratchpad that understands Markdown. More features coming.

## Download

Grab the latest build from [Releases](https://github.com/robinebers/notemac-app/releases).

Requires macOS 15.0+.

## Development

```bash
swift run        # Run the app
swift test       # Run tests
```

### Build & Notarize

1. Copy `.env.example` to `.env` with your signing credentials
2. Run `./scripts/build-and-notarize.sh`

Output lands in `build/NoteMac.app` and `build/NoteMac.zip`.

## License

MIT
