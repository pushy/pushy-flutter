@JS('Pushy')
library pushy_flutter_web;

import 'dart:js_interop';
import 'package:universal_html/js_util.dart';

@JS('register')
external JSAny registerJS(JSAny obj);

@JS('isRegistered')
external JSAny isRegisteredJS();

@JS('setNotificationListener')
external void setNotificationListenerJS(JSFunction callback);

@JS('subscribe')
external JSAny subscribeJS(JSAny topic);

@JS('unsubscribe')
external JSAny unsubscribeJS(JSAny topic);

@JS('setEnterpriseConfig')
external void setEnterpriseConfigJS(String endpoint);

// Define notification listener callback function and its params
typedef NotificationCallback = void Function(Map<String, JSAny>);

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

  // Notification received listener
  static void setNotificationListener(NotificationCallback callback) {
    // Save Dart callback for later
    _dartCallback = callback;

    // Exported function passed to JS
    setNotificationListenerJS(_jsCallback.toJS);
  }
}

// Store handle to Dart callback
late NotificationCallback _dartCallback;

void _jsCallback(JSAny data) {
  // Convert JS object into Dart Map
  final dartData = dartify(data);

  // Success?
  if (dartData is Map) {
    // Invoke Dart notification listener
    _dartCallback(Map<String, JSAny>.from(dartData));
  }
}
