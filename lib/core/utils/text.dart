import 'dart:math';

// Turkish alphabet order, with q/w/x placed where English names expect them.
const String _alphabet = 'abcçdefgğhıijklmnoöpqrsştuüvwxyz';

/// Lower-cases with Turkish rules (I → ı, İ → i).
String turkishLower(String text) =>
    text.replaceAll('I', 'ı').replaceAll('İ', 'i').toLowerCase();

/// Sort comparator that puts "Ç" after "C" and "Ş" after "S".
int turkishCompare(String a, String b) {
  final x = turkishLower(a);
  final y = turkishLower(b);
  final length = min(x.length, y.length);
  for (var i = 0; i < length; i++) {
    if (x[i] == y[i]) continue;
    final ix = _alphabet.indexOf(x[i]);
    final iy = _alphabet.indexOf(y[i]);
    if (ix >= 0 && iy >= 0) return ix - iy;
    return x[i].compareTo(y[i]);
  }
  return x.length - y.length;
}

/// Accent-free key so "omuz" matches "Omuz" and "sinav" matches "Şınav".
String searchKey(String text) => turkishLower(text)
    .replaceAll('ç', 'c')
    .replaceAll('ğ', 'g')
    .replaceAll('ı', 'i')
    .replaceAll('ö', 'o')
    .replaceAll('ş', 's')
    .replaceAll('ü', 'u');
