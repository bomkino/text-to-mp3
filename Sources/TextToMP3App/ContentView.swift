import SwiftUI

struct ContentView: View {
    @ObservedObject var model: TTSViewModel
    @FocusState private var editorFocused: Bool
    @Environment(\.colorScheme) private var colorScheme

    private var palette: PDPallette { PDPallette(colorScheme: colorScheme) }

    var body: some View {
        HStack(spacing: 0) {
            identityPanel
                .frame(width: 196)

            workspace
        }
        .frame(minWidth: 900, minHeight: 660)
        .background(palette.sheet)
        .tint(palette.cobalt)
        .onAppear {
            model.startIfNeeded()
            editorFocused = true
        }
    }

    private var identityPanel: some View {
        Color.pdCobalt
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("PITCH.DOG")
                        .font(.pdUtility(size: 10, weight: .semibold))
                        .tracking(1.1)
                        .foregroundStyle(.white.opacity(0.72))

                    Spacer()

                    Text("TEXT\nTO MP3.")
                        .font(.pdDisplay(size: 42))
                        .tracking(-1)
                        .lineSpacing(-5)
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer()

                    Text("PRIVATE / 001")
                        .font(.pdUtility(size: 9, weight: .semibold))
                        .tracking(1)
                        .foregroundStyle(.white.opacity(0.66))
                }
                .padding(.horizontal, 22)
                .padding(.top, 20)
                .padding(.bottom, 24)
        }
        .accessibilityElement(children: .contain)
    }

    private var workspace: some View {
        VStack(spacing: 0) {
            workspaceHeader
            rule
            scriptEditor
            rule
            controls
            rule
            actionBar
        }
        .background(palette.sheet)
    }

    private var workspaceHeader: some View {
        HStack(alignment: .top, spacing: 24) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Give your words a voice.")
                    .font(.pdBody(size: 29, weight: .medium))
                    .tracking(-0.25)
                    .foregroundStyle(palette.ink)

                Text("Natural Microsoft Edge speech, saved as an MP3.")
                    .font(.pdBody(size: 14))
                    .foregroundStyle(palette.mutedInk)
            }

            Spacer(minLength: 20)

            VStack(alignment: .trailing, spacing: 5) {
                Text("PRIVATE MAC TOOL")
                    .font(.pdUtility(size: 10, weight: .semibold))
                    .tracking(1)
                    .foregroundStyle(palette.mutedInk)

                Label("Free · no account", systemImage: "lock.fill")
                    .font(.pdUtility(size: 11, weight: .medium))
                    .foregroundStyle(palette.ink)
                    .accessibilityLabel("Free to use. No account required.")

                Text("Sent to Microsoft only when you generate.")
                    .font(.pdBody(size: 11))
                    .foregroundStyle(palette.mutedInk)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
    }

    private var scriptEditor: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text("SCRIPT / 01")
                    .font(.pdUtility(size: 10, weight: .semibold))
                    .tracking(1)
                    .foregroundStyle(palette.mutedInk)

                Spacer()

                Text(model.stats.summary)
                Text("/")
                    .accessibilityHidden(true)
                Text(model.stats.estimatedDuration(rate: model.rate))
                Button(action: model.openDocumentPicker) {
                    Label("OPEN PDF / TXT", systemImage: "doc.badge.plus")
                }
                    .buttonStyle(PDEditorialButtonStyle())
                    .disabled(!model.canImportDocument)
                    .accessibilityHint("Loads a PDF or plain-text file. Scanned PDF pages are read with private on-device OCR.")

                Button("CLEAR", action: model.clear)
                    .buttonStyle(PDEditorialButtonStyle())
                    .disabled(model.text.isEmpty || model.isGenerating || model.isImporting)
                    .accessibilityHint("Removes all text from the editor")
            }
            .font(.pdUtility(size: 10, weight: .medium))
            .tracking(0.45)
            .foregroundStyle(palette.mutedInk)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)

            ZStack(alignment: .topLeading) {
                palette.editor

                if model.text.isEmpty {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("Paste the words you want to hear…")
                            .font(.system(size: 17))

                        Text("or drop a PDF or text file here")
                            .font(.pdUtility(size: 10, weight: .medium))
                            .tracking(0.35)
                    }
                        .foregroundStyle(palette.mutedInk.opacity(0.58))
                        .padding(.horizontal, 25)
                        .padding(.vertical, 19)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }

                TextEditor(text: $model.text)
                    .font(.system(size: 17))
                    .lineSpacing(5)
                    .foregroundStyle(palette.ink)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .focused($editorFocused)
                    .accessibilityLabel("Script")
                    .accessibilityHint("Paste, type, or open a PDF or text file to turn into an MP3")
            }
            .overlay {
                Rectangle()
                    .strokeBorder(
                        editorFocused ? palette.cobalt : palette.rule,
                        lineWidth: editorFocused ? 2 : 1
                    )
            }
            .dropDestination(for: URL.self) { urls, _ in
                guard let url = urls.first else { return false }
                return model.importDocument(at: url)
            } isTargeted: { _ in }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .frame(maxHeight: .infinity)
    }

    private var controls: some View {
        HStack(alignment: .top, spacing: 0) {
            controlGroup(title: "LANGUAGE", systemImage: "globe") {
                Picker(
                    "Language",
                    selection: Binding(
                        get: { model.selectedLocale },
                        set: { locale in model.selectLocale(locale) }
                    )
                ) {
                    ForEach(model.locales, id: \.self) { locale in
                        Text(model.localeName(locale)).tag(locale)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: .infinity)
            }

            verticalRule

            controlGroup(title: "VOICE", systemImage: "waveform") {
                Picker(
                    "Voice",
                    selection: Binding(
                        get: { model.selectedVoiceID },
                        set: { voiceID in model.selectVoice(voiceID) }
                    )
                ) {
                    ForEach(model.voicesForSelectedLocale) { voice in
                        Text(voice.displayName).tag(voice.shortName)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: .infinity)
            }

            verticalRule

            controlGroup(title: "PACE", systemImage: "speedometer") {
                HStack(spacing: 10) {
                    Slider(
                        value: Binding(
                            get: { Double(model.rate) },
                            set: { value in model.setRate(value) }
                        ),
                        in: -30...100,
                        step: 5
                    )
                    .accessibilityLabel("Speaking pace")
                    .accessibilityValue(model.rateDescription)

                    Text(model.rateDescription.uppercased())
                        .font(.pdUtility(size: 9, weight: .semibold))
                        .tracking(0.55)
                        .foregroundStyle(palette.mutedInk)
                        .lineLimit(1)
                        .frame(minWidth: 70, alignment: .trailing)
                }
            }
        }
        .disabled(model.isBusy || model.voices.isEmpty)
        .frame(height: 94)
        .background(palette.quietSurface)
    }

    private func controlGroup<Content: View>(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.pdUtility(size: 9, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(palette.mutedInk)
            content()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var actionBar: some View {
        HStack(spacing: 12) {
            PDStatusView(model: model)

            Spacer(minLength: 16)

            if model.isGenerating || model.isImporting {
                Button("CANCEL", action: model.cancel)
                    .buttonStyle(PDSecondaryButtonStyle())
                    .keyboardShortcut(.escape, modifiers: [])
            } else {
                if model.canRevealLastOutput {
                    Button(action: model.revealLastOutput) {
                        Label("FINDER", systemImage: "folder")
                    }
                    .buttonStyle(PDSecondaryButtonStyle())
                }

                if model.needsSetupRetry {
                    Button("RETRY VOICES", action: model.retrySetup)
                        .buttonStyle(PDPrimaryButtonStyle())
                } else {
                    Button(action: model.generate) {
                        HStack(spacing: 18) {
                            Text(model.primaryActionTitle.uppercased())
                            Image(systemName: "arrow.down")
                        }
                    }
                    .buttonStyle(PDPrimaryButtonStyle())
                    .disabled(!model.canGenerate)
                    .accessibilityHint("Opens a Save dialog, then sends the text to Microsoft to make an MP3")
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .frame(minHeight: 80)
    }

    private var rule: some View {
        Rectangle()
            .fill(palette.rule)
            .frame(height: 1)
            .accessibilityHidden(true)
    }

    private var verticalRule: some View {
        Rectangle()
            .fill(palette.rule)
            .frame(width: 1)
            .accessibilityHidden(true)
    }
}

private struct PDStatusView: View {
    @ObservedObject var model: TTSViewModel
    @Environment(\.colorScheme) private var colorScheme

    private var palette: PDPallette { PDPallette(colorScheme: colorScheme) }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 11) {
                ZStack {
                    Rectangle()
                        .fill(statusColor.opacity(0.13))
                        .frame(width: 34, height: 34)

                    if model.isBusy {
                        ProgressView()
                            .controlSize(.small)
                            .tint(statusColor)
                    } else {
                        Image(systemName: model.statusSymbol)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(statusColor)
                    }
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(model.statusTitle.uppercased())

                        if let percentage = model.activeProgressPercentage {
                            Text("\(percentage)%")
                                .foregroundStyle(statusColor)
                        }
                    }
                    .font(.pdUtility(size: 10, weight: .semibold))
                    .tracking(0.7)
                    .foregroundStyle(palette.ink)

                    Text(model.statusDetail)
                        .font(.pdBody(size: 12))
                        .foregroundStyle(model.hasError ? palette.vermilion : palette.mutedInk)
                        .lineLimit(2)
                        .textSelection(.enabled)
                }
            }

            if let fraction = model.activeProgressFraction {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(palette.rule)

                        Rectangle()
                            .fill(statusColor)
                            .frame(width: geometry.size.width * fraction)
                    }
                }
                .frame(height: 4)
                .padding(.leading, 45)
                .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: 340, alignment: .leading)
    }

    private var statusColor: Color {
        if model.hasError { return palette.vermilion }
        if case .complete = model.state { return .green }
        return palette.cobalt
    }
}

private struct PDEditorialButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        let palette = PDPallette(colorScheme: colorScheme)
        configuration.label
            .font(.pdUtility(size: 9, weight: .semibold))
            .tracking(0.7)
            .foregroundStyle(isEnabled ? palette.ink : palette.mutedInk.opacity(0.45))
            .padding(.horizontal, 8)
            .frame(minHeight: 28)
            .background(configuration.isPressed ? palette.pressedSurface : .clear)
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(pressAnimation, value: configuration.isPressed)
    }

    private var pressAnimation: Animation {
        reduceMotion ? .linear(duration: 0.01) : .timingCurve(0.23, 1, 0.32, 1, duration: 0.1)
    }
}

