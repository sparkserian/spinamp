import 'dart:io';

import 'package:finamp/screens/playback_history_screen.dart';
import 'package:finamp/screens/player_screen.dart';
import 'package:finamp/screens/queue_restore_screen.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:get_it/get_it.dart';
import 'package:window_manager/window_manager.dart';

import '../../config/product_config.dart';
import '../../screens/downloads_screen.dart';
import '../../screens/logs_screen.dart';
import '../../screens/settings_screen.dart';
import '../../services/finamp_user_helper.dart';
import 'offline_mode_switch_list_tile.dart';
import 'view_list_tile.dart';

enum MusicScreenSidebarSection {
  home,
  library,
}

class MusicScreenDrawer extends StatelessWidget {
  const MusicScreenDrawer({
    super.key,
    this.sidebar = false,
    this.selectedSection,
    this.onSectionSelected,
  });

  final bool sidebar;
  final MusicScreenSidebarSection? selectedSection;
  final void Function(MusicScreenSidebarSection section)? onSectionSelected;

  @override
  Widget build(BuildContext context) {
    final finampUserHelper = GetIt.instance<FinampUserHelper>();
    final content = _MusicScreenDrawerContent(
      finampUserHelper: finampUserHelper,
      sidebar: sidebar,
      selectedSection: selectedSection,
      onSectionSelected: onSectionSelected,
    );

    if (sidebar) {
      return ColoredBox(
        color: Theme.of(context).colorScheme.surface,
        child: content,
      );
    }

    return Drawer(
      surfaceTintColor: Colors.white,
      child: content,
    );
  }
}

class _MusicScreenDrawerContent extends StatelessWidget {
  const _MusicScreenDrawerContent({
    required this.finampUserHelper,
    required this.sidebar,
    this.selectedSection,
    this.onSectionSelected,
  });

  final FinampUserHelper finampUserHelper;
  final bool sidebar;
  final MusicScreenSidebarSection? selectedSection;
  final void Function(MusicScreenSidebarSection section)? onSectionSelected;

  @override
  Widget build(BuildContext context) {
    return ListTileTheme(
      contentPadding: const EdgeInsetsDirectional.only(start: 16.0, end: 8.0),
      horizontalTitleGap: 0,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              padding: EdgeInsets.fromLTRB(20, sidebar ? 22 : 12, 20, 18),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).dividerColor.withOpacity(0.45),
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.asset(
                    'images/finamp_cropped.png',
                    width: 42,
                    height: 42,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    kProductName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    finampUserHelper.currentUser?.currentView?.name ??
                        AppLocalizations.of(context)!.music,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).hintColor,
                        ),
                  ),
                ],
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildListDelegate.fixed(
              [
                if (onSectionSelected != null) ...[
                  ListTile(
                    leading: const Padding(
                      padding: EdgeInsets.only(right: 16),
                      child: Icon(TablerIcons.home_2),
                    ),
                    title: const Text("Home"),
                    selected: selectedSection == MusicScreenSidebarSection.home,
                    onTap: () =>
                        onSectionSelected?.call(MusicScreenSidebarSection.home),
                  ),
                  ListTile(
                    leading: const Padding(
                      padding: EdgeInsets.only(right: 16),
                      child: Icon(TablerIcons.music),
                    ),
                    title: Text(AppLocalizations.of(context)!.music),
                    selected:
                        selectedSection == MusicScreenSidebarSection.library,
                    onTap: () => onSectionSelected
                        ?.call(MusicScreenSidebarSection.library),
                  ),
                  const Divider(),
                ],
                ListTile(
                  leading: const Padding(
                    padding: EdgeInsets.only(right: 16),
                    child: Icon(Icons.file_download),
                  ),
                  title: Text(AppLocalizations.of(context)!.downloads),
                  onTap: () => Navigator.of(context)
                      .pushNamed(DownloadsScreen.routeName),
                ),
                ListTile(
                  leading: const Padding(
                    padding: EdgeInsets.only(right: 16),
                    child: Icon(TablerIcons.clock),
                  ),
                  title: Text(AppLocalizations.of(context)!.playbackHistory),
                  onTap: () => Navigator.of(context)
                      .pushNamed(PlaybackHistoryScreen.routeName),
                ),
                const OfflineModeSwitchListTile(),
                const Divider(),
              ],
            ),
          ),
          if (finampUserHelper.currentUser != null)
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => ViewListTile(
                  view: finampUserHelper.currentUser!.views.values
                      .elementAt(index),
                ),
                childCount: finampUserHelper.currentUser!.views.length,
              ),
            ),
          SliverFillRemaining(
            hasScrollBody: false,
            child: SafeArea(
              bottom: true,
              top: false,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Divider(),
                    if (Platform.isWindows ||
                        Platform.isLinux ||
                        Platform.isMacOS)
                      Consumer(
                        builder: (context, ref, widget) {
                          final finampSettings = ref
                              .watch(
                                  FinampSettingsHelper.finampSettingsProvider)
                              .value;
                          return SwitchListTile.adaptive(
                            title: const Text("Miniplayer"),
                            secondary: const Padding(
                              padding: EdgeInsets.only(right: 16),
                              child: Icon(TablerIcons.window_minimize),
                            ),
                            activeTrackColor:
                                Theme.of(context).brightness == Brightness.light
                                    ? Theme.of(context)
                                        .primaryColor
                                        .withOpacity(0.5)
                                    : null,
                            trackOutlineColor:
                                MaterialStateProperty.all(Colors.black26),
                            thumbColor: MaterialStateProperty.all(
                                Theme.of(context).primaryColor),
                            value: finampSettings?.isMiniPlayer ?? false,
                            onChanged: (value) async {
                              FinampSettingsHelper.setIsMiniPlayer(value);
                              if (value) {
                                await WindowManager.instance
                                    .setTitleBarStyle(TitleBarStyle.hidden);
                                await WindowManager.instance
                                    .setAlwaysOnTop(true);
                                await WindowManager.instance
                                    .setSize(const Size(450, 250));
                                await Navigator.of(context)
                                    .pushNamed(PlayerScreen.routeName);
                              } else {
                                await WindowManager.instance
                                    .setTitleBarStyle(TitleBarStyle.normal);
                                await WindowManager.instance
                                    .setAlwaysOnTop(false);
                                await WindowManager.instance
                                    .setSize(const Size(1200, 800));
                              }
                            },
                          );
                        },
                      ),
                    ListTile(
                      leading: const Padding(
                        padding: EdgeInsets.only(right: 16),
                        child: Icon(Icons.warning),
                      ),
                      title: Text(AppLocalizations.of(context)!.logs),
                      onTap: () =>
                          Navigator.of(context).pushNamed(LogsScreen.routeName),
                    ),
                    ListTile(
                      leading: const Padding(
                        padding: EdgeInsets.only(right: 16),
                        child: Icon(Icons.auto_delete),
                      ),
                      title: Text(AppLocalizations.of(context)!.queuesScreen),
                      onTap: () => Navigator.of(context)
                          .pushNamed(QueueRestoreScreen.routeName),
                    ),
                    ListTile(
                      leading: const Padding(
                        padding: EdgeInsets.only(right: 16),
                        child: Icon(Icons.settings),
                      ),
                      title: Text(AppLocalizations.of(context)!.settings),
                      onTap: () => Navigator.of(context)
                          .pushNamed(SettingsScreen.routeName),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
