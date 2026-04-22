import SwiftUI

struct CallView: View {

    @ObservedObject var webrtc = WebRTCManager.shared

    var body: some View {
        ZStack {

            Color.black.ignoresSafeArea()

            if let remote = webrtc.remoteTrack {
                RTCVideoView(track: remote)
                    .ignoresSafeArea()
            }

            VStack {
                HStack {
                    Spacer()

                    if let local = webrtc.localTrack {
                        RTCVideoView(track: local)
                            .frame(width: 120, height: 180)
                            .cornerRadius(12)
                            .padding()
                    }
                }

                Spacer()

                Button(action: {
                    WebRTCManager.shared.endConnection()
                }) {
                    Image(systemName: "phone.down.fill")
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.red)
                        .clipShape(Circle())
                }
                .padding(.bottom, 40)
            }
        }
    }
}
