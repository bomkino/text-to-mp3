# Contributing

Thank you for helping make a tiny tool better without making it bloated.

## Ground rules

- Keep the core journey direct: document or text → voice → MP3.
- Preserve local-first behaviour and honest disclosure before any network request.
- Do not add analytics, accounts, advertising, paywalls, or hidden telemetry.
- Prefer native macOS frameworks and small, inspectable dependencies.
- Treat accessibility, keyboard use, cancellation, and cleanup as core behaviour.
- Never commit generated audio, app bundles, credentials, user documents, or proprietary font files.

## Development

```bash
swift build
./scripts/build-app.sh
```

Before opening a pull request:

1. Build in debug and release configurations.
2. Open both a plain-text file and a selectable-text PDF.
3. Verify a scanned PDF produces the OCR guidance instead of an empty script.
4. Generate and cancel a short MP3 job.
5. Check keyboard operation with `⌘O`, `⌘↩`, `Esc`, and `⇧⌘K`.
6. Inspect the app in both light and dark appearance.
7. Confirm no document contents, local paths, email addresses, credentials, or generated files entered the diff.

Keep pull requests small and explain the user-visible effect, failure mode, and validation performed.
