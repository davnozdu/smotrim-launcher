/*
 * Smotrim.CZ Launcher
 * Based on FLauncher (C) 2021 Étienne Fesser — GPLv3.
 */
package cz.smotrim.launcher;

import android.app.admin.DeviceAdminReceiver;
import android.content.ComponentName;
import android.content.Context;

/**
 * Device-admin receiver required to make this launcher a Device Owner.
 *
 * Provisioning (once, on a freshly reset device with no accounts):
 *   adb shell dpm set-device-owner cz.smotrim.launcher/.HotelAdminReceiver
 *
 * Once it's the Device Owner, the launcher can run "hotel mode" as a real
 * kiosk (lock task, hidden Play Store, blocked Settings/reset) — see
 * MainActivity#enableHotelMode.
 */
public class HotelAdminReceiver extends DeviceAdminReceiver {
    public static ComponentName getComponentName(Context context) {
        return new ComponentName(context.getApplicationContext(), HotelAdminReceiver.class);
    }
}
