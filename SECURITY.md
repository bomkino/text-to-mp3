# Security policy

## Supported version

Security fixes target the latest release on the default branch.

## Reporting a vulnerability

Please do not publish an exploitable issue before a fix is available. Email `hello@pitch.dog` with:

- the affected version;
- the smallest reproducible example;
- the likely impact;
- whether any user text, files, or credentials could be exposed.

Do not include real confidential documents in a report. A synthetic reproduction is strongly preferred.

## Trust boundary

The app reads user-selected files locally. When the user explicitly generates audio, it sends the editor text to Microsoft's Edge speech service through `edge-tts`. The app downloads Python packages from PyPI during first-run setup. It does not operate a backend or collect telemetry.
