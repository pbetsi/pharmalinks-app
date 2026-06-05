import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // 🔥 REMPLACEZ PAR VOS VALEURS FIREBASE
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCFJZ4FsFwP6tNqNb9ZODsNtEwzMu970ck',
    appId: '1:123456789012:web:abcdef123456',
    messagingSenderId: '123456789012',
    projectId: 'pharmalink-africa',
    authDomain: 'pharmalink-africa.firebaseapp.com',
    storageBucket: 'pharmalink-africa.appspot.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCFJZ4FsFwP6tNqNb9ZODsNtEwzMu970ck',
    appId: '1:123456789012:android:abcdef123456',
    messagingSenderId: '123456789012',
    projectId: 'pharmalink-africa',
    storageBucket: 'pharmalink-africa.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCFJZ4FsFwP6tNqNb9ZODsNtEwzMu970ck',
    appId: '1:123456789012:ios:abcdef123456',
    messagingSenderId: '123456789012',
    projectId: 'pharmalink-africa',
    storageBucket: 'pharmalink-africa.appspot.com',
    iosBundleId: 'com.pharmalink.africa',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyCFJZ4FsFwP6tNqNb9ZODsNtEwzMu970ck',
    appId: '1:123456789012:macos:abcdef123456',
    messagingSenderId: '123456789012',
    projectId: 'pharmalink-africa',
    storageBucket: 'pharmalink-africa.appspot.com',
    iosBundleId: 'com.pharmalink.africa',
  );
}