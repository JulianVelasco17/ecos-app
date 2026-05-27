import 'package:video_player/video_player.dart';

class EcosPlusVideoService {
  EcosPlusVideoService._();
  static final EcosPlusVideoService instance = EcosPlusVideoService._();

  VideoPlayerController? _ctrl;

  static const _url =
      'https://firebasestorage.googleapis.com/v0/b/astro-fd0bf.firebasestorage.app/o/Assets%2Ffondo.mp4?alt=media&token=ffe0ff5e-a14f-4bdf-ae8f-a4aadeddcd63';

  Future<void> precargar() async {
    try {
      _ctrl = VideoPlayerController.networkUrl(Uri.parse(_url))
        ..setLooping(true)
        ..setVolume(0);
      await _ctrl!.initialize();
    } catch (e) {
      _ctrl = null;
    }
  }

  VideoPlayerController? get controller => _ctrl;

  void liberar() {
    _ctrl?.dispose();
    _ctrl = null;
  }
}
