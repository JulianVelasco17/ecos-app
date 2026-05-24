import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/debug_config.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import '../widgets/ouroboros_loader.dart';
import '../widgets/debug_boton_carga.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/calculos_astrales.dart';
import '../services/calculos_planetarios.dart';
import '../services/claude_service.dart';
import '../services/clima_astral_service.dart';

class PantallaLecturaClimaPersonal extends StatefulWidget {
  const PantallaLecturaClimaPersonal({super.key});

  @override
  State<PantallaLecturaClimaPersonal> createState() => _PantallaLecturaClimaPersonalState();
}

class _PantallaLecturaClimaPersonalState extends State<PantallaLecturaClimaPersonal> {
  bool _cargando = true;
  double _videoOpacity = 0.0;
  Map<String, String> _lectura = {};
  List<Map<String, dynamic>> _aspectos = [];
  int _debugDiaOffset = 0;

  static const _beige = Color(0xFFF3EBD6);
  static const _gold  = Color(0xFFB8973A);

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final hoy = DateTime.now().add(Duration(days: _debugDiaOffset));
    final fechaKey = '${hoy.year}-${hoy.month.toString().padLeft(2,'0')}-${hoy.day.toString().padLeft(2,'0')}';
    final cacheKey = '${uid}_clima_personal_v3_$fechaKey';

    final cacheDoc = await FirebaseFirestore.instance
        .collection('lecturasProfundas').doc(cacheKey).get();

