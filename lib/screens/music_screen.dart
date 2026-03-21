import 'dart:io';

import 'package:finamp/services/queue_service.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:hive/hive.dart';
import 'package:logging/logging.dart';

import '../components/HomeScreen/desktop_home_screen.dart';
import '../components/MusicScreen/music_screen_drawer.dart';
import '../components/MusicScreen/music_screen_tab_view.dart';
import '../components/MusicScreen/sort_by_menu_button.dart';
import '../components/MusicScreen/sort_order_button.dart';
import '../components/global_snackbar.dart';
import '../components/now_playing_bar.dart';
import '../models/finamp_models.dart';
import '../services/audio_service_helper.dart';
import '../services/finamp_settings_helper.dart';
import '../services/finamp_user_helper.dart';
import '../services/jellyfin_api_helper.dart';

class MusicScreen extends ConsumerStatefulWidget {
  const MusicScreen({super.key});

  static const routeName = "/music";

  @override
  ConsumerState<MusicScreen> createState() => _MusicScreenState();
}

class _MusicScreenState extends ConsumerState<MusicScreen>
    with TickerProviderStateMixin {
  bool isSearching = false;
  bool _showShuffleFab = false;
  bool _desktopSidebarExpanded = false;
  MusicScreenSidebarSection _desktopSection = MusicScreenSidebarSection.home;
  TextEditingController textEditingController = TextEditingController();
  String? searchQuery;
  final _musicScreenLogger = Logger("MusicScreen");
  final Map<TabContentType, MusicRefreshCallback> refreshMap = {};
  final _homeRefresh = MusicRefreshCallback();
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  TabController? _tabController;

  final _audioServiceHelper = GetIt.instance<AudioServiceHelper>();
  final _finampUserHelper = GetIt.instance<FinampUserHelper>();
  final _jellyfinApiHelper = GetIt.instance<JellyfinApiHelper>();
  final _queueService = GetIt.instance<QueueService>();

  void _stopSearching() {
    setState(() {
      textEditingController.clear();
      searchQuery = null;
      isSearching = false;
    });
  }

  void _tabIndexCallback() {
    if (_desktopSection != MusicScreenSidebarSection.library) {
      if (_showShuffleFab) {
        setState(() {
          _showShuffleFab = false;
        });
      }
      return;
    }

    var tabKey = FinampSettingsHelper.finampSettings.showTabs.entries
        .where((element) => element.value)
        .elementAt(_tabController!.index)
        .key;
    if (_tabController != null &&
        (tabKey == TabContentType.songs ||
            tabKey == TabContentType.artists ||
            tabKey == TabContentType.albums)) {
      setState(() {
        _showShuffleFab = true;
      });
    } else {
      if (_showShuffleFab) {
        setState(() {
          _showShuffleFab = false;
        });
      }
    }
  }

  void _setDesktopSection(MusicScreenSidebarSection section) {
    if (_desktopSection == section) {
      return;
    }

    setState(() {
      _desktopSection = section;
      if (section != MusicScreenSidebarSection.library) {
        textEditingController.clear();
        searchQuery = null;
        isSearching = false;
      }
    });
  }

  void _openDesktopTab(List<TabContentType> sortedTabs, TabContentType tab) {
    final tabIndex = sortedTabs.indexOf(tab);

    setState(() {
      _desktopSection = MusicScreenSidebarSection.library;
      if (tabIndex == -1) {
        isSearching = false;
        searchQuery = null;
      }
    });

    if (tabIndex != -1) {
      _tabController?.animateTo(tabIndex);
    }
  }

  void _buildTabController() {
    _tabController?.removeListener(_tabIndexCallback);

    _tabController = TabController(
      length: FinampSettingsHelper.finampSettings.showTabs.entries
          .where((element) => element.value)
          .length,
      vsync: this,
      initialIndex: ModalRoute.of(context)?.settings.arguments as int? ?? 0,
    );

    _tabController!.addListener(_tabIndexCallback);
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  FloatingActionButton? getFloatingActionButton(
      List<TabContentType> sortedTabs) {
    // Show the floating action button only on the albums, artists, generes and songs tab.
    if (_tabController!.index == sortedTabs.indexOf(TabContentType.songs)) {
      return FloatingActionButton(
        tooltip: AppLocalizations.of(context)!.shuffleAll,
        onPressed: () async {
          try {
            await _audioServiceHelper.shuffleAll(
                FinampSettingsHelper.finampSettings.onlyShowFavourite);
          } catch (e) {
            GlobalSnackbar.error(e);
          }
        },
        child: const Icon(Icons.shuffle),
      );
    } else if (_tabController!.index ==
        sortedTabs.indexOf(TabContentType.artists)) {
      return FloatingActionButton(
          tooltip: AppLocalizations.of(context)!.startMix,
          onPressed: () async {
            try {
              if (_jellyfinApiHelper.selectedMixArtists.isEmpty) {
                GlobalSnackbar.message((scaffold) =>
                    AppLocalizations.of(context)!.startMixNoSongsArtist);
              } else {
                await _audioServiceHelper.startInstantMixForArtists(
                    _jellyfinApiHelper.selectedMixArtists);
                _jellyfinApiHelper.clearArtistMixBuilderList();
              }
            } catch (e) {
              GlobalSnackbar.error(e);
            }
          },
          child: const Icon(Icons.explore));
    } else if (_tabController!.index ==
        sortedTabs.indexOf(TabContentType.albums)) {
      return FloatingActionButton(
          tooltip: AppLocalizations.of(context)!.startMix,
          onPressed: () async {
            try {
              if (_jellyfinApiHelper.selectedMixAlbums.isEmpty) {
                GlobalSnackbar.message((scaffold) =>
                    AppLocalizations.of(context)!.startMixNoSongsAlbum);
              } else {
                await _audioServiceHelper.startInstantMixForAlbums(
                    _jellyfinApiHelper.selectedMixAlbums);
              }
            } catch (e) {
              GlobalSnackbar.error(e);
            }
          },
          child: const Icon(Icons.explore));
    } else if (_tabController!.index ==
        sortedTabs.indexOf(TabContentType.genres)) {
      return FloatingActionButton(
          tooltip: AppLocalizations.of(context)!.startMix,
          onPressed: () async {
            try {
              if (_jellyfinApiHelper.selectedMixGenres.isEmpty) {
                GlobalSnackbar.message((scaffold) =>
                    AppLocalizations.of(context)!.startMixNoSongsGenre);
              } else {
                await _audioServiceHelper.startInstantMixForGenres(
                    _jellyfinApiHelper.selectedMixGenres);
              }
            } catch (e) {
              GlobalSnackbar.error(e);
            }
          },
          child: const Icon(Icons.explore));
    } else {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    _queueService
        .performInitialQueueLoad()
        .catchError((x) => GlobalSnackbar.error(x));
    if (_tabController == null) {
      _buildTabController();
    }
    ref.watch(FinampUserHelper.finampCurrentUserProvider);
    return ValueListenableBuilder<Box<FinampSettings>>(
      valueListenable: FinampSettingsHelper.finampSettingsListener,
      builder: (context, value, _) {
        final finampSettings = value.get("FinampSettings");

        // Get the tabs from the user's tab order, and filter them to only
        // include enabled tabs
        final sortedTabs = finampSettings!.tabOrder.where(
            (e) => FinampSettingsHelper.finampSettings.showTabs[e] ?? false);
        refreshMap[sortedTabs.elementAt(_tabController!.index)] =
            MusicRefreshCallback();

        if (sortedTabs.length != _tabController?.length) {
          _musicScreenLogger.info(
              "Rebuilding MusicScreen tab controller (${sortedTabs.length} != ${_tabController?.length})");
          _buildTabController();
        }

        return PopScope(
          canPop: !isSearching,
          onPopInvoked: (popped) {
            if (isSearching) {
              _stopSearching();
            }
          },
          child: Builder(
            builder: (context) {
              final isDesktopPlatform = !Platform.isIOS && !Platform.isAndroid;
              final canUseDesktopSidebar =
                  isDesktopPlatform && MediaQuery.sizeOf(context).width >= 1180;
              final showDesktopSidebar =
                  canUseDesktopSidebar && _desktopSidebarExpanded;
              final effectiveSection = isDesktopPlatform
                  ? _desktopSection
                  : MusicScreenSidebarSection.library;
              final selectedTab = sortedTabs.elementAt(_tabController!.index);
              final showLibraryTools =
                  effectiveSection == MusicScreenSidebarSection.library;
              final appBarTitle =
                  effectiveSection == MusicScreenSidebarSection.home
                      ? "Home"
                      : _finampUserHelper.currentUser?.currentView?.name ??
                          AppLocalizations.of(context)!.music;
              void handleDrawerSectionSelected(
                  MusicScreenSidebarSection section) {
                _setDesktopSection(section);
                if (!showDesktopSidebar && Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
              }

              return Scaffold(
                key: _scaffoldKey,
                extendBody: true,
                appBar: AppBar(
                  automaticallyImplyLeading: !isDesktopPlatform,
                  titleSpacing:
                      0, // The surrounding iconButtons provide enough padding
                  title: isSearching
                      ? TextField(
                          controller: textEditingController,
                          autofocus: true,
                          onChanged: (value) => setState(() {
                            searchQuery = value;
                          }),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: MaterialLocalizations.of(context)
                                .searchFieldLabel,
                          ),
                        )
                      : Text(appBarTitle),
                  bottom: showLibraryTools
                      ? TabBar(
                          controller: _tabController,
                          tabs: sortedTabs
                              .map((tabType) => Tab(
                                    text: tabType
                                        .toLocalisedString(context)
                                        .toUpperCase(),
                                  ))
                              .toList(),
                          isScrollable: true,
                          tabAlignment: TabAlignment.start,
                        )
                      : null,
                  leading: isSearching
                      ? BackButton(
                          onPressed: () => _stopSearching(),
                        )
                      : isDesktopPlatform
                          ? IconButton(
                              icon: Icon(
                                canUseDesktopSidebar
                                    ? (_desktopSidebarExpanded
                                        ? Icons.menu_open
                                        : Icons.menu)
                                    : Icons.menu,
                              ),
                              tooltip: canUseDesktopSidebar
                                  ? (_desktopSidebarExpanded
                                      ? "Hide sidebar"
                                      : "Show sidebar")
                                  : MaterialLocalizations.of(context)
                                      .openAppDrawerTooltip,
                              onPressed: () {
                                if (canUseDesktopSidebar) {
                                  setState(() {
                                    _desktopSidebarExpanded =
                                        !_desktopSidebarExpanded;
                                  });
                                } else {
                                  _scaffoldKey.currentState?.openDrawer();
                                }
                              },
                            )
                          : null,
                  actions: isSearching
                      ? [
                          IconButton(
                            icon: Icon(
                              Icons.cancel,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            onPressed: () => setState(() {
                              textEditingController.clear();
                              searchQuery = null;
                            }),
                            tooltip: AppLocalizations.of(context)!.clear,
                          )
                        ]
                      : [
                          if (!Platform.isIOS && !Platform.isAndroid)
                            IconButton(
                                icon: const Icon(Icons.refresh),
                                onPressed: () {
                                  if (effectiveSection ==
                                      MusicScreenSidebarSection.home) {
                                    _homeRefresh();
                                  } else {
                                    refreshMap[selectedTab]!();
                                  }
                                }),
                          if (showLibraryTools)
                            SortOrderButton(
                              selectedTab,
                            ),
                          if (showLibraryTools)
                            SortByMenuButton(
                              selectedTab,
                            ),
                          if (showLibraryTools && finampSettings.isOffline)
                            IconButton(
                              icon: finampSettings.onlyShowFullyDownloaded
                                  ? const Icon(Icons.download)
                                  : const Icon(Icons.download_outlined),
                              onPressed: finampSettings.isOffline
                                  ? () => FinampSettingsHelper
                                      .setOnlyShowFullyDownloaded(
                                          !finampSettings
                                              .onlyShowFullyDownloaded)
                                  : null,
                              tooltip: AppLocalizations.of(context)!
                                  .onlyShowFullyDownloaded,
                            ),
                          if (showLibraryTools && !finampSettings.isOffline)
                            IconButton(
                              icon: finampSettings.onlyShowFavourite
                                  ? const Icon(Icons.favorite)
                                  : const Icon(Icons.favorite_outline),
                              onPressed: finampSettings.isOffline
                                  ? null
                                  : () =>
                                      FinampSettingsHelper.setOnlyShowFavourite(
                                          !finampSettings.onlyShowFavourite),
                              tooltip: AppLocalizations.of(context)!.favourites,
                            ),
                          IconButton(
                            icon: const Icon(Icons.search),
                            onPressed: () => setState(() {
                              if (effectiveSection ==
                                  MusicScreenSidebarSection.home) {
                                _desktopSection =
                                    MusicScreenSidebarSection.library;
                              }
                              isSearching = true;
                            }),
                            tooltip: MaterialLocalizations.of(context)
                                .searchFieldLabel,
                          ),
                        ],
                ),
                bottomNavigationBar: const NowPlayingBar(),
                drawer: isDesktopPlatform && canUseDesktopSidebar
                    ? null
                    : MusicScreenDrawer(
                        selectedSection:
                            isDesktopPlatform ? effectiveSection : null,
                        onSectionSelected: isDesktopPlatform
                            ? handleDrawerSectionSelected
                            : null,
                      ),
                floatingActionButton: Padding(
                  padding: EdgeInsets.only(
                      right:
                          FinampSettingsHelper.finampSettings.showFastScroller
                              ? 24.0
                              : 8.0),
                  child: showLibraryTools
                      ? getFloatingActionButton(sortedTabs.toList())
                      : null,
                ),
                body: Row(
                  children: [
                    if (showDesktopSidebar) ...[
                      SizedBox(
                        width: 280,
                        child: MusicScreenDrawer(
                          sidebar: true,
                          selectedSection: effectiveSection,
                          onSectionSelected: _setDesktopSection,
                        ),
                      ),
                      VerticalDivider(
                        width: 1,
                        thickness: 1,
                        color: Theme.of(context).dividerColor.withOpacity(0.45),
                      ),
                    ],
                    Expanded(
                      child: isDesktopPlatform &&
                              effectiveSection == MusicScreenSidebarSection.home
                          ? DesktopHomeScreen(
                              refresh: _homeRefresh,
                              onOpenLibrary: () => _setDesktopSection(
                                MusicScreenSidebarSection.library,
                              ),
                              onOpenTab: (tab) =>
                                  _openDesktopTab(sortedTabs.toList(), tab),
                            )
                          : TabBarView(
                              controller: _tabController,
                              physics: FinampSettingsHelper
                                      .finampSettings.disableGesture
                                  ? const NeverScrollableScrollPhysics()
                                  : const AlwaysScrollableScrollPhysics(),
                              dragStartBehavior: DragStartBehavior.down,
                              children: sortedTabs
                                  .map((tabType) => MusicScreenTabView(
                                        tabContentType: tabType,
                                        searchTerm: searchQuery,
                                        view: _finampUserHelper
                                            .currentUser?.currentView,
                                        refresh: refreshMap[tabType],
                                      ))
                                  .toList(),
                            ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
