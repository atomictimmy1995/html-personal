import Foundation
import AVFoundation

/// Sample-accurate metronome built on `AVAudioEngine`.
///
/// The scheduling strategy mirrors the classic Web Audio "lookahead scheduler":
/// a timer on the main run loop wakes up frequently and schedules any click
/// buffers that fall inside a short look-ahead window, using absolute sample
/// times so onsets land exactly on the audio clock regardless of timer jitter.
final class MetronomeEngine: ObservableObject {

    // MARK: - Public, observable state

    @Published var bpm: Double = 120 {
        didSet { bpm = min(maxBPM, max(minBPM, bpm)) }
    }
    @Published var beatsPerMeasure: Int = 4
    @Published var subdivision: Int = 1            // 1 = quarter, 2 = eighth, 3 = triplet, 4 = sixteenth
    @Published private(set) var isPlaying = false
    @Published private(set) var currentBeat = -1   // -1 when idle; 0-based beat within the measure

    let minBPM: Double = 30
    let maxBPM: Double = 240

    // MARK: - Audio graph

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var format: AVAudioFormat!
    private var sampleRate: Double = 44_100

    private var accentBuffer: AVAudioPCMBuffer!
    private var normalBuffer: AVAudioPCMBuffer!
    private var subBuffer: AVAudioPCMBuffer!

    // MARK: - Scheduler state

    private var timer: DispatchSourceTimer?
    private let lookahead = DispatchTimeInterval.milliseconds(20)
    private let scheduleAhead = 0.18               // seconds to schedule in advance

    private var noteIndex = 0                       // counts subdivisions within a measure
    private var nextNoteFrame: AVAudioFramePosition = 0
    private var pending: [(frame: AVAudioFramePosition, beat: Int, isSub: Bool)] = []

    // MARK: - Lifecycle

    init() {
        configureGraph()
        buildClickBuffers()
    }

    private func configureGraph() {
        format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        engine.prepare()
    }

    private func activateSession() {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [])
        try? session.setActive(true)
        #endif
    }

    // MARK: - Transport

    func toggle() { isPlaying ? stop() : start() }

    func start() {
        guard !isPlaying else { return }
        activateSession()
        do { try engine.start() } catch {
            print("Metronome: failed to start engine — \(error)")
            return
        }
        player.play()

        noteIndex = 0
        pending.removeAll()
        currentBeat = -1
        // Anchor scheduling a little ahead of the current play position.
        nextNoteFrame = currentSampleTime() + AVAudioFramePosition(0.1 * sampleRate)
        isPlaying = true
        startTimer()
    }

    func stop() {
        guard isPlaying else { return }
        timer?.cancel()
        timer = nil
        player.stop()
        engine.pause()
        isPlaying = false
        currentBeat = -1
        pending.removeAll()
    }

    /// Convenience for the slider's `+`/`−` steppers.
    func nudge(_ delta: Double) { bpm += delta }

    // MARK: - Scheduling

    private func startTimer() {
        let t = DispatchSource.makeTimerSource(queue: .main)
        t.schedule(deadline: .now(), repeating: lookahead)
        t.setEventHandler { [weak self] in self?.tick() }
        t.resume()
        timer = t
    }

    private func currentSampleTime() -> AVAudioFramePosition {
        guard let renderTime = player.lastRenderTime,
              let playerTime = player.playerTime(forNodeTime: renderTime) else { return 0 }
        return playerTime.sampleTime
    }

    private func tick() {
        let now = currentSampleTime()
        let horizon = now + AVAudioFramePosition(scheduleAhead * sampleRate)
        let totalSubdivisions = max(1, beatsPerMeasure * subdivision)

        // Schedule every click whose onset falls within the look-ahead window.
        while nextNoteFrame < horizon {
            let position = noteIndex % totalSubdivisions
            let beat = position / subdivision
            let isSub = position % subdivision != 0
            let isAccent = position == 0

            let buffer = isSub ? subBuffer! : (isAccent ? accentBuffer! : normalBuffer!)
            let when = AVAudioTime(sampleTime: nextNoteFrame, atRate: sampleRate)
            player.scheduleBuffer(buffer, at: when, options: [], completionHandler: nil)

            pending.append((nextNoteFrame, beat, isSub))

            let secondsPerSubdivision = 60.0 / bpm / Double(subdivision)
            nextNoteFrame += AVAudioFramePosition((secondsPerSubdivision * sampleRate).rounded())
            noteIndex = (noteIndex + 1) % totalSubdivisions
        }

        // Advance the visual beat indicator in lock-step with the audio clock.
        while let first = pending.first, first.frame <= now {
            if !first.isSub { currentBeat = first.beat }
            pending.removeFirst()
        }
    }

    // MARK: - Click synthesis

    private func buildClickBuffers() {
        accentBuffer = makeClick(frequency: 1_500, volume: 1.0)   // accented downbeat
        normalBuffer = makeClick(frequency: 1_000, volume: 0.6)   // normal beat
        subBuffer    = makeClick(frequency: 880,   volume: 0.3)   // subdivision
    }

    /// A short decaying sine burst followed by silence.
    private func makeClick(frequency: Double, volume: Float) -> AVAudioPCMBuffer {
        let duration = 0.08
        let frameCount = AVAudioFrameCount(duration * sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount

        let samples = buffer.floatChannelData![0]
        let decay = sampleRate * 0.012   // ~12 ms time constant
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let envelope = Float(exp(-Double(i) / decay))
            samples[i] = volume * envelope * Float(sin(2.0 * .pi * frequency * t))
        }
        return buffer
    }
}
