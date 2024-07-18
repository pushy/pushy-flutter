import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'dart:async';

import 'package:pushy_flutter/pushy_flutter.dart';

void main() => runApp(Main());

// Please place this code in main.dart,
// After the import statements, and outside any Widget class (top-level)

@pragma('vm:entry-point')
void backgroundNotificationListener(Map<String, dynamic> data) {
  // Print notification payload data
  print('Received notification: $data');

  // Notification title
  String notificationTitle = 'MyApp';

  // Attempt to extract the "message" property from the payload: {"message":"Hello World!"}
  String notificationText = data['message'] ?? 'Hello World!';

  // Android: Displays a system notification
  // iOS: Displays an alert dialog
  Pushy.notify(notificationTitle, notificationText, data);

  // Clear iOS app badge number
  Pushy.clearBadge();
}

class Main extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pushy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // Light theme with dark action bar
        brightness: Brightness.light,
        primaryColor: Colors.grey[900],
        secondaryHeaderColor: Colors.redAccent,
      ),
      home: PushyDemo(),
    );
  }
}

class PushyDemo extends StatefulWidget {
  @override
  _PushyDemoState createState() => _PushyDemoState();
}

class _PushyDemoState extends State<PushyDemo> {
  String _deviceToken = 'Loading...';
  String _instruction = '(please wait)';

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  // Platform messages are asynchronous, so we initialize in an async method
  Future<void> initPlatformState() async {
    // Start the Pushy service
    Pushy.listen();

    // Set Pushy app ID (required for Web Push)
    Pushy.setAppId('550ee57c5b5d72117f51e801');

    try {
      // Register the device for push notifications
      String deviceToken = await Pushy.register();

      // Print token to console/logcat
      print('Device token: $deviceToken');

      // Send the token to your backend server
      // ...

      // Update UI with token
      setState(() {
        _deviceToken = deviceToken;
        _instruction =
            isAndroid() ? '(copy from logcat)' : '(copy from console)';
      });
    } catch (error) {
      // Print to console/logcat
      print('Error: ${error.toString()}');

      // Show error
      setState(() {
        _deviceToken = 'Registration failed';
        _instruction = '(restart app to try again)';
      });
    }

    // Enable in-app notification banners (iOS 10+)
    Pushy.toggleInAppBanner(false);

    // Listen for push notifications received
    Pushy.setNotificationListener(backgroundNotificationListener);

    // Listen for push notification clicked
    Pushy.setNotificationClickListener((Map<String, dynamic> data) {
      // Print notification payload data
      print('Notification clicked: $data');

      // Extract notification messsage
      String message = data['message'] ?? 'Hello World!';

      // Display an alert with the "message" payload value
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
              title: Text('Notification clicked'),
              content: Text(message),
              actions: [
                ElevatedButton(
                  child: Text('OK'),
                  onPressed: () {
                    Navigator.of(context, rootNavigator: true).pop('dialog');
                  },
                )
              ]);
        },
      );

      // Clear iOS app badge number
      Pushy.clearBadge();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Demo app UI
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pushy'),
        foregroundColor: Colors.white,
        backgroundColor: Colors.grey[900]
      ),
      body: Builder(
        builder: (context) => Center(
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
              Image.asset('assets/ic_logo.png', width: 90),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Text(_deviceToken,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.grey[700])),
              ),
              Text(_instruction,
                  style: TextStyle(fontSize: 13, color: Colors.grey[600])),
            ])),
      ),
    );
  }
}

bool isAndroid() {
  try {
    // Return whether the device is running on Android
    return Platform.isAndroid;
  } catch (e) {
    // If it fails, we're on Web
    return false;
  }
}
