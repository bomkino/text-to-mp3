# Repository guide

Text to MP3 is a deliberately small native macOS utility. Keep the main path direct: bring in text, choose a voice, save an MP3.

## Source of truth

- Application source: `Sources/TextToMP3App/`
- App metadata: `Packaging/Info.plist`
- Packaging: `scripts/build-app.sh`
- Public behaviour and limits: `README.md`
- Dependency obligations: `THIRD_PARTY_NOTICES.md` and packaged OCR licence/SBOM material

## Before changing code

- Preserve local-first document handling. Text crosses the network only after Generate.
- Do not add analytics, accounts, advertising, subscriptions, hidden telemetry, secrets, or proprietary fonts.
- Keep the Microsoft dependency described as unofficial and changeable.
- Prefer native macOS APIs and focused changes over new dependency stacks.
- Keep OCR local, English-only until another trained-data language is deliberately packaged, and independent of a user's Homebrew installation.
- Preserve keyboard access, readable status, cancellation, cleanup, and the user's current script on failure.

## Verification

```bash
swift build -c debug
./scripts/test.sh
swift build -c release
./scripts/build-app.sh
```

Then exercise TXT import, selectable-PDF import, scanned-PDF OCR, a no-text scan, OCR cancellation, a valid MP3, a long-job ETA, generation cancellation, `Command-O`, and the accessibility reading order. Verify every packaged Mach-O OCR dependency is app-relative. Keep built, tested, released, downloaded, and installed states separate.
