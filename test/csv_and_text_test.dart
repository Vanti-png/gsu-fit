import 'package:flutter_test/flutter_test.dart';

import 'package:gsu_fit/core/utils/formatters.dart';
import 'package:gsu_fit/core/utils/id.dart';
import 'package:gsu_fit/core/utils/text.dart';
import 'package:gsu_fit/core/utils/units.dart';
import 'package:gsu_fit/features/data_transfer/data/data_transfer_service.dart';
import 'package:gsu_fit/features/data_transfer/domain/csv_codec.dart';
import 'package:gsu_fit/features/settings/domain/app_settings.dart';

void main() {
  group('CsvCodec', () {
    const codec = CsvCodec();

    test('round-trips separators, quotes, line breaks and Turkish text', () {
      final rows = [
        ['1', 'Şınav, dizler yerde', 'Not: "yavaş"'],
        ['2', 'İki\nsatır', ''],
      ];
      final decoded = codec.decode(codec.encode(['id', 'name', 'notes'], rows));
      expect(decoded.first, ['id', 'name', 'notes']);
      expect(decoded.sublist(1), rows);
    });

    test('accepts a BOM and CRLF line endings', () {
      final maps = codec.decodeMaps('${CsvCodec.bom}id,value\r\n1,a\r\n2,b\r\n');
      expect(maps, [
        {'id': '1', 'value': 'a'},
        {'id': '2', 'value': 'b'},
      ]);
    });

    test('pads short rows and skips empty lines', () {
      final maps = codec.decodeMaps('id,a,b\n1,x\n\n');
      expect(maps, [
        {'id': '1', 'a': 'x', 'b': ''},
      ]);
    });

    test('keeps an empty quoted last field', () {
      expect(codec.decode('a,""'), [
        ['a', ''],
      ]);
    });
  });

  test('tableFromFileName prefers the longest match', () {
    expect(DataTransferService.tableFromFileName('gsu_fit_workout_sets_2026-10-30.csv'), 'workout_sets');
    expect(DataTransferService.tableFromFileName('gsu_fit_workouts_2026-10-30.csv'), 'workouts');
    expect(DataTransferService.tableFromFileName('random.csv'), isNull);
  });

  group('units', () {
    test('kg/lb conversion', () {
      expect(WeightUnit.lb.fromKg(100), closeTo(220.462, 0.001));
      expect(WeightUnit.lb.toKg(220.462), closeTo(100, 0.001));
      expect(WeightUnit.kg.fromKg(42.5), 42.5);
    });

    test('roundToStep and cleanDouble', () {
      expect(roundToStep(54, 2.5), 55);
      expect(roundToStep(53.6, 2.5), 52.5);
      expect(cleanDouble(0.1 + 0.2), 0.3);
    });
  });

  group('number parsing and formatting', () {
    test('accepts comma and dot decimals', () {
      expect(parseDecimal('62,5'), 62.5);
      expect(parseDecimal(' 62.5 '), 62.5);
      expect(parseDecimal(''), isNull);
      expect(parseDecimal('abc'), isNull);
      expect(parseInt('12'), 12);
      expect(parseInt('12,6'), 13);
    });

    test('formats with Turkish separators', () {
      expect(formatNumber(1234.5), '1.234,5');
      expect(formatNumber(62.0), '62');
      expect(formatInputNumber(62.5), '62,5');
      expect(formatWeight(100, WeightUnit.kg), '100 kg');
    });
  });

  group('Turkish text helpers', () {
    test('search ignores case and Turkish accents', () {
      expect(searchKey('Şınav'), 'sinav');
      expect(searchKey('İTİŞ'), 'itis');
      expect(searchKey('ILIK'), 'ilik');
    });

    test('sorts Ç after C and Ş after S', () {
      final names = ['Şınav', 'Squat', 'Çekiş', 'Crunch', 'Barfiks'];
      names.sort(turkishCompare);
      expect(names, ['Barfiks', 'Crunch', 'Çekiş', 'Squat', 'Şınav']);
    });
  });

  test('newId produces distinct version 4 UUIDs', () {
    final ids = List.generate(200, (_) => newId());
    expect(ids.toSet(), hasLength(200));
    final pattern = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');
    expect(ids.every(pattern.hasMatch), isTrue);
  });

  test('AppSettings survive a JSON round trip', () {
    const settings = AppSettings(
      themeMode: AppThemeMode.dark,
      weightUnit: WeightUnit.lb,
      workoutReminderEnabled: true,
      workoutReminderDays: [2, 4],
      waterGoalMl: 2500,
    );
    final restored = AppSettings.fromJson(settings.toJson());
    expect(restored.themeMode, AppThemeMode.dark);
    expect(restored.weightUnit, WeightUnit.lb);
    expect(restored.workoutReminderEnabled, isTrue);
    expect(restored.workoutReminderDays, [2, 4]);
    expect(restored.waterGoalMl, 2500);
    expect(AppSettings.fromJson(const {}).stepGoal, const AppSettings().stepGoal);
  });
}
