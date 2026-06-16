# Smotrim.CZ Launcher

**Smotrim.CZ Launcher** is a minimal, open-source launcher for Android TV, branded for the **smotrim.cz** internet TV service.

<a href="https://github.com/davnozdu/smotrim-launcher/releases/latest">
  <img alt="Get it on GitHub" src="https://raw.githubusercontent.com/rubenpgrady/get-it-on-github/refs/heads/main/get-it-on-github.png" height="50">
</a>

## Features

- **Russian, Ukrainian & English** — full localization; the interface language follows your system settings.
- **App store (AppHub)** — a built-in store (`tv.smotrim.cz`) opens in a WebView; pick an app with the remote and it downloads & installs straight from GitHub releases.
- **One-tap companion installs** — buttons that install/update **Smotrim Player** and **HLS-PROXY**, always pulling the latest release.
- **Subscription renewal** — a button opens payment instructions with a Czech QR Platba code (amount pre-filled) or card payment.
- **In-app auto-update** — the launcher checks its own GitHub releases and updates itself; there's also a manual "Check for updates".
- **Hotel mode (kiosk)** — lock the box to a whitelist of apps behind an 8-digit PIN, enforced as a Device Owner (see below).
- **Network status** — a WiFi/Ethernet indicator next to the settings gear shows the connection at a glance.
- **OLED Screensaver** — minimal screensaver with clock position shifting to prevent burn-in.
- **Time-Based Wallpaper**, **Themes & Accent Color** (Default, Premium, Classic, Capsule), navigation sound feedback.
- **Customizable categories** — reorder apps and categories, row or grid layout, custom banners, a "Favorites" category.
- **No ads**, support for non-TV (sideloaded) apps. Universal APK (`armeabi-v7a` + `arm64-v8a`).

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

## Home screen & app store

At the bottom of the home screen, under the apps:
- **Renew subscription** — opens payment instructions: bank transfer with a pre-filled Czech QR Platba code (1000 Kč embedded) or card payment via a SumUp QR. Notes about business-hours processing and SMS confirmation are shown.
- **Install / Update Smotrim Player** and **Install / Update HLS-PROXY** — one tap checks the installed version against the latest GitHub release and either installs or updates it (or tells you it's already up to date).
- **App store (AppHub)** — opens the Smotrim store (`tv.smotrim.cz`) in a full-screen WebView. Drive the catalog with the D-pad, press **OK** to open an app, and **OK** on *Install* downloads & installs it. **Back** closes a card; at the store's main screen Back asks to confirm before leaving.

When a launcher update is available, a green prompt appears at the top of the home — press **OK** to install. You can also force a check in **Settings → System → Check for updates**.

## Wallpaper
Because Android's `WallpaperManager` is not available on some Android TV devices, the launcher implements its own wallpaper management. Changing the wallpaper requires a file explorer installed on the device to pick a file.

## Hotel mode (kiosk)

Hotel mode turns the box into a locked kiosk: the guest can only open the apps you whitelist (TV, YouTube, …). Google Play is hidden, system settings are unreachable, and factory reset / safe boot / ADB / uninstall are blocked. The only way into the admin panel is the owner-set **8-digit PIN** — there is **no hidden code or back-door of any kind**. A forgotten PIN can only be recovered by factory-resetting the device.

### Step 1 — Provision the launcher as Device Owner (one-time)

Real enforcement requires this launcher to be the **Device Owner**. Device Owner can only be set while the device has **no secondary users and no accounts** — but you do **not** need a factory reset or a "skip sign-in" option: just remove the account temporarily, set Device Owner, then add it back.

```shell
# Enable ADB on the TV (Settings → Device Preferences → About → tap Build 7×
# → Developer options → USB/Network debugging), then from a computer:
adb connect <tv-ip>:5555

# 1) Remove any secondary users (keep user 0 / Owner):
adb shell pm list users
adb shell pm remove-user <id>          # repeat for each non-0 user

# 2) Remove every account (Settings → Accounts → remove). Open the screen with:
adb shell am start -a android.settings.SYNC_SETTINGS
#    confirm none remain (output must be empty):
adb shell dumpsys account | grep "Account {"

# 3) Set Device Owner:
adb shell dpm set-device-owner cz.smotrim.launcher/.HotelAdminReceiver
#    → Success: Device owner set to package cz.smotrim.launcher/.HotelAdminReceiver

# 4) Add your Google account back so Play-dependent apps (YouTube, …) work:
adb shell am start -a android.settings.ADD_ACCOUNT_SETTINGS
```

Re-adding the account **after** Device Owner is set works on most devices (this launcher does not block accounts). Verified on Xiaomi Mi TV (Android 14).

> Without Device Owner, hotel mode is **cosmetic only** — it filters the app list, hides the action buttons and locks our settings behind the PIN, but Play Store and **system settings are not actually blocked** and a determined guest can still escape. Good enough for trusted guests; not a real lockdown.

**Does adding a user/account later break it?** No. Device Owner is permanent — it is **not** lost by adding or removing accounts or users. It is removed only by a factory reset, by uninstalling the launcher (blocked while hotel mode is on), or by the launcher relinquishing it. While hotel mode is active, adding new users is blocked.

### Step 2 — Set it up (in the launcher)
**Settings → Hotel mode:**
1. **Set the 8-digit PIN** — you enter it twice to confirm.
2. **Tick the apps** a guest may use (TV, YouTube, …).
3. *(optional)* **Auto-launch app** — the chosen app starts automatically on boot, so the guest lands straight on it.
4. **Turn on hotel mode.**

### Step 3 — Daily use & admin
- While locked, the home shows **only** the whitelisted apps (banner and all install/action buttons are hidden), and opening Settings shows **only** the unlock screen.
- Enter the PIN to reach the **admin panel**:
  - **Reset guest data** (checkout) — wipes data **and cache** of the guest apps, keeping the ones you toggle off (e.g. the TV app stays signed in); the choice is remembered for next time.
  - **Reset data by app** — pick exactly the apps to wipe right now.
  - **Change PIN** — entered twice.
  - **Leave hotel mode** — back to the full launcher.
  - **Full device reset** — factory reset, behind a confirmation.

### Security notes
- The PIN is stored salted-SHA-256 (never in clear text); 5 wrong tries trigger a 1-minute lockout. **There is no master/service code in the build** — the owner PIN is the only way in.
- Enforcement is at the OS level (Device Owner lock-task), not just in the UI — even a UI slip cannot launch Settings/Play because they aren't whitelisted.
- Hotel mode blocks developer features (ADB), factory reset, safe boot and uninstall, so the data can't be wiped or the launcher removed from outside. Keep the bootloader locked; no Android app can prevent a firmware re-flash on an unlocked bootloader.
- **Forgotten PIN:** the only recovery is a factory reset of the device (by design — there is no back-door).

## Building
APKs are built and signed automatically on **GitHub Actions** (`.github/workflows/build.yml`). Release builds are signed with a persistent key stored in repository secrets, so updates install over previous versions.

## License
Licensed under the **GNU General Public License v3.0**. See [LICENSE](LICENSE).

---

> **This project is a fork.** It is based on [LtvLauncher](https://github.com/LeanBitLab/LtvLauncher), which in turn is a fork of [FLauncher](https://gitlab.com/flauncher/flauncher) © 2021 Étienne Fesser. As required by the GPLv3, the original copyright and license are preserved.
