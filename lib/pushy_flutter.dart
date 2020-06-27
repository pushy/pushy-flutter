import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

typedef void NotificationCallback(Map<String, dynamic> data);

class Pushy {
  static const MethodChannel _channel =
      const MethodChannel('me.pushy.sdk.flutter/methods');
  static const EventChannel _eventChannel =
      const EventChannel('me.pushy.sdk.flutter/events');

  static NotificationCallback _notificationListener;
  static NotificationCallback _notificationClickListener;

  static var notificationQueue = [];
  static var notificationClickQueue = [];

  static Future<String> register() async {
    // Register for push notifications
    return await _channel.invokeMethod('register');
  }

  static void listen() {
    // Invoke native method
    _channel.invokeMethod('listen');

    // Listen for notifications published on event channel
    _eventChannel.receiveBroadcastStream().listen((dynamic data) {
      // Decode JSON string into map
      Map<String, dynamic> result = json.decode(data);

      // Print debug log
      print('Pushy notification received: $result');

      // Notification clicked?
      if (result['_pushyNotificationClicked'] != null) {
        // Notification click listener defined?
        if (_notificationClickListener != null) {
          _notificationClickListener(result);
        } else {
          // Queue for later
          notificationClickQueue.add(result);
        }
      } else {
        // Notification received (not clicked)
        if (_notificationListener != null) {
          _notificationListener(result);
        } else {
          // Queue for later
          notificationQueue.add(result);
        }
      }
    }, onError: (dynamic error) {
      // Print error
      print('Error: ${error.message}');
    });
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
    // Save listener for later
    _notificationListener = fn;

    // Any notifications pending?
    if (notificationQueue.length > 0) {
      notificationQueue.forEach((element) => {_notificationListener(element)});

      // Empty queue
      notificationQueue = [];
    }
  }

  static void setNotificationClickListener(NotificationCallback fn) {
    // Save listener for later
    _notificationClickListener = fn;

    // Any notifications pending?
    if (notificationClickQueue.length > 0) {
      notificationClickQueue
          .forEach((element) => {_notificationClickListener(element)});

      // Empty queue
      notificationClickQueue = [];
    }
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

  static void toggleFCM(bool value) {
    // Invoke native method
    _channel.invokeMethod('toggleFCM', <dynamic>[value]);
  }

  static void toggleNotifications(bool value) {
    // Invoke native method
    _channel.invokeMethod('toggleNotifications', <dynamic>[value]);
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

  static Future<Object> getDeviceCredentials() async {
    // Fetch device credentials as list
    List result = await _channel.invokeMethod('getDeviceCredentials');

    // Return null if device not registered yet
    if (result == null) {
      return result;
    }
  
    // Convert list to map of {token, authKey}
    return {'token': result[0], 'authKey': result[1]};
  }

  static Future<String> setDeviceCredentials(Map credentials) async {
    // Attempt to assign device credentials
    return await _channel.invokeMethod('setDeviceCredentials', <dynamic>[credentials['token'], credentials['authKey']]);
  }

}
