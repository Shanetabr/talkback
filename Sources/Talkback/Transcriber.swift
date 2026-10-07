import AVFoundation
import Speech

/// Apple's on-device speech engine for one stream of sound.
/// Sound goes in through `send`; `onResult` gets the text, first as a guess
/// that keeps changing (`final` false) and then once as the settled line.
final class Transcriber {
    struct Failure: LocalizedError {
        let errorDescription: String?
    }

    /// The format `send` expects.
    let format: AVAudioFormat

    private let module: SpeechTranscriber
    private let analyzer: SpeechAnalyzer
    private let input: AsyncStream<AnalyzerInput>
    private let feed: AsyncStream<AnalyzerInput>.Continuation
    private var reading: Task<Void, Never>?

    /// Gets the speech model if this Mac does not have it yet (needs the
    /// internet once), then makes a transcriber ready to start.
    static func make(status: @escaping (String) -> Void) async throws -> Transcriber {
        guard SpeechTranscriber.isAvailable else {
            throw Failure(errorDescription: "On-device speech is not available on this Mac.")
        }
        let wanted = Locale(identifier: "en-US")
        guard let locale = await SpeechTranscriber.supportedLocale(equivalentTo: wanted) else {
            throw Failure(errorDescription: "English is not offered by the speech engine on this Mac.")
        }
        let module = SpeechTranscriber(locale: locale, transcriptionOptions: [],
                                       reportingOptions: [.volatileResults], attributeOptions: [])
        let state = await AssetInventory.status(forModules: [module])
        if state == .unsupported {
            throw Failure(errorDescription: "The speech model is not supported on this Mac.")
        }
        if state < .installed {
            status("Downloading the speech model from Apple (first time only)…")
            if let request = try await AssetInventory.assetInstallationRequest(supporting: [module]) {
                try await request.downloadAndInstall()
            }
        }
        guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [module]) else {
            throw Failure(errorDescription: "The speech engine did not offer an audio format.")
        }
        return Transcriber(module: module, format: format)
    }

    private init(module: SpeechTranscriber, format: AVAudioFormat) {
        self.module = module
        self.format = format
        self.analyzer = SpeechAnalyzer(modules: [module])
        (input, feed) = AsyncStream<AnalyzerInput>.makeStream()
    }

    func start(onResult: @escaping (_ text: String, _ final: Bool) -> Void,
               onError: @escaping (Error) -> Void) async throws {
        let module = self.module
        reading = Task {
            do {
                for try await result in module.results {
                    onResult(String(result.text.characters), result.isFinal)
                }
            } catch {
                onError(error)
            }
        }
        try await analyzer.start(inputSequence: input)
    }

    /// Safe to call from the audio thread.
    func send(_ buffer: AVAudioPCMBuffer) {
        feed.yield(AnalyzerInput(buffer: buffer))
    }

    /// Lets the engine settle what it has heard, then ends.
    func finish() async {
        feed.finish()
        try? await analyzer.finalizeAndFinishThroughEndOfInput()
        await reading?.value
    }
}
