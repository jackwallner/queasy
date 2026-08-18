import AVFoundation
import Foundation

/// 100 Hz sine tone — the frequency a 2025 Nagoya University study linked to
/// reduced motion-sickness symptoms after ~1 minute of exposure. Offered as an
/// optional layer during phone sessions (headphones recommended).
final class ToneGenerator {
    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private(set) var isPlaying = false

    static let frequency = 100.0
    static let amplitude: Float = 0.18

    func start() {
        guard !isPlaying else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)

        let sampleRate = engine.outputNode.outputFormat(forBus: 0).sampleRate
        guard sampleRate > 0 else { return }
        let increment = 2.0 * Double.pi * Self.frequency / sampleRate
        // The render closure runs on the audio thread; keep state local.
        var theta = 0.0
        let node = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            for frame in 0..<Int(frameCount) {
                let value = Float(sin(theta)) * ToneGenerator.amplitude
                theta += increment
                if theta > 2.0 * Double.pi { theta -= 2.0 * Double.pi }
                for buffer in buffers {
                    let samples = buffer.mData!.assumingMemoryBound(to: Float.self)
                    samples[frame] = value
                }
            }
            return noErr
        }
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: nil)
        sourceNode = node
        do {
            try engine.start()
            isPlaying = true
        } catch {
            engine.detach(node)
            sourceNode = nil
        }
    }

    func stop() {
        guard isPlaying else { return }
        engine.stop()
        if let node = sourceNode {
            engine.detach(node)
        }
        sourceNode = nil
        isPlaying = false
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }
}
