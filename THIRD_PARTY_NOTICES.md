# Third-party notices

Text to MP3 does not vendor third-party libraries into its source tree. Release builds package an architecture-matched OCR runtime from Homebrew bottles, and first launch installs the pinned speech bridge into a private Python environment.

## edge-tts

- Project: <https://github.com/rany2/edge-tts>
- Runtime version: `7.2.8`
- Licence: LGPL-3.0 for the main package; one SRT composer file is MIT-licensed
- Relationship: separate runtime process installed into the user's Application Support directory

`edge-tts` communicates with Microsoft Edge's online text-to-speech service. That service is not an official public API and may change without notice.

## Tesseract OCR runtime

- Project: <https://github.com/tesseract-ocr/tesseract>
- Release build version: `5.5.3`
- Licence: Apache-2.0
- Recognition data: English `eng.traineddata`, distributed by the Tesseract project under Apache-2.0
- Relationship: bundled command-line process; OCR runs locally and does not make network requests

The release app also bundles the dynamic-library closure required by the Tesseract executable built for its architecture. The 1.4.0 build contains:

| Component | Version | Licence |
| --- | --- | --- |
| Leptonica | 1.87.0 | BSD-2-Clause |
| libarchive | 3.8.9 | BSD-2-Clause |
| libpng | 1.6.58 | libpng-2.0 |
| libjpeg-turbo | 3.2.0 | IJG, Zlib, and BSD-3-Clause |
| giflib | 6.1.3 | MIT |
| libtiff | 4.7.2 | libtiff |
| WebP | 1.6.0 | BSD-3-Clause |
| OpenJPEG | 2.5.4 | BSD-2-Clause |
| XZ Utils / liblzma | 5.8.3 | 0BSD and GPL family notices supplied upstream |
| Zstandard | 1.5.7 | BSD-3-Clause, BSD-2-Clause, MIT, or GPL notices supplied upstream |
| LZ4 | 1.10.0 | BSD-2-Clause |
| libb2 | 0.98.1 | CC0-1.0 |

The app bundle includes the licence, copying, and SBOM material installed with those build inputs under `Contents/Resources/OCR/licenses/`, plus exact component versions in `Contents/Resources/OCR/VERSIONS.txt`. These libraries are separate works and retain their original licences.

## Apple frameworks

The app links only against system frameworks supplied with macOS, including SwiftUI, AppKit, PDFKit, Foundation, Combine, and Uniform Type Identifiers. They are not redistributed in this repository.

## Fonts

Neco and Erode font files are neither bundled nor published. If those families are installed on a user's Mac, the interface asks macOS to use them; otherwise it falls back to system fonts.
