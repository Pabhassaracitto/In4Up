class GoogleSignInConfig {
  static const String webClientId =
      String.fromEnvironment('GOOGLE_WEB_CLIENT_ID', defaultValue: '');

  static const String desktopClientId =
      String.fromEnvironment('GOOGLE_DESKTOP_CLIENT_ID', defaultValue: '');

  static const String desktopClientSecret =
      String.fromEnvironment('GOOGLE_DESKTOP_CLIENT_SECRET', defaultValue: '');

  static const String iosClientId =
      String.fromEnvironment('GOOGLE_IOS_CLIENT_ID', defaultValue: ''); 
}
