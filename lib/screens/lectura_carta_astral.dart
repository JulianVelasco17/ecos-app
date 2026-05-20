import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
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
import 'constelacion_widget.dart';

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
  Map<String, String> _planetas = {};
  String _errorMsg = '';
  String _nombre = '';
  String? _signoSolar;
  String? _signoLunar;
  String? _ascendente;

  bool _videoTerminado = false;
  bool _saltarVideo    = false;
  double _fadeNegroOpacity = 0.0;
  double _fraseOpacity = 0.0;

  double _arrowOpacity = 1.0;
  final ScrollController _scrollCtrl = ScrollController();

  static const _beige = Color(0xFFF3EBD6);
  static const _gold  = Color(0xFFB8973A);

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    Future.wait([_cargar(), _verificarVideoVisto()]);
  }

  Future<void> _verificarVideoVisto() async {
    final prefs = await SharedPreferences.getInstance();
    final visto = prefs.getBool('carta_astral_video_visto') ?? false;
    if (visto && mounted) {
      setState(() {
        _saltarVideo    = true;
        _videoTerminado = true;
        _fraseOpacity   = 1.0;
      });
    }
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

      if (cache.exists) {
        final extraido = _extraer(cache.data()!);
        if (extraido.values.any((v) => v.isNotEmpty)) {
          if (mounted) setState(() {
            _lectura    = extraido;
            _planetas   = carta.planetas;
            _signoSolar = extraido['signoSolar']?.isNotEmpty == true
                ? extraido['signoSolar'] : carta.signoSolar;
            _signoLunar = extraido['signoLunar']?.isNotEmpty == true
                ? extraido['signoLunar'] : carta.signoLunar;
            _ascendente = extraido['ascendente']?.isNotEmpty == true
                ? extraido['ascendente'] : carta.ascendente;
            _cargando   = false;
          });
          return;
        }
      }
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
        final clean = rawStr.replaceAll(RegExp(r'```[a-z]*', caseSensitive: false), '').replaceAll('```', '');
        final start = clean.indexOf('{');
        final end   = clean.lastIndexOf('}');
        final json  = jsonDecode(clean.substring(start, end + 1)) as Map<String, dynamic>;
        lectura = _extraer(json);
      } catch (_) {
        lectura = {'big3_p1': rawStr};
      }

      if (lectura.values.any((v) => v.isNotEmpty)) {
        await FirebaseFirestore.instance
            .collection('lecturasProfundas').doc('${uid}_carta_v3')
            .set({
              ...lectura,
              'signoSolar': carta.signoSolar,
              'signoLunar': carta.signoLunar,
              'ascendente': carta.ascendente,
              'fecha': FieldValue.serverTimestamp(),
            });
      }

      if (mounted) {
        setState(() {
          _lectura    = lectura;
          _planetas   = carta.planetas;
          _signoSolar = carta.signoSolar;
          _signoLunar = carta.signoLunar;
          _ascendente = carta.ascendente;
          _cargando   = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _cargando = false; _errorMsg = e.toString(); });
    }
  }

  Map<String, String> _extraer(Map<String, dynamic> raw) => {
    for (final k in ['frase', 'big3_p1', 'big3_p2', 'aspectos', 'virtudes', 'defectos', 'amor', 'amistad', 'suerte', 'familia', 'dinero', 'futuro',
                     'signoSolar', 'signoLunar', 'ascendente'])
      k: raw[k] as String? ?? '',
  };

  Future<void> _onVideoTerminado() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('carta_astral_video_visto', true);
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
          const Positioned.fill(child: CieloEstrellado()),
          if (!_saltarVideo) ...[
            _CartaVideo(onTerminado: _onVideoTerminado, preload: widget.videoPreload),
            AnimatedOpacity(
              opacity: _fadeNegroOpacity,
              duration: const Duration(milliseconds: 1000),
              child: const ColoredBox(color: Colors.black),
            ),
          ],

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
                            child: Stack(
                              children: [
                                Positioned(
                                  bottom: 60,
                                  left: 0,
                                  child: IgnorePointer(
                                    child: _FadeImage(
                                      url: 'https://firebasestorage.googleapis.com/v0/b/astro-fd0bf.firebasestorage.app/o/Assets%2Fcaida.png?alt=media&token=282fd473-8770-4532-8903-05ed896d238f',
                                      width: 200,
                                      color: const Color(0xFFE7D8C9).withValues(alpha: 0.55),
                                      colorBlendMode: BlendMode.srcIn,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 40,
                                  right: 0,
                                  child: IgnorePointer(
                                    child: _FadeImage(
                                      url: 'https://firebasestorage.googleapis.com/v0/b/astro-fd0bf.firebasestorage.app/o/Assets%2Fsun.png?alt=media&token=0b845a52-0477-4bc6-960c-64fd6e23111d',
                                      width: 180,
                                      color: const Color(0xFFE7D8C9).withValues(alpha: 0.55),
                                      colorBlendMode: BlendMode.srcIn,
                                    ),
                                  ),
                                ),
                                Center(
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
                              ],
                            ),
                          ),

                          // Full reading sections
                          if (!_cargando && _lectura.values.any((v) => v.isNotEmpty))
                            _LecturaCompleta(
                              lectura:    _lectura,
                              planetas:   _planetas,
                              beige:      _beige,
                              gold:       _gold,
                              signoSolar: _signoSolar,
                              signoLunar: _signoLunar,
                              ascendente: _ascendente,
                            ),
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
  final Map<String, String> planetas;
  final Color beige;
  final Color gold;
  final String? signoSolar;
  final String? signoLunar;
  final String? ascendente;

  const _LecturaCompleta({
    required this.lectura,
    required this.planetas,
    required this.beige,
    required this.gold,
    this.signoSolar,
    this.signoLunar,
    this.ascendente,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
      Padding(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Divider(gold: gold),
          if (signoSolar != null || (lectura['big3_p1'] ?? '').isNotEmpty) ...[
            Center(child: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: const TextStyle(fontFamily: 'PlayfairDisplay', fontSize: 22, fontWeight: FontWeight.w400, height: 1.3),
                  children: [
                    TextSpan(text: 'Tu ', style: TextStyle(color: beige.withValues(alpha: 0.9))),
                    TextSpan(text: 'esencia', style: TextStyle(color: gold)),
                    TextSpan(text: ', en tres.', style: TextStyle(color: beige.withValues(alpha: 0.9))),
                  ],
                ))),
            const SizedBox(height: 10),
            Center(child: Text('Tu Sol, tu Luna y tu Ascendente revelan cómo eres,\ncómo sientes y cómo te muestras al mundo.',
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(color: beige.withValues(alpha: 0.4), fontSize: 13, height: 1.6))),
            const SizedBox(height: 28),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF0D0D0D),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: gold.withValues(alpha: 0.35), width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (signoSolar != null) ...[
                    Center(child: Text('TU BIG 3', style: TextStyle(
                      fontFamily: 'PlayfairDisplay',
                      color: gold.withValues(alpha: 0.9),
                      fontSize: 20, letterSpacing: 3, fontWeight: FontWeight.w700))),
                    const SizedBox(height: 20),
                    _Big3Row(solar: signoSolar!, lunar: signoLunar!, ascendente: ascendente!),
                    const SizedBox(height: 20),
                    Center(child: Text('Así se mezclan los tres en ti.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.manrope(color: beige.withValues(alpha: 0.6), fontSize: 12, letterSpacing: 1.5, height: 1.5, fontStyle: FontStyle.italic))),
                    const SizedBox(height: 24),
                  ],
                  if ((lectura['big3_p1'] ?? '').isNotEmpty || (lectura['big3_p2'] ?? '').isNotEmpty) ...[
                    if ((lectura['big3_p2'] ?? '').isNotEmpty)
                      _TextoCarta(texto: lectura['big3_p2']!, color: beige.withValues(alpha: 0.85)),
                    if ((lectura['big3_p1'] ?? '').isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _TextoCarta(texto: lectura['big3_p1']!, color: beige.withValues(alpha: 0.85)),
                    ],
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 28),
          if ((lectura['virtudes'] ?? '').isNotEmpty) ...[
            _VirtudesDefectos(titulo: 'tus virtudes', subtitulo: 'Lo que te impulsa hacia adelante.', texto: lectura['virtudes']!, beige: beige, gold: gold),
            const SizedBox(height: 28),
          ],
          if ((lectura['defectos'] ?? '').isNotEmpty) ...[
            _VirtudesDefectos(titulo: 'tus sombras', subtitulo: 'Lo que te frena cuando no lo observas.', texto: lectura['defectos']!, beige: beige, gold: gold, esSombras: true),
            const SizedBox(height: 20),
          ],
          Stack(
            clipBehavior: Clip.none,
            children: [
              // nube primero = detrás de todo
              Positioned(
                bottom: -100,
                right: -10,
                child: IgnorePointer(
                  child: _FadeImage(
                    url: 'https://firebasestorage.googleapis.com/v0/b/astro-fd0bf.firebasestorage.app/o/Assets%2Fnube.png?alt=media&token=a0fcb73b-1bc0-4989-8d4a-3da163ff4a50',
                    width: 200,
                    color: const Color(0xFFE7D8C9).withValues(alpha: 0.45),
                    colorBlendMode: BlendMode.srcIn,
                  ),
                ),
              ),
              // columna encima = tarjeta tapa la nube
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if ((lectura['aspectos'] ?? '').isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D0D0D),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: beige.withValues(alpha: 0.1), width: 1),
                      ),
                      child: _TextoCarta(texto: lectura['aspectos']!, color: beige.withValues(alpha: 0.65)),
                    ),
                    const SizedBox(height: 36),
                  ],
                  _TituloSeccion(texto: 'ámbitos', gold: gold, fontSize: 24),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          _AmbitosSection(
            lectura: lectura,
            planetas: planetas,
            beige: beige,
            gold: gold,
          ),
          if ((lectura['futuro'] ?? '').isNotEmpty) ...[
            const SizedBox(height: 48),
            _FuturoSection(texto: lectura['futuro']!, beige: beige, gold: gold),
          ],
        ],
      ),
      ),
      // imagen future y despedida fuera del padding — ancho completo
      const SizedBox(height: 60),
      Center(
        child: IgnorePointer(
          child: _FadeImage(
            url: 'https://firebasestorage.googleapis.com/v0/b/astro-fd0bf.firebasestorage.app/o/Assets%2Ffuture.png?alt=media&token=3c7588f6-ebae-4ad0-9afb-cdea5c8c8aa5',
            width: 320,
            color: const Color(0xFFE7D8C9).withValues(alpha: 0.55),
            colorBlendMode: BlendMode.srcIn,
          ),
        ),
      ),
      const SizedBox(height: 60),
      Builder(builder: (context) {
        final screenW = MediaQuery.of(context).size.width;
        final screenH = MediaQuery.of(context).size.height;
        return ClipPath(
          clipper: _DespedidaClipper(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: screenH * 0.80, minWidth: screenW),
            child: Container(
              width: screenW,
              color: const Color(0xFFF0EBE3),
              padding: const EdgeInsets.fromLTRB(28, 52, 28, 60),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Gracias por dejarnos acompañarte en esta lectura.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontFamily: 'PlayfairDisplay',
                        color: const Color(0xFF1A1410),
                        fontSize: 22,
                        fontWeight: FontWeight.w400,
                        height: 1.8,
                        letterSpacing: 0.3),
                  ),
                  const SizedBox(height: 36),
                  Text(
                    'Ojalá encuentres en tu carta no respuestas absolutas, sino nuevas formas de entenderte. La astrología no está para decirte quién debes ser, sino para ayudarte a mirar con más claridad aquello que ya vive dentro de ti.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                        color: const Color(0xFF1A1410).withValues(alpha: 0.55),
                        fontSize: 15,
                        fontWeight: FontWeight.w300,
                        height: 2.0,
                        letterSpacing: 0.1),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Nada de lo que viste aquí tiene más fuerza que tu propia capacidad de elegir, cambiar y construirte. Tu carta puede señalar caminos, pero siempre serás tú quien decida cómo recorrerlos.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                        color: const Color(0xFF1A1410).withValues(alpha: 0.55),
                        fontSize: 15,
                        fontWeight: FontWeight.w300,
                        height: 2.0,
                        letterSpacing: 0.1),
                  ),
                  const SizedBox(height: 56),
                  Text(
                    'Con cariño — El equipo de ecos',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: const Color(0xFFB8973A),
                        fontSize: 16,
                        letterSpacing: 2.5,
                        fontWeight: FontWeight.w700,
                        fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    '<3',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: const Color(0xFFB8973A).withValues(alpha: 0.5),
                        fontSize: 18,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w300),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
      ],
    );
  }
}

