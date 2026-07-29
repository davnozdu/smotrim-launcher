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
              // The branding banner is hidden in hotel mode. Selector, not
              // watch(): watching here rebuilt this whole Stack (wallpaper
              // included) on any hotel-service notification.
              bottomNavigationBar: Selector<HotelModeService, bool>(
                selector: (_, hotel) => hotel.enabled,
                builder: (_, locked, __) =>
                    locked ? const SizedBox.shrink() : const SmotrimBanner(),
              ),
              body: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Consumer2<AppsService, HotelModeService>(
                  builder: (context, appsService, hotel, _) {
                    if (appsService.initialized) {
                      // CustomScrollView, not SingleChildScrollView+Column: the
                      // latter built and laid out every category — and therefore
                      // every app card, with its image load and animation
                      // controllers — before the first frame could be shown.
                      return CustomScrollView(
                        slivers: _sectionSlivers(appsService.launcherSections, hotel),
                      );
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

  /// Builds the home screen as a list of slivers, one per section.
  ///
  /// Each section is its own sliver so the viewport can skip building the ones
  /// that are off-screen, instead of the whole home screen being materialised up
  /// front.
  List<Widget> _sectionSlivers(List<LauncherSection> sections, HotelModeService hotel) {
    final bool locked = hotel.enabled;
    // Update prompt above the categories (Row keeps its height bounded inside
    // the scroll view; never use Align here). Hidden in hotel mode.
    List<Widget> slivers = [
      if (!locked)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(top: 8),
            child: Row(children: [UpdateBanner()]),
          ),
        ),
    ];
    bool firstCategoryFound = false;

    for (var section in sections) {
      // Categories and spacers are numbered by two independent autoincrement
      // tables, so `section.id` alone collides across the two kinds — which is a
      // duplicate-key error once both land in the same child list.
      final Key sectionKey = ValueKey(
          section is Category ? "category_${section.id}" : "spacer_${section.id}");

      if (section is LauncherSpacer) {
        if (!locked) {
          slivers.add(SliverToBoxAdapter(
              key: sectionKey,
              child: SizedBox(height: section.height.toDouble())));
        }
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
              category: category,
              applications: apps,
              isFirstSection: isFirstSection
          );
          break; // Added break
        case CategoryType.grid:
          categoryWidget = AppsGrid(
              category: category,
              applications: apps,
              isFirstSection: isFirstSection
          );
          break; // Added break
      }

      // CategoryRow and AppsGrid are sliver widgets, so the padding around them
      // has to be a SliverPadding rather than a box Padding.
      slivers.add(SliverPadding(
        key: sectionKey,
        padding: const EdgeInsets.symmetric(vertical: 8),
        sliver: categoryWidget,
      ));
    }

    // Action buttons (subscription / installers / store) are hidden in hotel
    // mode — a guest must not install or change anything.
    if (locked) {
      return slivers;
    }

    // "Renew subscription" + "Install/Update player" at the very bottom, under
    // all the apps, side by side with a small gap (wraps on narrow screens).
    slivers.add(SliverToBoxAdapter(
      child: Padding(
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
                const BecomeSubscriberButton(),
                const SubscriptionButton(),
                const PlayerInstallButton(),
                AppStoreButton(compact: compactStore),
              ],
            );
          },
        ),
      ),
    ));

    return slivers;
  }

  Widget _wallpaper(BuildContext context, WallpaperService wallpaperService) {
    if (wallpaperService.wallpaper != null) {
      final size = MediaQuery.sizeOf(context);
      final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
      // Decode at screen resolution. A full-size photo picked from the gallery
      // could otherwise occupy most of the image cache on its own and keep
      // evicting the app banners, which showed up as stutter while scrolling.
      return Image(
        image: ResizeImage(
          wallpaperService.wallpaper!,
          width: (size.width * devicePixelRatio).round(),
          height: (size.height * devicePixelRatio).round(),
          policy: ResizeImagePolicy.fit,
        ),
        key: Key("background_${wallpaperService.version}"),
        fit: BoxFit.cover,
        height: size.height,
        width: size.width
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
