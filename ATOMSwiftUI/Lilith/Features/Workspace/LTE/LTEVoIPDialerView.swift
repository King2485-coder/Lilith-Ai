import SwiftUI

// MARK: - VoIP Dialer View

struct LTEVoIPDialerView: View {
    @StateObject private var vm = LTEVoIPViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // SIP connection card
            sipStatusCard

            // Dialer
            dialerCard

            // Recent calls
            if !vm.callHistory.isEmpty {
                recentCallsSection
            }
        }
    }

    // MARK: SIP Status

    private var sipStatusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("SIP CONNECTION")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LilithTheme.textSecondary)
                Spacer()
                Circle()
                    .fill(vm.sipConnected ? LilithTheme.accentA : .red)
                    .frame(width: 8, height: 8)
                Text(vm.sipConnected ? "Connected" : "Disconnected")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(vm.sipConnected ? LilithTheme.accentA : .red)
            }

            VStack(spacing: 0) {
                sipInfoRow(label: "Server",   value: "localhost:5060")
                sipInfoRow(label: "Protocol", value: "UDP / TCP")
                sipInfoRow(label: "User A",   value: "sip:user_a@lilith-pvt-lte.local")
                sipInfoRow(label: "User B",   value: "sip:user_b@lilith-pvt-lte.local", last: true)
            }
            .background(LilithTheme.elevated, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            Button {
                vm.toggleConnection()
            } label: {
                Label(vm.sipConnected ? "Disconnect" : "Connect", systemImage: vm.sipConnected ? "phone.down.fill" : "phone.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(vm.sipConnected ? .red : .black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(
                        vm.sipConnected ? Color.red.opacity(0.18) : LilithTheme.accentA,
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(LilithTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(LilithTheme.border, lineWidth: 1))
    }

    private func sipInfoRow(label: String, value: String, last: Bool = false) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(label)
                    .font(.system(size: 12))
                    .foregroundStyle(LilithTheme.textSecondary)
                    .frame(width: 70, alignment: .leading)
                Spacer()
                Text(value)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.trailing)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            if !last {
                Divider().background(LilithTheme.border).padding(.leading, 12)
            }
        }
    }

    // MARK: Dialer

    private var dialerCard: some View {
        VStack(spacing: 16) {
            // Display
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(LilithTheme.elevated)
                HStack {
                    Text(vm.dialString.isEmpty ? "Enter number" : vm.dialString)
                        .font(.system(size: 26, weight: .semibold, design: .monospaced))
                        .foregroundStyle(vm.dialString.isEmpty ? LilithTheme.textSecondary : .white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Spacer()
                    if !vm.dialString.isEmpty {
                        Button {
                            vm.backspace()
                        } label: {
                            Image(systemName: "delete.left")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(LilithTheme.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
            .frame(height: 54)

            // Keypad
            let keys: [[String]] = [
                ["1","2","3"],
                ["4","5","6"],
                ["7","8","9"],
                ["*","0","#"]
            ]
            VStack(spacing: 10) {
                ForEach(keys, id: \.self) { row in
                    HStack(spacing: 10) {
                        ForEach(row, id: \.self) { key in
                            Button {
                                vm.tap(key)
                            } label: {
                                Text(key)
                                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 56)
                                    .background(LilithTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            // Call / End button
            if vm.inCall {
                HStack(spacing: 16) {
                    Button {
                        vm.muteToggle()
                    } label: {
                        Image(systemName: vm.muted ? "mic.slash.fill" : "mic.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(vm.muted ? .orange : LilithTheme.textSecondary)
                            .frame(width: 52, height: 52)
                            .background(LilithTheme.surface, in: Circle())
                    }
                    .buttonStyle(.plain)

                    Button {
                        vm.endCall()
                    } label: {
                        Image(systemName: "phone.down.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color.red, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button {
                        vm.speakerToggle()
                    } label: {
                        Image(systemName: vm.speakerOn ? "speaker.wave.3.fill" : "speaker.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(vm.speakerOn ? LilithTheme.accentA : LilithTheme.textSecondary)
                            .frame(width: 52, height: 52)
                            .background(LilithTheme.surface, in: Circle())
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Button {
                    vm.dial()
                } label: {
                    Image(systemName: "phone.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(LilithTheme.accentA, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(!vm.sipConnected || vm.dialString.isEmpty)
                .opacity((!vm.sipConnected || vm.dialString.isEmpty) ? 0.4 : 1)
            }
        }
        .padding(16)
        .background(LilithTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(LilithTheme.border, lineWidth: 1))
    }

    // MARK: Recent Calls

    private var recentCallsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("RECENT CALLS")
                .font(.caption.weight(.semibold))
                .foregroundStyle(LilithTheme.textSecondary)

            VStack(spacing: 8) {
                ForEach(vm.callHistory) { record in
                    callRow(record)
                }
            }
        }
    }

    private func callRow(_ record: LTECallRecord) -> some View {
        HStack(spacing: 12) {
            Image(systemName: record.direction == .outgoing ? "phone.arrow.up.right" : "phone.arrow.down.left")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(record.direction == .outgoing ? LilithTheme.accentA : LilithTheme.accentB)

            VStack(alignment: .leading, spacing: 2) {
                Text(record.displayName ?? record.number)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Text(record.date.formatted(.relative(presentation: .named)))
                    .font(.caption)
                    .foregroundStyle(LilithTheme.textSecondary)
            }

            Spacer()

            Text(formatDuration(record.duration))
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(LilithTheme.textSecondary)

            Button {
                vm.dialString = record.number
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(LilithTheme.accentA)
                    .frame(width: 32, height: 32)
                    .background(LilithTheme.elevated, in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(LilithTheme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func formatDuration(_ t: TimeInterval) -> String {
        let m = Int(t) / 60
        let s = Int(t) % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - VoIP ViewModel

@MainActor
final class LTEVoIPViewModel: ObservableObject {
    @Published var dialString = ""
    @Published var sipConnected = false
    @Published var inCall = false
    @Published var muted = false
    @Published var speakerOn = false
    @Published var callHistory: [LTECallRecord] = []

    private var callTimer: Timer?
    private var callSeconds: TimeInterval = 0

    func tap(_ key: String) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if dialString.count < 20 { dialString += key }
    }

    func backspace() {
        if !dialString.isEmpty { dialString.removeLast() }
    }

    func toggleConnection() {
        sipConnected.toggle()
        if !sipConnected && inCall { endCall() }
    }

    func dial() {
        guard sipConnected, !dialString.isEmpty else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        inCall = true
        callSeconds = 0
        callTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.callSeconds += 1 }
        }
    }

    func endCall() {
        callTimer?.invalidate()
        callTimer = nil
        if inCall {
            let record = LTECallRecord(
                id: UUID().uuidString,
                direction: .outgoing,
                number: dialString,
                displayName: knownName(for: dialString),
                duration: callSeconds,
                date: Date()
            )
            callHistory.insert(record, at: 0)
        }
        inCall = false
        muted = false
        speakerOn = false
        callSeconds = 0
    }

    func muteToggle() { muted.toggle() }
    func speakerToggle() { speakerOn.toggle() }

    private func knownName(for number: String) -> String? {
        switch number {
        case "111": return "User A"
        case "222": return "User B"
        case "0":   return "Lilith Operator"
        default:    return nil
        }
    }
}
