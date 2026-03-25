import 'package:finamp/components/global_snackbar.dart';
import 'package:finamp/services/music_player_background_task.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';

class DesktopPlaybackShortcutScope extends StatefulWidget {
  const DesktopPlaybackShortcutScope({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<DesktopPlaybackShortcutScope> createState() =>
      _DesktopPlaybackShortcutScopeState();
}

class _DesktopPlaybackShortcutScopeState
    extends State<DesktopPlaybackShortcutScope> {
  final FocusNode _focusNode =
      FocusNode(debugLabel: "DesktopPlaybackShortcutScope");
  final MusicPlayerBackgroundTask _audioHandler =
      GetIt.instance<MusicPlayerBackgroundTask>();

  bool _shouldHandleShortcut() {
    final primaryFocus = FocusManager.instance.primaryFocus;
    final focusedContext = primaryFocus?.context;

    if (focusedContext == null) {
      return true;
    }

    if (focusedContext.widget is EditableText) {
      return false;
    }

    return focusedContext.findAncestorWidgetOfExactType<EditableText>() == null;
  }

  bool _hasActiveMediaItem() => _audioHandler.mediaItem.valueOrNull != null;

  Future<void> _runTransportAction(Future<void> Function() action) async {
    if (!_shouldHandleShortcut() || !_hasActiveMediaItem()) {
      return;
    }

    try {
      await action();
    } catch (error) {
      GlobalSnackbar.error(error);
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      focusNode: _focusNode,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.space): () {
            _runTransportAction(_audioHandler.togglePlayback);
          },
          const SingleActivator(LogicalKeyboardKey.keyK): () {
            _runTransportAction(_audioHandler.togglePlayback);
          },
          const SingleActivator(LogicalKeyboardKey.mediaPlayPause): () {
            _runTransportAction(_audioHandler.togglePlayback);
          },
          const SingleActivator(
            LogicalKeyboardKey.arrowLeft,
            meta: true,
          ): () {
            _runTransportAction(
              () => _audioHandler.skipToPrevious(forceSkip: true),
            );
          },
          const SingleActivator(
            LogicalKeyboardKey.arrowRight,
            meta: true,
          ): () {
            _runTransportAction(_audioHandler.skipToNext);
          },
          const SingleActivator(
            LogicalKeyboardKey.arrowLeft,
            control: true,
          ): () {
            _runTransportAction(
              () => _audioHandler.skipToPrevious(forceSkip: true),
            );
          },
          const SingleActivator(
            LogicalKeyboardKey.arrowRight,
            control: true,
          ): () {
            _runTransportAction(_audioHandler.skipToNext);
          },
          const SingleActivator(LogicalKeyboardKey.mediaTrackPrevious): () {
            _runTransportAction(
              () => _audioHandler.skipToPrevious(forceSkip: true),
            );
          },
          const SingleActivator(LogicalKeyboardKey.mediaTrackNext): () {
            _runTransportAction(_audioHandler.skipToNext);
          },
        },
        child: widget.child,
      ),
    );
  }
}
