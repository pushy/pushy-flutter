import Flutter
import UIKit
import Pushy

public class PushyFlutter: NSObject, FlutterPlugin, FlutterStreamHandler {
    var pushy: Pushy?
    var eventSink: FlutterEventSink?
    var hasStartupNotification = false
    var startupNotification: [AnyHashable : Any]?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        // On iOS 14+, Flutter apps built in the Debug scheme
        // Need to be attached to the Xcode debugger
        // 
        // https://github.com/flutter/flutter/issues/66422#issuecomment-697972897
        if #available(iOS 14, *) {
            // Built in Debug mode?
            #if DEBUG
                // Avoid plugin initialization if Xcode debugger is not attached
                if (getppid() == 1) {
                    return
                }
            #endif
        }
        
        // Register a method channel that the Flutter app may invoke
        let channel = FlutterMethodChannel(name: PushyChannels.methodChannel, binaryMessenger: registrar.messenger())
        
        // Instantiate Pushy plugin
        let instance = PushyFlutter()
        
        // Set up method channnel delegate
        registrar.addMethodCallDelegate(instance, channel: channel)
        
        // Create event channel for sending notifications to Flutter app
        let stream = FlutterEventChannel(name: PushyChannels.eventChannel, binaryMessenger: registrar.messenger())
        
        // Registers the plugin as a receiver of UIApplicationDelegate calls
        registrar.addApplicationDelegate(instance)
        
        // Handle stream events in this class
        stream.setStreamHandler(instance)
    }
    
    public func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) -> Bool {
        // It seems this method declaration is necessary for handling notification tap while app is killed
        return true
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        // Listen for notifications
        if (call.method == "listen") {
            // Do nothing on iOS
            result("success")
        }
        
        // Register for remote notifications
        if (call.method == "register") {
            register(result)
        }
        
        // Check if device is registered
        if (call.method == "isRegistered") {
            isRegistered(result)
        }
        
        // Fetch underlying APNs token
        if (call.method == "getAPNsToken") {
            getAPNsToken(result)
        }
        
        // Subscribe device to topic
        if (call.method == "subscribe") {
            subscribe(call, result: result)
        }

        // Multi Topic Subscribe device to multiple topics
        if (call.method == "multiTopicSubscribe") {
            multiTopicSubscribe(call, result: result)
        }
        
        // Unsubscribe device from topic
        if (call.method == "unsubscribe") {
            unsubscribe(call, result: result)
        }
        
        // Display an alert winow
        if (call.method == "notify") {
            notify(call, result: result)
        }
        
        // Toggle in-app notification banners (iOS 10+)
        if (call.method == "toggleInAppBanner") {
            toggleInAppBanner(call, result: result)
        }
        
        // Support for iOS 12+ Critical Alerts
        if (call.method == "setCriticalAlertOption") {
            setCriticalAlertOption(result)
        }
        
        // Pushy Enterprise support
        if (call.method == "setEnterpriseConfig") {
            setEnterpriseConfig(call, result: result)
        }
        
        // Enable/disable AppDelegate method swizzling
        if (call.method == "toggleMethodSwizzling") {
            toggleMethodSwizzling(call, result: result)
        }
        
        // Pushy Enterprise support
        if (call.method == "clearBadge") {
            clearBadge(result)
        }

        // Change Pushy App ID
        if (call.method == "setAppId") {
            setAppId(call, result: result)
        }
    }
    
    public override init() {
        super.init()
        
        // Listen for startup notifications
        self.getPushyInstance().setNotificationHandler({ (userInfo, completionHandler) in
            // Store for later
            self.storeStartupNotification(userInfo)
            
            // Call background completion handler
            completionHandler(UIBackgroundFetchResult.newData)
        })
        
        // Listen for startup notifications (both listeners required)
        self.getPushyInstance().setNotificationClickListener({ (userInfo) in
            // Store for later
            self.storeStartupNotification(userInfo)
        })
    }
    
    func storeStartupNotification(_ data: [AnyHashable : Any]) {
        // Print event & notification payload data
        print("Startup notification: \(data)")
        
        // Store for later
        self.startupNotification = data
        self.hasStartupNotification = true
    }
    
    func getPushyInstance() -> Pushy {
        // Pushy instance singleton
        if pushy == nil {
            pushy = Pushy(UIApplication.shared)
        }
        
        return pushy!
    }
    
    func register(_ result: @escaping FlutterResult) {
        // Register the device for push notifications
        getPushyInstance().register({ (error, deviceToken) in
            // Handle registration errors
            if error != nil {
                // Send error to Flutter app
                return result(FlutterError(code: "PUSHY ERROR",
                                           message: String(describing: error!),
                                           details: nil))
            }
            
            // Send device token to Flutter app
            result(deviceToken)
        })
    }
    
    public func onListen(withArguments arguments: Any?, eventSink: @escaping FlutterEventSink) -> FlutterError? {
        // Save the event sink in instance members
        self.eventSink = eventSink
        
        // Set notification handler to our own
        getPushyInstance().setNotificationHandler(self.notificationHandler)
        
        // Set notification click listener to our own
        getPushyInstance().setNotificationClickListener(self.notificationClickListener)
        
        // Check for startup notification if exists
        if self.hasStartupNotification {
            // Execute click notification handler
            self.notificationClickListener(userInfo: self.startupNotification!)
        }
        
        // Nil means success
        return nil
    }
    
    func notificationHandler(data: [AnyHashable : Any], completionHandler: ((UIBackgroundFetchResult) -> Void)) {
        // Print notification payload data
        print("Received notification: \(data)")
        
        // Convert to JSON (stringified)
        let json: String
        
        do {
            // Attempt to serialize into JSON string
            json = String(bytes: try JSONSerialization.data(withJSONObject: data, options: []), encoding: String.Encoding.utf8) ?? ""
        }
        catch let err {
            // Throw err
            self.eventSink?(FlutterError(code: "PUSHY ERROR",
                                         message: err.localizedDescription,
                                         details: nil))
            return
        }
        
        // Send JSON data to Flutter app
        self.eventSink?(json)
        
        // Call the completion handler immediately on behalf of the app
        completionHandler(UIBackgroundFetchResult.newData)
    }
    
    func notificationClickListener(userInfo: [AnyHashable : Any]) {
        // Make userInfo mutable
        var data = userInfo;
    
        // Set flag for invoking click listener
        data["_pushyNotificationClicked"] = true;
        
        // Print notification payload data
        print("Clicked notification: \(data)")
        
        // Convert to JSON (stringified)
        let json: String
        
        do {
            // Attempt to serialize into JSON string
            json = String(bytes: try JSONSerialization.data(withJSONObject: data, options: []), encoding: String.Encoding.utf8) ?? ""
        }
        catch let err {
            // Throw err
            self.eventSink?(FlutterError(code: "PUSHY ERROR",
                                         message: err.localizedDescription,
                                         details: nil))
            return
        }
        
        // Send JSON data to Flutter app
        self.eventSink?(json)
    }
    
    func notify(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        // Get arguments as list of strings
        let args = call.arguments as! [String]
        
        // Alert title and message
        let title = args[0];
        let message = args[1];
        
        // Display the notification as an alert
        let alert = UIAlertController(title: title, message: message, preferredStyle: UIAlertController.Style.alert)
        
        // Add an action button
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: nil))
        
        // Show the alert dialog
        UIApplication.shared.delegate?.window??.rootViewController?.present(alert, animated: true, completion: nil)
        
        // Success
        result("success")
    }
    
    func subscribe(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        // Get arguments as list of strings
        let args = call.arguments as! [String]
        
        // Subscribe the device to a topic
        getPushyInstance().subscribe(topic: args[0], handler: { (error) in
            // Handle errors
            if error != nil {
                // Send error to Flutter app
                return result(FlutterError(code: "PUSHY ERROR",
                                           message: String(describing: error!),
                                           details: nil))
            }
            
            // Success
            result("success")
        })
    }

    func multiTopicSubscribe(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        // Get arguments as list of strings
        let args = call.arguments as! [String]
        
        // Subscribe the device to list of topics
        getPushyInstance().subscribe(topics: args, handler: { (error) in
            // Handle errors
            if error != nil {
                // Send error to Flutter app
                return result(FlutterError(code: "PUSHY ERROR",
                                           message: String(describing: error!),
                                           details: nil))
            }
            
            // Success
            result("success")
        })
    }
    
    func unsubscribe(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        // Get arguments as list of strings
        let args = call.arguments as! [String]
        
        // Unsubscribe the device from a topic
        getPushyInstance().unsubscribe(topic: args[0], handler: { (error) in
            // Handle errors
            if error != nil {
                // Send error to Flutter app
                return result(FlutterError(code: "PUSHY ERROR",
                                           message: String(describing: error!),
                                           details: nil))
            }
            
            // Success
            result("success")
        })
    }
    
    func isRegistered(_ result: @escaping FlutterResult) {
        // Check whether the device is registered
        let isRegistered = getPushyInstance().isRegistered()
        
        // Send result to Flutter app
        result(isRegistered ? "true" : "false")
    }

    func getAPNsToken(_ result: @escaping FlutterResult) {
        // Fetch underlying APNs token
        let apnsToken = getPushyInstance().getAPNsToken()
        
        // Send result to Flutter app
        result(apnsToken != nil ? apnsToken : "")
    }
    
    func setEnterpriseConfig(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        // Get arguments as list of strings
        let args = call.arguments as! [String?]
        
        // Set Pushy Enterprise API endpoint
        getPushyInstance().setEnterpriseConfig(apiEndpoint: args[0])
        
        // Always success
        result("success")
    }

    func setAppId(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        // Get arguments as list of strings
        let args = call.arguments as! [String?]
        
        // Set Pushy App ID
        getPushyInstance().setAppId(args[0])
        
        // Always success
        result("success")
    }
    
    func toggleInAppBanner(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        // Get arguments as list of bools
        let args = call.arguments as! [Bool?]
        
        // Get toggle value
        let toggle = args[0]!
        
        // Enable/disable in-app notification banners (iOS 10+)
        getPushyInstance().toggleInAppBanner(toggle)
        
        // iOS 10+ only
        if #available(iOS 10.0, *) {
            // Toggled off? (after previously being toggled on)
            if (!toggle) {
                // Reset UNUserNotificationCenterDelegate to nil to avoid displaying banner
                UNUserNotificationCenter.current().delegate = nil
            } else {
                // Set UNUserNotificationCente delegate so in-app banners are displayed
                UNUserNotificationCenter.current().delegate = getPushyInstance()
            }
        }
        
        // Always success
        result("success")
    }

    func toggleMethodSwizzling(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        // Get arguments as list of bools
        let args = call.arguments as! [Bool?]
        
        // Pass value to Pushy SDK
        getPushyInstance().toggleMethodSwizzling(args[0]!)
        
        // Always success
        result("success")
    }
    
    func setCriticalAlertOption(_ result: @escaping FlutterResult) {
        // iOS 12+ only
        if #available(iOS 12, *) {
            // Prepare notification options
            var options = UNAuthorizationOptions()
            
            // Declare standard options alogn with .criticalAlert
            options = [.badge, .alert, .sound, .criticalAlert]

            // Set custom notification options
            getPushyInstance().setCustomNotificationOptions(options)
        }
        
        // Always success
        result("success")
    }
    
    func clearBadge(_ result: @escaping FlutterResult) {
        // Clear app badge
        UIApplication.shared.applicationIconBadgeNumber = 0;
        
        // Always success
        result("success")
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        // Flutter app cancelled the event listener
        self.eventSink = nil
        return nil
    }
}
