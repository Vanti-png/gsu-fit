# GSU Fit: Android spor ve fitness uygulaması

Çevrimdışı çalışan, Türkçe arayüzlü bir antrenman, ilerleme ve beslenme takip uygulaması. Flutter ile yazıldı ve APK olarak derlenir.

> **Durum:** Kod bu bilgisayarda **derlenmedi**. Flutter, JDK ve Android SDK kurulu değil, kotalı internet nedeniyle de kurulmadı. Bunların yerine şu kontroller betiklerle otomatik yapıldı:
>
> - Koddaki 535 metin anahtarının hepsi `app_tr.arb` dosyasında var. Parametre sayıları ve sıraları da eşleşiyor.
> - Dosyalar arası import'lar ve parantez dengesi kontrol edildi.
>
> Birim testleri yazıldı ama henüz çalıştırılmadı. İlk `flutter analyze` veya `flutter build` çıktısında hata görürsen çıktıyı olduğu gibi gönder, düzelteyim.

---

## 1. Mimari plan

### Teknoloji seçimi

| Konu | Seçim | Gerekçe |
|---|---|---|
| Framework | **Flutter** (Dart) | Tek kod tabanı ve Material 3'ün hazır gelmesi. Hızlı arayüz geliştirme ve tek komutla APK (`flutter build apk`). İleride iOS da aynı koddan çıkar. Kotlin/Compose daha "yerli" olurdu ama iOS'a geçişi kapatırdı. |
| Yerel veritabanı | **SQLite** (`sqflite`) | İlişkisel veri (program → gün → egzersiz, antrenman → set) için doğal bir seçim. Kod üretimi gerektirmez, sorgu esnektir. Isar bakımsız kaldı. Hive anahtar-değer olduğu için ilişkili sorgulara uygun değil. Room ise yalnızca Kotlin. |
| Durum yönetimi | **Riverpod 2** | Test edilebilir, `BuildContext` gerektirmeyen bağımlılık enjeksiyonu. Kod üretimi gerekmez. |
| Grafikler | Kendi `CustomPainter` çizgi ve sütun grafiği | Paket indirmesi yok, API değişikliği riski yok. |
| Görsel/video önbelleği | Kendi `MediaCache` sınıfı (`dart:io`) | Paket yok. Bir dosya bir kez indirilir, sonra çevrimdışı açılır. |
| Bildirimler | Kendi Kotlin kodu (AlarmManager) | `flutter_local_notifications` ve `timezone` paketlerine gerek kalmaz. |
| Dosya kaydet/aç | Kendi Kotlin kodu (Storage Access Framework) | `file_picker` paketine gerek kalmaz, depolama izni de gerekmez. |
| Adım sayısı | `health` paketi (Android Health Connect) | İzin akışını ve Health Connect API'sini hazır yönetir. |

Bağımlılıklar bilinçli olarak az tutuldu. Kotalı internette derleme sırasında indirilecek paket sayısı böylece düşük kalıyor.

### Katmanlar

```
presentation/  Ekranlar ve widget'lar (yalnızca UI)
     │  ref.watch / ref.read
application/   Riverpod provider'ları, controller'lar (ActiveWorkoutController, SettingsController…)
     │
domain/        Saf Dart: modeller, iş kuralları (ilerleme, program üretimi, kalori), repository arayüzleri
     │  (arayüz)
data/          SQLite uygulamaları (Sqlite…Repository), dışa/içe aktarma servisi
```

- Her özellik `lib/features/<özellik>/` altında kendi `domain`, `data`, `application` ve `presentation` klasörlerine ayrılır.
- `domain` katmanı Flutter'a ve veritabanına bağımlı değildir. Bu yüzden birim testleri cihaz olmadan çalışır.
- Ortak kod `lib/core/` altında durur: veritabanı, tema, yardımcılar, ortak widget'lar, Android köprüsü.

### Bulut senkronizasyonuna hazırlık

