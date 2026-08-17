# Text to MP3

A small, local-first macOS app that turns pasted text, plain-text files, and selectable-text PDFs into MP3 audio with Microsoft Edge neural voices.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-111111) ![Swift 6](https://img.shields.io/badge/Swift-6-F05138) ![License: MIT](https://img.shields.io/badge/License-MIT-1357D5)

Text to MP3 is deliberately one-purpose software: bring words in, choose a voice, save an MP3. There is no account, subscription, analytics, document history, or server owned by this project.

## What it does

- Paste or type directly into a large native editor.
- Open `.txt`, `.text`, `.md`, `.markdown`, and selectable-text `.pdf` documents with `⌘O`.
- Drop a supported document directly onto the editor.
- Choose from the voices and languages currently exposed by Microsoft Edge speech.
- Start with US English, Ava Multilingual, and 1.5× pace by default.
- Adjust speaking pace from 0.7× to 2×.
- See explicit setup, document-reading, connection, audio-receiving, and finalizing stages.
- See received audio duration, percentage, and a smoothed time-left estimate during long jobs.
- Cancel safely without leaving a broken partial MP3.

## Privacy

- Documents are read locally with macOS PDFKit and Foundation.
- Source text is never saved by the app.
- Voice and pace preferences are stored locally.
- Text is sent to Microsoft's online speech service only after you press **Generate MP3**.
- The app contains no analytics, ads, account system, or project-operated backend.

The Microsoft Edge speech endpoint is undocumented and can change or stop working. This project is not affiliated with or endorsed by Microsoft. Do not use it for confidential material unless sending that text to Microsoft's service is acceptable to you.

## PDF limits

PDFKit can extract text only when a PDF contains a selectable text layer. Scanned-image PDFs need OCR before import. Password-protected PDFs must be unlocked first. The app reports both cases plainly rather than pretending the document was empty.

## Roadmap

The first candidate after this deliberately small release is optional, on-device OCR for scanned PDFs. [Tesseract](https://github.com/tesseract-ocr/tesseract) is the likely open-source engine, but it will land only if the added binary size, language data, packaging work, speed, and recognition errors remain proportionate to this app's one-job design.

OCR is not included in 1.3.0.

## Install

Download the latest app archive from [Releases](https://github.com/bomkino/text-to-mp3/releases), unzip it, and move **Text to MP3.app** into `/Applications`.

Current public builds are ad-hoc signed, not Apple-notarized. macOS may ask you to right-click the app and choose **Open** the first time. Building from source avoids downloaded-app quarantine.

## Build from source

Requirements:

- macOS 14 or newer
- Swift 6
- Python 3
- Internet access for voices and first-run installation of `edge-tts`

```bash
git clone https://github.com/bomkino/text-to-mp3.git
cd text-to-mp3
./scripts/build-app.sh
open "dist/Text to MP3.app"
```

First launch creates an isolated Python environment in `~/Library/Application Support/Text to MP3/` and installs the pinned `edge-tts` version declared in `EdgeTTSEngine.swift`. Administrator access is not required.

## Keyboard

- `⌘O` — open a PDF or text file
- `⌘↩` — generate an MP3
- `Esc` — cancel generation
- `⇧⌘K` — clear the editor

## Architecture

- SwiftUI and AppKit for the native macOS interface and file panels
- PDFKit for local PDF text extraction
- A tiny Python bridge around [`edge-tts`](https://github.com/rany2/edge-tts)
- A private per-user Python environment created on first launch
- No project server, database, telemetry, or API key

The interface uses locally installed Neco and Erode fonts when available and native system fallbacks everywhere else. Font files are not bundled or included in this repository.

## Contributing

Bug reports, accessible-interface improvements, documentation, and focused pull requests are welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a change. Please report security problems privately as described in [SECURITY.md](SECURITY.md).

## Licence

The original Text to MP3 source is available under the [MIT License](LICENSE). Runtime dependencies keep their own licences; see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
