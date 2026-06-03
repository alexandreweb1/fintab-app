// ignore_for_file: lines_longer_than_80_chars
//
// Gerado automaticamente via firebase apps:sdkconfig
// Projeto: my-finance-app-flutter
// NÃO versione este arquivo em repositórios públicos.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions não foi configurado para '
          '${defaultTargetPlatform.name}.',
        );
      case TargetPlatform.fuchsia:
        throw UnsupportedError(
            'DefaultFirebaseOptions não suporta Fuchsia.');
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDB_Ot43QD3bc89pII1uEcUH1CjBuSBIRo',
    authDomain: 'my-finance-app-flutter.firebaseapp.com',
    projectId: 'my-finance-app-flutter',
    storageBucket: 'my-finance-app-flutter.firebasestorage.app',
    messagingSenderId: '53669256636',
    appId: '1:53669256636:web:6958fda619770505a55fb9',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBrVkpRHhciklzKNJeQOerYlJwH339PvmM',
    appId: '1:53669256636:android:8c6a428486cc96e5a55fb9',
    messagingSenderId: '53669256636',
    projectId: 'my-finance-app-flutter',
    storageBucket: 'my-finance-app-flutter.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDNuKph3DjNVluQoNbHN23_JZ3okgD90ic',
    appId: '1:53669256636:ios:796a9640e566c77ca55fb9',
    messagingSenderId: '53669256636',
    projectId: 'my-finance-app-flutter',
    storageBucket: 'my-finance-app-flutter.firebasestorage.app',
    iosBundleId: 'com.alexdev.fintab',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyDNuKph3DjNVluQoNbHN23_JZ3okgD90ic',
    appId: '1:53669256636:ios:796a9640e566c77ca55fb9',
    messagingSenderId: '53669256636',
    projectId: 'my-finance-app-flutter',
    storageBucket: 'my-finance-app-flutter.firebasestorage.app',
    iosBundleId: 'com.alexdev.fintab',
  );
}
