package me.pushy.sdk.flutter;

import android.Manifest;
import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.os.AsyncTask;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.lang.reflect.Method;
import java.util.ArrayList;

import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry;
import io.flutter.plugin.common.PluginRegistry.Registrar;

import me.pushy.sdk.flutter.config.PushyChannels;
import me.pushy.sdk.Pushy;
import me.pushy.sdk.config.PushyLogging;
import me.pushy.sdk.flutter.config.PushyIntentExtras;
import me.pushy.sdk.util.PushyStringUtils;
import me.pushy.sdk.util.exceptions.PushyException;
import me.pushy.sdk.flutter.util.PushyPersistence;

public class PushyPlugin implements MethodCallHandler, PluginRegistry.NewIntentListener, EventChannel.StreamHandler {
    static Activity mActivity;
    static EventChannel.EventSink mNotificationListener;

    public static void registerWith(Registrar registrar) {
        // Instantiate plugin
        PushyPlugin plugin = new PushyPlugin(registrar.activity());

        // Register a method channel that the Flutter app may invoke
        MethodChannel channel = new MethodChannel(registrar.messenger(), PushyChannels.METHOD_CHANNEL);

        // Instantiate Pushy plugin
        channel.setMethodCallHandler(plugin);

        // Listen for new intents (notification clicked)
        registrar.addNewIntentListener(plugin);

        // Register an event channel that the Flutter app may listen on
        new EventChannel(registrar.messenger(), PushyChannels.EVENT_CHANNEL).setStreamHandler(plugin);
    }

    @Override
    public boolean onNewIntent(Intent intent) {
        // Handle notification click
        onNotificationClicked(mActivity, intent);

        // Handled
        return true;
    }

    private PushyPlugin(Activity activity) {
        // Store activity for later
        mActivity = activity;
    }

    void onNotificationClicked(Activity activity, Intent intent) {
        // Activity is not running?
        if (activity == null || activity.isFinishing()) {
            return;
        }

        // Not a clicked Pushy notification?
        if (!intent.getBooleanExtra(PushyIntentExtras.NOTIFICATION_CLICKED, false) ) {
            return;
        }

        // Attempt to extract stringified JSON payload
        String payload = intent.getStringExtra(PushyIntentExtras.NOTIFICATION_PAYLOAD);

        // No payload?
        if (PushyStringUtils.stringIsNullOrEmpty(payload)) {
            return;
        }

        // Notification payload object
        JSONObject notification;

        try {
            // Gracefully attempt to parse it back into JSONObject
            notification = new JSONObject(payload);

            // Mark notification as clicked
            notification.put(PushyIntentExtras.NOTIFICATION_CLICKED, true);
        }
        catch (Exception e) {
            // Log error to logcat and stop execution
            Log.e(PushyLogging.TAG, "Failed to parse notification click data into JSONObject:" + e.getMessage(), e);
            return;
        }

        // Invoke the notification clicked handler
        onNotificationReceived(notification, activity);
    }

    @Override
    public void onMethodCall(MethodCall call, Result result) {
        // // Restart the socket service
        if (call.method.equals("listen")) {
            Pushy.listen(mActivity);

            // Send success result
            success(result, "success");
        }

        // Register the device for notifications
        if (call.method.equals("register")) {
            register(result);
        }

        // Request WRITE_EXTERNAL_STORAGE permission
        if (call.method.equals("requestStoragePermission")) {
            requestStoragePermission(result);
        }

        // Check if device is registered
        if (call.method.equals("isRegistered")) {
            isRegistered(result);
        }

        // Subscribe device to topic
        if (call.method.equals("subscribe")) {
            subscribe(call, result);
        }

        // Unsubscribe device from topic
        if (call.method.equals("unsubscribe")) {
            unsubscribe(call, result);
        }

        // Pushy Enterprise support
        if (call.method.equals("setEnterpriseConfig")) {
            setEnterpriseConfig(call, result);
        }

        // Toggle notifications support
        if (call.method.equals("toggleNotifications")) {
            toggleNotifications(call, result);
        }

        // Custom icon support
        if (call.method.equals("setNotificationIcon")) {
            setNotificationIcon(call, result);
        }

        // Custom heartbeat interval support
        if (call.method.equals("setHeartbeatInterval")) {
            setHeartbeatInterval(call, result);
        }
    }

    private void register(final Result result) {
        // Run network I/O in background thread
        AsyncTask.execute(new Runnable() {
            @Override
            public void run() {
                try {
                    // Assign a unique token to this device
                    String deviceToken = Pushy.register(mActivity);

                    // Resolve the promise with the token
                    success(result, deviceToken);
                } catch (final PushyException exc) {
                    // Reject the promise with the exception
                    error(result, exc.getMessage());
                }
            }
        });
    }

    @Override
    public void onListen(Object args, final EventChannel.EventSink events) {
        // Flutter app is listening for notifications
        Log.w("Pushy", "Flutter app is listening for notifications");

        // Store handle for later
        mNotificationListener = events;

        // Attempt to deliver any pending notifications (from when activity was closed)
        deliverPendingNotifications();

        // If app was opened from notification, invoke notification click listener
        onNotificationClicked(mActivity, mActivity.getIntent());
    }

