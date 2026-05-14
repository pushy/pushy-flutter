import Flutter
import Foundation

// Expose the class to Objective-C under the name `PushyPlugin` so Flutter's
// generated plugin registrant can discover it via the iOS `pluginClass` entry.
@objc(PushyPlugin)
public class PushyPlugin: NSObject, FlutterPlugin {
    // Plugin entry point invoked by Flutter's generated registrant
    public static func register(with registrar: FlutterPluginRegistrar) {
        // Delegate registration to the actual implementation
        PushyFlutter.register(with: registrar)
    }
}
