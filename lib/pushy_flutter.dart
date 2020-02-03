import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

typedef void NotificationCallback(Map<String, dynamic> data);

class Pushy {
  static const MethodChannel _channel =
      const MethodChannel('me.pushy.sdk.flutter/methods');
  static const EventChannel _eventChannel =
      const EventChannel('me.pushy.sdk.flutter/events');

  static Future<String> register() async {
    // Register for push notifications
    return await _channel.invokeMethod('register');
  }

  static void listen() {
    // Invoke native method
    _channel.invokeMethod('listen');
  }

  static void requestStoragePermission() {
    // Show permission request dialog
    _channel.invokeMethod('requestStoragePermission');
  }

  static Future<bool> isRegistered() async {
    // Query for registration status
    String result = await _channel.invokeMethod('isRegistered');

    // Convert string result to bool
    return result == "true" ? true : false;
  }

  static void setNotificationListener(NotificationCallback fn) {
    // Listen for notifications published on event channel
    _eventChannel.receiveBroadcastStream().listen((dynamic data) {
      // Decode JSON string into map
      Map<String, dynamic> result = json.decode(data);

      // Invoke callback
      fn(result);
    }, onError: (dynamic error) {
      // Print error
      print('Error: ${error.message}');
    });
  }

  static Future<String> subscribe(String topic) async {
    // Attempt to subscribe the device to topic
    return await _channel.invokeMethod('subscribe', <dynamic>[topic]);
  }

  static Future<String> unsubscribe(String topic) async {
    // Attempt to unsubscribe the device from topic
    return await _channel.invokeMethod('unsubscribe', <dynamic>[topic]);
  }

  static void setEnterpriseConfig(String apiEndpoint, String mqttEndpoint) {
    // Invoke native method
    _channel.invokeMethod(
        'setEnterpriseConfig', <dynamic>[apiEndpoint, mqttEndpoint]);
  }

  static void setNotificationIcon(String resourceName) {
    // Invoke native method
    _channel.invokeMethod('setNotificationIcon', <dynamic>[resourceName]);
  }

  static void setHeartbeatInterval(int resourceName) {
    // Invoke native method
    _channel.invokeMethod('setHeartbeatInterval', <dynamic>[resourceName]);
  }

  static void clearBadge() {
    // Invoke native method
    _channel.invokeMethod('clearBadge');
  }
}
