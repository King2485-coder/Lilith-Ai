import Foundation
#if canImport(WebRTC)
import WebRTC
#endif
import AVFoundation
import SwiftUI

#if canImport(WebRTC)
final class WebRTCManager: NSObject, ObservableObject {

    static let shared = WebRTCManager()

    private var factory: RTCPeerConnectionFactory!
    private var peerConnection: RTCPeerConnection!

    private var videoSource: RTCVideoSource!
    private var videoTrack: RTCVideoTrack!
    private var audioTrack: RTCAudioTrack!
    private var capturer: RTCCameraVideoCapturer!

    @Published var localTrack: RTCVideoTrack?
    @Published var remoteTrack: RTCVideoTrack?

    override init() {
        super.init()
        RTCInitializeSSL()
        factory = RTCPeerConnectionFactory()
    }

    func startConnection() {
        createPeerConnection()
        startLocalMedia()
        createOffer()
    }

    func endConnection() {
        peerConnection?.close()
        peerConnection = nil
    }

    func createPeerConnection() {
        let config = RTCConfiguration()

        config.iceServers = [
            RTCIceServer(urlStrings: ["stun:stun.l.google.com:19302"])
        ]

        peerConnection = factory.peerConnection(
            with: config,
            constraints: RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil),
            delegate: self
        )
    }

    func startLocalMedia() {

        videoSource = factory.videoSource()
        capturer = RTCCameraVideoCapturer(delegate: videoSource)

        guard let camera = RTCCameraVideoCapturer.captureDevices().first,
              let format = camera.formats.first else { return }

        capturer.startCapture(with: camera, format: format, fps: 30)

        videoTrack = factory.videoTrack(with: videoSource, trackId: "video0")
        localTrack = videoTrack

        let audioSource = factory.audioSource(with: RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil))
        audioTrack = factory.audioTrack(with: audioSource, trackId: "audio0")

        peerConnection.add(videoTrack, streamIds: ["stream0"])
        peerConnection.add(audioTrack, streamIds: ["stream0"])
    }

    func createOffer() {
        let constraints = RTCMediaConstraints(
            mandatoryConstraints: ["OfferToReceiveAudio": "true", "OfferToReceiveVideo": "true"],
            optionalConstraints: nil
        )

        peerConnection.offer(for: constraints) { offer, _ in
            guard let offer = offer else { return }

            Task {
                do {
                    try await self.peerConnection.setLocalDescription(offer)
                } catch {
                    return
                }

                await MainActor.run {
                    LilithSystem.shared.send("""
                    {
                      "type":"offer",
                      "sdp":"\(offer.sdp)"
                    }
                    """)
                }
            }
        }
    }

    func receiveOffer(_ data: [String: Any]) {
        guard let sdp = data["sdp"] as? String else { return }

        let desc = RTCSessionDescription(type: .offer, sdp: sdp)
        Task {
            do {
                try await peerConnection.setRemoteDescription(desc)
            } catch {
                return
            }
            createAnswer()
        }
    }

    func createAnswer() {
        peerConnection.answer(for: RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)) { answer, _ in
            guard let answer = answer else { return }

            Task {
                do {
                    try await self.peerConnection.setLocalDescription(answer)
                } catch {
                    return
                }

                await MainActor.run {
                    LilithSystem.shared.send("""
                    {
                      "type":"answer",
                      "sdp":"\(answer.sdp)"
                    }
                    """)
                }
            }
        }
    }

    func receiveAnswer(_ data: [String: Any]) {
        guard let sdp = data["sdp"] as? String else { return }

        let desc = RTCSessionDescription(type: .answer, sdp: sdp)
        Task {
            try? await peerConnection.setRemoteDescription(desc)
        }
    }

    func receiveICE(_ data: [String: Any]) {
        guard let candidate = data["candidate"] as? String else { return }

        let ice = RTCIceCandidate(sdp: candidate, sdpMLineIndex: 0, sdpMid: "0")
        Task {
            try? await peerConnection.add(ice)
        }
    }
}

extension WebRTCManager: RTCPeerConnectionDelegate {

    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
                Task { @MainActor in
                        LilithSystem.shared.send("""
                        {
                            "type":"ice",
                            "candidate":"\(candidate.sdp)"
                        }
                        """)
                }
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        if let track = stream.videoTracks.first {
            DispatchQueue.main.async {
                self.remoteTrack = track
            }
        }
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCIceConnectionState) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {}
    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCSignalingState) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCPeerConnectionState) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didStartReceivingOn transceiver: RTCRtpTransceiver) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd rtpReceiver: RTCRtpReceiver, streams: [RTCMediaStream]) {}
}
#else
final class WebRTCManager: NSObject, ObservableObject {

    static let shared = WebRTCManager()

    @Published var localTrack: AnyObject?
    @Published var remoteTrack: AnyObject?

    func startConnection() {}
    func endConnection() {}
    func createPeerConnection() {}
    func startLocalMedia() {}
    func createOffer() {}
    func receiveOffer(_ data: [String: Any]) {}
    func createAnswer() {}
    func receiveAnswer(_ data: [String: Any]) {}
    func receiveICE(_ data: [String: Any]) {}
}
#endif