    @Override
    public void onCancel(Object args) {
        // Clear notification listener
        mNotificationListener = null;
    }

    private void deliverPendingNotifications() {
        // Activity must be running for this to work
        if (mActivity == null || mActivity.isFinishing()) {
            return;
        }

        // Get pending notifications
        JSONArray notifications = PushyPersistence.getPendingNotifications(mActivity);

        // Got at least one?
        if (notifications.length() > 0) {
            // Traverse notifications
            for (int i = 0; i < notifications.length(); i++) {
                try {
                    // Emit notification to listener
                    onNotificationReceived(notifications.getJSONObject(i), mActivity);
                }
                catch (JSONException e) {
                    // Log error to logcat
                    Log.e(PushyLogging.TAG, "Failed to parse JSON object: " + e.getMessage(), e);
                }
            }

            // Clear persisted notifications
            PushyPersistence.clearPendingNotifications(mActivity);
        }
    }

    public static void onNotificationReceived(final JSONObject notification, Context context) {
        // Activity is not running or no notification handler defined?
        if (mNotificationListener == null || mActivity == null || mActivity.isFinishing()) {
            // Store notification JSON in SharedPreferences and deliver it when app is opened
            PushyPersistence.persistNotification(notification, context);
            return;
        }

        // Run on main thread
        new Handler(Looper.getMainLooper()).post(new Runnable() {
            @Override
            public void run() {
                // Invoke with notification payload
                mNotificationListener.success(notification.toString());
            }
        });
    }

    private void subscribe(final MethodCall call, final Result result) {
        // Get arguments
        final ArrayList<String> args = call.arguments();

        // Run network I/O in background thread
        AsyncTask.execute(new Runnable() {
            @Override
            public void run() {
                try {
                    // Attempt to subscribe the device to topic
                    Pushy.subscribe(args.get(0), mActivity);

                    // Resolve the callback with success
                    success(result, "success");
                } catch (Exception exc) {
                    // Reject the callback with the exception
                    error(result, exc.getMessage());
                }
            }
        });
    }

    private void unsubscribe(final MethodCall call, final Result result) {
        // Get arguments
        final ArrayList<String> args = call.arguments();

        // Run network I/O in background thread
        AsyncTask.execute(new Runnable() {
            @Override
            public void run() {
                try {
                    // Attempt to unsubscribe the device from topic
                    Pushy.unsubscribe(args.get(0), mActivity);

                    // Resolve the callback with success
                    success(result, "success");
                } catch (Exception exc) {
                    // Reject the callback with the exception
                    error(result, exc.getMessage());
                }
            }
        });
    }

    private void requestStoragePermission(Result result) {
        // Request permission method
        Method requestPermission;

        try {
            // Get method reference via reflection (to support earlier Android versions)
            requestPermission = mActivity.getClass().getMethod("requestPermissions", String[].class, int.class);

            // Request the permission via user-friendly dialog
            requestPermission.invoke(mActivity, new String[]{ Manifest.permission.WRITE_EXTERNAL_STORAGE }, 0);
        } catch (Exception e) {
            // Log error
            Log.d(PushyLogging.TAG, "Failed to request WRITE_EXTERNAL_STORAGE permission", e);
        }

        // Return success nonetheless
        success(result, "success");
    }

    private void setEnterpriseConfig(MethodCall call, Result result) {
        // Get arguments
        final ArrayList<String> args = call.arguments();

        // Set enterprise config based on passed in args
        Pushy.setEnterpriseConfig(args.get(0), args.get(1), mActivity);

        // Return success nonetheless
        success(result, "success");
    }

    private void setNotificationIcon(MethodCall call, Result result) {
        // Get arguments
        final ArrayList<String> args = call.arguments();

        // Get resource String name
        String iconResourceName = args.get(0);

        // Store in SharedPreferences using PushyPersistence helper
        PushyPersistence.setNotificationIcon(iconResourceName, mActivity);

        // Return success nonetheless
        success(result, "success");
    }

    private void setHeartbeatInterval(MethodCall call, Result result) {
        // Get arguments
        final ArrayList<Integer> args = call.arguments();

        // Get interval in ms
        int interval = args.get(0);

        // Modify heartbeat interval
        Pushy.setHeartbeatInterval(interval, mActivity);

        // Return success
        success(result, "success");
    }

    private void toggleNotifications(MethodCall call, Result result) {
        // Get arguments
        final ArrayList<Boolean> args = call.arguments();

        // Get toggle value as bool
        Boolean value = args.get(0);

        // Toggle notifications on/off
        Pushy.toggleNotifications(value, mActivity);

        // Return success
        success(result, "success");
    }

    private void isRegistered(Result result) {
        // Resolve the event with boolean result
        success(result, Pushy.isRegistered(mActivity) ? "true" : "false");
    }

    void success(final Result result, final String message) {
        // Run on main thread
        new Handler(Looper.getMainLooper()).post(new Runnable() {
            @Override
            public void run() {
                // Resolve the method
                result.success(message);
            }
        });
    }

    void error(final Result result, final String message) {
        // Run on main thread
        new Handler(Looper.getMainLooper()).post(new Runnable() {
            @Override
            public void run() {
                // Reject the method
                result.error("PUSHY ERROR", message, null);
            }
        });
    }
}
