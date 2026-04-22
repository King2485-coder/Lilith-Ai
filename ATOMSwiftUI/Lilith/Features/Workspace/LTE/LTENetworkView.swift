import SwiftUI
import CoreImage.CIFilterBuiltins

// MARK: - ViewModel

@MainActor
final class LTENetworkViewModel: ObservableObject {
    @Published var nodes: [LTENetworkNode] = LTENetworkNode.samples
    @Published var isRefreshing = false
    @Published var lastRefreshed: Date? = nil

    func refresh() async {
        isRefreshing = true
        try? await Task.sleep(nanoseconds: 1_200_000_000)
        // Simulate a small variation in status
        nodes = LTENetworkNode.samples
        lastRefreshed = Date()
        isRefreshing = false
    }

    var operationalCount: Int { nodes.filter { $0.status == .operational }.count }
    var offlineCount: Int { nodes.filter { $0.status == .offline }.count }
    var degradedCount: Int { nodes.filter { $0.status == .degraded }.count }
}

// MARK: - Main LTE View

struct LTENetworkView: View {
    @StateObject private var vm = LTENetworkViewModel()
    @State private var selectedTab: LTETab = .network

    enum LTETab: String, CaseIterable {
        case network = "Network"
        case esim    = "eSIM"
        case voip    = "VoIP"
        case subscribers = "Subscribers"

        var icon: String {
            switch self {
            case .network:     return "antenna.radiowaves.left.and.right"
            case .esim:        return "simcard.2"
            case .voip:        return "phone.connection"
            case .subscribers: return "person.2"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(LTETab.allCases, id: \.self) { tab in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { selectedTab = tab }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: tab.icon)
                                    .font(.system(size: 13, weight: .semibold))
                                Text(tab.rawValue)
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                            }
                            .foregroundStyle(selectedTab == tab ? .black : LilithTheme.textSecondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(
                                Capsule()
                                    .fill(selectedTab == tab ? LilithTheme.accentA : LilithTheme.surface)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }

            Divider().background(LilithTheme.border)

            ScrollView {
                Group {
                    switch selectedTab {
                    case .network:     networkSection
                    case .esim:        esimSection
                    case .voip:        voipSection
                    case .subscribers: subscriberSection
                    }
                }
                .padding(16)
            }
        }
        .background(LilithTheme.background)
        .task { await vm.refresh() }
    }

    // MARK: Network Status

    private var networkSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Summary cards
            HStack(spacing: 12) {
                lteStatCard(label: "Operational", value: "\(vm.operationalCount)", icon: "checkmark.circle.fill", color: LilithTheme.accentA)
                lteStatCard(label: "Degraded",    value: "\(vm.degradedCount)",    icon: "exclamationmark.triangle.fill", color: .orange)
                lteStatCard(label: "Offline",     value: "\(vm.offlineCount)",     icon: "xmark.circle.fill", color: .red)
            }

            HStack {
                Text("NODES")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LilithTheme.textSecondary)
                Spacer()
                if let last = vm.lastRefreshed {
                    Text("Updated \(last.formatted(.relative(presentation: .named)))")
                        .font(.caption2)
                        .foregroundStyle(LilithTheme.textSecondary)
                }
                Button {
                    Task { await vm.refresh() }
                } label: {
                    Image(systemName: vm.isRefreshing ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(LilithTheme.accentA)
                        .rotationEffect(.degrees(vm.isRefreshing ? 360 : 0))
                        .animation(vm.isRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: vm.isRefreshing)
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: 8) {
                ForEach(vm.nodes) { node in
                    lteNodeRow(node)
                }
            }

            networkInfoCard
        }
    }

