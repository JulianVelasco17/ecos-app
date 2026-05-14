import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../services/ouroboros_service.dart';

class OuroborosLoader extends StatefulWidget {
  final double size;
  const OuroborosLoader({super.key, this.size = 120});

  @override
  State<OuroborosLoader> createState() => _OuroborosLoaderState();
}

class _OuroborosLoaderState extends State<OuroborosLoader> {
  VideoPlayerController? _ctrl;
  bool _listo = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final cached = OuroborosService.instance.controller;
    if (cached != null && cached.value.isInitialized) {
      _ctrl = cached;
      _ctrl!.play();
      if (mounted) setState(() => _listo = true);
      return;
    }

    // Fallback: inicializar aquí si el singleton no está listo
    await OuroborosService.instance.precargar();
    final ctrl = OuroborosService.instance.controller;
    if (ctrl != null && mounted) {
      _ctrl = ctrl;
      _ctrl!.play();
      setState(() => _listo = true);
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_listo || _ctrl == null) {
      return SizedBox(width: widget.size, height: widget.size);
    }

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _ctrl!.value.size.width,
          height: _ctrl!.value.size.height,
          child: VideoPlayer(_ctrl!),
        ),
      ),
    );
  }
}
