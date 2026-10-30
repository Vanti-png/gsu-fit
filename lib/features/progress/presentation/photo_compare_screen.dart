import 'dart:io';

import 'package:flutter/material.dart';

import 'package:gsu_fit/core/l10n/l10n.dart';
import 'package:gsu_fit/core/utils/formatters.dart';
import 'package:gsu_fit/features/body/domain/body_measurement.dart';

/// Two progress photos side by side; defaults to the oldest and newest.
class PhotoCompareScreen extends StatefulWidget {
  const PhotoCompareScreen({super.key, required this.photos});

  /// Newest first.
  final List<ProgressPhoto> photos;

  @override
  State<PhotoCompareScreen> createState() => _PhotoCompareScreenState();
}

class _PhotoCompareScreenState extends State<PhotoCompareScreen> {
  late ProgressPhoto _before = widget.photos.last;
  late ProgressPhoto _after = widget.photos.first;

  Widget _picker(String label, ProgressPhoto value, ValueChanged<ProgressPhoto> onChanged) {
    return DropdownMenu<String>(
      initialSelection: value.id,
      expandedInsets: EdgeInsets.zero,
      label: Text(label),
      onSelected: (id) {
        final photo = widget.photos.where((p) => p.id == id).firstOrNull;
        if (photo != null) onChanged(photo);
      },
      dropdownMenuEntries: [
        for (final photo in widget.photos)
          DropdownMenuEntry(value: photo.id, label: formatDate(photo.date)),
      ],
    );
  }

  Widget _image(ProgressPhoto photo) {
    return Expanded(
      child: Column(
        children: [
          Expanded(
            child: InteractiveViewer(
              maxScale: 4,
              child: Image.file(
                File(photo.filePath),
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(formatDate(photo.date), style: Theme.of(context).textTheme.labelLarge),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final days = _after.date.difference(_before.date).inDays.abs();
    return Scaffold(
      appBar: AppBar(title: Text(l.photoCompare)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: _picker(l.photoBefore, _before, (p) => setState(() => _before = p))),
                  const SizedBox(width: 12),
                  Expanded(child: _picker(l.photoAfter, _after, (p) => setState(() => _after = p))),
                ],
              ),
              const SizedBox(height: 8),
              Text(l.photoDaysBetween('$days')),
              const SizedBox(height: 8),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [_image(_before), const SizedBox(width: 8), _image(_after)],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
