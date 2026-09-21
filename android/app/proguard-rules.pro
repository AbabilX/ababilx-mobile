-keep class com.hiennv.flutter_callkit_incoming.** { *; }
-keep class org.webrtc.** { *; }
-dontwarn org.webrtc.**
# Reached by reflection from the patched flutter_webrtc MediaProjection
# callback (android/patches/flutter-webrtc-projection-stop.gradle).
-keep class com.ababilx.app.ScreenCaptureStop { public static void onSystemStop(); }
