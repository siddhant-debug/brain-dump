import Foundation
import Speech
import AVFoundation
import Flutter

class SpeechRecognitionService {
    static let shared = SpeechRecognitionService()
    
    func setupChannel(messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(name: "com.braindump.speech", binaryMessenger: messenger)
        channel.setMethodCallHandler { [weak self] (call, result) in
            guard let self = self else { return }
            
            switch call.method {
            case "requestPermissions":
                self.requestPermissions(result: result)
            case "checkPermissions":
                self.checkPermissions(result: result)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }
    
    private func requestPermissions(result: @escaping FlutterResult) {
        // 1. Request Speech Recognition Authorization
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    // 2. If Speech is authorized, request Microphone permission
                    self.requestMicrophonePermission(result: result)
                case .denied, .restricted, .notDetermined:
                    print("[SpeechRecognitionService] Speech recognition denied or restricted: \(authStatus)")
                    result(false)
                @unknown default:
                    result(false)
                }
            }
        }
    }
    
    private func requestMicrophonePermission(result: @escaping FlutterResult) {
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            DispatchQueue.main.async {
                if granted {
                    print("[SpeechRecognitionService] Both Speech and Mic permissions granted.")
                    result(true)
                } else {
                    print("[SpeechRecognitionService] Microphone permission denied.")
                    result(false)
                }
            }
        }
    }
    
    private func checkPermissions(result: @escaping FlutterResult) {
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        let micStatus = AVAudioSession.sharedInstance().recordPermission
        
        let isAuthorized = (speechStatus == .authorized) && (micStatus == .granted)
        result(isAuthorized)
    }
}
