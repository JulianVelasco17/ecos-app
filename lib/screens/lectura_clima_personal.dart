import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/calculos_astrales.dart';
import '../services/calculos_planetarios.dart';
import '../services/claude_service.dart';

class PantallaLecturaClimaPersonal extends StatefulWidget {
  const PantallaLecturaClimaPersonal({super.key});

  @override
  State<PantallaLecturaClimaPersonal> createState() => _PantallaLecturaClimaPersonalState();
}

class _PantallaLecturaClimaPersonalState extends State<PantallaLecturaClimaPersonal> {
  bool _cargando = true;
  Map<String, String> _lectura = {};

  static const _beige = Color(0xFFF3EBD6);

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final hoy = DateTime.now();
    final fechaKey = '${hoy.year}-${hoy.month.toString().padLeft(2,'0')}-${hoy.day.toString().padLeft(2,'0')}';
    final cacheKey = '${uid}_clima_personal_$fechaKey';

    final cacheDoc = await FirebaseFirestore.instance
        .collection('lecturasProfundas').doc(cacheKey).get();

    if (cacheDoc.exists) {
      if (mounted) {
      setState(() {
        _lectura = Map<String, String>.from(cacheDoc.data()!['lectura'] as Map);
        _cargando = false;
      });
    }
    return;
    }

    // Carta del usuario
    final userDoc = await FirebaseFirestore.instance.collection('usuarios').doc(uid).get();
    if (!userDoc.exists || !mounted) return;
    final datos = userDoc.data()!;
    final fechaTs = datos['fechaNacimiento'] as Timestamp?;
    if (fechaTs == null) return;
    final fecha  = fechaTs.toDate();
    final horaParts = ((datos['horaNacimiento'] as String?) ?? '12:00').split(':');
    final hora   = int.tryParse(horaParts[0]) ?? 12;
    final min    = int.tryParse(horaParts.length > 1 ? horaParts[1] : '0') ?? 0;
    final lat    = (datos['latitud']  as num?)?.toDouble() ?? 0.0;
    final lon    = (datos['longitud'] as num?)?.toDouble() ?? 0.0;

    final carta = CalculosAstrales.calcular(
        fechaNacimiento: fecha, hora: hora, minutos: min, latitud: lat, longitud: lon);
    final planetas = CalculosPlanetarios.calcularPosiciones(hoy);
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
      };
    } catch (_) {
      lectura = {'activado': raw};
    }

    await FirebaseFirestore.instance
        .collection('lecturasProfundas').doc(cacheKey)
        .set({'lectura': lectura, 'fecha': FieldValue.serverTimestamp()});

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
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.arrow_back_ios,
                          color: Color(0x66F3EBD6), size: 18),
                    ),
                    const SizedBox(height: 48),

                    const Text('LECTURA PROFUNDA',
                        style: TextStyle(color: Color(0x55F3EBD6),
                            fontSize: 10, letterSpacing: 3)),
                    const SizedBox(height: 16),
                    const Text('Cómo afecta el clima de hoy\na tu carta natal.',
                        style: TextStyle(color: _beige, fontSize: 22,
                            fontWeight: FontWeight.w300, height: 1.4,
                            letterSpacing: 0.5)),

                    const SizedBox(height: 48),
                    Divider(color: _beige.withValues(alpha: 0.08)),
                    const SizedBox(height: 36),

                    _seccion('QUÉ ESTÁ ACTIVADO', _lectura['activado'] ?? ''),
                    _seccion('CÓMO NAVEGARLO',    _lectura['navegar']  ?? ''),
                    _seccion('QUÉ CUIDAR',         _lectura['cuidar']   ?? ''),

                    const SizedBox(height: 48),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _seccion(String titulo, String texto) {
    if (texto.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo,
              style: TextStyle(color: _beige.withValues(alpha: 0.3),
                  fontSize: 10, letterSpacing: 3)),
          const SizedBox(height: 14),
          Text(texto,
              style: TextStyle(color: _beige.withValues(alpha: 0.8),
                  fontSize: 15, fontWeight: FontWeight.w300,
                  height: 1.8, letterSpacing: 0.2)),
        ],
      ),
    );
  }
}