private struct PDSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        let palette = PDPallette(colorScheme: colorScheme)
        configuration.label
            .font(.pdUtility(size: 10, weight: .semibold))
            .tracking(0.8)
            .foregroundStyle(isEnabled ? palette.ink : palette.mutedInk.opacity(0.5))
            .padding(.horizontal, 16)
            .frame(height: 48)
            .background(configuration.isPressed ? palette.pressedSurface : palette.sheet)
            .overlay {
                Rectangle().strokeBorder(palette.rule, lineWidth: 1)
            }
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(pressAnimation, value: configuration.isPressed)
    }

    private var pressAnimation: Animation {
        reduceMotion ? .linear(duration: 0.01) : .timingCurve(0.23, 1, 0.32, 1, duration: 0.1)
    }
}

private struct PDPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        let palette = PDPallette(colorScheme: colorScheme)
        configuration.label
            .font(.pdUtility(size: 11, weight: .bold))
            .tracking(0.95)
            .foregroundStyle(.white.opacity(isEnabled ? 1 : 0.62))
            .padding(.horizontal, 18)
            .frame(height: 52)
            .background(isEnabled ? palette.actionCobalt : palette.disabledInk)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(.black.opacity(configuration.isPressed ? 0.22 : 0))
                    .frame(height: 3)
            }
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(pressAnimation, value: configuration.isPressed)
    }

    private var pressAnimation: Animation {
        reduceMotion ? .linear(duration: 0.01) : .timingCurve(0.23, 1, 0.32, 1, duration: 0.1)
    }
}

