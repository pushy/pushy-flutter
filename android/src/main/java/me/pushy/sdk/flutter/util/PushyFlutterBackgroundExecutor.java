package me.pushy.sdk.flutter.util;

import android.content.Context;
import android.content.SharedPreferences;
import android.content.res.AssetManager;
import android.util.Log;

import org.json.JSONObject;

import io.flutter.FlutterInjector;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.embedding.engine.dart.DartExecutor;
import io.flutter.embedding.engine.dart.DartExecutor.DartCallback;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.JSONMethodCodec;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.view.FlutterCallbackInformation;
import io.flutter.view.FlutterMain;
import me.pushy.sdk.config.PushyLogging;
import me.pushy.sdk.flutter.PushyPlugin;
import me.pushy.sdk.flutter.config.PushyChannels;
import me.pushy.sdk.flutter.config.PushySharedPrefs;

public class PushyFlutterBackgroundExecutor implements MethodCallHandler {
    private boolean mIsIsolateRunning;

    private MethodChannel mBackgroundChannel;
    private FlutterEngine mBackgroundFlutterEngine;

    private static Context mContext;
    private static PushyFlutterBackgroundExecutor mInstance;

    public static boolean isRunning() {
        // Ensure isolate is running and callback has been invoked
        return isInitialized() && getSingletonInstance().mIsIsolateRunning;
    }

    public void startBackgroundIsolate(Context context) {
        // Get shared preferences handle
        SharedPreferences sharedPreferences = PushyPersistence.getSettings(context);

        // Retrieve previously-stored callback handle IDs
        long isolateCallbackId = sharedPreferences.getLong(PushySharedPrefs.FLUTTER_ISOLATE_ID, 0);
        long notificationHandlerCallbackId = sharedPreferences.getLong(PushySharedPrefs.FLUTTER_NOTIFICATION_HANDLER_ID, 0);

        // Check for null values before continuing
        if (isolateCallbackId == 0 || notificationHandlerCallbackId == 0) {
            Log.e(PushyLogging.TAG, "Isolate / notification callback IDs are missing from SharedPreferences");
            return;
        }

        // Start isolate with persisted callback IDs
        startBackgroundIsolate(context, isolateCallbackId, notificationHandlerCallbackId);
    }

    public void startBackgroundIsolate(Context context, long isolateCallbackId, long notificationHandlerCallbackId) {
        // Additional check to ensure isolate not already started
        if (mBackgroundFlutterEngine != null || isRunning()) {
            Log.e(PushyLogging.TAG, "Background isolate already started / running");
            return;
        }

        // Log initialization
        Log.d(PushyLogging.TAG, "Initializing FlutterBackgroundExecutor background isolate");

        // Store context for later
        mContext = context;

        // Persist callback handles in SharedPreferences for when process is terminated
        persistCallbackHandleIds(context, isolateCallbackId, notificationHandlerCallbackId);

        // Get assets and app bundle path
        AssetManager assets = context.getAssets();
        
        // Fix for NullPointerException when calling findAppBundlePath() in background
        // https://github.com/transistorsoft/flutter_background_fetch/issues/160#issuecomment-751667361
        FlutterInjector.instance().flutterLoader().startInitialization(context);

        // Get app bundle path as string
        String appBundlePath = FlutterInjector.instance().flutterLoader().findAppBundlePath();

        // Null safety check
        if (appBundlePath != null) {
            // We need to create an instance of `FlutterEngine` before looking up the callback
            // If we don't, the callback cache won't be initialized and the lookup will fail
            mBackgroundFlutterEngine = new FlutterEngine(context);

            // Attempt to look up the _isolate() callback by its handle
            FlutterCallbackInformation flutterCallback = FlutterCallbackInformation.lookupCallbackInformation(isolateCallbackId);

            // Notify in case of failure
            if (flutterCallback == null) {
                Log.e(PushyLogging.TAG, "Failed to locate _isolate() callback");
                return;
            }

            // Dart code executor
            DartExecutor executor = mBackgroundFlutterEngine.getDartExecutor();

            // Initialize a dedicate channel for communicating with the background isolate
            initializeBackgroundMethodChannel(executor);

            // Execute the callback (when it's done it will invoke a method call to "notificationCallbackReady")
            executor.executeDartCallback(new DartCallback(assets, appBundlePath, flutterCallback));
        }
    }

    public static void persistCallbackHandleIds(Context context, long isolateCallbackId, long notificationHandlerCallbackId) {
        // Get shared preferences handle
        SharedPreferences sharedPreferences = PushyPersistence.getSettings(context);

        // Store callback handle IDs
        sharedPreferences.edit().putLong(PushySharedPrefs.FLUTTER_ISOLATE_ID, isolateCallbackId).apply();
        sharedPreferences.edit().putLong(PushySharedPrefs.FLUTTER_NOTIFICATION_HANDLER_ID, notificationHandlerCallbackId).apply();
    }

    private void initializeBackgroundMethodChannel(BinaryMessenger isolate) {
        // Initialize a dedicated channel for communicating with the background isolate
        mBackgroundChannel = new MethodChannel(isolate, PushyChannels.BACKGROUND_CHANNEL, JSONMethodCodec.INSTANCE);

        // Handle method calls in this class (onMethodCall())
        mBackgroundChannel.setMethodCallHandler(this);
    }

    @Override
    public void onMethodCall(MethodCall call, Result result) {
        // Notification callback ready event
        if (call.method.equals("notificationCallbackReady")) {
            // Log Dart background isolate / Dart method channel initialization
            Log.d(PushyLogging.TAG, "Isolate called notificationCallbackReady()");

            // Background isolate is ready to forward messages to notification handler callback
            onIsolateInitialized();

            // Send back success
            result.success(true);
        }
    }

    private void onIsolateInitialized() {
        // Isolate reported it is running
        mIsIsolateRunning = true;

        // Attempt to deliver any pending notifications (from when activity was closed)
        PushyPlugin.deliverPendingNotifications(mContext);
    }

    public void invokeDartNotificationHandler(JSONObject notification, Context context) {
        // Get shared preferences handle
        SharedPreferences sharedPreferences = PushyPersistence.getSettings(context);

        // Retrieve stored notification handler callback handle ID
        long notificationHandlerCallbackId = sharedPreferences.getLong(PushySharedPrefs.FLUTTER_NOTIFICATION_HANDLER_ID, 0);

        // Pass notification (as JSON string) to notification handler through background channel
        mBackgroundChannel.invokeMethod("onNotificationReceived", new Object[] {notificationHandlerCallbackId, notification.toString()},null);
    }

    private static boolean isInitialized() {
        // Singleton instance null check
        return mInstance != null;
    }

    public static PushyFlutterBackgroundExecutor getSingletonInstance() {
        // Check for existing instance
        if (mInstance != null) {
            return mInstance;
        }

        // Initialize a new one and return it
        mInstance = new PushyFlutterBackgroundExecutor();
        return mInstance;
    }

}
