package me.pushy.sdk.flutter.internal;

import android.content.Intent;
import android.content.Context;
import android.content.BroadcastReceiver;
import android.os.Bundle;
import android.util.Log;

import org.json.JSONException;
import org.json.JSONObject;

import java.util.Set;

import me.pushy.sdk.flutter.PushyPlugin;
import me.pushy.sdk.config.PushyLogging;

public class PushyInternalReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context context, Intent intent) {
        // Prepare JSON object containing the notification payload
        JSONObject json = new JSONObject();

        // Get intent extras
        Bundle bundle = intent.getExtras();

        // Get JSON key names
        Set<String> keys = bundle.keySet();

        // Traverse keys
        for (String key : keys) {
            try {
                // Attempt to insert the key and its value into the JSONObject
                json.put(key, bundle.get(key));
            }
            catch (JSONException e) {
                // Log error to logcat and stop execution
                Log.e(PushyLogging.TAG, "Failed to insert intent extra into JSONObject:" + e.getMessage(), e);
                return;
            }
        }

        // Invoke the notification received handler
        PushyPlugin.onNotificationReceived(json, context);
    }
}