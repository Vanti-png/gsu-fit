import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gsu_fit/core/l10n/l10n.dart';
import 'package:gsu_fit/core/media/media_cache.dart';
import 'package:gsu_fit/core/providers.dart';
import 'package:gsu_fit/features/exercises/domain/exercise.dart';
import 'package:gsu_fit/features/settings/application/settings_controller.dart';
import 'package:gsu_fit/features/settings/domain/app_settings.dart';

String mediaErrorText(AppLocalizations l, Object error) {
  if (error is MediaException) {
    return switch (error.failure) {
      MediaFailure.offline => l.mediaOffline,
      MediaFailure.notFound => l.mediaNotFound,
      MediaFailure.server => l.mediaServerError,
      MediaFailure.invalidUrl => l.mediaInvalidUrl,
    };
  }
  return l.mediaLoadFailed;
}

/// Exercise illustration. With several frames it alternates them as a
/// short animation. Respects the quality and "load on tap" settings:
/// low quality downloads only the first frame.
class ExerciseMediaView extends ConsumerStatefulWidget {
  const ExerciseMediaView({super.key, required this.urls, this.height = 240});

  final List<String> urls;
  final double height;

  @override
  ConsumerState<ExerciseMediaView> createState() => _ExerciseMediaViewState();
}

class _ExerciseMediaViewState extends ConsumerState<ExerciseMediaView> {
  List<File>? _files;
  Object? _error;
  bool _loading = false;
  bool _waitingForTap = false;
  int _frame = 0;
  Timer? _animation;

  @override
  void initState() {
    super.initState();
    _load(force: false);
  }

  @override
  void dispose() {
    _animation?.cancel();
    super.dispose();
  }

  List<String> _wantedUrls() {
    final quality = ref.read(settingsProvider).mediaQuality;
    if (widget.urls.isEmpty) return const [];
    return quality == MediaQuality.high ? widget.urls : widget.urls.take(1).toList();
  }

  Future<void> _load({required bool force}) async {
    final urls = _wantedUrls();
    if (urls.isEmpty) return;
    final cache = ref.read(mediaCacheProvider);
    final cached = <File>[];
    for (final url in urls) {
      final file = await cache.cached(url);
      if (file != null) cached.add(file);
    }
    if (!mounted) return;
    if (cached.length == urls.length) {
      _show(cached);
      return;
    }
    if (!force && ref.read(settingsProvider).mediaOnDemand) {
      setState(() => _waitingForTap = true);
      return;
    }
    setState(() {
      _loading = true;
      _waitingForTap = false;
      _error = null;
    });
    try {
      final files = await Future.wait(urls.map(cache.get));
      if (mounted) _show(files);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
          _loading = false;
        });
      }
    }
  }

  void _show(List<File> files) {
    _animation?.cancel();
    setState(() {
      _files = files;
      _loading = false;
      _error = null;
      _frame = 0;
    });
    if (files.length > 1) {
      _animation = Timer.periodic(const Duration(milliseconds: 1200), (_) {
        if (mounted) setState(() => _frame = (_frame + 1) % files.length);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final files = _files;
    Widget child;
    if (widget.urls.isEmpty) {
      child = _Placeholder(icon: Icons.image_not_supported_outlined, text: l.mediaNoImage);
    } else if (files != null) {
      child = AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: Image.file(
          files[_frame],
          key: ValueKey(_frame),
          fit: BoxFit.contain,
          width: double.infinity,
          height: widget.height,
          errorBuilder: (context, error, stackTrace) =>
              _Placeholder(icon: Icons.broken_image_outlined, text: l.mediaLoadFailed),
        ),
      );
    } else if (_loading) {
      child = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      child = _Placeholder(
        icon: Icons.wifi_off,
        text: mediaErrorText(l, _error!),
        actionLabel: l.commonRetry,
        onAction: () => _load(force: true),
      );
    } else if (_waitingForTap) {
      child = _Placeholder(
        icon: Icons.download_outlined,
        text: l.mediaTapToLoad,
        actionLabel: l.mediaLoad,
        onAction: () => _load(force: true),
      );
    } else {
      child = const SizedBox.shrink();
    }
    return Container(
      height: widget.height,
      width: double.infinity,
      color: scheme.surfaceContainerHighest,
      child: Semantics(image: true, label: l.mediaIllustration, child: child),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.icon, required this.text, this.actionLabel, this.onAction});

  final IconData icon;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40),
            const SizedBox(height: 8),
            Text(text, textAlign: TextAlign.center),
            if (actionLabel != null) ...[
              const SizedBox(height: 8),
              FilledButton.tonal(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Small list image. Never downloads on its own when "load on tap" is on;
/// otherwise fetches the first frame once and keeps it cached.
class ExerciseThumbnail extends ConsumerStatefulWidget {
  const ExerciseThumbnail({super.key, required this.exercise, this.size = 56});

  final Exercise? exercise;
  final double size;

  @override
  ConsumerState<ExerciseThumbnail> createState() => _ExerciseThumbnailState();
}

class _ExerciseThumbnailState extends ConsumerState<ExerciseThumbnail> {
  File? _file;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ExerciseThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.exercise?.id != widget.exercise?.id) {
      _file = null;
      _load();
    }
  }

  Future<void> _load() async {
    final urls = widget.exercise?.imageUrls ?? const <String>[];
    if (urls.isEmpty) return;
    final cache = ref.read(mediaCacheProvider);
    var file = await cache.cached(urls.first);
    if (file == null && !ref.read(settingsProvider).mediaOnDemand) {
      try {
        file = await cache.get(urls.first);
      } catch (_) {
        file = null;
      }
    }
    if (mounted && file != null) setState(() => _file = file);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final file = _file;
    final pixels = (widget.size * MediaQuery.devicePixelRatioOf(context)).round();
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: widget.size,
        height: widget.size,
        color: scheme.surfaceContainerHighest,
        child: file == null
            ? Icon(Icons.fitness_center, color: scheme.onSurfaceVariant)
            : Image.file(
                file,
                fit: BoxFit.cover,
                cacheWidth: pixels,
                errorBuilder: (context, error, stackTrace) =>
                    Icon(Icons.fitness_center, color: scheme.onSurfaceVariant),
              ),
      ),
    );
  }
}
