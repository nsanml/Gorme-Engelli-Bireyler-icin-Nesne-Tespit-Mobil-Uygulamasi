# Edge AI Based Visual Assistant for Visually Impaired Individuals

Bu proje, görme engelli bireylerin çevrelerini daha kolay algılayabilmesi için geliştirilen Edge AI tabanlı mobil destek uygulamasıdır. Sistem, kamera üzerinden gerçek zamanlı nesne tespiti yaparak kullanıcıya sesli geri bildirim sağlar.

## Özellikler

* Gerçek zamanlı nesne algılama
* TensorFlow Lite ile Edge AI entegrasyonu
* Sesli geri bildirim (Text-to-Speech)
* Kamera üzerinden canlı analiz
* Mobil cihaz üzerinde offline çalışma
* Erişilebilirlik odaklı kullanım

## Kullanılan Teknolojiler

* Flutter
* Dart
* TensorFlow Lite
* Text-to-Speech (TTS)
* Camera Package

## Çalışma Mantığı

1. Mobil cihaz kamerası aktif edilir.
2. Kamera görüntüsü gerçek zamanlı olarak işlenir.
3. TensorFlow Lite modeli nesneleri tespit eder.
4. Algılanan nesne sınıflandırılır.
5. Sistem nesne bilgisini kullanıcıya sesli olarak iletir.

## Proje Yapısı

```text id="1vxckh"
blind-assistant/
│── README.md
│── pubspec.yaml
│── lib/
│   │── main.dart
│   │── screens/
│   │   └── camera_screen.dart
│   │── services/
│   │   ├── feature_extractor_service.dart
│   │   └── tts_service.dart
│── assets/
│   │── models/
│   │   └── detect.tflite
│   │── labels/
│   │   └── labelmap.txt
```

## Kullanım

Bağımlılıkları yüklemek için:

```bash id="rl65ms"
flutter pub get
```

Uygulamayı çalıştırmak için:

```bash id="q3stik"
flutter run
```

## Amaç

Bu proje, görme engelli bireylerin çevresel farkındalığını artırmak ve günlük yaşamda bağımsız hareket kabiliyetlerini desteklemek amacıyla geliştirilmiştir.
