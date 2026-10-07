import SwiftUI

private let panel = Color(white: 0.17)
private let back = Color(white: 0.12)
private let dim = Color(white: 0.55)
private let accent = Color(red: 0.95, green: 0.62, blue: 0.2)

struct ContentView: View {
    @StateObject private var model = Model()
    @State private var atLive = true

    private static let clock: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            bar
            transcript
            Text(model.status)
                .font(.system(size: 11))
                .foregroundStyle(dim)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(panel)
        }
        .background(back)
        .preferredColorScheme(.dark)
        .frame(minWidth: 620, minHeight: 380)
    }

    private var bar: some View {
        HStack(spacing: 8) {
            Picker("Input", selection: $model.deviceID) {
                ForEach(model.devices) { device in
                    Text(device.name).tag(device.id)
                }
            }
            .frame(maxWidth: 260)
            .onChange(of: model.deviceID) { model.refreshDevices() }

            Picker("Channel", selection: $model.channel) {
                ForEach(0..<max(1, model.device?.channels ?? 1), id: \.self) { index in
                    Text("\(index + 1)").tag(index)
                }
            }
            .frame(width: 120)

            Button {
                model.refreshDevices()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help("Look for input devices again")

            Meter(level: model.level)
                .frame(width: 90, height: 8)

            Spacer()

            Button("Clear") { model.clear() }
            Button(model.running ? "Stop" : "Start") { model.toggle() }
                .keyboardShortcut(.space, modifiers: [])
                .tint(model.running ? .red : accent)
                .buttonStyle(.borderedProminent)
                .disabled(model.busy || model.devices.isEmpty)
        }
        .disabled(model.busy)
        .font(.system(size: 12))
        .padding(8)
        .background(panel)
        // The device and channel cannot change under a running transcript.
        .onChange(of: model.running) { atLive = true }
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(model.lines) { line in
                        row(time: line.time, text: Text(line.text))
                    }
                    if !model.partial.isEmpty {
                        row(time: model.partialTime, text: Text(model.partial).italic())
                            .opacity(0.65)
                    }
                    Color.clear.frame(height: 1).id("live")
                }
                .padding(12)
            }
            .onScrollGeometryChange(for: Bool.self) { geometry in
                geometry.contentSize.height - geometry.contentOffset.y - geometry.containerSize.height < 40
            } action: { _, near in
                atLive = near
            }
            .onChange(of: model.lines.count) { if atLive { proxy.scrollTo("live", anchor: .bottom) } }
            .onChange(of: model.partial) { if atLive { proxy.scrollTo("live", anchor: .bottom) } }
            .overlay(alignment: .bottom) {
                if !atLive {
                    Button("Jump to live") { proxy.scrollTo("live", anchor: .bottom) }
                        .buttonStyle(.borderedProminent)
                        .tint(accent)
                        .padding(10)
                }
            }
        }
        .disabled(false)
    }

    private func row(time: Date, text: Text) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(Self.clock.string(from: time))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(dim)
            text
                .font(.system(size: 16))
                .foregroundStyle(Color(white: 0.93))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct Meter: View {
    let level: Float

    var body: some View {
        GeometryReader { geometry in
            // -60 dB to 0 dB across the bar
            let db = 20 * log10(max(level, 0.001))
            let part = CGFloat(min(1, max(0, (db + 60) / 60)))
            ZStack(alignment: .leading) {
                Rectangle().fill(Color(white: 0.08))
                Rectangle().fill(level > 0.9 ? Color.red : Color.green)
                    .frame(width: geometry.size.width * part)
            }
        }
    }
}
