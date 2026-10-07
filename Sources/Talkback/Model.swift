import AVFoundation
import CoreAudio
import SwiftUI

struct Line: Identifiable {
    let id = UUID()
    let time: Date
    let text: String
}

@MainActor
final class Model: ObservableObject {
    @Published var devices: [InputDevice] = []
    @Published var deviceID: AudioDeviceID = 0
    @Published var channel = 0          // counts from 0; shown from 1
    @Published var running = false
    @Published var busy = false         // starting or stopping
    @Published var status = "Stopped"
    @Published var level: Float = 0
    @Published var lines: [Line] = []
    @Published var partial = ""
    @Published var partialTime = Date()

    private let capture = AudioCapture()
    private var transcriber: Transcriber?

    var device: InputDevice? { devices.first { $0.id == deviceID } }

    init() {
        refreshDevices()
    }

    func refreshDevices() {
        devices = AudioDevices.inputs()
        if device == nil {
            let preferred = AudioDevices.defaultInput()
            deviceID = devices.first { $0.id == preferred }?.id ?? devices.first?.id ?? 0
        }
        channel = min(channel, max(0, (device?.channels ?? 1) - 1))
    }

    func toggle() {
        guard !busy else { return }
        busy = true
        Task {
            if running { await stop() } else { await start() }
            busy = false
        }
    }

    func clear() {
        lines.removeAll()
        partial = ""
    }

    private func start() async {
        guard let device else {
            status = "No input device"
            return
        }
        guard await AVCaptureDevice.requestAccess(for: .audio) else {
            status = "Microphone access was refused. Allow Talkback in System Settings › Privacy & Security › Microphone."
            return
        }
        status = "Starting…"
        do {
            let transcriber = try await Transcriber.make { text in
                Task { @MainActor in self.status = text }
            }
            try await transcriber.start(
                onResult: { text, final in
                    Task { @MainActor in self.heard(text, final: final) }
                },
                onError: { error in
                    Task { @MainActor in self.status = "Speech engine stopped: \(error.localizedDescription)" }
                })
            try capture.start(
                device: device.id, channel: channel, target: transcriber.format,
                sink: { transcriber.send($0) },
                level: { peak in
                    Task { @MainActor in self.level = max(peak, self.level * 0.7) }
                })
            self.transcriber = transcriber
            running = true
            status = "Listening to \(device.name), input \(channel + 1)"
        } catch {
            capture.stop()
            status = error.localizedDescription
        }
    }

    private func stop() async {
        capture.stop()
        level = 0
        status = "Stopping…"
        await transcriber?.finish()
        transcriber = nil
        running = false
        status = "Stopped"
    }

    private func heard(_ text: String, final: Bool) {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if final {
            if !text.isEmpty {
                lines.append(Line(time: partial.isEmpty ? Date() : partialTime, text: text))
            }
            partial = ""
        } else {
            if partial.isEmpty { partialTime = Date() }
            partial = text
        }
    }
}