class _FadeImage extends StatelessWidget {
  final String url;
  final double? width;
  final Color? color;
  final BlendMode? colorBlendMode;
  const _FadeImage({required this.url, this.width, this.color, this.colorBlendMode});

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      width: width,
      color: color,
      colorBlendMode: colorBlendMode,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) return child;
        return AnimatedOpacity(
          opacity: frame == null ? 0.0 : 1.0,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeIn,
          child: child,
        );
      },
    );
  }
}

class _Big3Row extends StatelessWidget {
  final String solar;
  final String lunar;
  final String ascendente;
  const _Big3Row({required this.solar, required this.lunar, required this.ascendente});

  static const _beige = Color(0xFFF3EBD6);
  static const _gold  = Color(0xFFB8973A);
  static const _simbolos = {
    'Aries': '♈', 'Tauro': '♉', 'Géminis': '♊', 'Geminis': '♊',
    'Cáncer': '♋', 'Cancer': '♋', 'Leo': '♌', 'Virgo': '♍',
    'Libra': '♎', 'Escorpio': '♏', 'Sagitario': '♐',
    'Capricornio': '♑', 'Acuario': '♒', 'Piscis': '♓',
  };

  @override
  Widget build(BuildContext context) {
    final items = [('☉', solar, 'SOL'), ('☽', lunar, 'LUNA'), ('↑', ascendente, 'ASC')];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: items.map((item) {
        final glifo = _simbolos[item.$2] ?? '✦';
        return Column(
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _gold.withValues(alpha: 0.55), width: 1),
                color: const Color(0xFF0D0D0D),
                boxShadow: [
                  BoxShadow(color: _gold.withValues(alpha: 0.30), blurRadius: 14, spreadRadius: 0),
                  BoxShadow(color: _gold.withValues(alpha: 0.12), blurRadius: 28, spreadRadius: 0),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(item.$1, style: TextStyle(color: _gold.withValues(alpha: 0.6), fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(glifo, style: TextStyle(color: _beige.withValues(alpha: 0.9), fontSize: 22)),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(item.$3, style: TextStyle(color: _beige.withValues(alpha: 0.3), fontSize: 9, letterSpacing: 2.5)),
            const SizedBox(height: 3),
            Text(item.$2, style: const TextStyle(color: _beige, fontFamily: 'PlayfairDisplay', fontSize: 12, fontWeight: FontWeight.w400)),
          ],
        );
      }).toList(),
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
  final double fontSize;
  const _TituloSeccion({required this.texto, required this.gold, this.fontSize = 14});
  @override
  Widget build(BuildContext context) => Text(
    texto.toUpperCase(),
    style: TextStyle(fontFamily: 'PlayfairDisplay', color: gold.withValues(alpha: 0.85), fontSize: fontSize, letterSpacing: 2, fontWeight: FontWeight.w700),
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
        _TextoCarta(texto: cuerpo, color: beige.withValues(alpha: 0.85)),
      ],
    );
  }
}

