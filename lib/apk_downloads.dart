/*
 * Smotrim.CZ Launcher
 * Based on FLauncher (C) 2021 Étienne Fesser — GPLv3.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

import 'dart:io';

import 'package:flutter/foundation.dart';

/// Deletes APKs left in [dir] by earlier downloads.
///
/// Every install (store, player, launcher update) downloads into the temporary
/// directory, and nothing ever removed the file afterwards: the installer reads
/// it asynchronously, so it cannot be deleted right after hand-off. On a box
/// with a few GB of storage that runs for months, those files added up. They
/// are cleared before the next download instead, sparing anything recent enough
/// that an installer might still be reading it.
Future<void> deleteStaleApks(Directory dir,
    {Duration olderThan = const Duration(minutes: 10)}) async {
  try {
    final cutoff = DateTime.now().subtract(olderThan);
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File || !entity.path.toLowerCase().endsWith(".apk")) continue;
      try {
        if ((await entity.lastModified()).isBefore(cutoff)) await entity.delete();
      } catch (_) {
        // In use or already gone; the next run will get it.
      }
    }
  } catch (e) {
    debugPrint("Could not clean up old APKs: $e");
  }
}

/// Throws when a download ended before [expected] bytes arrived.
///
/// A connection that closes cleanly mid-transfer ends the byte stream without
/// an error, and the truncated file used to be handed to the system installer,
/// which then failed with an unhelpful "problem parsing the package".
void checkDownloadComplete(int received, int expected) {
  if (expected > 0 && received != expected) {
    throw HttpException("Incomplete download: $received of $expected bytes");
  }
}
