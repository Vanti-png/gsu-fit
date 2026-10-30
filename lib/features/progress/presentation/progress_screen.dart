import 'package:flutter/material.dart';

import 'package:gsu_fit/core/l10n/l10n.dart';
import 'package:gsu_fit/core/widgets/common.dart';
import 'package:gsu_fit/features/progress/presentation/charts_tab.dart';
import 'package:gsu_fit/features/progress/presentation/measurements_tab.dart';
import 'package:gsu_fit/features/progress/presentation/photos_tab.dart';
import 'package:gsu_fit/features/settings/presentation/settings_screen.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.progressTitle),
          actions: [SettingsAction(onOpen: () => openSettings(context))],
          bottom: TabBar(
            tabs: [
              Tab(icon: const Icon(Icons.show_chart), text: l.progressCharts),
              Tab(icon: const Icon(Icons.straighten), text: l.progressMeasurements),
              Tab(icon: const Icon(Icons.photo_library_outlined), text: l.progressPhotos),
            ],
          ),
        ),
        body: const TabBarView(
          children: [ChartsTab(), MeasurementsTab(), PhotosTab()],
        ),
      ),
    );
  }
}
