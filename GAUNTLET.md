# Gauntlet receipt — 1.4.1

Date: 2026-08-17

Artifact: `Text to MP3.zip`

SHA-256: `17617fce1c29d857517cd7e7fcfff37ec884e8a7ddd93b01753913264e11d599`

## Frozen bar

- Import text, selectable PDFs, scanned PDFs, and mixed PDFs without uploading the source document.
- Preserve page order, paragraphs, and the existing editor text on failure or cancellation.
- Make OCR progress legible: stage, percentage, page count, and an ETA once measured work exists.
- Let the visible Cancel button and Escape stop OCR and remove temporary page images.
- Ship OCR inside the app, with no Homebrew dependency on the installed machine.
- Keep the app's main path one-purpose: words in, editable script, voice, MP3 out.

## Round 1 — engine qualification

RapidOCR 3.9.2 was tested against a clean English scan and rejected after it mangled ordinary long lines. Tesseract 5.5.3 read the same fixture exactly. The product choice followed recognition quality, not novelty or dependency count.

## Round 2 — integration pressure

- Automated plain-text import passed with 26 words and preserved paragraph separation.
- Automated image-only PDF import entered the OCR stage and recovered both expected English lines.
- Automated cancellation stopped an eight-page OCR import and returned `CancellationError`.
- Post-test inspection found no `TextToMP3-OCR-*` temporary directory residue.
- Runtime import of a genuine image-only PDF recovered the exact 26-word fixture and both paragraphs.
- An icon-only PDF correctly failed with “OCR could not find readable English text” and did not invent content.

## Round 3 — packaged reality

- The release app and bundled Tesseract executable are Apple Silicon Mach-O binaries.
- Every non-system OCR dependency was copied into the app and rewritten to app-relative loader paths.
- Inspection found no `/opt/homebrew` or `/usr/local` reference in the packaged Mach-O dependency graph.
- Bundled Tesseract ran in an empty environment and recovered the exact fixture.
- The complete app passed deep, strict code-signature verification.
- The installed `/Applications/Text to MP3.app` reports version 1.4.1, build 10, and successfully OCR'd the fixture.
- OCR dependency versions, licence texts, and available SBOM records ship inside the app.
- A clean GitHub-hosted Mac passed debug compilation, all OCR tests, release packaging, metadata checks, and signature verification.

## Verdict

The deterministic OCR, cancellation, cleanup, packaging, signing, and installed-behaviour bars hold for this Apple Silicon English-OCR release. Criticism was same-context rather than independent because no separate critic agent was used; subjective product taste remains the owner's acceptance call.
