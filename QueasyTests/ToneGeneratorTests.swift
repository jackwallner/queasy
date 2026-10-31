import AVFoundation
import Foundation
import Testing
@testable import Queasy

/// The tone's one claim is its pitch, so this reads the pitch back out of the
/// audio instead of trusting the constant. The generator renders offline through
/// an engine whose output runs at each rate a phone can report: 48 kHz for the
/// built-in speaker and wired headphones, 44.1 kHz on some Bluetooth routes, and
/// the lower rates of a Bluetooth call route.
@Suite("Tone generator", .serialized)
struct ToneGeneratorTests {
    /// The pitch of what `ToneGenerator` plays, counted as upward zero crossings
    /// over two seconds of offline output.
    private func renderedHertz(outputRate: Double) throws -> Double {
        let engine = AVAudioEngine()
        let format = try #require(AVAudioFormat(standardFormatWithSampleRate: outputRate, channels: 2))
        try engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 4096)

        let tone = ToneGenerator(engine: engine)
        tone.start()
        defer { tone.stop() }
        try #require(tone.isPlaying, "the generator did not start")

        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4096))
        let wanted = Int(outputRate) * 2
        var samples: [Float] = []
        samples.reserveCapacity(wanted)
        while samples.count < wanted {
            guard try engine.renderOffline(4096, to: buffer) == .success,
                  let channel = buffer.floatChannelData?[0] else { break }
            samples.append(contentsOf: UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))
        }

        // Skip the first quarter second so the start of the render cannot bias the count.
        let skip = Int(outputRate / 4)
        try #require(samples.count > skip + 1, "the engine rendered no audio")
        var crossings = 0
        var first = 0
        var last = 0
        for index in (skip + 1)..<samples.count where samples[index - 1] <= 0 && samples[index] > 0 {
            if crossings == 0 { first = index }
            last = index
            crossings += 1
        }
        try #require(crossings > 10, "no tone in the rendered audio")
        return Double(crossings - 1) * outputRate / Double(last - first)
    }

    @Test(arguments: [48_000.0, 44_100.0, 24_000.0, 16_000.0])
    func playsOneHundredHertzWhateverTheOutputRate(outputRate: Double) throws {
        let hertz = try renderedHertz(outputRate: outputRate)
        #expect(
            abs(hertz - ToneGenerator.frequency) < 0.5,
            "with the output at \(Int(outputRate)) Hz the tone played \(hertz) Hz, not \(ToneGenerator.frequency) Hz"
        )
    }
}