private struct PDPallette {
    let colorScheme: ColorScheme

    var sheet: Color { colorScheme == .dark ? .pdPanelDark : .pdSheet }
    var editor: Color { colorScheme == .dark ? .pdInkRoom : .white }
    var ink: Color { colorScheme == .dark ? .pdLightInk : .pdInk }
    var mutedInk: Color { colorScheme == .dark ? .pdMutedLightInk : .pdMutedInk }
    var quietSurface: Color { ink.opacity(0.04) }
    var pressedSurface: Color { ink.opacity(0.16) }
    var rule: Color { ink.opacity(colorScheme == .dark ? 0.16 : 0.14) }
    var disabledInk: Color { mutedInk.opacity(0.48) }
    var cobalt: Color { colorScheme == .dark ? .pdCobaltDark : .pdCobalt }
    var actionCobalt: Color { .pdCobalt }
    var vermilion: Color { .pdVermilion }
}

private extension Font {
    static func pdDisplay(size: CGFloat) -> Font {
        .custom("NecoVariable-Bold_Bold", fixedSize: size)
    }

    static func pdBody(size: CGFloat, weight: Weight = .regular) -> Font {
        let name = weight == .medium
            ? "Erode-Variable-Light_Medium"
            : "Erode-Variable-Light_Regular"
        return .custom(name, fixedSize: size)
    }

    static func pdUtility(size: CGFloat, weight: Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

private extension Color {
    static let pdSheet = Color(.displayP3, red: 0.992, green: 0.988, blue: 0.982)
    static let pdInk = Color(.displayP3, red: 0.055, green: 0.054, blue: 0.060)
    static let pdMutedInk = Color(.displayP3, red: 0.37, green: 0.38, blue: 0.41)
    static let pdInkRoom = Color(.displayP3, red: 0.044, green: 0.047, blue: 0.054)
    static let pdPanelDark = Color(.displayP3, red: 0.083, green: 0.085, blue: 0.097)
    static let pdLightInk = Color(.displayP3, red: 0.945, green: 0.941, blue: 0.931)
    static let pdMutedLightInk = Color(.displayP3, red: 0.65, green: 0.655, blue: 0.69)
    static let pdCobalt = Color(.displayP3, red: 0.13, green: 0.31, blue: 0.80)
    static let pdCobaltDark = Color(.displayP3, red: 0.55, green: 0.66, blue: 0.95)
    static let pdVermilion = Color(.displayP3, red: 0.88, green: 0.32, blue: 0.21)
}
