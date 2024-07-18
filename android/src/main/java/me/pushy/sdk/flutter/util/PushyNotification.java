package me.pushy.sdk.flutter.util;

import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageManager;
import android.content.res.Resources;

import me.pushy.sdk.flutter.config.PushyIntentExtras;

public class PushyNotification {
    public static int getNotificationIcon(Context context) {
        try {
            // Try to query for app metadata
            ApplicationInfo app = context.getPackageManager().getApplicationInfo(context.getPackageName(), PackageManager.GET_META_DATA);

            // App metadata retrieved?
            if (app != null && app.metaData != null) {
                // Attempt to fetch icon name from <meta-data>
                int iconResource = app.metaData.getInt("me.pushy.sdk.notification.icon");

                // Is it defined?
                if (iconResource > 0) {
                    return iconResource;
                }
            }
        } catch (PackageManager.NameNotFoundException e) {
            // Ignore exceptions
        }

        // If failed, fallback to Pushy.setNotificationIcon()
        // Attempt to fetch icon name from SharedPreferences
        String icon = PushyPersistence.getNotificationIcon(context);

        // Did we configure a custom icon?
        if (icon != null) {
            // Cache app resources
            Resources resources = context.getResources();

            // Cache app package name
            String packageName = context.getPackageName();

            // Look for icon in drawable folders
            int iconId = resources.getIdentifier(icon, "drawable", packageName);

            // Found it?
            if (iconId != 0) {
                return iconId;
            }

            // Look for icon in mipmap folders
            iconId = resources.getIdentifier(icon, "mipmap", packageName);

            // Found it?
            if (iconId != 0) {
                return iconId;
            }
        }

        // Fallback to generic icon
        return android.R.drawable.ic_dialog_info;
    }

    public static PendingIntent getMainActivityPendingIntent(Context context, String payload) {
        // Get launcher activity intent
        Intent launchIntent = context.getPackageManager().getLaunchIntentForPackage(context.getApplicationContext().getPackageName());

        // Make sure to update the activity if it exists
        launchIntent.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP | Intent.FLAG_ACTIVITY_CLEAR_TOP);

        // Pass payload data into PendingIntent
        launchIntent.putExtra(PushyIntentExtras.NOTIFICATION_CLICKED, true);
        launchIntent.putExtra(PushyIntentExtras.NOTIFICATION_PAYLOAD, payload);

        // Convert intent into pending intent
        return PendingIntent.getActivity(context, payload.hashCode(), launchIntent, PendingIntent.FLAG_IMMUTABLE);
    }
}
