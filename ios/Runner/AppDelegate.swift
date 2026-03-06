import Flutter
import UIKit
import MusicKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    let musicChannel = FlutterMethodChannel(name: "com.braindump.music",
                                              binaryMessenger: controller.binaryMessenger)
    
    musicChannel.setMethodCallHandler({
      (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      if call.method == "getSystemMusicPlayerState" {
          self.getSystemMusicPlayerState(result: result)
      } else {
        result(FlutterMethodNotImplemented)
        return
      }
    })

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func getSystemMusicPlayerState(result: @escaping FlutterResult) {
      if #available(iOS 15.0, *) {
          Task {
              let player = SystemMusicPlayer.shared
              let state = player.state
              let isPlaying = state.playbackStatus == .playing
              
              var title: String? = nil
              var artist: String? = nil
              
              if let entry = player.queue.currentEntry {
                  title = entry.title
                  artist = entry.subtitle
              }
              
              DispatchQueue.main.async {
                  result([
                      "isPlaying": isPlaying,
                      "title": title,
                      "artist": artist,
                      "rawStatus": "\(state.playbackStatus)"
                  ])
              }
          }
      } else {
          result(FlutterError(code: "UNAVAILABLE", message: "MusicKit requires iOS 15.0", details: nil))
      }
  }
}
