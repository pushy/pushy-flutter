class PushyWebSDK {
  // Convert JS promise to future
  static Future<String> register(String appId) async {
    throw UnsupportedError('This method is only supported on the web platform.');
  }

  // Convert JS promise to future
  static Future<void> subscribe(topic) async {
    throw UnsupportedError('This method is only supported on the web platform.');
  }

  // Convert JS promise to future
  static Future<void> unsubscribe(topic) async {
    throw UnsupportedError('This method is only supported on the web platform.');
  }

  // Convert non-null to bool
  static Future<bool> isRegistered() async {
    throw UnsupportedError('This method is only supported on the web platform.');
  }

  // Pushy Enterprise support
  static void setEnterpriseConfig(endpoint) async {
    throw UnsupportedError('This method is only supported on the web platform.');
  }
  
  static void setNotificationListener(dynamic callback) {
    throw UnsupportedError('This method is only supported on the web platform.');
  }
}