package cz.smotrim.launcher;

import android.content.Context;
import android.content.pm.LauncherApps;
import android.os.UserHandle;

import java.io.Serializable;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

import io.flutter.plugin.common.EventChannel;

public class LauncherAppsEventStreamHandler implements EventChannel.StreamHandler
{
    private final LauncherApps _launcherApps;
    private final MainActivity _activity;

    private LauncherApps.Callback _launcherAppsCallback;

    // LauncherApps delivers its callbacks on the main thread, and resolving an
    // app means querying PackageManager and loading its label -- disk work that
    // has no business happening there. It shows up as the launcher hitching
    // while apps install or update, which is exactly when several arrive at
    // once. Single-threaded on purpose: these events are naturally sequential
    // and there is nothing to gain from racing them.
    private ExecutorService _executor;

    public LauncherAppsEventStreamHandler(MainActivity activity)
    {
        _activity = activity;
        _launcherApps = (LauncherApps) _activity.getSystemService(Context.LAUNCHER_APPS_SERVICE);
    }

    @Override
    public void onCancel(Object arguments)
    {
        // onListen may never have run, or may have failed before assigning:
        // unregisterCallback(null) throws.
        if (_launcherAppsCallback != null) {
            try {
                _launcherApps.unregisterCallback(_launcherAppsCallback);
            } catch (RuntimeException e) {
                e.printStackTrace();
            }
            _launcherAppsCallback = null;
        }
        if (_executor != null) {
            _executor.shutdownNow();
            _executor = null;
        }
    }

    @Override
    public void onListen(Object arguments, EventChannel.EventSink events)
    {
        _executor = Executors.newSingleThreadExecutor();
        _launcherAppsCallback = new LauncherAppsCallback(events);
        _launcherApps.registerCallback(_launcherAppsCallback);
    }


    private class LauncherAppsCallback extends LauncherApps.Callback
    {
        private final EventChannel.EventSink _eventSink;

        public LauncherAppsCallback(EventChannel.EventSink eventSink)
        {
            _eventSink = eventSink;
        }

        /**
         * Resolves off the main thread, then emits on it.
         *
         * Catches Throwable so a failure can never leave the worker dead with
         * the event silently dropped -- the same shape of bug that once left
         * every app card loading forever.
         */
        private void emitResolved(Resolver resolver)
        {
            ExecutorService executor = _executor;
            if (executor == null || executor.isShutdown()) return;

            executor.execute(() -> {
                final Map<String, Object> event;
                try {
                    event = resolver.resolve();
                } catch (Throwable t) {
                    t.printStackTrace();
                    return;
                }
                if (event == null) return;
                _activity.runOnUiThread(() -> {
                    try {
                        _eventSink.success(event);
                    } catch (Throwable t) {
                        t.printStackTrace();
                    }
                });
            });
        }

        @Override
        public void onPackageRemoved(String packageName, UserHandle user) {
            _eventSink.success(new java.util.HashMap<String, Object>() {{ put("action", "PACKAGE_REMOVED"); put("packageName", packageName); }});
        }

        @Override
        public void onPackageAdded(String packageName, UserHandle user) {
            emitResolved(() -> singleAppEvent("PACKAGE_ADDED", packageName));
        }

        @Override
        public void onPackageChanged(String packageName, UserHandle user) {
            emitResolved(() -> singleAppEvent("PACKAGE_CHANGED", packageName));
        }

        private Map<String, Object> singleAppEvent(String action, String packageName) {
            Map<String, Serializable> application = _activity.getApplication(packageName);
            if (application.isEmpty()) return null;

            Map<String, Object> event = new java.util.HashMap<>();
            event.put("action", action);
            event.put("activityInfo", application);
            return event;
        }

        @Override
        public void onPackagesAvailable(String[] packageNames, UserHandle user, boolean replacing) {
            emitResolved(() -> {
                List<Map<String, Serializable>> applications = new ArrayList<>(packageNames.length);

                for (String name : packageNames) {
                    Map<String, Serializable> application = _activity.getApplication(name);

                    if (!application.isEmpty()) {
                        applications.add(application);
                    }
                }

                if (applications.isEmpty()) return null;

                Map<String, Object> event = new java.util.HashMap<>();
                event.put("action", "PACKAGES_AVAILABLE");
                event.put("activitiesInfo", applications);
                return event;
            });
        }

        @Override
        public void onPackagesUnavailable(String[] packageNames, UserHandle user, boolean replacing) {
        }
    }

    /** Builds an event map off the main thread; null means "nothing to emit". */
    private interface Resolver
    {
        Map<String, Object> resolve();
    }
}
