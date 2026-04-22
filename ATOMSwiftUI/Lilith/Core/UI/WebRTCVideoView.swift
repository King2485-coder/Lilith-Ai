import SwiftUI
#if canImport(WebRTC)
import WebRTC
#endif

#if canImport(WebRTC)
struct RTCVideoView: UIViewRepresentable {

    var track: RTCVideoTrack?

    func makeUIView(context: Context) -> RTCMTLVideoView {
        let view = RTCMTLVideoView()
        view.videoContentMode = .scaleAspectFill
        return view
    }

    func updateUIView(_ uiView: RTCMTLVideoView, context: Context) {
        track?.add(uiView)
    }
}
#else
struct RTCVideoView: View {

    var track: AnyObject?

    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.black.opacity(0.2))
            .overlay(
                Text("WebRTC unavailable")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
            )
    }
}
#endif
