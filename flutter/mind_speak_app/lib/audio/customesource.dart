// lib/audio/custom_audio_source.dart

import 'package:just_audio/just_audio.dart';

class CustomAudioSource extends StreamAudioSource {
  final List<int> bytes;

  CustomAudioSource(this.bytes);

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= bytes.length;

    return StreamAudioResponse(
      sourceLength: bytes.length,
      contentLength: end - start,
      offset: start,
      stream: Stream.value(bytes.sublist(start, end)),
      contentType: 'audio/mpeg',
    );
  }
}