- **Birincil anahtarlar UUID v4:** farklı cihazlarda çevrimdışı oluşturulan kayıtlar çakışmaz.
- **Senkron sütunları:** her tabloda `created_at`, `updated_at` ve `deleted_at` var.
- **Yumuşak silme:** normal kullanımda satırlar fiziksel olarak silinmez, `deleted_at` işaretlenir. İleride bir senkron servisi "`updated_at` > son senkron" olan satırları (silinenler dahil) gönderebilir.
- **Repository arayüzleri** `domain` katmanındadır. Bulut için ayrı bir uygulama (Supabase, Firebase vb.) eklenip provider'dan değiştirilebilir.
- **Hazır veri biçimi:** JSON yedeği zaten "tablo → satırlar" biçimindedir ve senkron yükü olarak kullanılabilir. İçe aktarma birincil anahtara göre birleştirir.

### Metinler ve dil

- Tüm arayüz metinleri `lib/l10n/app_tr.arb` dosyasındadır. Kod yorumları ve değişken isimleri İngilizcedir.
- Flutter'ın `gen-l10n` aracı `flutter pub get` sırasında `AppLocalizations` sınıfını üretir.
- **İngilizce eklemek** için:
  1. `app_tr.arb` dosyasını `app_en.arb` olarak kopyalayıp metinleri çevir.
  2. `lib/core/l10n/l10n.dart` içindeki `appLocale` değerini cihaz diline göre seçilecek hale getir.
- Örnek egzersiz içerikleri arayüz metni değil veri olduğu için `lib/seed/seed_exercises.dart` dosyasındadır.

### Varsayımlar

1. **Uygulama kimliği:** Uygulama adı "GSU Fit", paket adı `com.gsu.gsu_fit`. Değiştirmek için `app_tr.arb` içindeki `appTitle` ile `AndroidManifest.xml` içindeki `android:label` güncellenmeli.
2. **Android sürümü:** En düşük **Android 8.0 (API 26)**. Health Connect bunu gerektiriyor.
3. **Birimler:** kg/lb seçimi yalnızca ağırlık içindir. Mesafe km, boy ve çevre ölçüleri cm. Veritabanında ağırlık her zaman kg olarak tutulur.
4. **Video:** Kaynak olarak **harici URL** seçildi (doğrudan oynatılabilen https MP4). Yerel dosya yolu ve `asset:` de desteklenir.
   - Örnek egzersizlerle video gelmiyor, çünkü güvenilir ve lisansı uygun bir kaynak bulunmadı. Kullanıcı egzersiz detayından ⋮ → "Video bağlantısı" ile ekler.
   - YouTube bağlantıları doğrudan oynatılamaz. Bu bir web görünümü veya ek paket gerektirir (bkz. Gelecek özellikler).
5. **Görseller:** Örnek egzersizlerin başlangıç ve bitiş pozisyonu görselleri kamu malı (Unlicense) **free-exercise-db** projesinden ilk açılışta indirilir. Sonra önbellekte kalır. İki kare sırayla gösterildiği için kısa bir animasyon oluşur. Görsel adresleri kontrol edildi, hepsi erişilebilir.
6. **Program günleri:** Günler sabit hafta günlerine bağlı değil, sırayla döner. "Bugünün antrenmanı", son yapılan günden sonraki gündür. Hatırlatıcı günleri ayarlardan ayrıca seçilir.
7. **Bildirimler:** "Kesin olmayan" (inexact) alarmlar kullanılır. Ek izin gerektirmez, ancak cihaz derin uykudaysa birkaç dakika gecikebilir.
8. **Hesaplamalar:** Kalori, makro ve su hedefleri tahminidir (Mifflin-St Jeor ve MET tabloları). Tıbbi tavsiye değildir. Cinsiyet yalnızca bu hesap için ve isteğe bağlı sorulur.
9. **Gizlilik:** İlerleme fotoğrafları uygulamanın özel klasöründe saklanır. Galeride görünmez, yedeğe ve dışa aktarmaya dahil edilmez. `android:allowBackup="false"` ayarı sayesinde veriler Google yedeğine de gitmez. İzinler (bildirim, Health Connect) yalnızca ilgili özellik açılınca istenir. Kamera izni gerekmez, çünkü sistem kamerası kullanılır.

---

## 2. Proje yapısı

