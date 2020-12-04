import Flutter
import UIKit
import Pushy

public class PushyFlutter: NSObject, FlutterPlugin, FlutterStreamHandler {
    var pushy: Pushy?
    var eventSink: FlutterEventSink?
    var hasStartupNotification = false
    var startupNotification: [AnyHashable : Any]?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
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
        
        // Subscribe device to topic
        if (call.method == "subscribe") {
            subscribe(call, result: result)
        }
        
        // Unsubscribe device from topic
        if (call.method == "unsubscribe") {
            unsubscribe(call, result: result)
        }
        
        // Display an alert winow
        if (call.method == "notify") {
            notify(call, result: result)
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
    }
    
    public override init() {
        super.init()
        
        // Listen for startup notifications
        self.getPushyInstance().setNotificationHandler({ (userInfo, completionHandler) in
            // Make userInfo mutable
            var data = userInfo;
            
            // Startup notifications have always been clicked
            data["_pushyNotificationClicked"] = true;
            
            // Print notification payload data
            print("Received notification: \(data)")
            
            // Store for later
            self.startupNotification = data
            self.hasStartupNotification = true
            
            // You must call this completion handler when you finish processing
            // the notification (after fetching background data, if applicable)
            completionHandler(UIBackgroundFetchResult.newData)
        })
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
        
        // Check for startup notification if exists
        if self.hasStartupNotification {
            // Execute notification handler accordingly
            self.notificationHandler(userInfo: self.startupNotification!, completionHandler: {(UIBackgroundFetchResult) in})
        }
        
        // Nil means success
        return nil
    }
    
    func notificationHandler(userInfo: [AnyHashable : Any], completionHandler: ((UIBackgroundFetchResult) -> Void)) {
        // Make userInfo mutable
        var data = userInfo;
        
        // Notification clicked?
        if (UIApplication.shared.applicationState == UIApplication.State.inactive) {
            // Set flag for invoking click listener
            data["_pushyNotificationClicked"] = true;
        }
        
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
    
    func setEnterpriseConfig(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        // Get arguments as list of strings
        let args = call.arguments as! [String?]
        
        // Set Pushy Enterprise API endpoint
        getPushyInstance().setEnterpriseConfig(apiEndpoint: args[0])
        
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
