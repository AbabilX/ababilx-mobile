// File generated manually from google-services.json
// Do not commit sensitive keys to public repos.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) throw UnsupportedError('Web not supported.');
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions not configured for ${defaultTargetPlatform.name}',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCYHLZKCI-LtwJdUjwycCIYbKKDBKJJTXU',
    appId: '1:327297150133:android:63e8106e9eb1bf657822fc',
    messagingSenderId: '327297150133',
    projectId: 'ababilx',
    storageBucket: 'ababilx.firebasestorage.app',
    androidClientId:
        '327297150133-ehoak4sd8o7582j14cgg6c7ftvefmvko.apps.googleusercontent.com',
  );

  /// From ios/Runner/GoogleService-Info.plist (bundle com.ababilx.app).
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBcb02N8BGMNkH7PEQr2lzbwTe6SGxg6V8',
    appId: '1:327297150133:ios:c7d8dc5be6e3c3207822fc',
    messagingSenderId: '327297150133',
    projectId: 'ababilx',
    storageBucket: 'ababilx.firebasestorage.app',
    iosClientId:
        '327297150133-p1t4oadh1e50gcop047u9mbg3ppku19n.apps.googleusercontent.com',
    iosBundleId: 'com.ababilx.app',
  );

  /// Web OAuth client (client_type 3) — required as serverClientId for idToken on Android.
  static const String googleWebClientId =
      '327297150133-7vg5888mjqras0pgoqiupg6but4nk0oj.apps.googleusercontent.com';
}