```
GSU/
├── android/app/src/main/              ← flutter create'in üzerine yazmadığı Android dosyaları
│   ├── AndroidManifest.xml            izinler, Health Connect, bildirim alıcıları
│   ├── kotlin/com/gsu/gsu_fit/
│   │   ├── MainActivity.kt            dosya kaydet/aç + bildirim izni (method channel)
│   │   └── Reminders.kt               AlarmManager hatırlatıcıları, açılışta yeniden kurma
│   └── res/values/strings.xml
├── lib/
│   ├── main.dart                      açılış: DB, örnek veri, ayarlar, ProviderScope
│   ├── app.dart                       MaterialApp, tema, ilk kurulum / ana ekran geçişi
│   ├── core/
│   │   ├── database/                  app_database, migrations (şema), sqlite_store (senkron alanları)
│   │   ├── l10n/                      l10n.dart (context.l10n), labels.dart (enum → Türkçe)
│   │   ├── media/media_cache.dart     görsel/video önbelleği
│   │   ├── platform/native_bridge.dart Kotlin köprüsü (hatırlatıcı, dosya)
│   │   ├── theme/app_theme.dart       Material 3 açık/koyu tema
│   │   ├── utils/                     tarih, birim, sayı biçimi, UUID, Türkçe sıralama/arama
│   │   ├── widgets/                   ortak widget'lar, çizgi/sütun grafik
│   │   └── providers.dart
│   ├── features/
│   │   ├── profile/                   profil, ilk kurulum (onboarding), profil düzenleme
│   │   ├── programs/                  program modeli, öneri üretici, progressive overload, ekranlar
│   │   ├── workout/                   aktif antrenman, set kaydı, dinlenme sayacı, geçmiş
│   │   ├── exercises/                 kütüphane, arama/filtre, detay, görsel/video oynatıcı
│   │   ├── cardio/                    kardiyo kaydı, MET kalori hesabı
│   │   ├── body/                      vücut ölçümleri, ilerleme fotoğrafları
│   │   ├── progress/                  grafikler, ölçüm listesi, fotoğraf karşılaştırma
│   │   ├── nutrition/                 su ve yiyecek/makro takibi, hedef hesabı
│   │   ├── steps/                     Health Connect adım sayısı
│   │   ├── settings/                  ayarlar, hatırlatıcı zamanlayıcı
│   │   ├── data_transfer/             JSON/CSV dışa-içe aktarma, tüm verileri silme
│   │   └── home/                      alt navigasyon, ana sayfa
│   ├── l10n/app_tr.arb                TÜM arayüz metinleri (Türkçe)
│   └── seed/                          29 örnek egzersiz + örnek program
├── test/                              birim ve widget testleri
├── tool/patch_android.dart            flutter create sonrası Gradle ayarı (minSdk 26, imzalama)
├── pubspec.yaml, l10n.yaml, analysis_options.yaml, .gitignore
└── README.md
```

Her dosyanın tam kodu klasördedir: Dart ve Kotlin olmak üzere yaklaşık 14.000 satır.

---

## 3. Bağımlılıklar ve kurulum

### Paketler (`pubspec.yaml`)

| Paket | Amaç |
|---|---|
| `flutter_localizations`, `intl` | Türkçe metinler, tarih ve sayı biçimi |
| `flutter_riverpod` ^2.6.1 | Durum yönetimi |
| `sqflite`, `path`, `path_provider` | Yerel veritabanı ve dosya yolları |
| `video_player` | Video oynatma (hız, döngü, tam ekran kontrolleri uygulamanın kendi kodu) |
| `image_picker` | İlerleme fotoğrafı (kamera/galeri) |
| `health` ^13 | Health Connect adım sayısı |
| `flutter_lints` (geliştirme) | Kod kuralları |

### Gerekli araçlar ve tahmini indirme boyutları

İnternetin kotalıysa bu adımları Wi-Fi'da yapmanı öneririm.

