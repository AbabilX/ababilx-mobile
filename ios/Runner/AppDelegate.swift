import AVFoundation
import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var ringtonePlayer: AVAudioPlayer?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Same rule as Signal: the notification-center delegate must be set
    // before this method returns, or a tap never reaches Flutter.
    UNUserNotificationCenter.current().delegate = self
    let launched = super.application(
      application,
      didFinishLaunchingWithOptions: launchOptions
    )
    UNUserNotificationCenter.current().delegate = self
    return launched
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
      "/Library/Ringtones/Opening.m4r",
      "/System/Library/Audio/UISounds/nano/Alert_Calendar_Haptic.caf",
      "/System/Library/Audio/UISounds/sms-received1.caf",
      "/System/Library/Audio/UISounds/SIMToolkitCallDropped.caf",
      "/System/Library/Audio/UISounds/Tink.caf",
      "/System/Library/Audio/UISounds/new-mail.caf",
    ]
    guard let path = candidates.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
      return
    }
    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(.playback, mode: .default, options: [.duckOthers, .mixWithOthers])
      try session.setActive(true, options: [])
      let player = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: path))
      player.numberOfLoops = -1
      player.volume = 1.0
      player.prepareToPlay()
      guard player.play() else { return }
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
