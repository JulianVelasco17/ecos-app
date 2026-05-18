import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import '../widgets/ouroboros_loader.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/calculos_astrales.dart';
import '../services/aspectos_natales.dart';
import '../services/claude_service.dart';

class PantallaLecturaCartaAstral extends StatefulWidget {
  final VideoPlayerController? videoPreload;
  const PantallaLecturaCartaAstral({super.key, this.videoPreload});

  static void navigateTo(BuildContext context, Offset origin,
      {VideoPlayerController? videoPreload}) {
    Navigator.pushReplacement(
      context,
      _CartaRevealRoute(origin: origin, videoPreload: videoPreload),
    );
  }

  @override
  State<PantallaLecturaCartaAstral> createState() => _PantallaLecturaCartaAstralState();
}

class _PantallaLecturaCartaAstralState extends State<PantallaLecturaCartaAstral> {
  bool _cargando = true;
  Map<String, String> _lectura = {};
  String _errorMsg = '';
  String _nombre = '';

  bool _videoTerminado = false;
  double _fadeNegroOpacity = 0.0;
  double _fraseOpacity = 0.0;

  double _arrowOpacity = 1.0;
  final ScrollController _scrollCtrl = ScrollController();

  static const _beige = Color(0xFFF3EBD6);
  static const _gold  = Color(0xFFB8973A);

  @override
  void initState() {
    super.initState();
    _cargar();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    final offset = _scrollCtrl.offset;
    final opacity = (1.0 - (offset / 60.0)).clamp(0.0, 1.0);
    if ((opacity - _arrowOpacity).abs() > 0.01) {
      setState(() => _arrowOpacity = opacity);
    }
  }