class _VirtudesDefectos extends StatefulWidget {
  final String titulo;
  final String subtitulo;
  final String texto;
  final Color beige;
  final Color gold;
  final bool esSombras;
  const _VirtudesDefectos({
    required this.titulo,
    required this.subtitulo,
    required this.texto,
    required this.beige,
    required this.gold,
    this.esSombras = false,
  });

  @override
  State<_VirtudesDefectos> createState() => _VirtudesDefectosState();
}

class _VirtudesDefectosState extends State<_VirtudesDefectos> {
  late final ScrollController _ctrl;
  int _pagina = 0;

  static const _iconosVirtudes = [
    Icons.auto_awesome, Icons.visibility_outlined, Icons.flag_outlined,
    Icons.favorite_border, Icons.bolt_outlined, Icons.spa_outlined,
    Icons.psychology_outlined, Icons.diamond_outlined, Icons.star_border,
  ];
  static const _iconosSombras = [
    Icons.schedule_outlined, Icons.shield_outlined, Icons.self_improvement_outlined,
    Icons.cloud_outlined, Icons.lock_outline, Icons.warning_amber_outlined,
    Icons.loop, Icons.hourglass_empty, Icons.block_outlined,
  ];

  static IconData _iconoPorNombre(String nombre, List<IconData> pool) {
    final hash = nombre.codeUnits.fold(0, (a, b) => a + b);
    return pool[hash % pool.length];
  }

