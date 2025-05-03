package me.pushy.sdk.flutter;

import android.app.Activity;
import android.app.Notification;
import android.app.NotificationManager;
import android.content.Context;
import android.content.Intent;
import android.media.RingtoneManager;
import android.os.AsyncTask;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;
import android.provider.Settings;
import android.os.PowerManager;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.Arrays;

import androidx.annotation.NonNull;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry;

import me.pushy.sdk.flutter.config.PushyChannels;
import me.pushy.sdk.Pushy;
import me.pushy.sdk.config.PushyLogging;
import me.pushy.sdk.flutter.util.PushyFlutterBackgroundExecutor;
import me.pushy.sdk.flutter.util.PushyNotification;
import me.pushy.sdk.model.PushyDeviceCredentials;
import me.pushy.sdk.flutter.config.PushyIntentExtras;
import me.pushy.sdk.util.PushyStringUtils;
import me.pushy.sdk.util.exceptions.PushyException;
import me.pushy.sdk.flutter.util.PushyPersistence;

public class PushyPlugin implements FlutterPlugin, ActivityAware, MethodCallHandler, PluginRegistry.NewIntentListener, EventChannel.StreamHandler {
    static Context mContext;
    static Activity mActivity;
    static EventChannel.EventSink mNotificationListener;

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
        // Store context for later
        mContext = binding.getApplicationContext();

        // Register a method channel that the Flutter app may invoke
        MethodChannel channel = new MethodChannel(binding.getBinaryMessenger(), PushyChannels.METHOD_CHANNEL);

        // Handle method calls (onMethodCall())
        channel.setMethodCallHandler(this);

