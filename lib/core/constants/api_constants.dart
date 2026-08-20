class ApiConstants {
  // Live Base URLs (Commented for now)
  // static const String deviceBaseUrl = 'https://mhx.vhb.temporary.site/';
  // static const String storageBaseUrl = 'https://mhx.vhb.temporary.site/public/storage/';

  // Local / Wi-Fi Network Base URLs
  static const String deviceBaseUrl = 'http://192.168.100.203:3000/';
  static const String storageBaseUrl = 'http://192.168.100.203:3000';

  static String get socketUrl {
    final uri = Uri.tryParse(deviceBaseUrl);
    if (uri != null && uri.hasAuthority) {
      if (uri.hasPort) {
        return '${uri.scheme}://${uri.host}:${uri.port}';
      }
      return '${uri.scheme}://${uri.host}';
    }
    return 'http://192.168.100.203:3000';
  }

  static const String weatherBaseUrl = 'https://api.openweathermap.org/';
  static const String weatherApiKey = 'ed2a5bdfe284309e18af7143f7d94eb6';

  static const String appTag = 'TvApp';
  static const String toastMessage =
      'Please verify your internet connection as something seems to have gone wrong.';
  static const String someWrongMessage =
      'Something went wrong or you are disconnected';
  static const String screenDisconnectedMsg =
      'Screen has been disconnected. Connect and come again';
  static const String screenDeletedMsg =
      'Screen has been deleted. Create new one and come again';

  static String getFullStorageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    if (path.startsWith('/')) {
      return '$storageBaseUrl$path';
    }
    return '$storageBaseUrl/$path';
  }
}
