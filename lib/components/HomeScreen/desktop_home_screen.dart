import 'dart:math';

import 'package:collection/collection.dart';
import 'package:finamp/components/MusicScreen/music_screen_tab_view.dart';
import 'package:finamp/components/album_image.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/screens/album_screen.dart';
import 'package:finamp/screens/artist_screen.dart';
import 'package:finamp/screens/playback_history_screen.dart';
import 'package:finamp/screens/player_screen.dart';
import 'package:finamp/services/audio_service_helper.dart';
import 'package:finamp/services/downloads_service.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/finamp_user_helper.dart';
import 'package:finamp/services/generate_subtitle.dart';
import 'package:finamp/services/jellyfin_api_helper.dart';
import 'package:finamp/services/playback_history_service.dart';
import 'package:finamp/services/queue_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:get_it/get_it.dart';

class DesktopHomeScreen extends StatefulWidget {
  const DesktopHomeScreen({
    super.key,
    required this.onOpenTab,
    required this.onOpenLibrary,
    this.refresh,
  });

  final void Function(TabContentType tab) onOpenTab;
  final VoidCallback onOpenLibrary;
  final MusicRefreshCallback? refresh;

  @override
  State<DesktopHomeScreen> createState() => _DesktopHomeScreenState();
}

class _DesktopHomeScreenState extends State<DesktopHomeScreen> {
  final _api = GetIt.instance<JellyfinApiHelper>();
  final _audioServiceHelper = GetIt.instance<AudioServiceHelper>();
  final _downloadsService = GetIt.instance<DownloadsService>();
  final _finampUserHelper = GetIt.instance<FinampUserHelper>();
  final _queueService = GetIt.instance<QueueService>();