  @override
  void initState() {
    super.initState();
    _ctrl = ScrollController();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final lineas = widget.texto.split('\n').where((l) => l.trim().isNotEmpty).toList();
    final items = lineas.map((l) {
      final idx = l.indexOf(':');
      return (
        idx > 0 ? l.substring(0, idx).trim() : l.trim(),
        idx > 0 ? l.substring(idx + 1).trim() : '',
      );
    }).toList();

    final iconos = widget.esSombras ? _iconosSombras : _iconosVirtudes;
    const purple = Color(0xFF9B7EC8);
    final accentColor = widget.esSombras ? purple : widget.gold.withValues(alpha: 0.85);
    final headerIcon = widget.esSombras ? '☾' : '✦';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(headerIcon, style: TextStyle(color: accentColor, fontSize: 14)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.titulo.toUpperCase(),
                      style: TextStyle(
                          fontFamily: 'PlayfairDisplay',
                          color: accentColor,
                          fontSize: 16, letterSpacing: 2.5, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(widget.subtitulo,
                      style: GoogleFonts.manrope(
                          color: widget.beige.withValues(alpha: 0.5),
                          fontSize: 12, height: 1.4)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        // Carrusel
        LayoutBuilder(builder: (context, constraints) {
          final cardW = constraints.maxWidth * 0.72;
          const gap = 10.0;

          final viewportW = constraints.maxWidth;
          final sideInset = (viewportW - cardW) / 2;

          void snapTo(int i) {
            // With horizontal padding = sideInset, card i's left edge is at i*(cardW+gap)
            // scrolling to that offset centers the card in the viewport
            final offset = (i * (cardW + gap)).clamp(0.0, double.infinity);
            _ctrl.animateTo(
              offset,
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOut,
            );
            setState(() => _pagina = i);
          }

          return NotificationListener<ScrollEndNotification>(
            onNotification: (_) {
              final nearest = (_ctrl.offset / (cardW + gap)).round()
                  .clamp(0, items.length - 1);
              final targetOffset = (nearest * (cardW + gap)).clamp(0.0, double.infinity);
              if ((_ctrl.offset - targetOffset).abs() > 1) {
                _ctrl.animateTo(targetOffset,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut);
                setState(() => _pagina = nearest);
              }
              return false;
            },
            child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            controller: _ctrl,
            clipBehavior: Clip.none,
            padding: EdgeInsets.symmetric(horizontal: sideInset, vertical: 20),
            child: IntrinsicHeight(
              child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: List.generate(items.length, (i) {
                final selec = i == _pagina;
                final item = items[i];
                final icono = _iconoPorNombre(item.$1, iconos);
                return GestureDetector(
                  onTap: () => snapTo(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                    width: cardW,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F0F0F),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selec ? accentColor.withValues(alpha: 0.7) : widget.beige.withValues(alpha: 0.07),
                        width: 1,
                      ),
                      boxShadow: selec ? [
                        BoxShadow(color: accentColor.withValues(alpha: 0.25), blurRadius: 20, spreadRadius: 0),
                        BoxShadow(color: accentColor.withValues(alpha: 0.10), blurRadius: 40, spreadRadius: 0),
                      ] : [],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 58, height: 58,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: accentColor.withValues(alpha: 0.4), width: 1),
                            color: accentColor.withValues(alpha: 0.08),
                            boxShadow: selec ? [
                              BoxShadow(color: accentColor.withValues(alpha: 0.2), blurRadius: 12),
                            ] : [],
                          ),
                          child: Icon(icono, color: accentColor.withValues(alpha: selec ? 0.95 : 0.5), size: 24),
                        ),
                        const SizedBox(height: 18),
                        Text(item.$1,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontFamily: 'PlayfairDisplay',
                                color: widget.beige.withValues(alpha: selec ? 1.0 : 0.6),
                                fontSize: 15, fontWeight: FontWeight.w600,
                                letterSpacing: 0.5, height: 1.25)),
                        const SizedBox(height: 10),
                        Text(item.$2,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.manrope(
                                color: widget.beige.withValues(alpha: selec ? 0.6 : 0.3),
                                fontSize: 13, fontWeight: FontWeight.w300, height: 1.6,
                                letterSpacing: 0.1)),
                      ],
                    ),
                  ),
                );
              }),
            ),
            ),
          ),
          );
        }),
      ],
    );
  }
}

