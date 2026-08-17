# Third-party notices

Text to MP3 does not vendor third-party libraries into its source tree. On first launch it creates a private Python environment and installs the pinned runtime dependency below from PyPI.

## edge-tts

- Project: <https://github.com/rany2/edge-tts>
- Runtime version: `7.2.8`
- Licence: LGPL-3.0 for the main package; one SRT composer file is MIT-licensed
- Relationship: separate runtime process installed into the user's Application Support directory

`edge-tts` communicates with Microsoft Edge's online text-to-speech service. That service is not an official public API and may change without notice.

## Apple frameworks

The app links only against system frameworks supplied with macOS, including SwiftUI, AppKit, PDFKit, Foundation, Combine, and Uniform Type Identifiers. They are not redistributed in this repository.

## Fonts

Neco and Erode font files are neither bundled nor published. If those families are installed on a user's Mac, the interface asks macOS to use them; otherwise it falls back to system fonts.