  late Future<_DesktopHomeData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
  }

  Future<void> _refresh() async {
    final future = _loadData();
    setState(() {
      _dataFuture = future;
    });
    await future;
  }

  Future<_DesktopHomeData> _loadData() async {
    final currentView = _finampUserHelper.currentUser?.currentView;
    final isOffline = FinampSettingsHelper.finampSettings.isOffline;

    if (isOffline) {
      final albums = await _downloadsService.getAllCollections(
        baseTypeFilter: BaseItemDtoType.album,
        viewFilter: currentView?.id,
      );
      final artists = await _downloadsService.getAllCollections(
        baseTypeFilter: BaseItemDtoType.artist,
        childViewFilter: currentView?.id,
      );
      final playlists = await _downloadsService.getAllCollections(
        baseTypeFilter: BaseItemDtoType.playlist,
      );
      final songs = await _downloadsService.getAllSongs(
        viewFilter: currentView?.id,
        nullableViewFilters: true,
      );

      return _DesktopHomeData(
        isOffline: true,
        latestAlbums:
            albums.map((item) => item.baseItem).nonNulls.take(10).toList(),
        favoriteAlbums: const [],
        favoriteArtists:
            artists.map((item) => item.baseItem).nonNulls.take(10).toList(),
        playlists:
            playlists.map((item) => item.baseItem).nonNulls.take(10).toList(),
        freshTracks:
            songs.map((item) => item.baseItem).nonNulls.take(6).toList(),
      );
    }

    final results = await Future.wait<dynamic>([
      _api.getLatestItems(
        parentItem: currentView,
        includeItemTypes: BaseItemDtoType.album.idString,
        limit: 10,
      ),
      _api.getItems(
        parentItem: currentView,
        includeItemTypes: BaseItemDtoType.album.idString,
        filters: "IsFavorite",
        sortBy: "SortName",
        limit: 10,
      ),
      _api.getItems(
        parentItem: currentView,
        includeItemTypes: BaseItemDtoType.artist.idString,
        filters: "IsFavorite",
        sortBy: "SortName",
        limit: 10,
      ),
      _api.getItems(
        includeItemTypes: BaseItemDtoType.playlist.idString,
        sortBy: "DateCreated,SortName",
        limit: 10,
      ),
      _api.getLatestItems(
        parentItem: currentView,
        includeItemTypes: BaseItemDtoType.song.idString,
        limit: 6,
      ),
    ]);

    return _DesktopHomeData(
      isOffline: false,
      latestAlbums: _cleanItems(results[0]),
      favoriteAlbums: _cleanItems(results[1]),
      favoriteArtists: _cleanItems(results[2]),
      playlists: _cleanItems(results[3]),
      freshTracks: _cleanItems(results[4]),
    );
  }

  List<BaseItemDto> _cleanItems(dynamic items) {
    return (items as List<BaseItemDto>? ?? [])
        .where((item) => item.id.isNotEmpty)
        .toList();
  }

  Future<void> _playFreshTrack(List<BaseItemDto> tracks, int index) async {
    if (tracks.isEmpty) {
      return;
    }

    await _queueService.startPlayback(
      items: tracks,
      startingIndex: index,
      source: QueueItemSource(
        type: QueueItemSourceType.unknown,
        name: const QueueItemSourceName(
          type: QueueItemSourceNameType.preTranslated,
          pretranslatedName: "Fresh tracks",
        ),
        id: "desktop-home-fresh-tracks",
      ),
    );
  }

  void _openItem(BaseItemDto item) {
    if (item.type == "MusicArtist" || item.type == "MusicGenre") {
      Navigator.of(context).pushNamed(ArtistScreen.routeName, arguments: item);
    } else {
      Navigator.of(context).pushNamed(AlbumScreen.routeName, arguments: item);
    }
  }

  @override
  Widget build(BuildContext context) {
    widget.refresh?.callback = _refresh;

    return FutureBuilder<_DesktopHomeData>(
      future: _dataFuture,
      builder: (context, snapshot) {
        final data = snapshot.data;

        return CustomScrollView(
          physics: const ClampingScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
              sliver: SliverToBoxAdapter(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final stacked = constraints.maxWidth < 1080;
                    if (stacked) {
                      return Column(
                        children: [
                          _HomeOverviewCard(
                            featuredItem: data?.heroItem,
                            onOpenLibrary: widget.onOpenLibrary,
                            onOpenSpotlightItem: _openItem,
                            onOpenTab: widget.onOpenTab,
                            onOpenPlayer: () => Navigator.of(context)
                                .pushNamed(PlayerScreen.routeName),
                            onOpenHistory: () => Navigator.of(context)
                                .pushNamed(PlaybackHistoryScreen.routeName),
                            onShuffleAll: () async {
                              await _audioServiceHelper.shuffleAll(
                                FinampSettingsHelper
                                    .finampSettings.onlyShowFavourite,
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          _QueueSnapshotCard(
                            onOpenPlayer: () {
                              Navigator.of(context)
                                  .pushNamed(PlayerScreen.routeName);
                            },
                          ),
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 6,
                          child: _HomeOverviewCard(
                            featuredItem: data?.heroItem,
                            onOpenLibrary: widget.onOpenLibrary,
                            onOpenSpotlightItem: _openItem,
                            onOpenTab: widget.onOpenTab,
                            onOpenPlayer: () => Navigator.of(context)
                                .pushNamed(PlayerScreen.routeName),
                            onOpenHistory: () => Navigator.of(context)
                                .pushNamed(PlaybackHistoryScreen.routeName),
                            onShuffleAll: () async {
                              await _audioServiceHelper.shuffleAll(
                                FinampSettingsHelper
                                    .finampSettings.onlyShowFavourite,
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 4,
                          child: _QueueSnapshotCard(
                            onOpenPlayer: () {
                              Navigator.of(context)
                                  .pushNamed(PlayerScreen.routeName);
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            if (snapshot.connectionState == ConnectionState.waiting &&
                data == null)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (snapshot.hasError)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(28, 24, 28, 32),
                sliver: SliverToBoxAdapter(
                  child: _ErrorPanel(onRetry: _refresh),
                ),
              )
            else ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
                sliver: SliverToBoxAdapter(
                  child: _FreshTracksShelf(
                    tracks: data!.freshTracks,
                    title:
                        data.isOffline ? "Downloaded tracks" : "Fresh tracks",
                    subtitle:
                        "Short picks you can start immediately without leaving home.",
                    onPlayTrack: _playFreshTrack,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(28, 28, 28, 0),
                sliver: SliverToBoxAdapter(
                  child: _HomeShelf(
                    title: data.isOffline
                        ? "Downloaded albums"
                        : "Recently added albums",
                    subtitle: "A fast way back into your library.",
                    emptyText: "No albums available yet.",
                    icon: TablerIcons.disc,
                    items: data.latestAlbums,
                    onOpenTab: () => widget.onOpenTab(TabContentType.albums),
                    onOpenItem: _openItem,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(28, 28, 28, 0),
                sliver: SliverToBoxAdapter(
                  child: _HomeShelf(
                    title: data.isOffline
                        ? "Downloaded artists"
                        : "Favorite artists",
                    subtitle:
                        "Jump straight into the people you keep coming back to.",
                    emptyText: data.isOffline
                        ? "No downloaded artists yet."
                        : "Mark artists as favorites to see them here.",
                    icon: TablerIcons.microphone_2,
                    items: data.favoriteArtists,
                    onOpenTab: () => widget.onOpenTab(TabContentType.artists),
                    onOpenItem: _openItem,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(28, 28, 28, 0),
                sliver: SliverToBoxAdapter(
                  child: _HomeShelf(
                    title:
                        data.isOffline ? "Downloaded playlists" : "Playlists",
                    subtitle:
                        "Personal mixes, editorials, and long-tail queues.",
                    emptyText: "No playlists available.",
                    icon: TablerIcons.playlist,
                    items: data.playlists,
                    onOpenTab: () =>
                        widget.onOpenTab(TabContentType.playlists),
                    onOpenItem: _openItem,
                  ),
                ),
              ),
              if (data.favoriteAlbums.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(28, 28, 28, 0),
                  sliver: SliverToBoxAdapter(
                    child: _HomeShelf(
                      title: "Favorite albums",
                      subtitle:
                          "A tighter shelf for the records you keep close.",
                      emptyText: "No favorite albums yet.",
                      icon: TablerIcons.heart,
                      items: data.favoriteAlbums,
                      onOpenTab: () =>
                          widget.onOpenTab(TabContentType.albums),
                      onOpenItem: _openItem,
                    ),
                  ),
                ),
              const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
            ],
          ],
        );
      },
    );
  }
}

class _DesktopHomeData {
  const _DesktopHomeData({
    required this.isOffline,
    required this.latestAlbums,
    required this.favoriteAlbums,
    required this.favoriteArtists,
    required this.playlists,
    required this.freshTracks,
  });

  final bool isOffline;
  final List<BaseItemDto> latestAlbums;
  final List<BaseItemDto> favoriteAlbums;
  final List<BaseItemDto> favoriteArtists;
  final List<BaseItemDto> playlists;
  final List<BaseItemDto> freshTracks;

  BaseItemDto? get heroItem => [
        ...latestAlbums,
        ...favoriteAlbums,
        ...playlists,
        ...favoriteArtists,
      ].firstOrNull;
}

class _HomeOverviewCard extends StatelessWidget {
  const _HomeOverviewCard({
    required this.featuredItem,
    required this.onOpenLibrary,
    required this.onOpenSpotlightItem,
    required this.onOpenTab,
    required this.onOpenPlayer,
    required this.onOpenHistory,
    required this.onShuffleAll,
  });

  final BaseItemDto? featuredItem;
  final VoidCallback onOpenLibrary;
  final void Function(BaseItemDto item) onOpenSpotlightItem;
  final void Function(TabContentType tab) onOpenTab;
  final VoidCallback onOpenPlayer;
  final VoidCallback onOpenHistory;
  final Future<void> Function() onShuffleAll;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentView =
        GetIt.instance<FinampUserHelper>().currentUser?.currentView?.name ??
            AppLocalizations.of(context)!.music;
    final isOffline = FinampSettingsHelper.finampSettings.isOffline;
    final queueService = GetIt.instance<QueueService>();

    return StreamBuilder<FinampQueueInfo?>(
      stream: queueService.getQueueStream(),
      initialData: queueService.getQueue(),
      builder: (context, snapshot) {
        final queue = snapshot.data;
        final currentTrack = queue?.currentTrack;
        final spotlightItem = currentTrack?.baseItem ?? featuredItem;
        final headline = currentTrack != null
            ? currentTrack.item.title
            : "Home for $currentView";
        final subhead = currentTrack != null
            ? currentTrack.item.artist ?? currentView
            : isOffline
                ? "Offline mode is active. Everything here is coming from downloaded music."
                : "Jump between new albums, playlists, artists, and your current queue without leaving this screen.";
        final queueLabel = queue?.currentTrack != null
            ? "${queue?.trackCount ?? 0} tracks in queue"
            : "Queue is idle";
        final compactSubtitle = spotlightItem == null
            ? "No spotlight item yet"
            : generateSubtitle(spotlightItem, null, context) ??
                spotlightItem.type ??
                "";
        return Container(
          constraints: const BoxConstraints(minHeight: 196),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            color: colorScheme.surfaceContainerLow,
            border: Border.all(
              color: colorScheme.outlineVariant.withOpacity(0.35),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final stacked = constraints.maxWidth < 840;
                final summary = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _OverviewPill(
                          icon: TablerIcons.home_2,
                          label: "Home",
                        ),
                        _OverviewPill(
                          icon: isOffline
                              ? TablerIcons.cloud_off
                              : TablerIcons.server,
                          label: currentView,
                        ),
                        _OverviewPill(
                          icon: TablerIcons.player_track_next,
                          label: queueLabel,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      headline,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: Text(
                        subhead,
                        maxLines: stacked ? 3 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.color
                                  ?.withOpacity(0.76),
                              height: 1.35,
                            ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        FilledButton.icon(
                          onPressed: currentTrack != null
                              ? onOpenPlayer
                              : onOpenLibrary,
                          icon: const Icon(TablerIcons.player_play_filled,
                              size: 16),
                          label: Text(currentTrack != null
                              ? "Open player"
                              : "Open library"),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: () async => onShuffleAll(),
                          icon:
                              const Icon(TablerIcons.arrows_shuffle, size: 16),
                          label: const Text("Shuffle all"),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => onOpenTab(TabContentType.albums),
                          icon: const Icon(TablerIcons.disc, size: 16),
                          label: const Text("Albums"),
                        ),
                        TextButton.icon(
                          onPressed: onOpenHistory,
                          icon: const Icon(TablerIcons.clock, size: 16),
                          label: const Text("History"),
                        ),
                      ],
                    ),
                  ],
                );

                final spotlight = _CompactSpotlightCard(
                  item: spotlightItem,
                  title: currentTrack != null ? "Now playing" : "Spotlight",
                  subtitle: compactSubtitle,
                  onTap: currentTrack != null
                      ? onOpenPlayer
                      : spotlightItem != null
                          ? () => onOpenSpotlightItem(spotlightItem)
                          : null,
                );

                if (stacked) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      summary,
                      const SizedBox(height: 16),
                      spotlight,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 7, child: summary),
                    const SizedBox(width: 16),
                    SizedBox(
                        width: min(320, constraints.maxWidth * 0.32),
                        child: spotlight),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _CompactSpotlightCard extends StatelessWidget {
  const _CompactSpotlightCard({
    required this.item,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final BaseItemDto? item;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final child = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(TablerIcons.sparkles, size: 16, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              SizedBox(
                width: 78,
                child: AlbumImage(
                  item: item,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item?.name ?? "No spotlight item yet",
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.color
                                ?.withOpacity(0.72),
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                TablerIcons.arrow_up_right,
                size: 18,
                color: onTap != null
                    ? colorScheme.primary
                    : colorScheme.outline.withOpacity(0.7),
              ),
            ],
          ),
        ],
      ),
    );

    final surface = DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.55),
        borderRadius: BorderRadius.circular(22),
      ),
      child: child,
    );

    if (onTap == null) {
      return surface;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: surface,
      ),
    );
  }
}

class _QueueSnapshotCard extends StatelessWidget {
  const _QueueSnapshotCard({
    required this.onOpenPlayer,
  });

  final VoidCallback onOpenPlayer;

  @override
  Widget build(BuildContext context) {
    final queueService = GetIt.instance<QueueService>();
    final playbackHistoryService = GetIt.instance<PlaybackHistoryService>();

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(TablerIcons.wave_square,
                  size: 20, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 10),
              Text(
                "Queue snapshot",
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              StreamBuilder<FinampQueueInfo?>(
                stream: queueService.getQueueStream(),
                initialData: queueService.getQueue(),
                builder: (context, snapshot) => TextButton(
                  onPressed:
                      snapshot.data?.currentTrack != null ? onOpenPlayer : null,
                  child: const Text("Open player"),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          StreamBuilder<FinampQueueInfo?>(
            stream: queueService.getQueueStream(),
            initialData: queueService.getQueue(),
            builder: (context, snapshot) {
              final queue = snapshot.data;
              final currentTrack = queue?.currentTrack;

              if (currentTrack == null) {
                return Text(
                  "Nothing is queued right now. Start from a shelf below or shuffle your library.",
                  style: Theme.of(context).textTheme.bodyLarge,
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 88,
                        child: AlbumImage(
                          item: currentTrack.baseItem,
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentTrack.item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              currentTrack.item.artist ?? "Unknown artist",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.color
                                        ?.withOpacity(0.74),
                                  ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                _StatPill(
                                    label: "${queue?.trackCount ?? 0} tracks"),
                                _StatPill(
                                    label: _formatDuration(
                                        queue?.remainingDuration ??
                                            Duration.zero)),
                                _StatPill(
                                    label:
                                        queue?.source.name.pretranslatedName ??
                                            queue?.source.name
                                                .getLocalized(context) ??
                                            "Queue"),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  StreamBuilder<List<FinampHistoryItem>>(
                    stream: playbackHistoryService.historyStream,
                    initialData: playbackHistoryService.history
                        .cast<FinampHistoryItem>(),
                    builder: (context, historySnapshot) {
                      final recent =
                          (historySnapshot.data ?? const <FinampHistoryItem>[])
                              .reversed
                              .take(3)
                              .toList();
                      if (recent.isEmpty) {
                        return const SizedBox.shrink();
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Recently played",
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 10),
                          ...recent.map(
                            (entry) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                "${entry.item.item.title}  •  ${entry.item.item.artist ?? "Unknown artist"}",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FreshTracksShelf extends StatelessWidget {
  const _FreshTracksShelf({
    required this.tracks,
    required this.title,
    required this.subtitle,
    required this.onPlayTrack,
  });

  final List<BaseItemDto> tracks;
  final String title;
  final String subtitle;
  final Future<void> Function(List<BaseItemDto> tracks, int index) onPlayTrack;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(TablerIcons.music,
                  size: 20, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 10),
              Text(
                title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed:
                    tracks.isEmpty ? null : () async => onPlayTrack(tracks, 0),
                icon: const Icon(TablerIcons.player_play, size: 16),
                label: const Text("Play"),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.color
                      ?.withOpacity(0.72),
                ),
          ),
          const SizedBox(height: 16),
          if (tracks.isEmpty)
            Text(
              "This section will fill as your library starts surfacing tracks.",
              style: Theme.of(context).textTheme.bodyLarge,
            )
          else
            SizedBox(
              height: 98,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: tracks.length,
                itemBuilder: (context, index) => SizedBox(
                  width: 260,
                  child: _FreshTrackTile(
                    track: tracks[index],
                    onTap: () async => onPlayTrack(tracks, index),
                  ),
                ),
                separatorBuilder: (context, index) => const SizedBox(width: 12),
              ),
            ),
        ],
      ),
    );
  }
}

class _HomeShelf extends StatelessWidget {
  const _HomeShelf({
    required this.title,
    required this.subtitle,
    required this.emptyText,
    required this.icon,
    required this.items,
    required this.onOpenTab,
    required this.onOpenItem,
  });

  final String title;
  final String subtitle;
  final String emptyText;
  final IconData icon;
  final List<BaseItemDto> items;
  final VoidCallback onOpenTab;
  final void Function(BaseItemDto item) onOpenItem;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon,
                          size: 20,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 10),
                      Text(
                        title,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.color
                              ?.withOpacity(0.72),
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            TextButton.icon(
              onPressed: onOpenTab,
              icon: const Icon(TablerIcons.arrow_right, size: 18),
              label: const Text("Show all"),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (items.isEmpty)
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(22),
            ),
            child:
                Text(emptyText, style: Theme.of(context).textTheme.bodyLarge),
          )
        else
          SizedBox(
            height: 255,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              itemBuilder: (context, index) {
                return SizedBox(
                  width: 170,
                  child: _HomeItemTile(
                    item: items[index],
                    onTap: () => onOpenItem(items[index]),
                  ),
                );
              },
              separatorBuilder: (context, index) => const SizedBox(width: 14),
            ),
          ),
      ],
    );
  }
}

class _HomeItemTile extends StatefulWidget {
  const _HomeItemTile({
    required this.item,
    required this.onTap,
  });

  final BaseItemDto item;
  final VoidCallback onTap;

  @override
  State<_HomeItemTile> createState() => _HomeItemTileState();
}

class _HomeItemTileState extends State<_HomeItemTile> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final subtitle = generateSubtitle(widget.item, null, context);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        transform: Matrix4.translationValues(0, _hovering ? -4 : 0, 0),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(_hovering ? 0.16 : 0.08),
                        blurRadius: _hovering ? 24 : 18,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: AlbumImage(
                    item: widget.item,
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.item.name ?? "Unknown item",
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.color
                              ?.withOpacity(0.72),
                        ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FreshTrackTile extends StatelessWidget {
  const _FreshTrackTile({
    required this.track,
    required this.onTap,
  });

  final BaseItemDto track;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withOpacity(0.55),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                SizedBox(
                  width: 64,
                  child: AlbumImage(
                    item: track,
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track.name ?? "Unknown track",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        track.albumArtist ??
                            track.artists?.join(", ") ??
                            "Unknown artist",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.color
                                  ?.withOpacity(0.72),
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primaryContainer
                        .withOpacity(0.9),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    TablerIcons.player_play_filled,
                    size: 16,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OverviewPill extends StatelessWidget {
  const _OverviewPill({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.48),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 8),
          Text(label, style: Theme.of(context).textTheme.labelLarge),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelMedium
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({
    required this.onRetry,
  });

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Icon(TablerIcons.alert_triangle,
              color: Theme.of(context).colorScheme.onErrorContainer),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              "Home content could not be loaded right now.",
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
            ),
          ),
          const SizedBox(width: 14),
          FilledButton(
            onPressed: () async => onRetry(),
            child: const Text("Retry"),
          ),
        ],
      ),
    );
  }
}

String _formatDuration(Duration duration) {
  if (duration <= Duration.zero) {
    return "0 min";
  }

  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours == 0) {
    return "${max(duration.inMinutes, 1)} min";
  }
  if (minutes == 0) {
    return "$hours hr";
  }
  return "$hours hr $minutes min";
}