// ── Futuro ───────────────────────────────────────────────────────────────────

class _FuturoSection extends StatelessWidget {
  final String texto;
  final Color beige;
  final Color gold;
  const _FuturoSection({required this.texto, required this.beige, required this.gold});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // encabezado
        Text('QUÉ FUTURO TE ESPERA',
            style: TextStyle(
                fontFamily: 'PlayfairDisplay',
                color: gold.withValues(alpha: 0.9),
                fontSize: 24, letterSpacing: 2, fontWeight: FontWeight.w700)),
        const SizedBox(height: 18),
        // tarjeta con gradiente lateral dorado
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF080808),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: gold.withValues(alpha: 0.2), width: 1),
            boxShadow: [
              BoxShadow(color: gold.withValues(alpha: 0.08), blurRadius: 32, spreadRadius: 0),
            ],
          ),
          child: Stack(
            children: [
              // barra dorada izquierda
              Positioned(
                left: 0, top: 16, bottom: 16,
                child: Container(
                  width: 2,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        gold.withValues(alpha: 0.0),
                        gold.withValues(alpha: 0.55),
                        gold.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Lo que se está formando',
                        style: TextStyle(
                            fontFamily: 'PlayfairDisplay',
                            color: gold.withValues(alpha: 0.6),
                            fontSize: 13, letterSpacing: 1.2, fontWeight: FontWeight.w400,
                            fontStyle: FontStyle.italic)),
                    const SizedBox(height: 6),
                    Divider(color: gold.withValues(alpha: 0.1), thickness: 0.5),
                    const SizedBox(height: 14),
                    _TextoCarta(texto: texto, color: beige.withValues(alpha: 0.82)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Ámbitos: círculos + reveal ───────────────────────────────────────────────

class _AmbitosSection extends StatefulWidget {
  final Map<String, String> lectura;
  final Map<String, String> planetas;
  final Color beige;
  final Color gold;
  const _AmbitosSection({required this.lectura, required this.planetas, required this.beige, required this.gold});

  @override
  State<_AmbitosSection> createState() => _AmbitosSectionState();
}

class _AmbitosSectionState extends State<_AmbitosSection>
    with SingleTickerProviderStateMixin {
  static const _datos = [
    ('amor',     '♡',  'Venus',    Icons.favorite_border),
    ('amistad',  '◦',  'Mercurio', Icons.people_outline),
    ('suerte',   '✦',  'Júpiter',  Icons.auto_awesome_outlined),
    ('familia',  '◈',  'Luna',     Icons.home_outlined),
    ('dinero',   '◇',  'Saturno',  Icons.diamond_outlined),
  ];

  int? _abierto;
  final Set<int> _vistos = {};
  bool _subtituloVisible = true;
  late final AnimationController _animCtrl;
  late final Animation<double> _rotAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 420));
    _rotAnim  = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _animCtrl, curve: Curves.easeIn));
  }

  @override
  void dispose() { _animCtrl.dispose(); super.dispose(); }

  void _tap(int i) {
    setState(() => _subtituloVisible = false);
    if (_abierto == i) {
      _animCtrl.reverse().then((_) => setState(() => _abierto = null));
    } else {
      setState(() {
        _abierto = i;
        _vistos.add(i);
      });
      _animCtrl.forward(from: 0);
    }
  }

  Widget _circulo(int i) {
    final beige = widget.beige;
    final gold  = widget.gold;
    final entry = _datos[i];
    final selec = _abierto == i;
    final visto = _vistos.contains(i);

    final iconColor = visto
        ? (selec ? gold : gold.withValues(alpha: 0.7))
        : Colors.grey.withValues(alpha: 0.4);
    final borderColor = visto
        ? (selec ? gold.withValues(alpha: 0.85) : gold.withValues(alpha: 0.35))
        : Colors.grey.withValues(alpha: 0.2);

    return GestureDetector(
      onTap: () => _tap(i),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _animCtrl,
            builder: (_, child) {
              final angle = selec ? _rotAnim.value * 3.14159 * 2 : 0.0;
              return Transform.rotate(angle: angle, child: child);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF0D0D0D),
                border: Border.all(color: borderColor, width: 1),
                boxShadow: selec ? [
                  BoxShadow(color: gold.withValues(alpha: 0.4),
                      blurRadius: 20, spreadRadius: 0),
                  BoxShadow(color: gold.withValues(alpha: 0.18),
                      blurRadius: 40, spreadRadius: 0),
                ] : [],
              ),
              child: Icon(entry.$4, size: 26, color: iconColor),
            ),
          ),
          const SizedBox(height: 9),
          Text(entry.$1.toUpperCase(),
              style: TextStyle(
                  color: visto
                      ? beige.withValues(alpha: 0.85)
                      : beige.withValues(alpha: 0.5),
                  fontSize: 9,
                  letterSpacing: 1.8)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final beige = widget.beige;
    final gold  = widget.gold;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // subtítulo fade
        AnimatedOpacity(
          opacity: _subtituloVisible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 500),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Text('presiona para revelar',
                style: TextStyle(
                    color: beige.withValues(alpha: 0.3),
                    fontSize: 11, letterSpacing: 1.2,
                    fontStyle: FontStyle.italic)),
          ),
        ),

        // ── fila 1: 3 círculos ──
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [0, 1, 2]
              .where((i) => (widget.lectura[_datos[i].$1] ?? '').isNotEmpty)
              .map(_circulo)
              .toList(),
        ),
        const SizedBox(height: 20),
        // ── fila 2: 2 círculos centrados ──
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [3, 4]
              .where((i) => (widget.lectura[_datos[i].$1] ?? '').isNotEmpty)
              .expand((i) => [_circulo(i), if (i == 3) const SizedBox(width: 40)])
              .toList(),
        ),

        // ── tarjeta reveal ──
        if (_abierto != null) ...[
          const SizedBox(height: 28),
          FadeTransition(
            opacity: _fadeAnim,
            child: _AmbCardReveal(
              entry: _datos[_abierto!],
              signo: widget.planetas[_datos[_abierto!].$3] ?? '',
              cuerpo: widget.lectura[_datos[_abierto!].$1]!,
              beige: beige,
              gold: gold,
              onClose: () {
                _animCtrl.reverse().then((_) => setState(() => _abierto = null));
              },
            ),
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }
}

