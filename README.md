# Smotrim.CZ Launcher

**Smotrim.CZ Launcher** is a minimal, open-source launcher for Android TV, branded for the **smotrim.cz** internet TV service.

<a href="https://github.com/davnozdu/smotrim-launcher/releases/latest">
  <img alt="Get it on GitHub" src="https://raw.githubusercontent.com/rubenpgrady/get-it-on-github/refs/heads/main/get-it-on-github.png" height="50">
</a>

## Features

- **Russian & Ukrainian** — full localization; the interface language follows your system settings.
- **Subscription renewal** — a "Renew subscription" button on the home screen opens payment instructions with a Czech QR Platba code (amount pre-filled).
- **Info banner** — `smotrim.cz` and the support phone number are always visible at the bottom of the home screen.
- **Data Usage Widget** — track daily Internet consumption (WiFi, Ethernet, Mobile) from the status bar.
- **OLED Screensaver** — minimal screensaver with clock position shifting to prevent burn-in.
- **Easy WiFi Access** — the network indicator doubles as a shortcut to system WiFi settings.
- **Quick Presets** — pick time/date formats and category names from a list (no keyboard required).
- **Time-Based Wallpaper** — automatically switch between day and night backgrounds.
- **Themes & Accent Color** — multiple visual styles (Default, Premium, Classic, Capsule) and color presets.
- **Customizable categories** — reorder apps and categories, row or grid layout, custom banners, a "Favorites" category.
- **No ads**, support for non-TV (sideloaded) apps, navigation sound feedback.
- **Official support** for `armeabi-v7a` and `arm64-v8a` devices.

## Screenshots

<table>
  <tr>
    <td align="center">Home Screen</td>
    <td align="center">Settings 1</td>
    <td align="center">Settings 2</td>
    <td align="center">Settings 3</td>
    <td align="center">Screensaver</td>
  </tr>
  <tr>
    <td><img src="docs/images/screenshot_1.png" width="100%" alt="Home Screen"/></td>
    <td><img src="docs/images/screenshot_2.png" width="100%" alt="Settings 1"/></td>
    <td><img src="docs/images/screenshot_3.png" width="100%" alt="Settings 2"/></td>
    <td><img src="docs/images/screenshot_4.png" width="100%" alt="Settings 3"/></td>
    <td><img src="docs/images/screensaver.gif" width="100%" alt="Screensaver"/></td>
  </tr>
</table>

## Set Smotrim.CZ Launcher as the default launcher

### Method 1: Remap the Home button
The safest and easiest way. Use [Key Mapper](https://github.com/keymapperorg/KeyMapper) to remap the Home button of the remote to launch Smotrim.CZ Launcher.

### Method 2: Disable the default launcher
> **:warning: You do this at your own risk and are responsible for any malfunction on your device.**

The following commands were tested on Chromecast with Google TV only and may differ on other devices. Once the default launcher is disabled, press the Home button and the system will prompt you to choose a default.

#### Disable default launcher
```shell
# Disable com.google.android.apps.tv.launcherx (default launcher on CCwGTV)
$ adb shell pm disable-user --user 0 com.google.android.apps.tv.launcherx
# com.google.android.tungsten.setupwraith re-enables the default launcher, so disable it too
$ adb shell pm disable-user --user 0 com.google.android.tungsten.setupwraith
```

#### Re-enable default launcher
```shell
$ adb shell pm enable com.google.android.apps.tv.launcherx
$ adb shell pm enable com.google.android.tungsten.setupwraith
```

#### Known issues
On Chromecast with Google TV (and possibly others), the "YouTube" remote button stops working while the default launcher is disabled. As a workaround, remap it with [Key Mapper](https://github.com/keymapperorg/KeyMapper).

## Wallpaper
Because Android's `WallpaperManager` is not available on some Android TV devices, the launcher implements its own wallpaper management. Changing the wallpaper requires a file explorer installed on the device to pick a file.

## Hotel mode (kiosk)

Hotel mode turns the box into a locked kiosk: the guest can only open the apps you whitelist (TV, YouTube, …). Google Play is hidden, system settings are unreachable, and factory reset / safe boot / ADB / uninstall are blocked. The only way into the admin panel is the owner-set **8-digit PIN** — there is **no hidden code or back-door of any kind**. A forgotten PIN can only be recovered by factory-resetting (re-provisioning) the device.

### One-time provisioning (required for real enforcement)
Hotel mode is enforced only when this launcher is the **Device Owner**. Set it once on a **freshly reset** device that has **no Google account added yet**:

```shell
# Enable ADB (Settings → System → Developer options → USB/Network debugging),
# then from a computer:
adb connect <tv-ip>:5555
adb shell dpm set-device-owner cz.smotrim.launcher/.HotelAdminReceiver
```

You should see `Success: Device owner set ...`. If it fails with "already has an account/owner", factory-reset the TV first and run it before signing in.

> Without this step hotel mode is **cosmetic only** (it filters the app list and locks our settings, but Play Store and system settings are **not** blocked).

### Setup & daily use
1. Settings → **Hotel mode** → set the 8-digit PIN, tick the apps a guest may use, then **Turn on hotel mode**.
2. While locked, opening Settings shows **only** the unlock screen.
3. Enter the PIN to reach the **admin panel**: reset guest data, leave hotel mode, or factory-reset the device.
4. **Checkout reset** wipes only the data of the apps you choose (e.g. clears the YouTube login) — toggle off the apps to keep signed in (e.g. the TV app). Hotel mode, the PIN and the whitelist are preserved.

### Security notes
- The PIN is stored salted-SHA-256 (never in clear text); 5 wrong tries trigger a 1-minute lockout. There is no master/service code in the build.
- Enforcement is at the OS level (Device Owner lock-task), not just in the UI — even a UI slip cannot launch Settings/Play because they aren't whitelisted.
- After provisioning, hotel mode disables developer features (ADB) so the data can't be cleared over `adb`. Keep the bootloader locked; no Android app can prevent a firmware re-flash on an unlocked bootloader.

## Building
APKs are built and signed automatically on **GitHub Actions** (`.github/workflows/build.yml`). Release builds are signed with a persistent key stored in repository secrets, so updates install over previous versions.

## License
Licensed under the **GNU General Public License v3.0**. See [LICENSE](LICENSE).

---

> **This project is a fork.** It is based on [LtvLauncher](https://github.com/LeanBitLab/LtvLauncher), which in turn is a fork of [FLauncher](https://gitlab.com/flauncher/flauncher) © 2021 Étienne Fesser. As required by the GPLv3, the original copyright and license are preserved.
