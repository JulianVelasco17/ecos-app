import 'package:video_player/video_player.dart';

class OuroborosService {
  OuroborosService._();
  static final OuroborosService instance = OuroborosService._();

  VideoPlayerController? _ctrl;

  static const _url =
      'https://firebasestorage.googleapis.com/v0/b/astro-fd0bf.firebasestorage.app/o/Assets%2Fouroboros.mp4?alt=media&token=1c134c52-db2b-4531-8411-a06342829f03';

  Future<void> precargar() async {
    try {
      _ctrl = VideoPlayerController.networkUrl(Uri.parse(_url))
        ..setLooping(true)
        ..setVolume(0);
      await _ctrl!.initialize();
      // ignore: avoid_print
      print('[OuroborosService] video listo: ${_ctrl!.value.isInitialized}');
    } catch (e) {
      // ignore: avoid_print
      print('[OuroborosService] error al precargar: $e');
      _ctrl = null;
    }
  }

  VideoPlayerController? get controller => _ctrl;
}