class _AmbCardReveal extends StatelessWidget {
  final (String, String, String, IconData) entry;
  final String signo;
  final String cuerpo;
  final Color beige;
  final Color gold;
  final VoidCallback onClose;

  static const _simbolosPlaneta = {
    'Venus': '♀', 'Mercurio': '☿', 'Júpiter': '♃',
    'Luna': '☽', 'Saturno': '♄', 'Sol': '☉',
    'Marte': '♂', 'Urano': '♅', 'Neptuno': '♆', 'Plutón': '♇',
  };

  const _AmbCardReveal({
    required this.entry, required this.signo, required this.cuerpo,
    required this.beige, required this.gold, required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: gold.withValues(alpha: 0.3), width: 1),
        boxShadow: [
          BoxShadow(color: gold.withValues(alpha: 0.1), blurRadius: 20, spreadRadius: 0),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── header estilo tarjeta ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // círculo icono izquierdo
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: gold.withValues(alpha: 0.08),
                  border: Border.all(color: gold.withValues(alpha: 0.5), width: 1),
                  boxShadow: [
                    BoxShadow(color: gold.withValues(alpha: 0.25), blurRadius: 12, spreadRadius: 0),
                  ],
                ),
                child: Icon(entry.$4, size: 20, color: gold),
              ),
              const SizedBox(width: 14),
              // título
              Text(entry.$1.toUpperCase(),
                  style: TextStyle(
                      fontFamily: 'PlayfairDisplay',
                      color: gold,
                      fontSize: 16, letterSpacing: 2.5, fontWeight: FontWeight.w700)),
              const Spacer(),
              // planeta en signo + círculo símbolo
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (signo.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${entry.$3.toUpperCase()} EN',
                            style: GoogleFonts.manrope(
                                color: beige.withValues(alpha: 0.42),
                                fontSize: 8, letterSpacing: 1.5, fontWeight: FontWeight.w300)),
                        const SizedBox(height: 2),
                        Text(signo.toUpperCase(),
                            style: GoogleFonts.manrope(
                                color: beige.withValues(alpha: 0.72),
                                fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  const SizedBox(width: 8),
                  Container(
                    width: 30, height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: beige.withValues(alpha: 0.04),
                      border: Border.all(color: beige.withValues(alpha: 0.18), width: 1),
                    ),
                    child: Center(
                      child: Text(
                        _simbolosPlaneta[entry.$3] ?? entry.$2,
                        style: TextStyle(color: beige.withValues(alpha: 0.55), fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: onClose,
                child: Icon(Icons.close, size: 16, color: beige.withValues(alpha: 0.25)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: gold.withValues(alpha: 0.1), thickness: 0.5),
          const SizedBox(height: 14),
          _TextoCarta(texto: cuerpo, color: beige.withValues(alpha: 0.8)),
        ],
      ),
    );
  }
}

class _AmbCard extends StatelessWidget {
  final String simbolo;
  final String titulo;
  final String planeta;
  final String cuerpo;
  final Color beige;
  final Color gold;
  const _AmbCard({required this.simbolo, required this.titulo, required this.planeta,
      required this.cuerpo, required this.beige, required this.gold});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: gold.withValues(alpha: 0.25), width: 1),
        boxShadow: [
          BoxShadow(color: gold.withValues(alpha: 0.08), blurRadius: 16, spreadRadius: 0),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Text(simbolo, style: TextStyle(color: gold.withValues(alpha: 0.7), fontSize: 16)),
            const SizedBox(width: 10),
            Text(titulo.toUpperCase(),
                style: TextStyle(fontFamily: 'PlayfairDisplay', color: gold.withValues(alpha: 0.9),
                    fontSize: 14, letterSpacing: 2, fontWeight: FontWeight.w700)),
            const Spacer(),
            Text(planeta,
                style: GoogleFonts.manrope(color: beige.withValues(alpha: 0.25),
                    fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.w300)),
          ]),
          const SizedBox(height: 4),
          Divider(color: gold.withValues(alpha: 0.12), thickness: 0.5),
          const SizedBox(height: 10),
          _TextoCarta(texto: cuerpo, color: beige.withValues(alpha: 0.8)),
        ],
      ),
    );
  }
}

