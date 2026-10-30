/// RFC 4180 style CSV: fields with separators, quotes or line breaks are
/// quoted and inner quotes doubled. A UTF-8 BOM is tolerated on input (Excel
/// adds one, and needs one to show Turkish characters correctly).
class CsvCodec {
  const CsvCodec({this.separator = ','});

  final String separator;

  static const String bom = '﻿';

  String encode(List<String> header, List<List<Object?>> rows) {
    final buffer = StringBuffer()..writeln(header.map(_escape).join(separator));
    for (final row in rows) {
      buffer.writeln(row.map((value) => _escape(value?.toString() ?? '')).join(separator));
    }
    return buffer.toString();
  }

  String _escape(String value) {
    final needsQuotes = value.contains(separator) ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r');
    return needsQuotes ? '"${value.replaceAll('"', '""')}"' : value;
  }

  List<List<String>> decode(String input) {
    final text = input.startsWith(bom) ? input.substring(1) : input;
    final rows = <List<String>>[];
    var row = <String>[];
    final field = StringBuffer();
    var inQuotes = false;
    var fieldStarted = false;

    for (var i = 0; i < text.length; i++) {
      final char = text[i];
      if (inQuotes) {
        if (char == '"') {
          if (i + 1 < text.length && text[i + 1] == '"') {
            field.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          field.write(char);
        }
        continue;
      }
      if (char == '"') {
        inQuotes = true;
        fieldStarted = true;
      } else if (char == separator) {
        row.add(field.toString());
        field.clear();
        fieldStarted = true;
      } else if (char == '\r') {
        // Part of a CRLF line ending; the '\n' ends the row.
      } else if (char == '\n') {
        row.add(field.toString());
        field.clear();
        rows.add(row);
        row = <String>[];
        fieldStarted = false;
      } else {
        field.write(char);
        fieldStarted = true;
      }
    }
    if (fieldStarted || field.isNotEmpty || row.isNotEmpty) {
      row.add(field.toString());
      rows.add(row);
    }
    return rows;
  }

  /// Rows as header → value maps; rows shorter than the header are padded.
  List<Map<String, String>> decodeMaps(String input) {
    final rows = decode(input);
    if (rows.isEmpty) return const [];
    final header = rows.first.map((h) => h.trim()).toList();
    return [
      for (final row in rows.skip(1))
        if (row.any((value) => value.isNotEmpty))
          {
            for (var i = 0; i < header.length; i++) header[i]: i < row.length ? row[i] : '',
          },
    ];
  }
}
