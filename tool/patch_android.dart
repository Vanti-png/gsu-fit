// Adjusts the files that `flutter create` generates:
//  - Android: minSdk 26 (required by Health Connect) and release signing
//    from android/key.properties when that file exists
//  - Web: app name, language and description in index.html/manifest.json
//
// Usage (from the project root, after `flutter create`):
//   dart run tool/patch_android.dart
//
// Running it again is safe; already applied changes are skipped.
import 'dart:convert';
import 'dart:io';

const _imports = 'import java.io.FileInputStream\nimport java.util.Properties\n\n';

const _loader = '''

// Release signing: reads android/key.properties when present (see README).
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
''';

const _signingConfigs = '''
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

''';

const _releaseSigning = 'signingConfig = if (keystorePropertiesFile.exists()) '
    'signingConfigs.getByName("release") else signingConfigs.getByName("debug")';

void main() {
  final android = File('android/app/build.gradle.kts');
  final web = Directory('web');
  if (!android.existsSync() && !web.existsSync()) {
    stderr.writeln('android/ veya web/ bulunamadı. Önce README\'deki '
        '"flutter create" komutunu çalıştırın.');
    exit(1);
  }
  if (android.existsSync()) _patchAndroid(android);
  if (web.existsSync()) _patchWeb();
}

void _patchAndroid(File file) {
  var text = file.readAsStringSync();
  final original = text;

  // 1. minSdk 26
  if (!text.contains('maxOf(26')) {
    final minSdk = RegExp(r'minSdk(Version)?\s*=\s*[^\n]+');
    if (minSdk.hasMatch(text)) {
      text = text.replaceFirst(minSdk, 'minSdk = maxOf(26, flutter.minSdkVersion)');
      stdout.writeln('✓ minSdk = 26');
    } else {
      stderr.writeln('! minSdk satırı bulunamadı; defaultConfig içine elle "minSdk = 26" ekleyin.');
    }
  }

  // 2. Release signing
  if (!text.contains('keystoreProperties')) {
    final pluginsEnd = _blockEnd(text, 'plugins {');
    final buildTypes = RegExp(r'^[ \t]*buildTypes\s*\{', multiLine: true).firstMatch(text);
    const debugSigning = 'signingConfig = signingConfigs.getByName("debug")';
    if (pluginsEnd == null || buildTypes == null || !text.contains(debugSigning)) {
      stderr.writeln('! İmzalama ayarı otomatik eklenemedi; README\'deki adımları elle uygulayın.');
    } else {
      text = text.substring(0, buildTypes.start) +
          _signingConfigs +
          text.substring(buildTypes.start);
      text = text.replaceFirst(debugSigning, _releaseSigning);
      final end = _blockEnd(text, 'plugins {')!;
      text = _imports + text.substring(0, end) + _loader + text.substring(end);
      stdout.writeln('✓ key.properties ile release imzalama');
    }
  }

  if (text == original) {
    stdout.writeln('Değişiklik gerekmedi.');
    return;
  }
  file.writeAsStringSync(text);
  stdout.writeln('android/app/build.gradle.kts güncellendi.');
}

void _patchWeb() {
  final manifest = File('web/manifest.json');
  if (manifest.existsSync()) {
    final json = jsonDecode(manifest.readAsStringSync()) as Map<String, dynamic>;
    json
      ..['name'] = 'GSU Fit'
      ..['short_name'] = 'GSU Fit'
      ..['description'] = 'Çevrimdışı spor ve fitness takibi'
      ..['lang'] = 'tr'
      ..['theme_color'] = '#1B8A5A'
      ..['background_color'] = '#FFFFFF';
    manifest.writeAsStringSync(const JsonEncoder.withIndent('    ').convert(json));
  }
  final index = File('web/index.html');
  if (index.existsSync()) {
    final html = index
        .readAsStringSync()
        .replaceFirst('<html>', '<html lang="tr">')
        .replaceAll(RegExp(r'<title>[^<]*</title>'), '<title>GSU Fit</title>')
        .replaceAll(
          RegExp(r'<meta name="apple-mobile-web-app-title" content="[^"]*">'),
          '<meta name="apple-mobile-web-app-title" content="GSU Fit">',
        )
        .replaceAll(
          RegExp(r'<meta name="description" content="[^"]*">'),
          '<meta name="description" content="Çevrimdışı spor ve fitness takibi">',
        );
    index.writeAsStringSync(html);
  }
  stdout.writeln('✓ web: uygulama adı ve dil');
}

/// Index just after the closing brace of the block starting with [opener].
int? _blockEnd(String text, String opener) {
  final start = text.indexOf(opener);
  if (start < 0) return null;
  var depth = 0;
  for (var i = start; i < text.length; i++) {
    if (text[i] == '{') depth++;
    if (text[i] == '}') {
      depth--;
      if (depth == 0) return i + 1;
    }
  }
  return null;
}