// ── Texto con palabras en negrita ────────────────────────────────────────────

class _TextoCarta extends StatefulWidget {
  final String texto;
  final Color color;
  const _TextoCarta({required this.texto, required this.color});
  @override
  State<_TextoCarta> createState() => _TextoCartaState();
}

class _TextoCartaState extends State<_TextoCarta> {
  late List<Set<int>> _negritaPorParrafo;
  late List<int?> _doradoPorParrafo;

  static const _gold = Color(0xFFB8973A);

  @override
  void initState() {
    super.initState();
    final parrafos = widget.texto.split(RegExp(r'\n\n+'));
    _negritaPorParrafo = parrafos.map((p) {
      final palabras = p.trim().split(RegExp(r'\s+'));
      final candidatos = palabras.asMap().entries
          .where((e) => e.value.replaceAll(RegExp(r'[^\wáéíóúüñÁÉÍÓÚÜÑ]'), '').length >= 6)
          .map((e) => e.key)
          .toList()..shuffle(Random());
      return candidatos.take(3).toSet();
    }).toList();

    _doradoPorParrafo = parrafos.map((p) {
      final palabras = p.trim().split(RegExp(r'\s+'));
      final candidatos = palabras.asMap().entries
          .where((e) => e.value.replaceAll(RegExp(r'[^\wáéíóúüñÁÉÍÓÚÜÑ]'), '').length >= 8)
          .map((e) => e.key)
          .toList()..shuffle(Random());
      return candidatos.isNotEmpty ? candidatos.first : null;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final parrafos = widget.texto.split(RegExp(r'\n\n+'));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var pi = 0; pi < parrafos.length; pi++) ...[
          if (pi > 0) const SizedBox(height: 14),
          RichText(
            text: TextSpan(
              children: () {
                final palabras = parrafos[pi].trim().split(RegExp(r'\s+'));
                final negrita = _negritaPorParrafo[pi];
                final dorado  = pi < _doradoPorParrafo.length ? _doradoPorParrafo[pi] : null;
                return List.generate(palabras.length, (i) => TextSpan(
                  text: i < palabras.length - 1 ? '${palabras[i]} ' : palabras[i],
                  style: GoogleFonts.manrope(
                    color: i == dorado ? _gold : widget.color,
                    fontSize: 14,
                    fontWeight: negrita.contains(i) ? FontWeight.w700 : FontWeight.w300,
                    height: 1.75,
                  ),
                ));
              }(),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Clipper despedida ─────────────────────────────────────────────────────────

class _DespedidaClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    final arcHeight = 40.0;
    // empieza en esquina superior izquierda
    path.moveTo(0, arcHeight);
    // arco cóncavo: la curva sube hacia el centro y baja en los lados
    path.quadraticBezierTo(size.width / 2, -arcHeight, size.width, arcHeight);
    // resto del rectángulo
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(_DespedidaClipper old) => false;
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
