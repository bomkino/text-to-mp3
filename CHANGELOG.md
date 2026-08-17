# Changelog

## 1.4.0 — 2026-08-17

- Add automatic, on-device Tesseract OCR for scanned and mixed PDFs.
- Bundle the English OCR engine and recognition data so installed builds need no separate setup.
- Show scanned-page stage, page progress, and an ETA after the first OCR page.
- Let Escape and the visible Cancel button stop document reading as well as MP3 generation.
- Preserve the existing editor text when OCR fails or is cancelled.
- Package OCR dependency licence texts, component versions, and SBOM records.
- Add automated plain-text, scanned-PDF, and OCR-cancellation tests.

## 1.3.0 — 2026-08-17

- Add local PDF and plain-text document import.
- Add drag-and-drop and the native `⌘O` open command.
- Explain scanned and password-protected PDF failures.
- Show first-run setup and document-reading stages.
- Add a smoothed time-left estimate and explicit receive/finalize stages for MP3 generation.
- Keep progress monotonic while the estimate recalibrates, and name the active stage.
- Keep status title, percentage, and detail in the native VoiceOver reading order.
- Publish the original source under the MIT License.

## 1.2.1 — 2026-08-17

- Add byte-backed generation progress with percentage and received audio duration.
- Cap in-progress display below completion until MP3 validation succeeds.
- Keep cancellation cleanup and output validation visible and reliable.

## 1.2.0 — 2026-08-17

- Make US English, Ava Multilingual, and 1.5× pace the first-run defaults.
- Expand the pace range to 0.7×–2×.
- Refine the pitch.dog interface, sidebar, accessibility labels, keyboard commands, and status states.