| Araç | Yaklaşık boyut |
|---|---|
| JDK 17 | 180 MB |
| Flutter SDK (sığ git klonu) | 700 MB – 1 GB |
| Android SDK komut satırı araçları ve platform | 600 MB – 1 GB |
| İlk Gradle derlemesi (Gradle, Android eklentisi, paketler) | 300–700 MB |
| `flutter pub get` | 20–40 MB |

İlk derlemeden sonra her şey önbellekte kalır, sonraki derlemeler çok az indirir.

1. **JDK 17:**
   ```bash
   winget install Microsoft.OpenJDK.17
   ```
2. **Flutter (stable).** `--depth 1` indirmeyi küçültür:
   ```bash
   git clone https://github.com/flutter/flutter.git -b stable --depth 1 C:\Users\Hakan\dev\flutter
   ```
   Ardından `C:\Users\Hakan\dev\flutter\bin` klasörünü PATH'e ekle.
3. **Android SDK.** Android Studio kurabilirsin. Daha küçük seçenek ise yalnızca "Command line tools" paketini indirip `C:\Users\Hakan\dev\android-sdk\cmdline-tools\latest` altına açmak. Sonra:
   ```bash
   flutter config --android-sdk C:\Users\Hakan\dev\android-sdk
   ```
   ```bash
   flutter doctor --android-licenses
   ```
   Lisanslar kabul edildiğinde eksik SDK parçalarını Gradle ilk derlemede kendisi indirir.
4. Kontrol:
   ```bash
   flutter doctor
   ```

### Projeyi hazırlama (bir kez)

GSU klasöründe çalıştır:

```bash
flutter create --org com.gsu --project-name gsu_fit --platforms android .
```
Bu komut yalnızca **eksik** Android dosyalarını üretir. Mevcut `lib/`, `pubspec.yaml`, `AndroidManifest.xml` ve `MainActivity.kt` dosyalarının üzerine yazmaz. `--org` ve `--project-name` değerlerini değiştirme, Kotlin paket adı bunlara bağlı.

```bash
dart run tool/patch_android.dart
```
`android/app/build.gradle.kts` dosyasına `minSdk 26` ve release imzalama ayarını ekler. Tekrar çalıştırmak güvenlidir.

```bash
flutter pub get
```

```bash
flutter analyze
```

```bash
flutter test
```

---

## 4. APK üretme

### Web sürümü

Aynı kod tarayıcı için de derlenir. Her gönderimde GitHub Pages'e yayınlanır: **https://vanti-png.github.io/gsu-fit/**. Telefonda tarayıcı menüsünden "Ana ekrana ekle" ile uygulama gibi kullanılabilir.

- **Veriler:** SQLite yerine tarayıcının kendi deposunda (localStorage) tutulur. `lib/core/web_store/json_store.dart` aynı tablo ve sütunları kullanır.
- **Yedek:** Web'de alınan JSON yedeği APK'ya, APK'nın yedeği de web'e aktarılabilir.
- **Tarayıcı verisini temizlemek** web'deki kayıtları siler. Düzenli yedek al.
- **Görseller ve videolar:** doğrudan internetten yüklenir, önbelleği tarayıcı tutar.
- **Yalnızca Android'de olanlar:** ilerleme fotoğrafları, bildirimler ve Health Connect adım sayısı. Web'de bu bölümler gizlenir ve açıklama gösterilir.

### Bulutta derleme (önerilen, kotalı internet için)

Hiçbir şey kurmadan APK almak için:

- Kod GitHub'daki gizli `Vanti-png/gsu-fit` deposundadır. `main` dalına her gönderimde (push) `.github/workflows/build-apk.yml` GitHub'ın sunucularında şu adımları çalıştırır:
  1. Flutter kurulumu
  2. `flutter create`
  3. `flutter analyze`
  4. `flutter test`
  5. `flutter build apk --release --split-per-abi`
- İndirilen tek şey hazır APK'dır, yaklaşık 20 MB. Çoğu telefon için `gsu-fit-arm64-v8a` yeterlidir. Çok eski 32 bit telefonlar için `gsu-fit-armeabi-v7a` kullanılır.
- **İndirme:** GitHub'da depo → Actions → son çalışma → Artifacts bölümünden. Komut satırından:
  ```bash
  gh run download --repo Vanti-png/gsu-fit --name gsu-fit-arm64-v8a
  ```
