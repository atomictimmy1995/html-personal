import SwiftUI

struct ContentView: View {
    @StateObject private var engine = MetronomeEngine()
    @State private var tapTimes: [Date] = []

    // White & green palette
    private let green = Color(red: 0.086, green: 0.639, blue: 0.290)        // #16a34a
    private let greenDark = Color(red: 0.082, green: 0.502, blue: 0.239)    // #15803d
    private let greenLight = Color(red: 0.863, green: 0.988, blue: 0.906)   // #dcfce7

    var body: some View {
        VStack(spacing: 22) {
            header
            beatDots
            tempoDisplay
            stepper
            tempoSlider
            controlRow
            Spacer(minLength: 0)
            startButton
        }
        .padding(24)
        .background(Color.white.ignoresSafeArea())
        .preferredColorScheme(.light)
    }

    // MARK: - Sections

    private var header: some View {
        VStack(spacing: 4) {
            Text("🎵 Metronome")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(greenDark)
            Text("Keep perfect time, anywhere")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
    }

    private var beatDots: some View {
        HStack(spacing: 12) {
            ForEach(0..<engine.beatsPerMeasure, id: \.self) { i in
                Circle()
                    .fill(dotColor(for: i))
                    .frame(width: 18, height: 18)
                    .overlay(Circle().stroke(i == 0 ? greenDark : green, lineWidth: 2))
                    .scaleEffect(engine.currentBeat == i ? 1.4 : 1.0)
                    .shadow(color: engine.currentBeat == i ? green.opacity(0.5) : .clear, radius: 8)
                    .animation(.easeOut(duration: 0.08), value: engine.currentBeat)
            }
        }
        .frame(height: 28)
    }

    private var tempoDisplay: some View {
        VStack(spacing: 2) {
            Text("\(Int(engine.bpm))")
                .font(.system(size: 84, weight: .heavy, design: .rounded))
                .foregroundColor(greenDark)
                .monospacedDigit()
            Text("BPM")
                .font(.caption).kerning(3)
                .foregroundColor(.secondary)
            Text(tempoMarking(engine.bpm))
                .font(.subheadline).italic()
                .foregroundColor(green)
        }
    }

    private var stepper: some View {
        HStack(spacing: 16) {
            roundButton("−") { engine.nudge(-1) }
            roundButton("+") { engine.nudge(1) }
        }
    }

    private var tempoSlider: some View {
        Slider(value: $engine.bpm, in: engine.minBPM...engine.maxBPM, step: 1)
            .tint(green)
    }

    private var controlRow: some View {
        HStack(spacing: 12) {
            pickerField(title: "Beats") {
                Picker("Beats", selection: $engine.beatsPerMeasure) {
                    ForEach(1...8, id: \.self) { Text("\($0)").tag($0) }
                }
            }
            pickerField(title: "Subdivide") {
                Picker("Subdivide", selection: $engine.subdivision) {
                    Text("Quarter").tag(1)
                    Text("Eighth").tag(2)
                    Text("Triplet").tag(3)
                    Text("Sixteenth").tag(4)
                }
            }
            Button(action: tapTempo) {
                Text("TAP\nTEMPO")
                    .multilineTextAlignment(.center)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(greenDark)
                    .frame(maxWidth: .infinity, minHeight: 64)
                    .background(Color.white)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(green, lineWidth: 2))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    private var startButton: some View {
        Button(action: engine.toggle) {
            Text(engine.isPlaying ? "STOP" : "START")
                .font(.system(size: 22, weight: .heavy)).kerning(1)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, minHeight: 64)
                .background(engine.isPlaying ? greenDark : green)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .shadow(color: green.opacity(0.45), radius: 10, y: 5)
        }
    }

    // MARK: - Reusable pieces

    private func roundButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 30, weight: .bold))
                .foregroundColor(greenDark)
                .frame(width: 56, height: 56)
                .background(Color.white)
                .overlay(Circle().stroke(green, lineWidth: 2))
                .clipShape(Circle())
        }
    }

    private func pickerField<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 11)).kerning(1)
                .foregroundColor(greenDark)
            content()
                .pickerStyle(.menu)
                .tint(greenDark)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 64)
        .background(greenLight)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func dotColor(for index: Int) -> Color {
        if engine.currentBeat == index { return index == 0 ? greenDark : green }
        return greenLight
    }

    // MARK: - Logic

    private func tapTempo() {
        let now = Date()
        if let last = tapTimes.last, now.timeIntervalSince(last) > 2 {
            tapTimes = []   // reset a stale tap series
        }
        tapTimes.append(now)
        if tapTimes.count > 5 { tapTimes.removeFirst() }
        guard tapTimes.count >= 2 else { return }

        var total: TimeInterval = 0
        for i in 1..<tapTimes.count {
            total += tapTimes[i].timeIntervalSince(tapTimes[i - 1])
        }
        let average = total / Double(tapTimes.count - 1)
        engine.bpm = 60.0 / average
    }

    private func tempoMarking(_ bpm: Double) -> String {
        switch bpm {
        case ..<40:   return "Grave"
        case ..<60:   return "Largo"
        case ..<66:   return "Larghetto"
        case ..<76:   return "Adagio"
        case ..<108:  return "Andante"
        case ..<120:  return "Moderato"
        case ..<156:  return "Allegro"
        case ..<176:  return "Vivace"
        case ..<200:  return "Presto"
        default:      return "Prestissimo"
        }
    }
}

#Preview {
    ContentView()
}
