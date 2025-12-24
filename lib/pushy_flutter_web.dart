@JS('Pushy')
library pushy_flutter_web;

import 'dart:js_interop';

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
    final obj = <String, Object>{'appId': appId}.jsify() as JSAny;
    final promise = registerJS(obj) as JSPromise;
    return (await promise.toDart) as String;
  }

  // Convert JS promise to future
  static Future<void> subscribe(String topic) async {
    final promise = subscribeJS(topic.toJS) as JSPromise;
    await promise.toDart;
  }

  // Convert JS promise to future
  static Future<void> unsubscribe(String topic) async {
    final promise = unsubscribeJS(topic.toJS) as JSPromise;
    await promise.toDart;
  }

  // Convert non-null to bool
  static Future<bool> isRegistered() async {
    return isRegisteredJS().isDefinedAndNotNull;
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
  final dartData = (data as JSObject).dartify();

  // Success?
  if (dartData is Map) {
    // Invoke Dart notification listener
    _dartCallback(Map<String, JSAny>.from(dartData));
  }
}
