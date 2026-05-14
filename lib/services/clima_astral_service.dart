import 'package:video_player/video_player.dart';

class ClimaAstralService {
  ClimaAstralService._();
  static final ClimaAstralService instance = ClimaAstralService._();

  VideoPlayerController? _ctrl;

  static const _url =
      'https://firebasestorage.googleapis.com/v0/b/astro-fd0bf.firebasestorage.app/o/Assets%2Fclima%20astral.mp4?alt=media&token=77961731-1d89-445f-af1d-e80c3058dfd1';

  Future<void> precargar() async {
    try {
      _ctrl = VideoPlayerController.networkUrl(Uri.parse(_url))
        ..setLooping(true)
        ..setVolume(0);
      await _ctrl!.initialize();
      // ignore: avoid_print
      print('[ClimaAstralService] video listo: ${_ctrl!.value.isInitialized}');
    } catch (e) {
      // ignore: avoid_print
      print('[ClimaAstralService] error al precargar: $e');
      _ctrl = null;
    }
  }

  VideoPlayerController? get controller => _ctrl;
}
