import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:gsu_fit/core/l10n/l10n.dart';
import 'package:gsu_fit/core/utils/formatters.dart';
import 'package:gsu_fit/core/utils/id.dart';
import 'package:gsu_fit/core/widgets/common.dart';
import 'package:gsu_fit/features/body/application/body_providers.dart';
import 'package:gsu_fit/features/body/domain/body_measurement.dart';
import 'package:gsu_fit/features/progress/presentation/photo_compare_screen.dart';

class PhotosTab extends ConsumerWidget {
  const PhotosTab({super.key});

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(l.photoCamera),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l.photoGallery),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (picked == null) return;
      await ref.read(bodyActionsProvider).addPhoto(
            sourcePath: picked.path,
            id: newId(),
            date: DateTime.now(),
          );
      // The camera copy lives in the app cache; the kept copy is private.
      if (source == ImageSource.camera) {
        try {
          await File(picked.path).delete();
        } on FileSystemException {
          // Already gone; nothing to clean up.
        }
      }
    } catch (_) {
      if (context.mounted) showMessage(context, l.photoFailed);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final photos = ref.watch(photosProvider);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'photo-fab',
        onPressed: () => _add(context, ref),
        icon: const Icon(Icons.add_a_photo_outlined),
        label: Text(l.photoAdd),
      ),
      body: AsyncValueView<List<ProgressPhoto>>(
        value: photos,
        onRetry: () => ref.invalidate(photosProvider),
        data: (list) {
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_outline, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(l.photoPrivacy, style: Theme.of(context).textTheme.bodySmall),
                      ),
                    ],
                  ),
                ),
              ),
              if (list.length >= 2)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: FilledButton.tonalIcon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => PhotoCompareScreen(photos: list)),
                      ),
                      icon: const Icon(Icons.compare),
                      label: Text(l.photoCompare),
                    ),
                  ),
                ),
              if (list.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: Icons.photo_library_outlined,
                    title: l.photosEmpty,
                    message: l.photosEmptyHint,
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
                  sliver: SliverGrid.builder(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 160,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 3 / 4,
                    ),
                    itemCount: list.length,
                    itemBuilder: (context, index) => _PhotoTile(photo: list[index]),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _PhotoTile extends ConsumerWidget {
  const _PhotoTile({required this.photo});

  final ProgressPhoto photo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pixels = (160 * MediaQuery.devicePixelRatioOf(context)).round();
    return Semantics(
      button: true,
      label: formatDate(photo.date),
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => _PhotoViewer(photo: photo)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.file(
                File(photo.filePath),
                fit: BoxFit.cover,
                cacheWidth: pixels,
                errorBuilder: (context, error, stackTrace) =>
                    const ColoredBox(color: Colors.black12, child: Icon(Icons.broken_image)),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  color: Colors.black54,
                  padding: const EdgeInsets.all(6),
                  child: Text(
                    formatDateShort(photo.date),
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoViewer extends ConsumerWidget {
  const _PhotoViewer({required this.photo});

  final ProgressPhoto photo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(formatDate(photo.date)),
        actions: [
          IconButton(
            tooltip: l.commonDelete,
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final ok = await confirmDialog(
                context,
                title: l.photoDeleteTitle,
                message: l.photoDeleteMessage,
                confirmLabel: l.commonDelete,
                destructive: true,
              );
              if (!ok) return;
              await ref.read(bodyActionsProvider).deletePhoto(photo);
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ),
      body: InteractiveViewer(
        maxScale: 5,
        child: Center(child: Image.file(File(photo.filePath))),
      ),
    );
  }
}
