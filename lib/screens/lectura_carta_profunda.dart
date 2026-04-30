import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/calculos_astrales.dart';
import '../services/aspectos_natales.dart';
import '../services/claude_service.dart';

class PantallaLecturaCartaProfunda extends StatefulWidget {
  const PantallaLecturaCartaProfunda({super.key});

  @override
  State<PantallaLecturaCartaProfunda> createState() => _PantallaLecturaCartaProfundaState();
}

class _PantallaLecturaCartaProfundaState extends State<PantallaLecturaCartaProfunda> {
  bool _cargando = true;
  Map<String, String> _lectura = {};

  static const _beige = Color(0xFFE7D8C9);
  static const _gold  = Color(0xFFB8973A);

  static const _secciones = [
    ('ESENCIA',     'esencia',    '◉'),
    ('PROPÓSITO',   'proposito',  '↑'),
    ('AMOR',        'amor',       '♡'),
    ('SOMBRA',      'sombra',     '◐'),
    ('DONES',       'dones',      '✦'),
    ('CARRERA',     'carrera',    '△'),
    ('CRECIMIENTO', 'crecimiento','○'),
  ];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final cacheDoc = await FirebaseFirestore.instance
        .collection('lecturasProfundas').doc('${uid}_carta_profunda').get();

    if (cacheDoc.exists) {
      final raw = cacheDoc.data()!;
      if (mounted) {
        setState(() {
          _lectura = {for (final s in _secciones) s.$2: raw[s.$2] as String? ?? ''};
          _cargando = false;
        });
      }
      return;
    }

    final userDoc = await FirebaseFirestore.instance.collection('usuarios').doc(uid).get();
    if (!userDoc.exists || !mounted) return;
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
          .collection('lecturasProfundas').doc('${uid}_carta_profunda')
          .set({...lectura, 'fecha': FieldValue.serverTimestamp()});
    }

    if (mounted) setState(() { _lectura = lectura; _cargando = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _cargando
            ? const Center(child: CircularProgressIndicator(
                color: Color(0x44F3EBD6), strokeWidth: 1.5))
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 32, 28, 60),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.arrow_back_ios,
                          color: Color(0x55F3EBD6), size: 18),
                    ),
                    const SizedBox(height: 48),

                    Text('TU CARTA',
                        style: TextStyle(
                            color: _beige.withValues(alpha: 0.3),
                            fontSize: 10, letterSpacing: 4)),
                    const SizedBox(height: 10),
                    Text('Lectura profunda',
                        style: TextStyle(
                          fontFamily: 'PlayfairDisplay',
                          color: _beige,
                          fontSize: 30,
                          fontWeight: FontWeight.w400,
                          height: 1.2,
                        )),
                    const SizedBox(height: 8),
                    Container(width: 32, height: 1.5, color: _gold),
                    const SizedBox(height: 48),

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