    if (cacheDoc.exists) {
      if (mounted) {
        final lec = Map<String, String>.from(cacheDoc.data()!['lectura'] as Map);
        setState(() {
          _lectura  = lec;
          _aspectos = _parsearAspectos(lec['aspectos']);
          _cargando = false;
        });
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) setState(() => _videoOpacity = 1.0);
        });
      }
      return;
    }

    final userDoc = await FirebaseFirestore.instance.collection('usuarios').doc(uid).get();
    if (!userDoc.exists || !mounted) return;
    final datos = userDoc.data()!;
    final fechaTs = datos['fechaNacimiento'] as Timestamp?;
    if (fechaTs == null) return;
    final fecha      = fechaTs.toDate();
    final horaParts  = ((datos['horaNacimiento'] as String?) ?? '12:00').split(':');
    final hora       = int.tryParse(horaParts[0]) ?? 12;
    final min        = int.tryParse(horaParts.length > 1 ? horaParts[1] : '0') ?? 0;
    final lat        = (datos['latitud']  as num?)?.toDouble() ?? 0.0;
    final lon        = (datos['longitud'] as num?)?.toDouble() ?? 0.0;

    final carta      = CalculosAstrales.calcular(
        fechaNacimiento: fecha, hora: hora, minutos: min, latitud: lat, longitud: lon);
    final planetas   = CalculosPlanetarios.calcularPosiciones(hoy);
    final planetasStr = planetas.map((p) => '${p.nombre} en ${p.signo}').join(', ');

    final raw = await ClaudeService.generarLecturaClimaPersonal(
      signoSolar:  carta.signoSolar,
      signoLunar:  carta.signoLunar,
      ascendente:  carta.ascendente,
      planetasHoy: planetasStr,
    );

    Map<String, String> lectura = {};
    try {
      final start = raw.indexOf('{');
      final end   = raw.lastIndexOf('}');
      final json  = jsonDecode(raw.substring(start, end + 1));
      lectura = {
        'activado': json['activado'] as String? ?? '',
        'navegar':  json['navegar']  as String? ?? '',
        'cuidar':   json['cuidar']   as String? ?? '',
        'frase':    json['frase']    as String? ?? '',
      };
      // Guardar aspectos como JSON string
      if (json['aspectos'] != null) {
        lectura['aspectos'] = jsonEncode(json['aspectos']);
      }
    } catch (_) {
      lectura = {'activado': raw};
    }

    await FirebaseFirestore.instance
        .collection('lecturasProfundas').doc(cacheKey)
        .set({'lectura': lectura, 'fecha': FieldValue.serverTimestamp()});

    if (mounted) {
      setState(() {
        _lectura  = lectura;
        _aspectos = _parsearAspectos(lectura['aspectos']);
        _cargando = false;
      });
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) setState(() => _videoOpacity = 1.0);
      });
    }
  }

  List<Map<String, dynamic>> _parsearAspectos(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => {
        'nombre': e['nombre'] as String? ?? '',
        'valor':  (e['valor'] as num?)?.toInt() ?? 0,
      }).toList();
    } catch (_) {
      return [];
    }
  }

  bool get _tieneIndicadores => _aspectos.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.black,
      body: _cargando
          ? const Center(child: OuroborosLoader(size: 260))
          : Stack(
        children: [
          // Scroll principal — video de fondo + contenido encima
          SingleChildScrollView(
            child: Stack(
              children: [
                // Video: ocupa screenH, scrollea con el contenido
                SizedBox(
                  height: screenH,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      AnimatedOpacity(
                        opacity: _videoOpacity,
                        duration: const Duration(seconds: 2),
                        child: const _ClimaVideo(),
                      ),
                      Container(color: Colors.black.withValues(alpha: 0.45)),
                    ],
                  ),
                ),
                // Todo el contenido encima del video desde arriba
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(48, 24, 24, 0),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('CLIMA ASTRAL',
                                  style: TextStyle(color: _gold.withValues(alpha: 0.8), fontSize: 10, letterSpacing: 3, fontWeight: FontWeight.w500)),
                                const SizedBox(height: 14),
                                RichText(
                                  text: TextSpan(
                                    style: const TextStyle(fontFamily: 'PlayfairDisplay', color: _beige, fontSize: 48, fontWeight: FontWeight.w400, height: 1.15),
                                    children: [
                                      const TextSpan(text: 'El cielo\nde hoy\n'),
                                      TextSpan(text: 'en ti.', style: TextStyle(color: _gold.withValues(alpha: 0.9))),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(children: [
                                  Container(width: 32, height: 1, color: _gold.withValues(alpha: 0.45)),
                                  const SizedBox(width: 8),
                                  Text('✦', style: TextStyle(color: _gold.withValues(alpha: 0.55), fontSize: 11)),
                                ]),
                              ],
                            ),
                            Positioned(right: 40, top: 60, child: Text('·', style: TextStyle(color: _gold.withValues(alpha: 0.3), fontSize: 18))),
                            Positioned(right: 16, top: 110, child: Text('✦', style: TextStyle(color: _gold.withValues(alpha: 0.2), fontSize: 10))),
                            Positioned(right: 60, top: 130, child: Text('·', style: TextStyle(color: _gold.withValues(alpha: 0.25), fontSize: 12))),
                          ],
                        ),
                      ),
                    ),
                    // Tarjetas directamente debajo del título, sobre el video
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 48),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [

                          if (_tieneIndicadores) ...[
                            _Card(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('ASPECTOS INTERNOS',
                                      style: TextStyle(color: _beige.withValues(alpha: 0.25), fontSize: 9, letterSpacing: 3)),
                                  const SizedBox(height: 20),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                                    children: _aspectos.map((a) => _GaugeAspecto(
                                      nombre: a['nombre'] as String,
                                      valor:  a['valor']  as int,
                                    )).toList(),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],

                          if ((_lectura['activado'] ?? '').isNotEmpty) ...[
                            _SeccionCard(titulo: 'QUÉ ESTÁ ACTIVADO', texto: _lectura['activado']!),
                            const SizedBox(height: 12),
                          ],

                          if ((_lectura['navegar'] ?? '').isNotEmpty) ...[
                            _SeccionBullets(titulo: 'CÓMO NAVEGARLO', texto: _lectura['navegar']!),
                            const SizedBox(height: 12),
                          ],

                          if ((_lectura['cuidar'] ?? '').isNotEmpty) ...[
                            _SeccionCard(titulo: 'QUÉ CUIDAR', texto: _lectura['cuidar']!),
                            const SizedBox(height: 12),
                          ],

                          if ((_lectura['frase'] ?? '').isNotEmpty)
                            _Card(
                              child: Column(
                                children: [
                                  Text('✦', style: TextStyle(color: _gold.withValues(alpha: 0.35), fontSize: 14)),
                                  const SizedBox(height: 20),
                                  Text(
                                    _lectura['frase']!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontFamily: 'PlayfairDisplay',
                                      color: _beige,
                                      fontSize: 26,
                                      fontWeight: FontWeight.w400,
                                      height: 1.35,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Text('✦', style: TextStyle(color: _gold.withValues(alpha: 0.35), fontSize: 14)),
                                ],
                              ),
                            ),

                          const SizedBox(height: 32),
                          Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                DebugBotonCarga(
                                  onTap: () => setState(() => _cargando = true),
                                  color: _beige.withValues(alpha: 0.25),
                                ),
                                if (DebugConfig.instance.activo) ...[
                                Text('·', style: TextStyle(color: _beige.withValues(alpha: 0.12), fontSize: 10)),
                                GestureDetector(
                                  onTap: () {
                                    setState(() { _debugDiaOffset++; _lectura = {}; _cargando = true; });
                                    _cargar();
                                  },
                                  behavior: HitTestBehavior.opaque,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    child: Text('día +$_debugDiaOffset →',
                                        style: TextStyle(color: _beige.withValues(alpha: 0.12), fontSize: 10, letterSpacing: 1.5)),
                                  ),
                                ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Botón back flotante
          SafeArea(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              behavior: HitTestBehavior.opaque,
              child: const Padding(
                padding: EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.arrow_back_ios, color: Color(0x55F3EBD6), size: 18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Contenedor de tarjeta ─────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0E0E0E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF3EBD6).withValues(alpha: 0.06)),
      ),
      child: child,
    );
  }
}

