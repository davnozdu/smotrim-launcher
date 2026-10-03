/*
 * Smotrim.CZ Launcher
 * Based on FLauncher (C) 2021 Étienne Fesser — GPLv3.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

package cz.smotrim.launcher;

import android.content.Context;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.os.Build;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;

/**
 * On-disk cache of the encoded icons and banners handed to the Dart side.
 *
 * Producing one means loading the drawable from the app's APK, rasterising it
 * and encoding WEBP -- tens of milliseconds each on a low-end TV box, and all of
 * it queued on a single background thread. Without this the launcher redid that
 * for every visible card on every start. Reading the finished bytes back is a
 * millisecond or two.
 *
 * Entries are keyed on the package's last update time and version code, so an
 * updated app misses the cache on its own. Package events also drop entries
 * explicitly, which covers changes that keep both (a component toggled on or
 * off). A zero-length entry records "this app has no such artwork", which is
 * as worth remembering as the artwork itself.
 *
 * Lives in the app's cache directory: bounded by the installed apps (a few MB),
 * and the system may clear it under storage pressure, which only costs a rebuild.
 */
final class ArtworkCache {
    static final String ICON = "icon";
    static final String BANNER = "banner";

    // Bump when the encoding changes (size caps, format) to orphan old entries.
    private static final String DIR_NAME = "artwork-v1";
    // Not a legal character in a package name, so prefixes never collide.
    private static final char SEP = '@';

    private final File _dir;

    ArtworkCache(Context context) {
        _dir = new File(context.getCacheDir(), DIR_NAME);
    }

    /** Identifies the installed build of [packageName], or null if unknown. */
    @SuppressWarnings("deprecation")
    static String stampOf(PackageManager packageManager, String packageName) {
        try {
            PackageInfo info = packageManager.getPackageInfo(packageName, 0);
            long versionCode = Build.VERSION.SDK_INT >= Build.VERSION_CODES.P
                    ? info.getLongVersionCode()
                    : info.versionCode;
            return info.lastUpdateTime + "-" + versionCode;
        } catch (PackageManager.NameNotFoundException e) {
            return null;
        }
    }

    /** The cached bytes, or null on a miss. An empty array is a cached "none". */
    byte[] get(String kind, String packageName, String stamp) {
        if (stamp == null) return null;
        File file = new File(_dir, name(kind, packageName, stamp));
        if (!file.isFile()) return null;
        try {
            return readFully(file);
        } catch (IOException e) {
            file.delete();
            return null;
        }
    }

    void put(String kind, String packageName, String stamp, byte[] bytes) {
        if (stamp == null) return;
        try {
            if (!_dir.isDirectory() && !_dir.mkdirs()) return;
            deleteByPrefix(prefix(kind, packageName));

            // Written aside and renamed into place, so a reader never sees a
            // half-written file -- not even after a power cut mid-write.
            File target = new File(_dir, name(kind, packageName, stamp));
            File temp = new File(_dir, target.getName() + ".tmp" + Thread.currentThread().getId());
            try (FileOutputStream out = new FileOutputStream(temp)) {
                out.write(bytes);
            }
            if (!temp.renameTo(target)) temp.delete();
        } catch (IOException | RuntimeException e) {
            e.printStackTrace();
        }
    }

    /** Drops everything cached for [packageName]. */
    void invalidate(String packageName) {
        deleteByPrefix(prefix(ICON, packageName));
        deleteByPrefix(prefix(BANNER, packageName));
    }

    private void deleteByPrefix(String prefix) {
        String[] names = _dir.list();
        if (names == null) return;
        for (String name : names) {
            if (name.startsWith(prefix)) {
                new File(_dir, name).delete();
            }
        }
    }

    private static String prefix(String kind, String packageName) {
        return kind + SEP + packageName + SEP;
    }

    private static String name(String kind, String packageName, String stamp) {
        return prefix(kind, packageName) + stamp;
    }

    private static byte[] readFully(File file) throws IOException {
        long length = file.length();
        if (length > Integer.MAX_VALUE) throw new IOException("Too large: " + file);
        byte[] bytes = new byte[(int) length];
        try (FileInputStream in = new FileInputStream(file)) {
            int offset = 0;
            while (offset < bytes.length) {
                int read = in.read(bytes, offset, bytes.length - offset);
                if (read < 0) throw new IOException("Truncated: " + file);
                offset += read;
            }
        }
        return bytes;
    }
}
