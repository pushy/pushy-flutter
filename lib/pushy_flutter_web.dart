@JS('Pushy')
library pushy_flutter_web;

import 'web/js.dart';
import 'package:universal_html/js_util.dart';

@JS('register')
external dynamic registerJS(dynamic obj);

@JS('isRegistered')
external dynamic isRegisteredJS();

@JS('setNotificationListener')
external void setNotificationListenerJS(Function callback);

@JS('subscribe')
external dynamic subscribeJS(dynamic topic);

@JS('unsubscribe')
external dynamic unsubscribeJS(dynamic topic);

@JS('setEnterpriseConfig')
external void setEnterpriseConfigJS(String endpoint);

class PushyWebSDK {
  // Convert JS promise to future
  static Future<String> register(String appId) async {
    return await promiseToFuture(registerJS(jsify({'appId': appId})));
  }

  // Convert JS promise to future
  static Future<void> subscribe(topic) async {
    return await promiseToFuture(subscribeJS(topic));
  }

  // Convert JS promise to future
  static Future<void> unsubscribe(topic) async {
    return await promiseToFuture(unsubscribeJS(topic));
  }

  // Convert non-null to bool
  static Future<bool> isRegistered() async {
    return !(isRegisteredJS() == Null);
  }

  // Pushy Enterprise support
  static void setEnterpriseConfig(endpoint) async {
    return setEnterpriseConfigJS(endpoint);
  }

  // Convert JS callback into Dart callback 
  static void setNotificationListener(Function callback) {
    // Allow interop permits JS engine to execute Dart callback function
    setNotificationListenerJS(allowInterop((dynamic data) {
      // Invoke app notification listener (convert JS object into Dart Map)
      callback(Map<String, dynamic>.from(dartify(data) as Map));
    }));
  }
}