- **Elle tetikleme:** GitHub'da Actions → "APK derle" → "Run workflow".
- Bu APK debug anahtarıyla imzalıdır: kendi telefonuna kurmak için yeterli, Play Store için uygun değil. Mağaza için aşağıdaki keystore adımları uygulanmalı. Keystore şifreleri GitHub'da ancak "Secrets" olarak tutulmalı, dosya olarak depoya eklenmemeli.

### Debug APK

```bash
flutter build apk --debug
```
Çıktı: `build/app/outputs/flutter-apk/app-debug.apk`. Telefona kopyalayıp yükleyebilirsin. USB hata ayıklama açıksa `flutter install` veya `adb install` da kullanılabilir.

### Release APK (imzalı)

1. **Anahtar deposu (keystore) oluştur.** Bir kez yapılır. Dosyayı ve şifreleri güvenli bir yerde sakla: kaybedersen güncellemeleri aynı anahtarla imzalayamazsın.
   ```bash
   keytool -genkey -v -keystore C:\Users\Hakan\gsu-fit-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias gsufit
   ```
2. **`android/key.properties` dosyasını oluştur.** Bu dosya `.gitignore` içinde, paylaşma.
   ```properties
   storePassword=KEYSTORE_SIFREN
   keyPassword=ANAHTAR_SIFREN
   keyAlias=gsufit
   storeFile=C:/Users/Hakan/gsu-fit-release.jks
   ```
   Windows'ta da yolu `/` ile yaz.
3. **Derle.** ABI'ye göre bölmek dosyayı küçültür; çoğu telefon için `app-arm64-v8a-release.apk` yeterlidir:
   ```bash
   flutter build apk --release --split-per-abi
   ```
   Tek ve evrensel bir APK istersen:
   ```bash
   flutter build apk --release
   ```
   Çıktılar `build/app/outputs/flutter-apk/` klasörüne yazılır.

`key.properties` yoksa release derlemesi debug anahtarıyla imzalanır. Bu kurulum için çalışır ama mağaza dağıtımına uygun değildir.

`tool/patch_android.dart` imzalama ayarını ekleyemezse `android/app/build.gradle.kts` dosyasını elle düzenle:

```kotlin
import java.io.FileInputStream
import java.util.Properties
// plugins { ... } bloğundan sonra:
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) keystoreProperties.load(FileInputStream(keystorePropertiesFile))
// android { ... } içinde, buildTypes'tan önce:
signingConfigs {
    create("release") {
        keyAlias = keystoreProperties["keyAlias"] as String?
        keyPassword = keystoreProperties["keyPassword"] as String?
        storeFile = keystoreProperties["storeFile"]?.let { file(it) }
        storePassword = keystoreProperties["storePassword"] as String?
    }
}
// buildTypes { release { signingConfig = signingConfigs.getByName("release") } }
// defaultConfig içinde: minSdk = 26
```

### Sorun giderme

- **Paket sürüm çakışması:** `flutter pub upgrade` dene. `--major-versions` kullanma, çünkü `flutter_riverpod` 3 ve `health` 14+ kod değişikliği gerektirebilir.
- **Health Connect paketi derlenmezse:** adım özelliği isteğe bağlıdır. `pubspec.yaml` içinden `health:` satırını sil ve bana yaz, `steps_service.dart` dosyasını paketsiz bir sürümle değiştireyim. Uygulamanın geri kalanı etkilenmez.
- **Herhangi bir derleme hatası:** komut çıktısını olduğu gibi gönder.

---

## 5. Test kontrol listesi

### Otomatik testler

`flutter test` komutuyla çalışır:

