import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:pushy_flutter/pushy_flutter.dart';

void main() => runApp(Main());

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
        accentColor: Colors.redAccent,
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

    // Request the WRITE_EXTERNAL_STORAGE permission on Android so that the Pushy SDK will be able to persist the device token in the external storage
    Pushy.requestStoragePermission();

    // Set custom notification icon (Android)
    Pushy.setNotificationIcon('ic_notify');

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
            Platform.isAndroid ? '(copy from logcat)' : '(copy from console)';
      });
    } on PlatformException catch (error) {
      // Print to console/logcat
      print('Error: ${error.message}');

      // Show error
      setState(() {
        _deviceToken = 'Registration failed';
        _instruction = '(restart app to try again)';
      });
    }

    // Listen for push notifications
    Pushy.setNotificationListener((Map<String, dynamic> data) {
      // Print notification payload data
      print('Received notifications: $data');

      // Clear iOS app badge number
      Pushy.clearBadge();

      // Extract notification messsage
      String message = data['message'] ?? 'Hello World!';

      // Display an alert with the "message" payload value
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
              title: Text('Pushy'),
              content: Text(message),
              actions: [
                FlatButton(
                  child: Text('OK'),
                  onPressed: () {
                    Navigator.of(context, rootNavigator: true).pop('dialog');
                  },
                )
              ]);
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // Demo app UI
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pushy'),
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
