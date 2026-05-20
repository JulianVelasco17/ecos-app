import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/calculos_astrales.dart';
import '../services/aspectos_natales.dart';
import '../services/claude_service.dart';
import '../widgets/ouroboros_loader.dart';

class PantallaLecturaCartaProfunda extends StatefulWidget {
  const PantallaLecturaCartaProfunda({super.key});

  @override
  State<PantallaLecturaCartaProfunda> createState() => _PantallaLecturaCartaProfundaState();
}

class _PantallaLecturaCartaProfundaState extends State<PantallaLecturaCartaProfunda> {
  bool _cargando = true;
  Map<String, String> _lectura = {};
  String? _signoSolar;
  String? _signoLunar;
  String? _ascendente;

  static const _beige = Color(0xFFE7D8C9);
  static const _gold  = Color(0xFFB8973A);

  static const _secciones = [
    ('TU BIG 3',          'big3',     '◉'),
    ('ASPECTOS NATALES',  'aspectos', '✦'),
    ('AMOR',              'amor',     '♡'),
    ('AMISTAD',           'amistad',  '○'),
    ('SUERTE',            'suerte',   '△'),
    ('FAMILIA',           'familia',  '◐'),
    ('DINERO',            'dinero',   '↑'),
  ];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) { if (mounted) setState(() => _cargando = false); return; }

      final cacheDoc = await FirebaseFirestore.instance
          .collection('lecturasProfundas').doc('${uid}_carta_v2').get();

      final userDoc = await FirebaseFirestore.instance.collection('usuarios').doc(uid).get();
      if (!mounted) return;
      if (!userDoc.exists) { setState(() => _cargando = false); return; }
      final datos = userDoc.data()!;

      final fechaTs = datos['fechaNacimiento'] as dynamic;
      final fecha   = fechaTs.toDate() as DateTime;
      final horaParts = ((datos['horaNacimiento'] as String?) ?? '12:00').split(':');
      final hora = int.tryParse(horaParts[0]) ?? 12;
      final min  = int.tryParse(horaParts.length > 1 ? horaParts[1] : '0') ?? 0;
      final lat  = (datos['latitud']  as num?)?.toDouble() ?? 0.0;
      final lon  = (datos['longitud'] as num?)?.toDouble() ?? 0.0;

      final carta = CalculosAstrales.calcular(
          fechaNacimiento: fecha, hora: hora, minutos: min, latitud: lat, longitud: lon);

      if (cacheDoc.exists) {
        final raw = cacheDoc.data()!;
        if (mounted) {
          setState(() {
            _lectura = {for (final s in _secciones) s.$2: raw[s.$2] as String? ?? ''};
            _signoSolar  = carta.signoSolar;
            _signoLunar  = carta.signoLunar;
            _ascendente  = carta.ascendente;
            _cargando = false;
          });
        }
        return;
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
        final start = rawStr.indexOf('{');
        final end   = rawStr.lastIndexOf('}');
        final json  = jsonDecode(rawStr.substring(start, end + 1)) as Map<String, dynamic>;
        lectura = {for (final s in _secciones) s.$2: json[s.$2] as String? ?? ''};
      } catch (_) {
        lectura = {'esencia': rawStr};
      }

      if (lectura.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('lecturasProfundas').doc('${uid}_carta_v2')
            .set({...lectura, 'fecha': FieldValue.serverTimestamp()});
      }

      if (mounted) {
        setState(() {
          _lectura     = lectura;
          _signoSolar  = carta.signoSolar;
          _signoLunar  = carta.signoLunar;
          _ascendente  = carta.ascendente;
          _cargando    = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _cargando
            ? const Center(child: OuroborosLoader(size: 200))
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 32, 28, 60),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      behavior: HitTestBehavior.opaque,
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Icon(Icons.arrow_back_ios,
                            color: Color(0x55F3EBD6), size: 18),
                      ),
                    ),
                    const SizedBox(height: 48),

                    Text('TU CARTA',
                        style: TextStyle(
                            color: _beige.withValues(alpha: 0.3),
                            fontSize: 10, letterSpacing: 4)),
                    const SizedBox(height: 10),
                    Text('Lectura profunda',
                        style: const TextStyle(
                          fontFamily: 'PlayfairDisplay',
                          color: _beige,
                          fontSize: 36,
                          fontWeight: FontWeight.w400,
                          height: 1.2,
                          letterSpacing: 1.0,
                        )),
                    const SizedBox(height: 8),
                    Container(width: 32, height: 1.5, color: _gold),
                    const SizedBox(height: 48),

                    if (_signoSolar != null) ...[
                      _Big3Row(
                        solar:      _signoSolar!,
                        lunar:      _signoLunar!,
                        ascendente: _ascendente!,
                      ),
                      const SizedBox(height: 44),
                    ],

                    ..._secciones.where((s) => (_lectura[s.$2] ?? '').isNotEmpty).map((s) =>
                      _Seccion(icono: s.$3, titulo: s.$1, texto: _lectura[s.$2]!),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

// ── Big 3 row ─────────────────────────────────────────────────────────────────

class _Big3Row extends StatelessWidget {
  final String solar;
  final String lunar;
  final String ascendente;

  const _Big3Row({required this.solar, required this.lunar, required this.ascendente});

  static const _beige = Color(0xFFE7D8C9);
  static const _gold  = Color(0xFFB8973A);

  static const _simbolos = {
    'Aries': '♈', 'Tauro': '♉', 'Géminis': '♊', 'Geminis': '♊',
    'Cáncer': '♋', 'Cancer': '♋', 'Leo': '♌', 'Virgo': '♍',
    'Libra': '♎', 'Escorpio': '♏', 'Sagitario': '♐',
    'Capricornio': '♑', 'Acuario': '♒', 'Piscis': '♓',
  };

  @override
  Widget build(BuildContext context) {
    final items = [
      ('☉', solar,      'SOL'),
      ('☽', lunar,      'LUNA'),
      ('↑', ascendente, 'ASC'),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: items.map((item) {
        final simboloSigno = _simbolos[item.$2] ?? '✦';
        return Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _gold.withValues(alpha: 0.45), width: 1),
                color: Colors.white.withValues(alpha: 0.04),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(item.$1,
                      style: TextStyle(color: _gold.withValues(alpha: 0.6), fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(simboloSigno,
                      style: TextStyle(color: _beige.withValues(alpha: 0.9), fontSize: 22)),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(item.$3,
                style: TextStyle(
                    color: _beige.withValues(alpha: 0.3),
                    fontSize: 9, letterSpacing: 2.5)),
            const SizedBox(height: 3),
            Text(item.$2,
                style: TextStyle(
                    color: _beige.withValues(alpha: 0.75),
                    fontSize: 12,
                    fontFamily: 'PlayfairDisplay',
                    fontWeight: FontWeight.w400)),
          ],
        );
      }).toList(),
    );
  }
}

class _Seccion extends StatelessWidget {
  final String icono;
  final String titulo;
  final String texto;

  const _Seccion({required this.icono, required this.titulo, required this.texto});

  static const _beige = Color(0xFFE7D8C9);
  static const _gold  = Color(0xFFB8973A);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 44),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(icono, style: TextStyle(color: _gold.withValues(alpha: 0.7), fontSize: 13)),
            const SizedBox(width: 8),
            Text(titulo, style: TextStyle(
                color: _beige.withValues(alpha: 0.3),
                fontSize: 10, letterSpacing: 3)),
          ]),
          const SizedBox(height: 14),
          Text(texto, style: TextStyle(
              color: _beige.withValues(alpha: 0.85),
              fontSize: 15,
              fontWeight: FontWeight.w300,
              height: 1.85,
              letterSpacing: 0.2)),
        ],
      ),
    );
  }
}