- [ ] `progression_test.dart`: progressive overload (ilk antrenman, ağırlık/tekrar artışı, tekrar, deload, vücut ağırlığı ve süreli egzersiz) ve 1TM hesabı
- [ ] `program_generator_test.dart`: gün sayısı ve deneyime göre program bölünmesi, set/tekrar reçeteleri, başlangıç seviyesi için kolay egzersizler, benzersiz ID'ler
- [ ] `calculators_test.dart`: MET kalori, tempo, BMR, kalori/makro/su hedefleri
- [ ] `workout_stats_test.dart`: haftalık özet, haftalık hacim, egzersiz geçmişi, program tamamlanma yüzdesi, sıradaki gün
- [ ] `csv_and_text_test.dart`: CSV kodlama/çözme, birim dönüşümü, Türkçe sayı biçimi, Türkçe sıralama/arama, UUID, ayarların JSON gidiş-dönüşü
- [ ] `widget_test.dart`: ortak widget'lar ve grafikler

### Elle test

**İlk kurulum**
- [ ] İlk açılışta karşılama ekranı geliyor, "Başlayalım" ile profil adımlarına geçiliyor.
- [ ] Yaş, boy ve kilo doğrulaması çalışıyor (ör. yaş 5 kabul edilmiyor). kg/lb değişince kilo alanı dönüşüyor.
- [ ] Hedef, deneyim ve gün seçimi yapılıyor. Özet ekranında önerilen program görünüyor (ör. 4 gün → Üst/Alt).
- [ ] "Programımı oluştur" ile ana sayfa açılıyor ve "Bugünün antrenmanı" dolu geliyor.

**Antrenman**
- [ ] "Antrenmanı başlat" ile setler önerilen ağırlık ve tekrarla geliyor. Süre sayacı işliyor.
- [ ] Set ✓ işaretlenince dinlenme sayacı açılıyor. −15/+15/Atla çalışıyor, süre bitince titreşim ve mesaj geliyor.
- [ ] Telefonu kilitleyip dinlenme bitince bildirim geliyor (bildirim izni verildiyse).
- [ ] Set ekleme, sola kaydırarak set silme, egzersiz ekleme/çıkarma çalışıyor.
- [ ] Antrenman ortasında uygulama kapatılıp açılıyor. Alt kısımda "Devam eden antrenman" çıkıyor ve devam ediliyor.
- [ ] "Bitir" ile özet ekranı açılıyor. Geçmişte ve haftalık özette görünüyor.
- [ ] Aynı programla ikinci antrenmanda öneri değişiyor (ör. tüm setler 12 tekrar → ağırlık artışı önerisi).
- [ ] Geçmiş → "Kayıt ekle" → "Geçmiş antrenman" ile tarih ve süre girilerek kayıt yapılıyor.

**Programlar**
- [ ] Yeni program: profile göre, şablondan ve boş program seçenekleri çalışıyor. Önizleme görünüyor.
- [ ] Gün ekle/sil/sırala, egzersiz ekle/değiştir/sırala, set/tekrar/dinlenme/artış ayarı kaydediliyor.
- [ ] "Aktif program yap" ana sayfayı güncelliyor. Bu hafta ve genel tamamlanma yüzdeleri doğru.

**Kütüphane ve medya**
- [ ] Türkçe karakterli arama çalışıyor ("sinav" yazınca "Şınav" bulunuyor). Kas ve ekipman filtreleri çalışıyor.
- [ ] Egzersiz detayında görsel animasyonu, adım adım form, kaslar ve ekipman görünüyor.
- [ ] Uçak modunda daha önce açılmış görseller görünüyor. Açılmamışlarda anlaşılır "internet yok" mesajı ve "Tekrar dene" düğmesi var.
- [ ] Ayarlar → "Medyayı dokununca indir" açıkken görseller kendiliğinden inmiyor.
- [ ] Bir egzersize video bağlantısı ekleniyor. Test için `https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4` kullanılabilir.
- [ ] Video oynatıcıda oynat/duraklat, ileri-geri sarma, hız, döngü, baştan oynat ve tam ekran (yatay) çalışıyor.
- [ ] İkinci açılışta video internetsiz oynuyor. Geçersiz bağlantıda hata mesajı çıkıyor.
- [ ] Özel egzersiz ekleme, düzenleme ve silme çalışıyor.

