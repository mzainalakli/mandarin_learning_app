import 'dart:io';

import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  TtsService._();
  static final TtsService instance = TtsService._();

  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;

  Future<void> _ensureInit() async {
    if (_initialized) return;
    _initialized = true;
    await _tts.setLanguage('zh-CN');
    await _tts.setSpeechRate(0.45);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    if (Platform.isAndroid) {
      await _tts.setEngine('com.google.android.tts');
    }
  }

  Future<void> speak(String text) async {
    await _ensureInit();
    await _tts.stop();
    await _tts.speak(text);
  }
}