        // Register an event channel that the Flutter app may listen on
        new EventChannel(binding.getBinaryMessenger(), PushyChannels.EVENT_CHANNEL).setStreamHandler(this);
    }

    @Override
    public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
        // Store reference to activity object
        mActivity = binding.getActivity();

        // Listen for new intents (notification clicked)
        binding.addOnNewIntentListener(this);
    }

    @Override
    public boolean onNewIntent(Intent intent) {
        // Handle notification click
        onNotificationClicked(mContext, intent);

        // Handled
        return true;
    }

    void onNotificationClicked(Context context, Intent intent) {
        // Not a clicked Pushy notification?
        if (!intent.getBooleanExtra(PushyIntentExtras.NOTIFICATION_CLICKED, false)) {
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
        } catch (Exception e) {
            // Log error to logcat and stop execution
            Log.e(PushyLogging.TAG, "Failed to parse notification click data into JSONObject:" + e.getMessage(), e);
            return;
        }

        // No listener defined yet?
        if (mNotificationListener == null) {
            Log.d(PushyLogging.TAG, "No notification click listener is currently registered");
            return;
        }

        // Invoke the notification clicked handler (via EventChannel)
        mNotificationListener.success(notification.toString());
    }

    @Override
    public void onMethodCall(MethodCall call, Result result) {
        // // Start the socket service
        if (call.method.equals("listen")) {
            Pushy.listen(mContext);

            // Send success result
            success(result, "success");
        }

        // Register the device for notifications
        if (call.method.equals("register")) {
            register(result);
        }

        // Background notification listener
        if (call.method.equals("setNotificationListener")) {
            setNotificationListener(call, result);
        }
        
        // Check if device is registered
        if (call.method.equals("isRegistered")) {
            isRegistered(result);
        }

        // Display a system notification
        if (call.method.equals("notify")) {
            notify(call, result);
        }

        // Subscribe device to topic
        if (call.method.equals("subscribe")) {
            subscribe(call, result);
        }

        // Unsubscribe device from topic
        if (call.method.equals("unsubscribe")) {
            unsubscribe(call, result);
        }

        // FCM fallback delivery
        if (call.method.equals("toggleFCM")) {
            toggleFCM(call, result);
        }

        // Toggle foreground service support
        if (call.method.equals("toggleForegroundService")) {
            toggleForegroundService(call, result);
        }

        // Get FCM fallback delivery token
        if (call.method.equals("getFCMToken")) {
            getFCMToken(result);
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

        // Custom JobService interval support
        if (call.method.equals("setJobServiceInterval")) {
            setJobServiceInterval(call, result);
        }

        // Device credential retrieval support
        if (call.method.equals("getDeviceCredentials")) {
            getDeviceCredentials(result);
        }

        // Device credential assignment support
        if (call.method.equals("setDeviceCredentials")) {
            setDeviceCredentials(call, result);
        }

        // Check whether app whitelisted from battery optimizations
        if (call.method.equals("isIgnoringBatteryOptimizations")) {
            isIgnoringBatteryOptimizations(result);
        }

        // Launch battery optimizations activity
        if (call.method.equals("launchBatteryOptimizationsActivity")) {
            launchBatteryOptimizationsActivity(result);
        }

        // Set Pushy App ID support
        if (call.method.equals("setAppId")) {
            setAppId(call, result);
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

    private void getDeviceCredentials(final Result result) {
        // Get device unique credentials (may be null)
        PushyDeviceCredentials credentials = Pushy.getDeviceCredentials(mContext);

        // Convert to ArrayList<String>
        ArrayList<String> list = new ArrayList<>(Arrays.asList(credentials.token, credentials.authKey));

        // Resolve the promise with credentials
        success(result, list);
    }

    private void setDeviceCredentials(final MethodCall call, final Result result) {
        // Get arguments
        ArrayList<String> args = call.arguments();

        // Create credentials object
        final PushyDeviceCredentials credentials = new PushyDeviceCredentials(args.get(0), args.get(1));

        // Run network I/O in background thread
        AsyncTask.execute(new Runnable() {
            @Override
            public void run() {
                try {
                    // Assign credentials for this device (may fail)
                    Pushy.setDeviceCredentials(credentials, mContext);

                    // Resolve the promise successfully
                    success(result, null);
                } catch (final PushyException exc) {
                    // Reject the promise with the exception
                    error(result, exc.getMessage());
                }
            }
        });
    }

    @Override
    public void onListen(Object args, final EventChannel.EventSink events) {
        // Flutter app is listening for foreground notification events
        Log.w("Pushy", "Flutter app is listening for foreground notification events");

        // Store handle for later
        mNotificationListener = events;

        // Activity not null?
        if (mActivity != null) {
            // If app was opened from notification, invoke notification click listener
            onNotificationClicked(mActivity, mActivity.getIntent());
        }
    }

    @Override
    public void onCancel(Object args) {
        // Clear notification listener
        mNotificationListener = null;
    }

    public static void deliverPendingNotifications(Context context) {
        // Get pending notifications
        JSONArray notifications = PushyPersistence.getPendingNotifications(context);

        // Got at least one?
        if (notifications.length() > 0) {
            // Traverse notifications
            for (int i = 0; i < notifications.length(); i++) {
                try {
                    // Emit notification to listener
                    onNotificationReceived(notifications.getJSONObject(i), context);
                }
                catch (JSONException e) {
                    // Log error to logcat
                    Log.e(PushyLogging.TAG, "Failed to parse JSON object: " + e.getMessage(), e);
                }
            }

            // Clear persisted notifications
            PushyPersistence.clearPendingNotifications(context);
        }
    }

    public static void onNotificationReceived(final JSONObject notification, final Context context) {
        // Run on main thread
        new Handler(Looper.getMainLooper()).post(new Runnable() {
            @Override
            public void run() {
                // Activity is running and notification handler defined?
                if (mNotificationListener != null && mActivity != null && !mActivity.isFinishing()) {
                    // Log action
                    Log.d("Pushy", "Invoking notification listener in foreground (no isolate)");

                    // Invoke with notification payload
                    mNotificationListener.success(notification.toString());
                    return;
                }

                // Activity is not running or no notification handler defined?
                if (!PushyFlutterBackgroundExecutor.isRunning()) {
                    // Start background isolate
                    PushyFlutterBackgroundExecutor.getSingletonInstance().startBackgroundIsolate(context);

                    // Store notification JSON in SharedPreferences and deliver it when isolate ready
                    PushyPersistence.persistNotification(notification, context);
                }
                else {
                    // Log action
                    Log.d("Pushy", "Handling notification in Flutter background isolate");

                    // Run on background executor
                    PushyFlutterBackgroundExecutor.getSingletonInstance().invokeDartNotificationHandler(notification, context);
                }
            }
        });
    }

    @SuppressWarnings("unchecked")
    private void subscribe(final MethodCall call, final Result result) {
        // Get arguments
        final ArrayList<Object> args = call.arguments();

        // Run network I/O in background thread
        AsyncTask.execute(new Runnable() {
            @Override
            public void run() {
                try {
                    // Single topic?
                    if (args.get(0) instanceof String) {
                        // Attempt to subscribe the device to topic
                        Pushy.subscribe((String)args.get(0), mContext);
                    }
                    // Multiple topics?
                    else if (args.get(0) instanceof ArrayList) {
                        // Attempt to subscribe the device to multiple topics
                        Pushy.subscribe(((ArrayList<String>)(args.get(0))).toArray(new String[0]), mContext);
                    }

                    // Resolve the callback with success
                    success(result, "success");
                } catch (Exception exc) {
                    // Reject the callback with the exception
                    error(result, exc.getMessage());
                }
            }
        });
    }

    @SuppressWarnings("unchecked")
    private void unsubscribe(final MethodCall call, final Result result) {
        // Get arguments
        final ArrayList<Object> args = call.arguments();

        // Run network I/O in background thread
        AsyncTask.execute(new Runnable() {
            @Override
            public void run() {
                try {
                    // Single topic?
                    if (args.get(0) instanceof String) {
                        // Attempt to unsubscribe the device from topic
                        Pushy.unsubscribe((String)args.get(0), mContext);
                    }
                    // Multiple topics?
                    else if (args.get(0) instanceof ArrayList) {
                        // Attempt to unsubscribe the device from multiple topics
                        Pushy.unsubscribe(((ArrayList<String>)(args.get(0))).toArray(new String[0]), mContext);
                    }

                    // Resolve the callback with success
                    success(result, "success");
                } catch (Exception exc) {
                    // Reject the callback with the exception
                    error(result, exc.getMessage());
                }
            }
        });
    }

    private void setEnterpriseConfig(MethodCall call, Result result) {
        // Get arguments
        final ArrayList<String> args = call.arguments();

        // Set enterprise config based on passed in args
        Pushy.setEnterpriseConfig(args.get(0), args.get(1), mContext);

        // Return success nonetheless
        success(result, "success");
    }

    private void setNotificationListener(MethodCall call, Result result) {
        // Get arguments as list
        final ArrayList<Object> args = call.arguments();

        // Get callback handles as long (_isolate and notification handler)
        long isolateCallback = (args.get(0) instanceof Long) ? (Long) args.get(0) : ((Integer)args.get(0)).longValue();
        long notificationHandlerCallback = (args.get(1) instanceof Long) ? (Long) args.get(1) : ((Integer)args.get(1)).longValue();

        // Start background isolate (if not already started)
        if (!PushyFlutterBackgroundExecutor.isRunning()) {
            PushyFlutterBackgroundExecutor.getSingletonInstance().startBackgroundIsolate(mContext, isolateCallback, notificationHandlerCallback);
        }
        else {
            // Persist callback handles in SharedPreferences
            PushyFlutterBackgroundExecutor.persistCallbackHandleIds(mContext, isolateCallback, notificationHandlerCallback);
        }

        // Return success
        success(result, true);
    }

    private void setNotificationIcon(MethodCall call, Result result) {
        // Get arguments
        final ArrayList<String> args = call.arguments();

        // Get resource String name
        String iconResourceName = args.get(0);

        // Store in SharedPreferences using PushyPersistence helper
        PushyPersistence.setNotificationIcon(iconResourceName, mContext);

        // Return success nonetheless
        success(result, "success");
    }
    
    private void setJobServiceInterval(MethodCall call, Result result) {
        // Get arguments
        final ArrayList<Integer> args = call.arguments();

        // Get interval in ms
        int interval = args.get(0);

        // Modify JobService interval
        Pushy.setJobServiceInterval(interval, mActivity);

        // Return success
        success(result, "success");
    }

    private void setHeartbeatInterval(MethodCall call, Result result) {
        // Get arguments
        final ArrayList<Integer> args = call.arguments();

        // Get interval in ms
        int interval = args.get(0);

        // Modify heartbeat interval
        Pushy.setHeartbeatInterval(interval, mContext);

        // Return success
        success(result, "success");
    }

    private void toggleNotifications(MethodCall call, Result result) {
        // Get arguments
        final ArrayList<Boolean> args = call.arguments();

        // Get toggle value as bool
        Boolean value = args.get(0);

        // Toggle notifications on/off
        Pushy.toggleNotifications(value, mContext);

        // Return success
        success(result, "success");
    }

    private void toggleFCM(MethodCall call, Result result) {
        // Get arguments
        final ArrayList<Boolean> args = call.arguments();

        // Get toggle value as bool
        Boolean value = args.get(0);

        // Toggle FCM on/off
        Pushy.toggleFCM(value, mContext);

        // Return success
        success(result, "success");
    }

    private void toggleForegroundService(MethodCall call, Result result) {
        // Get arguments
        final ArrayList<Boolean> args = call.arguments();

        // Get toggle value as bool
        Boolean value = args.get(0);

        // Toggle foreground service on/off
        Pushy.toggleForegroundService(value, mContext);

        // Return success
        success(result, "success");
    }

    private void getFCMToken(final Result result) {
        // Run synchronous operation in background thread
        AsyncTask.execute(new Runnable() {
            @Override
            public void run() {
                try {
                    // Fetch FCM fallback delivery token (blocking call)
                    String fcmToken = Pushy.getFCMToken();

                    // Resolve the promise with the token
                    success(result, fcmToken);
                } catch (final PushyException exc) {
                    // Reject the promise with the exception
                    error(result, exc.getMessage());
                }
            }
        });
    }

    private void isIgnoringBatteryOptimizations(final Result result) {
        // Get power manager instance
        PowerManager powerManager = (PowerManager) mContext.getSystemService(Context.POWER_SERVICE);

        // Resolve the promise with battery optimization status
        success(result, powerManager.isIgnoringBatteryOptimizations(mContext.getPackageName()));
    }

    private void launchBatteryOptimizationsActivity(Result result) {
        // Display the battery optimization settings screen
        mActivity.startActivity(new Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS));

        // Return success
        success(result, "success");
    }

    private void isRegistered(Result result) {
        // Resolve the event with boolean result
        success(result, Pushy.isRegistered(mContext) ? "true" : "false");
    }

    public void notify(MethodCall call, Result result) {
        // Get arguments
        final ArrayList<String> args = call.arguments();

        // Extract arguments
        String title = args.get(0);
        String text = args.get(1);
        String payload = args.get(2);

        // Prepare a notification with vibration, sound and lights
        Notification.Builder builder = new Notification.Builder(mContext)
                .setSmallIcon(PushyNotification.getNotificationIcon(mContext))
                .setContentTitle(title)
                .setContentText(text)
                .setAutoCancel(true)
                .setVibrate(new long[]{0, 400, 250, 400})
                .setContentIntent(PushyNotification.getMainActivityPendingIntent(mContext, payload))
                .setSound(RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION));

        // Get an instance of the NotificationManager service
        NotificationManager notificationManager = (NotificationManager) mContext.getSystemService(mContext.NOTIFICATION_SERVICE);

        // Automatically configure a Notification Channel for devices running Android O+
        Pushy.setNotificationChannel(builder, mContext);

        // Build the notification and display it
        notificationManager.notify(text.hashCode(), builder.build());

        // Return success
        success(result, true);
    }

    private void setAppId(MethodCall call, Result result) {
        // Get arguments
        final ArrayList<String> args = call.arguments();

        // Get App ID value as string
        String value = args.get(0);

        // Set the Pushy App ID
        Pushy.setAppId(value, mContext);

        // Return success
        success(result, "success");
    }

    void success(final Result result, final Object message) {
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

    @Override
    public void onDetachedFromActivityForConfigChanges() {
    }

    @Override
    public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {
    }

    @Override
    public void onDetachedFromActivity() {
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    }
}
