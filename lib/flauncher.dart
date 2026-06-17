/*
 * FLauncher
 * Copyright (C) 2021  Étienne Fesser
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */


import 'package:flauncher/actions.dart';
import 'package:flauncher/custom_traversal_policy.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/hotel_mode_service.dart';
import 'package:flauncher/models/app.dart';
import 'package:flauncher/providers/launcher_state.dart';
import 'package:flauncher/providers/wallpaper_service.dart';
import 'package:flauncher/widgets/apps_grid.dart';
import 'package:flauncher/widgets/category_row.dart';
import 'package:flauncher/widgets/launcher_alternative_view.dart';
import 'package:flauncher/widgets/focus_aware_app_bar.dart';
import 'package:flauncher/widgets/smotrim_banner.dart';
import 'package:flauncher/widgets/subscription_button.dart';
import 'package:flauncher/widgets/player_install_button.dart';
import 'package:flauncher/widgets/app_store_button.dart';
import 'package:flauncher/widgets/update_banner.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flauncher/l10n/app_localizations.dart';

import 'models/category.dart';

class FLauncher extends StatefulWidget {
  const FLauncher({super.key});

  @override
  State<FLauncher> createState() => _FLauncherState();
}

class _FLauncherState extends State<FLauncher> {
  final GlobalKey<FocusAwareAppBarState> _appBarKey = GlobalKey();

  @override
  Widget build(BuildContext context) => Actions(
    actions: <Type, Action<Intent>>{
      MoveFocusToSettingsIntent: CallbackAction<MoveFocusToSettingsIntent>(
        onInvoke: (_) => _appBarKey.currentState?.focusSettings(),
      ),
    },
    child: FocusTraversalGroup(
      policy: RowByRowTraversalPolicy(),
      child: Stack(
        children: [
          RepaintBoundary(
            child: Consumer<WallpaperService>(
              builder: (_, wallpaperService, __) => _wallpaper(context, wallpaperService)
            ),
          ),
          Consumer<LauncherState>(
            builder: (_, state, child) => Visibility(
              child: child!,
              replacement: const Center(
                child: AlternativeLauncherView()
              ),
              visible: state.launcherVisible
            ),
            child: Scaffold(
              backgroundColor: Colors.transparent,
              appBar: FocusAwareAppBar(key: _appBarKey),
              // The branding banner is hidden in hotel mode.
              bottomNavigationBar: context.watch<HotelModeService>().enabled ? null : const SmotrimBanner(),
              body: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Consumer2<AppsService, HotelModeService>(
                  builder: (context, appsService, hotel, _) {
                    if (appsService.initialized) {
                      return SingleChildScrollView(child: _sections(appsService.launcherSections, hotel));
                    }
                    else {
                      return _emptyState(context);
                    }
                  }
                )
              )
            )
          )
        ]
      )
    ),
  );

  Widget _sections(List<LauncherSection> sections, HotelModeService hotel) {
    final bool locked = hotel.enabled;
    // Update prompt above the categories (Row keeps its height bounded inside
    // the scroll view; never use Align here). Hidden in hotel mode.
    List<Widget> children = [
      if (!locked)
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Row(children: [UpdateBanner()]),
        ),
    ];
    bool firstCategoryFound = false;

    for (var section in sections) {
      final Key sectionKey = Key(section.id.toString());

      if (section is LauncherSpacer) {
        if (!locked) children.add(SizedBox(key: sectionKey, height: section.height.toDouble()));
        continue;
      }

      Category category = section as Category;

      // In hotel mode only whitelisted apps are shown; empty categories vanish.
      final List<App> apps = locked
          ? category.applications.where((a) => hotel.allowedPackages.contains(a.packageName)).toList()
          : category.applications;
      if (locked && apps.isEmpty) continue;

      Widget categoryWidget;

      // Pass isFirstSection only to the first category found
      bool isFirstSection = !firstCategoryFound;
      if (isFirstSection) firstCategoryFound = true;

      switch (category.type) {
        case CategoryType.row:
          categoryWidget = CategoryRow(
              key: sectionKey,
              category: category,
              applications: apps,
              isFirstSection: isFirstSection
          );
          break; // Added break
        case CategoryType.grid:
          categoryWidget = AppsGrid(
              key: sectionKey,
              category: category,
              applications: apps,
              isFirstSection: isFirstSection
          );
          break; // Added break
      }

      children.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: categoryWidget
      ));
    }

    // Action buttons (subscription / installers / store) are hidden in hotel
    // mode — a guest must not install or change anything.
    if (locked) {
      return Column(children: children);
    }

    // "Renew subscription" + "Install/Update player" at the very bottom, under
    // all the apps, side by side with a small gap (wraps on narrow screens).
    children.add(Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      // Keep the action buttons on one row when there's room; on a narrow row
      // the app-store button falls back to its short "AppHub" label to help
      // everything fit before the Wrap is forced to break onto a second line.
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compactStore = constraints.maxWidth < 1000;
          return Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              const SubscriptionButton(),
              const PlayerInstallButton(),
              AppStoreButton(compact: compactStore),
            ],
          );
        },
      ),
    ));

    return Column(children: children);
  }

  Widget _wallpaper(BuildContext context, WallpaperService wallpaperService) {
    if (wallpaperService.wallpaper != null) {
      final physicalSize = MediaQuery.sizeOf(context);
      return Image(
        image: wallpaperService.wallpaper!,
        key: Key("background_${wallpaperService.version}"),
        fit: BoxFit.cover,
        height: physicalSize.height,
        width: physicalSize.width
      );
    }
    else {
      return Container(key: const Key("background"), decoration: BoxDecoration(gradient: wallpaperService.gradient.gradient));
    }
  }

  Widget _emptyState(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(localizations.loading, style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    );
  }
}
