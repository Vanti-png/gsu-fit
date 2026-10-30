import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gsu_fit/core/widgets/common.dart';

// Kept as widget_test.dart so `flutter create .` does not add its default
// counter-app test (which would not compile against this app).
void main() {
  testWidgets('EmptyState shows its texts and action', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: EmptyState(
          icon: Icons.inbox,
          title: 'Başlık',
          message: 'Açıklama',
          action: TextButton(onPressed: () => tapped = true, child: const Text('Ekle')),
        ),
      ),
    ));
    expect(find.text('Başlık'), findsOneWidget);
    expect(find.text('Açıklama'), findsOneWidget);
    await tester.tap(find.text('Ekle'));
    expect(tapped, isTrue);
  });

  testWidgets('charts render with data and a single point', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ListView(
          children: [
            SimpleLineChart(
              points: [ChartPoint(DateTime(2026, 1, 1), 80), ChartPoint(DateTime(2026, 2, 1), 78.5)],
              formatValue: (v) => v.toStringAsFixed(1),
              formatDate: (d) => '${d.day}.${d.month}',
            ),
            SimpleLineChart(
              points: [ChartPoint(DateTime(2026, 1, 1), 80)],
              formatValue: (v) => v.toStringAsFixed(1),
              formatDate: (d) => '${d.day}.${d.month}',
            ),
            SimpleBarChart(
              bars: const [BarDatum('A', 10), BarDatum('B', 0), BarDatum('C', 25)],
              formatValue: (v) => v.toStringAsFixed(0),
            ),
          ],
        ),
      ),
    ));
    await tester.tap(find.byType(SimpleLineChart).first);
    await tester.pump();
    await tester.tap(find.text('C'));
    await tester.pump();
    expect(find.text('C · 25'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
