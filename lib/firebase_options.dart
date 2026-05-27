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
      default:
        throw UnsupportedError(
            'DefaultFirebaseOptions not configured for ${defaultTargetPlatform.name}');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCYHLZKCI-LtwJdUjwycCIYbKKDBKJJTXU',
    appId: '1:327297150133:android:63e8106e9eb1bf657822fc',
    messagingSenderId: '327297150133',
    projectId: 'ababilx',
    storageBucket: 'ababilx.firebasestorage.app',
    androidClientId: '327297150133-ehoak4sd8o7582j14cgg6c7ftvefmvko.apps.googleusercontent.com',
  );
}
