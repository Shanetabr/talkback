import AVFoundation
import AudioToolbox
import CoreAudio

/// Takes one channel out of a buffer and converts it to the format the
/// speech engine wants. Used for the live input and for the file check.
final class ChannelFeeder {
    private let channel: Int
    private let target: AVAudioFormat
    private var mono: AVAudioFormat?
    private var converter: AVAudioConverter?

    /// The loudest sample of the last buffer, 0 to 1.
    private(set) var peak: Float = 0

    init(channel: Int, target: AVAudioFormat) {
        self.channel = channel
        self.target = target
    }

    func feed(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard let data = buffer.floatChannelData, buffer.frameLength > 0 else { return nil }
        let ch = min(channel, Int(buffer.format.channelCount) - 1)
        let frames = Int(buffer.frameLength)

        if mono == nil || mono!.sampleRate != buffer.format.sampleRate {
            mono = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: buffer.format.sampleRate,
                                 channels: 1, interleaved: false)
            converter = mono.flatMap { AVAudioConverter(from: $0, to: target) }
            converter?.primeMethod = .none
        }
        guard let mono, let converter,
              let one = AVAudioPCMBuffer(pcmFormat: mono, frameCapacity: buffer.frameLength) else { return nil }

        let stride = buffer.format.isInterleaved ? Int(buffer.format.channelCount) : 1
        let source = buffer.format.isInterleaved ? data[0] + ch : data[ch]
        let dest = one.floatChannelData![0]
        var top: Float = 0
        for i in 0..<frames {
            let v = source[i * stride]
            dest[i] = v
            top = max(top, abs(v))
        }
        one.frameLength = buffer.frameLength
        peak = top

        let capacity = AVAudioFrameCount(Double(frames) * target.sampleRate / mono.sampleRate) + 64
        guard let out = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else { return nil }
        var fed = false
        var error: NSError?
        converter.convert(to: out, error: &error) { _, status in
            if fed {
                status.pointee = .noDataNow
                return nil
            }
            fed = true
            status.pointee = .haveData
            return one
        }
        return error == nil && out.frameLength > 0 ? out : nil
    }
}

/// One input channel of one device, live.
final class AudioCapture {
    private var engine: AVAudioEngine?

    struct Failure: LocalizedError {
        let errorDescription: String?
    }

    /// `channel` counts from 0. `sink` and `level` are called on the audio thread.
    func start(device: AudioDeviceID, channel: Int, target: AVAudioFormat,
               sink: @escaping (AVAudioPCMBuffer) -> Void,
               level: @escaping (Float) -> Void) throws {
        stop()
        let engine = AVAudioEngine()
        let input = engine.inputNode
        guard let unit = input.audioUnit else {
            throw Failure(errorDescription: "The audio input could not be opened.")
        }
        var id = device
        let status = AudioUnitSetProperty(unit, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 0,
                                          &id, UInt32(MemoryLayout<AudioDeviceID>.size))
        guard status == noErr else {
            throw Failure(errorDescription: "That input device could not be selected (error \(status)).")
        }
        let format = input.outputFormat(forBus: 0)
        guard format.channelCount > 0, format.sampleRate > 0 else {
            throw Failure(errorDescription: "That device has no usable input.")
        }
        let feeder = ChannelFeeder(channel: channel, target: target)
        input.installTap(onBus: 0, bufferSize: 4096, format: format) { buffer, _ in
            let out = feeder.feed(buffer)
            level(feeder.peak)
            if let out { sink(out) }
        }
        engine.prepare()
        try engine.start()
        self.engine = engine
    }

    func stop() {
        guard let engine else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        self.engine = nil
    }
}
