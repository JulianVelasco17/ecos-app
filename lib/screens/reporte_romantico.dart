import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/claude_service.dart';

class PantallaReporteRomantico extends StatefulWidget {
  final String miNombre;
  final String miSolar;
  final String miLunar;
  final String miAsc;
  final String amigoNombre;
  final String? amigoFotoUrl;
  final String amigoSolar;
  final String amigoLunar;
  final String amigoAsc;
  final String arquetipo;
  final String miUid;
  final String amigoUid;

  const PantallaReporteRomantico({
    super.key,
    required this.miNombre,
    required this.miSolar,
    required this.miLunar,
    required this.miAsc,
    required this.amigoNombre,
    this.amigoFotoUrl,
    required this.amigoSolar,
    required this.amigoLunar,
    required this.amigoAsc,
    required this.arquetipo,
    required this.miUid,
    required this.amigoUid,
  });

  @override
  State<PantallaReporteRomantico> createState() => _PantallaReporteRomaticoState();
}

class _PantallaReporteRomaticoState extends State<PantallaReporteRomantico> {
  bool _cargando = true;
  Map<String, String> _reporte = {};

  static const _beige   = Color(0xFFF3EBD6);
  static const _beigeOn = Color(0xFFD6CCB8);

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final cacheKey = 'romantico_${widget.miUid}_${widget.amigoUid}';
    final cacheDoc = await FirebaseFirestore.instance
        .collection('lecturasProfundas').doc(cacheKey).get();

    if (cacheDoc.exists) {
      final data = cacheDoc.data()!;
      if (mounted) {
      setState(() {
        _reporte = Map<String, String>.from(data['reporte'] as Map);
        _cargando = false;
      });
    }
    return;
    }

    final raw = await ClaudeService.generarCompatibilidadRomantica(
      nombre1:     widget.miNombre,
      signoSolar1: widget.miSolar,
      signoLunar1: widget.miLunar,
      asc1:        widget.miAsc,
      nombre2:     widget.amigoNombre,
      signoSolar2: widget.amigoSolar,
      signoLunar2: widget.amigoLunar,
      asc2:        widget.amigoAsc,
      arquetipo:   widget.arquetipo,
    );

    Map<String, String> reporte = {};
    try {
      final start = raw.indexOf('{');
      final end   = raw.lastIndexOf('}');
      final json  = jsonDecode(raw.substring(start, end + 1));
      reporte = {
        'intro':        json['intro']        as String? ?? '',
        'atraccion':    json['atraccion']    as String? ?? '',
        'comunicacion': json['comunicacion'] as String? ?? '',
        'desafios':     json['desafios']     as String? ?? '',
        'potencial':    json['potencial']    as String? ?? '',
      };
    } catch (_) {
      reporte = {'intro': raw};
    }

    await FirebaseFirestore.instance
        .collection('lecturasProfundas').doc(cacheKey)
        .set({'reporte': reporte, 'fecha': FieldValue.serverTimestamp()});

    if (mounted) setState(() { _reporte = reporte; _cargando = false; });
  }

  @override
  Widget build(BuildContext context) {
    final primerNombre = widget.amigoNombre.split(' ').first;

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

                    // ── Header ───────────────────────────────────────────────
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: Colors.white10,
                          backgroundImage: widget.amigoFotoUrl != null
                              ? NetworkImage(widget.amigoFotoUrl!)
                              : null,
                          child: widget.amigoFotoUrl == null
                              ? const Icon(Icons.person,
                                  color: Colors.white38, size: 20)
                              : null,
                        ),
                        const SizedBox(width: 14),
                        Text(
                          'Tú y $primerNombre',
                          style: const TextStyle(
                            color: _beige,
                            fontSize: 18,
                            fontWeight: FontWeight.w300,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 48),

                    // ── Arquetipo ────────────────────────────────────────────
                    Text(
                      'ARQUETIPO',
                      style: TextStyle(
                        color: _beigeOn.withValues(alpha: 0.35),
                        fontSize: 10,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.arquetipo,
                      style: const TextStyle(
                        color: _beige,
                        fontSize: 32,
                        fontWeight: FontWeight.w200,
                        letterSpacing: 1,
                        height: 1.2,
                      ),
                    ),

                    const SizedBox(height: 48),
                    Divider(color: _beige.withValues(alpha: 0.08)),
                    const SizedBox(height: 40),

                    // ── Intro ────────────────────────────────────────────────
                    if (_reporte['intro']?.isNotEmpty == true)
                      Text(
                        _reporte['intro']!,
                        style: const TextStyle(
                          color: _beige,
                          fontSize: 16,
                          fontWeight: FontWeight.w300,
                          height: 1.8,
                          letterSpacing: 0.2,
                        ),
                      ),

                    const SizedBox(height: 48),
                    Divider(color: _beige.withValues(alpha: 0.08)),
                    const SizedBox(height: 40),

                    // ── Secciones ────────────────────────────────────────────
                    _seccion('ATRACCIÓN',     _reporte['atraccion']    ?? ''),
                    _seccion('COMUNICACIÓN',  _reporte['comunicacion'] ?? ''),
                    _seccion('DESAFÍOS',      _reporte['desafios']     ?? ''),
                    _seccion('POTENCIAL',     _reporte['potencial']    ?? ''),

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
      padding: const EdgeInsets.only(bottom: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo,
              style: TextStyle(
                  color: _beigeOn.withValues(alpha: 0.35),
                  fontSize: 10,
                  letterSpacing: 3)),
          const SizedBox(height: 14),
          Text(texto,
              style: TextStyle(
                  color: _beige.withValues(alpha: 0.75),
                  fontSize: 14,
                  fontWeight: FontWeight.w300,
                  height: 1.85,
                  letterSpacing: 0.2)),
        ],
      ),
    );
  }
}
