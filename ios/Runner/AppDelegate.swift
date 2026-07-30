import AVFoundation
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var ringtonePlayer: AVAudioPlayer?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let messenger = engineBridge.applicationRegistrar.messenger()
    FlutterMethodChannel(
      name: "com.ababilx.app/ringtone",
      binaryMessenger: messenger
    ).setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "start":
        self?.startRingtone()
        result(nil)
      case "stop":
        self?.stopRingtone()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func startRingtone() {
    stopRingtone()
    // Best-effort system alert sound loop while the in-app call screen is open.
    // Full lock-screen ringing stays on CallKit.
    let candidates = [
      "/System/Library/Audio/UISounds/nano/Alert_Calendar_Haptic.caf",
      "/System/Library/Audio/UISounds/sms-received1.caf",
      "/System/Library/Audio/UISounds/Tink.caf",
    ]
    guard let path = candidates.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
      return
    }
    do {
      try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.duckOthers])
      try AVAudioSession.sharedInstance().setActive(true)
      let player = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: path))
      player.numberOfLoops = -1
      player.volume = 1.0
      player.play()
      ringtonePlayer = player
    } catch {
      // Keep silent rather than crash if the system sound is unavailable.
    }
  }

  private func stopRingtone() {
    ringtonePlayer?.stop()
    ringtonePlayer = nil
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
  }
}
