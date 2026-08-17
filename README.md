# Text to MP3

A small, local-first macOS app that turns pasted text, plain-text files, and PDFs—including scans—into MP3 audio with Microsoft Edge neural voices.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-111111) ![Swift 6](https://img.shields.io/badge/Swift-6-F05138) ![License: MIT](https://img.shields.io/badge/License-MIT-1357D5)

Text to MP3 is deliberately one-purpose software: bring words in, choose a voice, save an MP3. There is no account, subscription, analytics, document history, or server owned by this project.

## What it does

- Paste or type directly into a large native editor.
- Open `.txt`, `.text`, `.md`, `.markdown`, and `.pdf` documents with `⌘O`.
- Read scanned and mixed PDFs with built-in, open-source Tesseract OCR.
- Drop a supported document directly onto the editor.
- Choose from the voices and languages currently exposed by Microsoft Edge speech.
- Start with US English, Ava Multilingual, and 1.5× pace by default.
- Adjust speaking pace from 0.7× to 2×.
- See explicit setup, document-reading, connection, audio-receiving, and finalizing stages.
- See received audio duration, percentage, and a smoothed time-left estimate during long jobs.
- Cancel safely without leaving a broken partial MP3.

## Privacy

- Documents are read locally with macOS PDFKit, Foundation, and bundled Tesseract OCR.
- OCR runs entirely on the Mac. Scanned pages are not uploaded anywhere.
- Source text is never saved by the app.
- Voice and pace preferences are stored locally.
- Text is sent to Microsoft's online speech service only after you press **Generate MP3**.
- The app contains no analytics, ads, account system, or project-operated backend.

The Microsoft Edge speech endpoint is undocumented and can change or stop working. This project is not affiliated with or endorsed by Microsoft. Do not use it for confidential material unless sending that text to Microsoft's service is acceptable to you.

## OCR and PDF limits

The app first uses the PDF's selectable text layer. Any page without one is rendered locally and read with bundled [Tesseract](https://github.com/tesseract-ocr/tesseract) OCR. Version 1.4.0 includes English recognition data; other languages can still be spoken after their text reaches the editor, but scanned-page recognition is English-only for now.

OCR is fallible, especially on handwriting, unusual layouts, damaged scans, and low-resolution pages. The recognized text stays editable so it can be corrected before generation. Password-protected PDFs must be unlocked first.

## Install

Download the latest app archive from [Releases](https://github.com/bomkino/text-to-mp3/releases), unzip it, and move **Text to MP3.app** into `/Applications`.

Current public builds are for Apple Silicon, ad-hoc signed, and not Apple-notarized. macOS may ask you to right-click the app and choose **Open** the first time. Building from source avoids downloaded-app quarantine.

## Build from source

Requirements:

- macOS 14 or newer
- Swift 6
- Python 3
- Homebrew Tesseract (`brew install tesseract`)
- Internet access for voices and first-run installation of `edge-tts`

```bash
git clone https://github.com/bomkino/text-to-mp3.git
cd text-to-mp3
brew install tesseract
./scripts/build-app.sh
open "dist/Text to MP3.app"
```

The build script packages an architecture-matched Tesseract executable, English recognition data, its dynamic-library closure, licence texts, and an SBOM inside the app. People installing the finished app do not need Homebrew or a separate OCR download.

First launch creates an isolated Python environment in `~/Library/Application Support/Text to MP3/` and installs the pinned `edge-tts` version declared in `EdgeTTSEngine.swift`. Administrator access is not required.

## Keyboard

- `⌘O` — open a PDF or text file
- `⌘↩` — generate an MP3
- `Esc` — cancel document reading or MP3 generation
- `⇧⌘K` — clear the editor

## Architecture

- SwiftUI and AppKit for the native macOS interface and file panels
- PDFKit for local PDF text extraction and page rendering
- Bundled [Tesseract](https://github.com/tesseract-ocr/tesseract) for private English OCR
- A tiny Python bridge around [`edge-tts`](https://github.com/rany2/edge-tts)
- A private per-user Python environment created on first launch
- No project server, database, telemetry, or API key

The interface uses locally installed Neco and Erode fonts when available and native system fallbacks everywhere else. Font files are not bundled or included in this repository.

## Contributing

Bug reports, accessible-interface improvements, documentation, and focused pull requests are welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a change. Please report security problems privately as described in [SECURITY.md](SECURITY.md).

The bounded verification record for the current release lives in [GAUNTLET.md](GAUNTLET.md).

## Licence

The original Text to MP3 source is available under the [MIT License](LICENSE). Bundled and runtime dependencies keep their own licences; see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). Finished app bundles also contain dependency licence texts and SBOM files under `Contents/Resources/OCR/licenses/`.