    private func lteStatCard(label: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(LilithTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(LilithTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func lteNodeRow(_ node: LTENetworkNode) -> some View {
        HStack(spacing: 12) {
            Image(systemName: node.status.icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(nodeStatusColor(node.status))
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(node.name)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text(node.type)
                    .font(.caption)
                    .foregroundStyle(LilithTheme.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(":\(node.port)")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(LilithTheme.textSecondary)
                Text(node.protocol_)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(LilithTheme.textSecondary.opacity(0.7))
            }

            Text(node.status.label)
                .font(.caption2.weight(.bold))
                .foregroundStyle(nodeStatusColor(node.status))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(nodeStatusColor(node.status).opacity(0.15), in: Capsule())
        }
        .padding(12)
        .background(LilithTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var networkInfoCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("NETWORK PARAMETERS")
                .font(.caption.weight(.semibold))
                .foregroundStyle(LilithTheme.textSecondary)

            VStack(spacing: 0) {
                lteInfoRow(label: "Carrier", value: "LILITH")
                lteInfoRow(label: "PLMN", value: "001-01")
                lteInfoRow(label: "MCC / MNC", value: "001 / 01")
                lteInfoRow(label: "APN", value: "lilith")
                lteInfoRow(label: "UE Subnet", value: "10.45.0.0/16")
                lteInfoRow(label: "Band Node 1", value: "2680 MHz")
                lteInfoRow(label: "Band Node 2", value: "2700 MHz", last: true)
            }
            .background(LilithTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func lteInfoRow(label: String, value: String, last: Bool = false) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(label)
                    .font(.system(size: 13))
                    .foregroundStyle(LilithTheme.textSecondary)
                Spacer()
                Text(value)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            if !last {
                Divider().background(LilithTheme.border).padding(.leading, 14)
            }
        }
    }

    private func nodeStatusColor(_ status: LTENodeStatus) -> Color {
        switch status {
        case .operational: return LilithTheme.accentA
        case .degraded:    return .orange
        case .offline:     return .red
        case .unknown:     return LilithTheme.textSecondary
        }
    }

    // MARK: eSIM

    private var esimSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your eSIM profiles for the Lilith Private LTE Network. Scan the QR code or enter the LPA string manually in your device settings.")
                .font(.caption)
                .foregroundStyle(LilithTheme.textSecondary)

            ForEach(LTEeSIMProfile.samples) { profile in
                LTEeSIMCard(profile: profile)
            }

            // Activation instructions
            VStack(alignment: .leading, spacing: 10) {
                Text("ACTIVATION")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LilithTheme.textSecondary)

                VStack(alignment: .leading, spacing: 8) {
                    activationStep(num: 1, text: "Open Settings → Cellular → Add eSIM")
                    activationStep(num: 2, text: "Tap \"Use QR Code\" and scan the code above")
                    activationStep(num: 3, text: "Carrier will display as LILITH")
                    activationStep(num: 4, text: "Alternatively, enter the LPA string manually")
                }
                .padding(14)
                .background(LilithTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    private func activationStep(num: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(num)")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.black)
                .frame(width: 20, height: 20)
                .background(LilithTheme.accentA, in: Circle())
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(.white)
        }
    }

    // MARK: VoIP

    private var voipSection: some View {
        LTEVoIPDialerView()
    }

    // MARK: Subscribers

    private var subscriberSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Subscribers")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Registered on the Lilith Private LTE Network")
                        .font(.caption)
                        .foregroundStyle(LilithTheme.textSecondary)
                }
                Spacer()
                Text("\(LTESubscriber.samples.count) active")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LilithTheme.accentA)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(LilithTheme.accentA.opacity(0.15), in: Capsule())
            }

            VStack(spacing: 8) {
                ForEach(LTESubscriber.samples) { sub in
                    lteSubscriberRow(sub)
                }
            }

            networkInfoCard
        }
    }

    private func lteSubscriberRow(_ sub: LTESubscriber) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(LilithTheme.accentA.opacity(0.18))
                        .frame(width: 40, height: 40)
                    Text(sub.name.prefix(1))
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(LilithTheme.accentA)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(sub.name)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("MSISDN \(sub.msisdn)")
                        .font(.caption)
                        .foregroundStyle(LilithTheme.textSecondary)
                }

                Spacer()

                Text(sub.status.capitalized)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(sub.status == "active" ? LilithTheme.accentA : .red)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background((sub.status == "active" ? LilithTheme.accentA : Color.red).opacity(0.15), in: Capsule())
            }

            VStack(spacing: 0) {
                lteInfoRow(label: "IMSI", value: sub.imsi)
                lteInfoRow(label: "IMEI", value: sub.imei)
                lteInfoRow(label: "APN",  value: sub.apn, last: true)
            }
            .background(LilithTheme.elevated, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding(14)
        .background(LilithTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - eSIM Card

struct LTEeSIMCard: View {
    let profile: LTEeSIMProfile
    @State private var showLPA = false
    @State private var showCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(profile.userName)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("MSISDN \(profile.msisdn) · \(profile.carrier)")
                        .font(.caption)
                        .foregroundStyle(LilithTheme.textSecondary)
                }
                Spacer()
                Image(systemName: "simcard.2.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(LilithTheme.accentA)
            }

            // QR code generated from LPA string
            HStack {
                Spacer()
                LTEQRCodeView(content: profile.lpaString)
                    .frame(width: 160, height: 160)
                    .padding(10)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                Spacer()
            }

            // ICCID
            VStack(spacing: 0) {
                lteDetailRow(label: "ICCID", value: profile.iccid)
                lteDetailRow(label: "IMSI",  value: profile.imsi, last: !showLPA)
                if showLPA {
                    lteDetailRow(label: "LPA String", value: profile.lpaString, mono: true, last: true)
                }
            }
            .background(LilithTheme.elevated, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            HStack(spacing: 10) {
                Button {
                    withAnimation { showLPA.toggle() }
                } label: {
                    Label(showLPA ? "Hide LPA" : "Show LPA", systemImage: showLPA ? "eye.slash" : "eye")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(LilithTheme.elevated, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    UIPasteboard.general.string = profile.lpaString
                    withAnimation { showCopied = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation { showCopied = false }
                    }
                } label: {
                    Label(showCopied ? "Copied!" : "Copy LPA", systemImage: showCopied ? "checkmark" : "doc.on.doc")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(showCopied ? .black : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(showCopied ? LilithTheme.accentA : LilithTheme.elevated, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(LilithTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(LilithTheme.border, lineWidth: 1)
        )
    }

    private func lteDetailRow(label: String, value: String, mono: Bool = false, last: Bool = false) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                Text(label)
                    .font(.system(size: 12))
                    .foregroundStyle(LilithTheme.textSecondary)
                    .frame(width: 70, alignment: .leading)
                Spacer()
                Text(value)
                    .font(.system(size: 12, weight: .semibold, design: mono ? .monospaced : .default))
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
}

// MARK: - QR Code Generator

struct LTEQRCodeView: View {
    let content: String

    private var qrImage: UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(content.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    var body: some View {
        Group {
            if let img = qrImage {
                Image(uiImage: img)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "qrcode")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(LilithTheme.textSecondary)
            }
        }
    }
}