  Future<void> _cargar() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        if (mounted) setState(() => _cargando = false);
        return;
      }

      final userDoc = await FirebaseFirestore.instance.collection('usuarios').doc(uid).get();
      if (!mounted || !userDoc.exists) {
        setState(() => _cargando = false);
        return;
      }
      final datos = userDoc.data()!;
      _nombre = (datos['nombre'] as String? ?? '').split(' ').first;

      final cache = await FirebaseFirestore.instance
          .collection('lecturasProfundas').doc('${uid}_carta_v3').get();

      if (cache.exists) {
        final extraido = _extraer(cache.data()!);
        if (extraido.values.any((v) => v.isNotEmpty)) {
          if (mounted) setState(() { _lectura = extraido; _cargando = false; });
          return;
        }
      }

      final fechaTs = datos['fechaNacimiento'];
      if (fechaTs == null) {
        if (mounted) setState(() {
          _cargando = false;
          _errorMsg = 'Necesitamos tu fecha de nacimiento para generar tu lectura. Completa tu perfil primero.';
        });
        return;
      }
      final fecha = (fechaTs as Timestamp).toDate();
      final horaParts = ((datos['horaNacimiento'] as String?) ?? '12:00').split(':');
      final hora = int.tryParse(horaParts[0]) ?? 12;
      final min  = int.tryParse(horaParts.length > 1 ? horaParts[1] : '0') ?? 0;
      final lat  = (datos['latitud']  as num?)?.toDouble() ?? 0.0;
      final lon  = (datos['longitud'] as num?)?.toDouble() ?? 0.0;

      final carta = CalculosAstrales.calcular(
          fechaNacimiento: fecha, hora: hora, minutos: min, latitud: lat, longitud: lon);
      final aspectos = AspectosNatales.calcular(fecha, hora, min);
      final etiquetas = aspectos.map((a) =>
          '${a.planeta1} ${a.tipo} ${a.planeta2} (orbe ${a.orbe.toStringAsFixed(1)}°)').toList();

      final rawStr = await ClaudeService.generarLecturaCartaProfunda(
        nombre:     datos['nombre'] as String? ?? '',
        signoSolar: carta.signoSolar,
        signoLunar: carta.signoLunar,
        ascendente: carta.ascendente,
        aspectos:   etiquetas,
        planetas:   carta.planetas,
      );

      Map<String, String> lectura = {};
      try {
        final start = rawStr.indexOf('{');
        final end   = rawStr.lastIndexOf('}');
        final json  = jsonDecode(rawStr.substring(start, end + 1)) as Map<String, dynamic>;
        lectura = _extraer(json);
      } catch (_) {
        lectura = {'big3': rawStr};
      }

      if (lectura.values.any((v) => v.isNotEmpty)) {
        await FirebaseFirestore.instance
            .collection('lecturasProfundas').doc('${uid}_carta_v3')
            .set({...lectura, 'fecha': FieldValue.serverTimestamp()});
      }

      if (mounted) setState(() { _lectura = lectura; _cargando = false; });
    } catch (e) {
      if (mounted) setState(() { _cargando = false; _errorMsg = e.toString(); });
    }
  }

  Map<String, String> _extraer(Map<String, dynamic> raw) => {
    for (final k in ['frase', 'big3', 'aspectos', 'amor', 'amistad', 'suerte', 'familia', 'dinero'])
      k: raw[k] as String? ?? '',
  };

  Future<void> _onVideoTerminado() async {
    setState(() => _fadeNegroOpacity = 1.0);
    await Future.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;
    setState(() { _videoTerminado = true; _fraseOpacity = 1.0; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _CartaVideo(onTerminado: _onVideoTerminado, preload: widget.videoPreload),

          AnimatedOpacity(
            opacity: _fadeNegroOpacity,
            duration: const Duration(milliseconds: 1000),
            child: const ColoredBox(color: Colors.black),
          ),

          if (_videoTerminado)
            AnimatedOpacity(
              opacity: _fraseOpacity,
              duration: const Duration(milliseconds: 1000),
              child: SafeArea(
                child: Stack(
                  children: [
                    // Scrollable content: frase page + reading
                    SingleChildScrollView(
                      controller: _scrollCtrl,
                      child: Column(
                        children: [
                          // Frase — full screen height
                          SizedBox(
                            height: MediaQuery.of(context).size.height,
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 40),
                                child: _cargando
                                    ? const OuroborosLoader(size: 80)
                                    : (!_cargando && _lectura.values.every((v) => v.isEmpty))
                                        ? Column(mainAxisSize: MainAxisSize.min, children: [
                                            Text('no se pudo generar la lectura',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(color: _beige.withValues(alpha: 0.6), fontSize: 15, height: 1.6)),
                                            if (_errorMsg.isNotEmpty) ...[
                                              const SizedBox(height: 12),
                                              Text(_errorMsg, textAlign: TextAlign.center,
                                                  style: TextStyle(color: _beige.withValues(alpha: 0.25), fontSize: 11)),
                                            ],
                                            const SizedBox(height: 28),
                                            TextButton(
                                              onPressed: () { setState(() { _cargando = true; _errorMsg = ''; }); _cargar(); },
                                              child: Text('intentar de nuevo',
                                                  style: TextStyle(color: _gold, letterSpacing: 1.5, fontSize: 12)),
                                            ),
                                          ])
                                        : Text(
                                            _nombre.isNotEmpty
                                                ? '$_nombre,\n${_lectura['frase'] ?? ''}'
                                                : (_lectura['frase'] ?? ''),
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.playfairDisplay(
                                              color: _beige,
                                              fontSize: 28,
                                              fontWeight: FontWeight.w400,
                                              fontStyle: FontStyle.italic,
                                              height: 1.4,
                                            ),
                                          ),
                              ),
                            ),
                          ),

                          // Full reading sections
                          if (!_cargando && _lectura.values.any((v) => v.isNotEmpty))
                            _LecturaCompleta(lectura: _lectura, beige: _beige, gold: _gold),
                        ],
                      ),
                    ),

                    // Debug button
                    Positioned(
                      top: 12, right: 20,
                      child: GestureDetector(
                        onTap: () async {
                          final uid = FirebaseAuth.instance.currentUser?.uid;
                          if (uid == null) return;
                          await FirebaseFirestore.instance
                              .collection('lecturasProfundas')
                              .doc('${uid}_carta_v3')
                              .delete();
                          setState(() {
                            _cargando = true; _lectura = {}; _errorMsg = '';
                            _videoTerminado = false; _fadeNegroOpacity = 0.0;
                            _fraseOpacity = 0.0; _arrowOpacity = 1.0;
                          });
                          _cargar();
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text('debug ↺',
                              style: TextStyle(color: _gold.withValues(alpha: 0.4), fontSize: 11, letterSpacing: 1)),
                        ),
                      ),
                    ),

                    // Scroll indicator
                    if (!_cargando && _lectura.values.any((v) => v.isNotEmpty))
                      Positioned(
                        bottom: 28,
                        left: 0, right: 0,
                        child: AnimatedOpacity(
                          opacity: _arrowOpacity,
                          duration: const Duration(milliseconds: 200),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.keyboard_arrow_down,
                                  color: _beige.withValues(alpha: 0.4), size: 22),
                              const SizedBox(height: 2),
                              Text('desliza para leer',
                                style: TextStyle(
                                  color: _beige.withValues(alpha: 0.35),
                                  fontSize: 10,
                                  letterSpacing: 2.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Lectura completa ──────────────────────────────────────────────────────────

class _LecturaCompleta extends StatelessWidget {
  final Map<String, String> lectura;
  final Color beige;
  final Color gold;
  const _LecturaCompleta({required this.lectura, required this.beige, required this.gold});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 60),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Divider(gold: gold),
          if ((lectura['big3'] ?? '').isNotEmpty) ...[
            _SeccionCard(titulo: 'tu big 3', cuerpo: lectura['big3']!, beige: beige, gold: gold),
            const SizedBox(height: 28),
          ],
          if ((lectura['aspectos'] ?? '').isNotEmpty) ...[
            _SeccionCard(titulo: 'aspectos natales', cuerpo: lectura['aspectos']!, beige: beige, gold: gold),
            const SizedBox(height: 28),
          ],
          _TituloSeccion(texto: 'ámbitos', gold: gold),
          const SizedBox(height: 20),
          for (final entry in [
            ('amor',     '♡'),
            ('amistad',  '◦'),
            ('suerte',   '✦'),
            ('familia',  '◈'),
            ('dinero',   '◇'),
          ])
            if ((lectura[entry.$1] ?? '').isNotEmpty) ...[
              _AmbCard(
                simbolo: entry.$2,
                titulo: entry.$1,
                cuerpo: lectura[entry.$1]!,
                beige: beige,
                gold: gold,
              ),
              const SizedBox(height: 16),
            ],
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  final Color gold;
  const _Divider({required this.gold});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 40),
    child: Row(children: [
      Expanded(child: Divider(color: gold.withValues(alpha: 0.25), thickness: 0.5)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text('✦', style: TextStyle(color: gold.withValues(alpha: 0.4), fontSize: 12)),
      ),
      Expanded(child: Divider(color: gold.withValues(alpha: 0.25), thickness: 0.5)),
    ]),
  );
}

class _TituloSeccion extends StatelessWidget {
  final String texto;
  final Color gold;
  const _TituloSeccion({required this.texto, required this.gold});
  @override
  Widget build(BuildContext context) => Text(
    texto.toUpperCase(),
    style: TextStyle(color: gold.withValues(alpha: 0.7), fontSize: 10, letterSpacing: 3),
  );
}

class _SeccionCard extends StatelessWidget {
  final String titulo;
  final String cuerpo;
  final Color beige;
  final Color gold;
  const _SeccionCard({required this.titulo, required this.cuerpo, required this.beige, required this.gold});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TituloSeccion(texto: titulo, gold: gold),
        const SizedBox(height: 14),
        Text(cuerpo,
            style: TextStyle(color: beige.withValues(alpha: 0.85), fontSize: 15, height: 1.75)),
      ],
    );
  }
}

class _AmbCard extends StatelessWidget {
  final String simbolo;
  final String titulo;
  final String cuerpo;
  final Color beige;
  final Color gold;
  const _AmbCard({required this.simbolo, required this.titulo, required this.cuerpo,
      required this.beige, required this.gold});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border.all(color: gold.withValues(alpha: 0.18), width: 0.5),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(simbolo, style: TextStyle(color: gold.withValues(alpha: 0.6), fontSize: 14)),
            const SizedBox(width: 10),
            Text(titulo.toUpperCase(),
                style: TextStyle(color: gold.withValues(alpha: 0.6), fontSize: 10, letterSpacing: 2.5)),
          ]),
          const SizedBox(height: 12),
          Text(cuerpo, style: TextStyle(color: beige.withValues(alpha: 0.8), fontSize: 14, height: 1.7)),
        ],
      ),
    );
  }
}