// ── Tarjeta con viñetas ✦ ────────────────────────────────────────────────────

class _SeccionBullets extends StatelessWidget {
  final String titulo;
  final String texto;
  const _SeccionBullets({required this.titulo, required this.texto});

  static const _beige = Color(0xFFF3EBD6);
  static const _gold  = Color(0xFFB8973A);

  List<String> get _vinetas {
    // Divide por punto seguido de espacio o salto de línea
    final partes = texto
        .split(RegExp(r'\.\s+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    // Re-agrega el punto que se perdió al dividir
    return partes.map((s) => s.endsWith('.') ? s : '$s.').toList();
  }

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('✦ ', style: TextStyle(color: _gold.withValues(alpha: 0.65), fontSize: 11)),
              Text(titulo,
                  style: TextStyle(
                      color: _beige.withValues(alpha: 0.3),
                      fontSize: 9,
                      letterSpacing: 2.5)),
            ],
          ),
          const SizedBox(height: 14),
          ..._vinetas.map((v) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 4, right: 10),
                  child: Text('✦',
                      style: TextStyle(
                          color: _gold.withValues(alpha: 0.5), fontSize: 9)),
                ),
                Expanded(
                  child: Text(v,
                      style: GoogleFonts.manrope(
                        color: _beige.withValues(alpha: 0.78),
                        fontSize: 15,
                        fontWeight: FontWeight.w300,
                        height: 1.65,
                        letterSpacing: -0.1,
                      )),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

// ── Tarjeta de sección con título ✦ ──────────────────────────────────────────

class _SeccionCard extends StatelessWidget {
  final String titulo;
  final String texto;

  const _SeccionCard({required this.titulo, required this.texto});

  static const _beige = Color(0xFFF3EBD6);
  static const _gold  = Color(0xFFB8973A);

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('✦ ',
                  style: TextStyle(
                      color: _gold.withValues(alpha: 0.65), fontSize: 11)),
              Text(
                titulo,
                style: TextStyle(
                  color: _beige.withValues(alpha: 0.3),
                  fontSize: 9,
                  letterSpacing: 2.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            texto,
            style: GoogleFonts.manrope(
              color: _beige.withValues(alpha: 0.78),
              fontSize: 15,
              fontWeight: FontWeight.w300,
              height: 1.7,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Métrica individual de clima ───────────────────────────────────────────────

class _ClimaVideo extends StatefulWidget {
  const _ClimaVideo();

  @override
  State<_ClimaVideo> createState() => _ClimaVideoState();
}

class _ClimaVideoState extends State<_ClimaVideo> {
  VideoPlayerController? _ctrl;
  bool _listo = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    VideoPlayerController? cached = ClimaAstralService.instance.controller;
    if (cached == null || !cached.value.isInitialized) {
      await ClimaAstralService.instance.precargar();
      cached = ClimaAstralService.instance.controller;
    }
    if (cached == null || !mounted) return;
    _ctrl = cached;
    await _ctrl!.setLooping(true);
    await _ctrl!.setVolume(0);
    await _ctrl!.play();
    if (mounted) setState(() => _listo = true);
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_listo || _ctrl == null) return const SizedBox.shrink();
    return SizedBox.expand(
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

// ── Gauge circular por aspecto ────────────────────────────────────────────────

class _GaugeAspecto extends StatelessWidget {
  final String nombre;
  final int valor; // 1-100

  const _GaugeAspecto({required this.nombre, required this.valor});

  static const _beige = Color(0xFFF3EBD6);

  IconData get _icono {
    const mental   = ['claridad mental','ruido mental','enfoque','dispersión','sobreanálisis','creatividad','intuición','presencia'];
    const emocional= ['sensibilidad','apertura emocional','conexión emocional','cansancio emocional','vulnerabilidad','claridad emocional','tolerancia emocional','receptividad','nostalgia','conexión contigo mismo'];
    const accion   = ['motivación','impulsividad','espontaneidad','productividad','iniciativa','energía física','deseo de movimiento'];
    const social   = ['energía social','deseo de compañía','deseo de cercanía','deseo de aislamiento','necesidad de espacio'];
    const calma    = ['calma interna','paciencia','descanso','estabilidad','necesidad de descanso','flexibilidad'];
    const control  = ['tensión interna','inquietud','deseo de control','confianza'];

    if (mental.contains(nombre))    return Icons.psychology_outlined;
    if (emocional.contains(nombre)) return Icons.favorite_border;
    if (accion.contains(nombre))    return Icons.bolt_outlined;
    if (social.contains(nombre))    return Icons.people_outline;
    if (calma.contains(nombre))     return Icons.self_improvement;
    if (control.contains(nombre))   return Icons.tune;
    return Icons.auto_awesome;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 60,
          height: 60,
          child: CustomPaint(
            painter: _GaugePainter(valor: valor),
            child: Center(
              child: Icon(_icono, color: _beige.withValues(alpha: 0.55), size: 22),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 64,
          child: Text(
            nombre,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: TextStyle(
              color: _beige.withValues(alpha: 0.35),
              fontSize: 9,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _GaugePainter extends CustomPainter {
  final int valor;
  const _GaugePainter({required this.valor});

  static const _gold = Color(0xFFB8973A);
  static const _beige = Color(0xFFF3EBD6);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = (size.width / 2) - 3;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: radius);

    // Fondo del círculo
    final bgPaint = Paint()
      ..color = _beige.withValues(alpha: 0.08)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(Offset(cx, cy), radius, bgPaint);

    // Arco proporcional al valor
    final sweep = (valor / 100) * 2 * 3.141592653589793;
    final fgPaint = Paint()
      ..shader = SweepGradient(
        startAngle: -1.5707963267948966, // -π/2 (arriba)
        endAngle:   -1.5707963267948966 + sweep,
        colors: [
          _gold.withValues(alpha: 0.5),
          _gold,
        ],
        transform: const GradientRotation(-1.5707963267948966),
      ).createShader(rect)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, -1.5707963267948966, sweep, false, fgPaint);
  }

  @override
  bool shouldRepaint(_GaugePainter old) => old.valor != valor;
}