**Kardiyo, ölçüm, fotoğraf**
- [ ] Kardiyo: tür, süre ve mesafe girilince kalori ve tempo otomatik hesaplanıyor. Elle değiştirilebiliyor.
- [ ] Ölçüm ekleme/düzenleme/silme çalışıyor. Yeni kilo profile yansıyor (kalori hedefi değişiyor).
- [ ] Grafikler: kilo, haftalık hacim, egzersiz kuvveti (1TM/ağırlık/hacim) ve çevre ölçüleri görünüyor. Dokununca değer gösteriliyor, zaman aralığı filtresi çalışıyor.
- [ ] Fotoğraf: kamera ve galeriden ekleniyor, büyütülerek görüntüleniyor, siliniyor. Galeri uygulamasında görünmüyor.
- [ ] Önce/sonra karşılaştırmasında tarih seçimi ve aradaki gün sayısı doğru.

**Beslenme**
- [ ] Su düğmeleri, özel miktar ve "son ekleneni geri al" çalışıyor. İlerleme çubuğu hedefe göre doluyor.
- [ ] Yiyecek ekleniyor. Kalori boşsa makrolardan hesaplanıyor. Kaydırarak silme ve geri alma çalışıyor.
- [ ] Önceki günlere geçiliyor, gelecek güne geçilemiyor.

**Ayarlar**
- [ ] Tema açık/koyu/sistem anında değişiyor. kg/lb tüm ekranlara yansıyor.
- [ ] Hatırlatıcı açılınca bildirim izni isteniyor. Reddedilirse anahtar kapalı kalıyor ve mesaj çıkıyor.
- [ ] Antrenman, su ve ölçüm hatırlatıcıları seçilen saatte geliyor. Telefon yeniden başlatılınca da geliyor.
- [ ] Health Connect: yüklü değilse yükleme önerisi, izin reddinde mesaj, izinle adım sayısı görünüyor.
- [ ] JSON yedek alınıyor. "Tüm verileri sil" sonrası aynı yedek içe aktarılınca veriler geri geliyor.
- [ ] CSV dışa aktarılan dosya Excel/Sheets'te Türkçe karakterlerle doğru açılıyor ve geri içe aktarılabiliyor.

**Erişilebilirlik ve tasarım**
- [ ] Sistem yazı boyutu en büyüğe alındığında ekranlar taşmıyor, metinler okunuyor.
- [ ] TalkBack açıkken düğmeler anlamlı okunuyor: ipuçları, gün noktaları, sayaç.
- [ ] Koyu temada kontrast yeterli. Alt navigasyon tek elle kullanılabiliyor.

---

## 6. Gelecekte eklenebilecekler

- **Bulut senkronizasyonu ve hesap:** Supabase veya Firebase ile `updated_at` tabanlı çift yönlü senkron. Çakışmada "son yazan kazanır" veya alan bazlı birleştirme. Fotoğraflar uçtan uca şifreli depolama ile.
- **Giyilebilir cihazlar:**
  - Health Connect'e antrenman ve kalori yazma.
  - Nabız ve uyku verisini okuma.
  - Wear OS uygulamasında set işaretleme ve dinlenme sayacı.
- **Sosyal:**
  - Arkadaşlarla program paylaşımı (QR veya bağlantı).
  - Haftalık hedef rozetleri.
  - İsteğe bağlı liderlik tablosu.
- **İngilizce dil:** `app_en.arb` ve cihaz diline göre seçim.
- **Beslenme:**
  - Barkod okuyucu ve yiyecek veritabanı (ör. Open Food Facts).
  - Favori ve tekrarlanan öğünler.
- **Antrenman:**
  - Süperset ve devre antrenmanı.
  - RPE/RIR girişi, plaka hesaplayıcı, ısınma seti önerisi.
  - Deload haftası planlama.
- **YouTube videoları:** gömülü oynatıcı paketiyle (ek indirme gerektirir).
- **Ana ekran widget'ı:** bugünün antrenmanı ve su.
- **Tam zamanlı hatırlatıcılar:** SCHEDULE_EXACT_ALARM izniyle.
- **Gizlilik:** biyometrik uygulama kilidi, şifreli yedek dosyası.
- **iOS sürümü:** aynı Flutter kodu, HealthKit entegrasyonu ve iOS bildirimleri.
