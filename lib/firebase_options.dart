// File generated manually to fix project mismatch.
// Previous file was from project gen-lang-client-0027289707 (594...), while
// google-services.json is from vipsound-df903 (342774597309).
// This file now uses vipsound-df903 for all platforms.
// 
// IMPORTANT: Run `flutterfire configure --project=vipsound-df903 --platforms=android,ios,web,windows`
// to regenerate accurately with correct appIds for each flavor.
// For Android flavors, the native google-services.json already contains
// multiple clients (com.in2up, com.in2up.dev, com.in2up.beta, com.vipsound, etc.)
// so Android can also initialize without options (via google-services.json).

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
        // For flavors, use androidForFlavor if you pass --dart-define=FLAVOR=beta
        return androidForFlavor;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        return linux;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // Helper to get Android options per flavor (if you use --dart-define=FLAVOR=beta)
  static FirebaseOptions get androidForFlavor {
    const flavor = String.fromEnvironment('FLAVOR', defaultValue: 'stable');
    switch (flavor) {
      case 'dev':
        return androidDev;
      case 'beta':
        return androidBeta;
      case 'stable':
      default:
        return android;
    }
  }

  // ---------------------------------------------------------------------------
  // vipsound-df903 project (342774597309) - unified config
  // ---------------------------------------------------------------------------

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAsYaEwRBlZ3RW51DoElscbKx6X2JKP2dw',
    appId: '1:342774597309:web:7f7683e09f8781ae1319d4',
    messagingSenderId: '342774597309',
    projectId: 'vipsound-df903',
    authDomain: 'vipsound-df903.firebaseapp.com',
    storageBucket: 'vipsound-df903.firebasestorage.app',
    measurementId: 'G-XXXXXXXXXX',
  );

  // Stable: com.in2up
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAsYaEwRBlZ3RW51DoElscbKx6X2JKP2dw',
    appId: '1:342774597309:android:b0bcf08d94b674b21319d4',
    messagingSenderId: '342774597309',
    projectId: 'vipsound-df903',
    storageBucket: 'vipsound-df903.firebasestorage.app',
  );

  // Dev: com.in2up.dev
  static const FirebaseOptions androidDev = FirebaseOptions(
    apiKey: 'AIzaSyAsYaEwRBlZ3RW51DoElscbKx6X2JKP2dw',
    appId: '1:342774597309:android:807fbf766789f7dd1319d4',
    messagingSenderId: '342774597309',
    projectId: 'vipsound-df903',
    storageBucket: 'vipsound-df903.firebasestorage.app',
  );

  // Beta: com.in2up.beta
  static const FirebaseOptions androidBeta = FirebaseOptions(
    apiKey: 'AIzaSyAsYaEwRBlZ3RW51DoElscbKx6X2JKP2dw',
    appId: '1:342774597309:android:7f7683e09f8781ae1319d4',
    messagingSenderId: '342774597309',
    projectId: 'vipsound-df903',
    storageBucket: 'vipsound-df903.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAsYaEwRBlZ3RW51DoElscbKx6X2JKP2dw',
    appId: '1:342774597309:ios:40im71rl7k9h99fl1tv77p3oe61hhkg7',
    messagingSenderId: '342774597309',
    projectId: 'vipsound-df903',
    storageBucket: 'vipsound-df903.firebasestorage.app',
    iosClientId:
        '342774597309-7nqkge1vl8mljh6dcd5g3t1qbfi4g618.apps.googleusercontent.com',
    iosBundleId: 'com.in2up',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyAsYaEwRBlZ3RW51DoElscbKx6X2JKP2dw',
    appId: '1:342774597309:web:d3c25673d95f0911945ef6',
    messagingSenderId: '342774597309',
    projectId: 'vipsound-df903',
    authDomain: 'vipsound-df903.firebaseapp.com',
    storageBucket: 'vipsound-df903.firebasestorage.app',
  );

  static const FirebaseOptions linux = FirebaseOptions(
    apiKey: 'AIzaSyAsYaEwRBlZ3RW51DoElscbKx6X2JKP2dw',
    appId: '1:342774597309:web:linux001122334455',
    messagingSenderId: '342774597309',
    projectId: 'vipsound-df903',
    authDomain: 'vipsound-df903.firebaseapp.com',
    storageBucket: 'vipsound-df903.firebasestorage.app',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyAsYaEwRBlZ3RW51DoElscbKx6X2JKP2dw',
    appId: '1:342774597309:ios:40im71rl7k9h99fl1tv77p3oe61hhkg7',
    messagingSenderId: '342774597309',
    projectId: 'vipsound-df903',
    storageBucket: 'vipsound-df903.firebasestorage.app',
    iosClientId:
        '342774597309-7nqkge1vl8mljh6dcd5g3t1qbfi4g618.apps.googleusercontent.com',
    iosBundleId: 'com.in2up',
  );
}