// ── Video de fondo ────────────────────────────────────────────────────────────

class _CartaVideo extends StatefulWidget {
  final VoidCallback onTerminado;
  final VideoPlayerController? preload;
  const _CartaVideo({required this.onTerminado, this.preload});

  @override
  State<_CartaVideo> createState() => _CartaVideoState();
}

class _CartaVideoState extends State<_CartaVideo> {
  VideoPlayerController? _ctrl;
  double _opacidad = 0.0;
  bool _llamado = false;
  Timer? _hapticTimer;

  static const _url =
      'https://firebasestorage.googleapis.com/v0/b/astro-fd0bf.firebasestorage.app/o/Assets%2Fsolinvert.mov?alt=media&token=459f6a7d-0890-4f3a-8656-9937d323b7fa';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    VideoPlayerController ctrl;
    if (widget.preload != null && widget.preload!.value.isInitialized) {
      ctrl = widget.preload!;
    } else {
      ctrl = VideoPlayerController.networkUrl(Uri.parse(_url));
      await ctrl.setLooping(false);
      await ctrl.setVolume(0);
      await ctrl.initialize();
    }
    if (!mounted) { if (widget.preload == null) ctrl.dispose(); return; }
    await ctrl.setLooping(false);
    await ctrl.setVolume(0);
    _ctrl = ctrl;
    ctrl.addListener(_checkFin);
    await ctrl.play();
    if (!mounted) return;
    setState(() => _opacidad = 1.0);
    _hapticTimer = Timer.periodic(const Duration(milliseconds: 1800), (_) {
      if (mounted) HapticFeedback.lightImpact();
    });
  }

  void _checkFin() {
    if (_llamado) return;
    final c = _ctrl;
    if (c == null) return;
    if (c.value.duration > Duration.zero &&
        c.value.position >= c.value.duration - const Duration(milliseconds: 700)) {
      _llamado = true;
      _hapticTimer?.cancel();
      widget.onTerminado();
    }
  }

  @override
  void dispose() {
    _hapticTimer?.cancel();
    _ctrl?.removeListener(_checkFin);
    // Only dispose if we own the controller (not the preloaded one)
    if (widget.preload == null || _ctrl != widget.preload) {
      _ctrl?.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = _ctrl;
    return AnimatedOpacity(
      opacity: _opacidad,
      duration: const Duration(milliseconds: 800),
      child: ctrl != null && ctrl.value.isInitialized
          ? SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: ctrl.value.size.width,
                  height: ctrl.value.size.height,
                  child: VideoPlayer(ctrl),
                ),
              ),
            )
          : const ColoredBox(color: Colors.black),
    );
  }
}

// ── Circular reveal route ─────────────────────────────────────────────────────

class _CartaRevealRoute extends PageRoute<void> {
  final Offset origin;
  final VideoPlayerController? videoPreload;
  _CartaRevealRoute({required this.origin, this.videoPreload});

  @override Duration get transitionDuration => const Duration(milliseconds: 700);
  @override Color get barrierColor => Colors.transparent;
  @override String get barrierLabel => '';
  @override bool get maintainState => true;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation) =>
      PantallaLecturaCartaAstral(videoPreload: videoPreload);

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final size = MediaQuery.of(context).size;
        final maxRadius = sqrt(size.width * size.width + size.height * size.height);
        final radius = Curves.easeInOut.transform(animation.value) * maxRadius;
        return ClipPath(
          clipper: _CircleClipper(center: origin, radius: radius),
          child: child,
        );
      },
    );
  }
}

class _CircleClipper extends CustomClipper<Path> {
  final Offset center;
  final double radius;
  const _CircleClipper({required this.center, required this.radius});

  @override
  Path getClip(Size size) =>
      Path()..addOval(Rect.fromCircle(center: center, radius: radius));

  @override
  bool shouldReclip(_CircleClipper old) =>
      old.center != center || old.radius != radius;
}
