// File generated manually to fix project mismatch.
// Previous file was from project gen-lang-client-0027289707 (594...), while
// google-services.json is from vipsound-df903 (342774597309).
// This file now uses vipsound-df903 for all platforms.
// 
// IMPORTANT: Run `flutterfire configure --project=vipsound-df903 --platforms=android,ios,web,windows`
// to regenerate accurately with correct appIds for each flavor.
// For Android flavors, the native google-services.json already contains
// multiple clients (com.in4up, com.in4up.dev, com.in4up.beta, com.vipsound, etc.)
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
    apiKey: 'AIzaSyD-xDY8nduuCp8-G_S1CPfyoyYdgWvCJCk',
    appId: '1:342774597309:web:90afbabbcf57e8211319d4',
    messagingSenderId: '342774597309',
    projectId: 'vipsound-df903',
    authDomain: 'vipsound-df903.firebaseapp.com',
    databaseURL: 'https://vipsound-df903-default-rtdb.firebaseio.com',
    storageBucket: 'vipsound-df903.firebasestorage.app',
    measurementId: 'G-CMJ1PMPHPX',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAsYaEwRBlZ3RW51DoElscbKx6X2JKP2dw',
    appId: '1:342774597309:android:e0a919b0fb77dd391319d4',
    messagingSenderId: '342774597309',
    projectId: 'vipsound-df903',
    databaseURL: 'https://vipsound-df903-default-rtdb.firebaseio.com',
    storageBucket: 'vipsound-df903.firebasestorage.app',
  );

  // Stable: com.in4up

  // Dev: com.in4up.dev
  static const FirebaseOptions androidDev = FirebaseOptions(
    apiKey: 'AIzaSyAsYaEwRBlZ3RW51DoElscbKx6X2JKP2dw',
    appId: '1:342774597309:android:807fbf766789f7dd1319d4',
    messagingSenderId: '342774597309',
    projectId: 'vipsound-df903',
    storageBucket: 'vipsound-df903.firebasestorage.app',
  );

  // Beta: com.in4up.beta
  static const FirebaseOptions androidBeta = FirebaseOptions(
    apiKey: 'AIzaSyAsYaEwRBlZ3RW51DoElscbKx6X2JKP2dw',
    appId: '1:342774597309:android:7f7683e09f8781ae1319d4',
    messagingSenderId: '342774597309',
    projectId: 'vipsound-df903',
    storageBucket: 'vipsound-df903.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBpNh1jlG74XV_VplhSSqL--jFYvVOrRig',
    appId: '1:342774597309:ios:f1643ab0df1208351319d4',
    messagingSenderId: '342774597309',
    projectId: 'vipsound-df903',
    databaseURL: 'https://vipsound-df903-default-rtdb.firebaseio.com',
    storageBucket: 'vipsound-df903.firebasestorage.app',
    androidClientId: '342774597309-276p37a3jequc9hfp3vsrfn1b6jels0b.apps.googleusercontent.com',
    iosClientId: '342774597309-gk1uua5n5ldohtt4nroc8irie05bed4m.apps.googleusercontent.com',
    iosBundleId: 'com.in4up',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyD-xDY8nduuCp8-G_S1CPfyoyYdgWvCJCk',
    appId: '1:342774597309:web:777b459680ec02461319d4',
    messagingSenderId: '342774597309',
    projectId: 'vipsound-df903',
    authDomain: 'vipsound-df903.firebaseapp.com',
    databaseURL: 'https://vipsound-df903-default-rtdb.firebaseio.com',
    storageBucket: 'vipsound-df903.firebasestorage.app',
    measurementId: 'G-N72C4S87J8',
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
    iosBundleId: 'com.in4up',
  );
}