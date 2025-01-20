import 'dart:typed_data';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';

class CustomAudioSource extends StreamAudioSource {
  final Uint8List _buffer;
  
  CustomAudioSource(this._buffer);
  
  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= _buffer.length;

    try {
      return StreamAudioResponse(
        sourceLength: _buffer.length,
        contentLength: end - start,
        offset: start,
        contentType: 'audio/mpeg',
        stream: Stream.value(_buffer.sublist(start, end)),
      );
    } catch (e) {
      if (kDebugMode) {
        print('CustomAudioSource error: $e');
      }
      rethrow;
    }
  }
}