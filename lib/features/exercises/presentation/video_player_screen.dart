import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import 'package:gsu_fit/core/l10n/l10n.dart';
import 'package:gsu_fit/core/providers.dart';
import 'package:gsu_fit/core/utils/dates.dart';
import 'package:gsu_fit/core/widgets/common.dart';
import 'package:gsu_fit/features/exercises/presentation/exercise_media.dart';

/// Plays an exercise video from an http(s) URL, a local file path or an
/// "asset:" path. Network videos are downloaded once into the media cache
/// and then played from disk, so watching again costs no data and works
/// offline.
class VideoPlayerScreen extends ConsumerStatefulWidget {
  const VideoPlayerScreen({super.key, required this.source, required this.title});

  final String source;
  final String title;

  @override
  ConsumerState<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends ConsumerState<VideoPlayerScreen> {
  VideoPlayerController? _controller;
  Object? _error;
  double? _progress;
  bool _downloading = false;

  static const List<double> speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  @override
  void initState() {
    super.initState();
    _open();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _retry() {
    setState(() {
      _error = null;
      _progress = null;
    });
    _open();
  }

  /// Runs from initState, so it must not call setState before its first
  /// await; [_retry] schedules the rebuild for later attempts.
  Future<void> _open() async {
    try {
      final source = widget.source.trim();
      final VideoPlayerController controller;
      if (source.startsWith('asset:')) {
        controller = VideoPlayerController.asset(source.substring(6));
      } else if (kIsWeb) {
        // The browser streams and caches the video itself.
        controller = VideoPlayerController.networkUrl(Uri.parse(source));
      } else if (source.startsWith('http://') || source.startsWith('https://')) {
        _downloading = true;
        final file = await ref.read(mediaCacheProvider).get(
              source,
              onProgress: (value) {
                if (mounted) setState(() => _progress = value);
              },
            );
        controller = VideoPlayerController.file(file);
      } else {
        controller = VideoPlayerController.file(File(source.replaceFirst('file://', '')));
      }
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _downloading = false;
      });
      await controller.play();
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
          _downloading = false;
        });
      }
    }
  }

  Future<void> _fullscreen() async {
    final controller = _controller;
    if (controller == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => _FullscreenVideo(controller: controller)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final controller = _controller;
    final error = _error;
    Widget body;
    if (error != null) {
      body = ErrorView(
        message: error is PlatformException ? l.videoPlayFailed : mediaErrorText(l, error),
        onRetry: _retry,
      );
    } else if (controller == null) {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(value: _progress),
            const SizedBox(height: 16),
            Text(_downloading ? l.videoDownloading : l.videoLoading),
          ],
        ),
      );
    } else {
      body = ListView(
        children: [
          AspectRatio(
            aspectRatio: controller.value.aspectRatio == 0 ? 16 / 9 : controller.value.aspectRatio,
            child: VideoPlayer(controller),
          ),
          VideoControls(controller: controller, onFullscreen: _fullscreen),
          if (!kIsWeb)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l.videoCachedNote, style: Theme.of(context).textTheme.bodySmall),
            ),
        ],
      );
    }
    return Scaffold(appBar: AppBar(title: Text(widget.title)), body: body);
  }
}

/// Play/pause, seek bar, replay, loop, speed and fullscreen.
class VideoControls extends StatelessWidget {
  const VideoControls({super.key, required this.controller, this.onFullscreen, this.dark = false});

  final VideoPlayerController controller;
  final VoidCallback? onFullscreen;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final foreground = dark ? Colors.white : scheme.onSurface;
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final ended = value.duration > Duration.zero &&
            value.position >= value.duration &&
            !value.isPlaying;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              VideoProgressIndicator(
                controller,
                allowScrubbing: true,
                padding: const EdgeInsets.symmetric(vertical: 12),
                colors: VideoProgressColors(playedColor: scheme.primary),
              ),
              Row(
                children: [
                  IconButton(
                    color: foreground,
                    iconSize: 36,
                    tooltip: ended
                        ? l.videoReplay
                        : value.isPlaying
                            ? l.videoPause
                            : l.videoPlay,
                    icon: Icon(
                      ended
                          ? Icons.replay
                          : value.isPlaying
                              ? Icons.pause
                              : Icons.play_arrow,
                    ),
                    onPressed: () async {
                      if (ended) {
                        await controller.seekTo(Duration.zero);
                        await controller.play();
                      } else if (value.isPlaying) {
                        await controller.pause();
                      } else {
                        await controller.play();
                      }
                    },
                  ),
                  Text(
                    '${formatClock(value.position)} / ${formatClock(value.duration)}',
                    style: TextStyle(color: foreground),
                  ),
                  const Spacer(),
                  IconButton(
                    color: foreground,
                    tooltip: l.videoLoop,
                    isSelected: value.isLooping,
                    icon: const Icon(Icons.repeat),
                    selectedIcon: Icon(Icons.repeat_on, color: scheme.primary),
                    onPressed: () => controller.setLooping(!value.isLooping),
                  ),
                  PopupMenuButton<double>(
                    tooltip: l.videoSpeed,
                    initialValue: value.playbackSpeed,
                    onSelected: controller.setPlaybackSpeed,
                    itemBuilder: (context) => [
                      for (final speed in _VideoPlayerScreenState.speeds)
                        PopupMenuItem(value: speed, child: Text('${speed}x')),
                    ],
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        '${value.playbackSpeed}x',
                        style: TextStyle(color: foreground, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  if (onFullscreen != null)
                    IconButton(
                      color: foreground,
                      tooltip: l.videoFullscreen,
                      icon: const Icon(Icons.fullscreen),
                      onPressed: onFullscreen,
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FullscreenVideo extends StatefulWidget {
  const _FullscreenVideo({required this.controller});

  final VideoPlayerController controller;

  @override
  State<_FullscreenVideo> createState() => _FullscreenVideoState();
}

class _FullscreenVideoState extends State<_FullscreenVideo> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final controller = widget.controller;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: controller.value.aspectRatio == 0 ? 16 / 9 : controller.value.aspectRatio,
                child: VideoPlayer(controller),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                color: Colors.black54,
                child: VideoControls(controller: controller, dark: true),
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                color: Colors.white,
                tooltip: l.videoExitFullscreen,
                icon: const Icon(Icons.fullscreen_exit),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
