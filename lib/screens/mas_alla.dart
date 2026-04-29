import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/calculos_astrales.dart';
import '../services/aspectos_natales.dart';
import '../services/claude_service.dart';

// ─── Ruta con revelación negra circular ──────────────────────────────────────

class MasAllaRoute extends PageRoute<void> {
  final Offset origen;
  final String? frase;
  final String? desarrollo;

  MasAllaRoute({required this.origen, this.frase, this.desarrollo});

  @override Color get barrierColor => Colors.transparent;
  @override String get barrierLabel => '';
  @override bool get barrierDismissible => false;
  @override bool get maintainState => true;
  @override Duration get transitionDuration => const Duration(milliseconds: 700);
  @override Duration get reverseTransitionDuration => const Duration(milliseconds: 500);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation) {
    return PantallaMasAlla(frase: frase, desarrollo: desarrollo);
  }

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    final size = MediaQuery.of(context).size;
    final radioFinal = sqrt(pow(size.width, 2) + pow(size.height, 2));
    final curva = CurvedAnimation(parent: animation, curve: Curves.easeInOut,
        reverseCurve: Curves.easeInOut);

    return AnimatedBuilder(
      animation: curva,
      builder: (_, _) => ClipPath(
        clipper: _CircleClipper(centro: origen, radio: radioFinal * curva.value),
        child: child,
      ),
    );
  }
}

class _CircleClipper extends CustomClipper<Path> {
  final Offset centro;
  final double radio;
  _CircleClipper({required this.centro, required this.radio});

  @override
  Path getClip(Size size) =>
      Path()..addOval(Rect.fromCircle(center: centro, radius: radio));

  @override
  bool shouldReclip(_CircleClipper old) => old.radio != radio;
}

// ─── Pantalla ─────────────────────────────────────────────────────────────────

class PantallaMasAlla extends StatefulWidget {
  final String? frase;
  final String? desarrollo;
  const PantallaMasAlla({super.key, this.frase, this.desarrollo});

  @override
  State<PantallaMasAlla> createState() => _PantallaMasAllaState();
}

class _PantallaMasAllaState extends State<PantallaMasAlla> {
  bool _cargando = true;

  String _signoSolar = '';
  String _signoLunar = '';
  String _ascendente = '';
  List<AspectoNatal> _aspectos = [];
  String? _expansion;

  static const _beige   = Color(0xFFF3EBD6);
  static const _beigeOn = Color(0xFFD6CCB8);

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final doc = await FirebaseFirestore.instance.collection('usuarios').doc(uid).get();
    if (!doc.exists || !mounted) return;
    final datos = doc.data()!;

    final fechaTs = datos['fechaNacimiento'] as Timestamp?;
    final horaStr = datos['horaNacimiento'] as String? ?? '12:00';
    final partes  = horaStr.split(':');
    final hora    = int.tryParse(partes[0]) ?? 12;
    final min     = int.tryParse(partes.length > 1 ? partes[1] : '0') ?? 0;
    final lat     = (datos['latitud']  as num?)?.toDouble() ?? 0.0;
    final lon     = (datos['longitud'] as num?)?.toDouble() ?? 0.0;
    if (fechaTs == null) return;
    final fecha = fechaTs.toDate();

    final carta   = CalculosAstrales.calcular(
        fechaNacimiento: fecha, hora: hora, minutos: min, latitud: lat, longitud: lon);
    final aspectos = AspectosNatales.calcular(fecha, hora, min);
    final hoy = DateTime.now();

    // Expansión íntima — cache separado
    String? expansion;
    if (widget.frase != null && widget.desarrollo != null) {
      final expKey = '${uid}_exp_${hoy.year}-${hoy.month.toString().padLeft(2,'0')}-${hoy.day.toString().padLeft(2,'0')}';
      final expDoc = await FirebaseFirestore.instance
          .collection('lecturasProfundas').doc(expKey).get();
      if (expDoc.exists) {
        expansion = expDoc.data()!['expansion'] as String?;
      } else {
        expansion = await ClaudeService.generarExpansionDiaria(
          signoSolar:    carta.signoSolar,
          signoLunar:    carta.signoLunar,
          ascendente:    carta.ascendente,
          fraseBase:     widget.frase!,
          desarrolloBase: widget.desarrollo!,
        );
        await FirebaseFirestore.instance
            .collection('lecturasProfundas').doc(expKey)
            .set({'expansion': expansion, 'fecha': FieldValue.serverTimestamp()});
      }
    }

    if (mounted) {
      setState(() {
        _signoSolar = carta.signoSolar;
        _signoLunar = carta.signoLunar;
        _ascendente = carta.ascendente;
        _aspectos   = aspectos;
        _expansion  = expansion;
        _cargando   = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _cargando
            ? const Center(child: CircularProgressIndicator(color: Color(0x44F3EBD6), strokeWidth: 1.5))
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.arrow_back_ios, color: Color(0x66F3EBD6), size: 18),
                    ),

                    const SizedBox(height: 48),

                    // ── Lectura del día expandida ───────────────────────────
                    if (widget.frase != null) ...[
                      Text(
                        widget.frase!,
                        style: const TextStyle(
                          color: _beige,
                          fontSize: 24,
                          fontWeight: FontWeight.w300,
                          height: 1.5,
                          letterSpacing: 0.5,
                        ),
                      ),
                      if (widget.desarrollo != null) ...[
                        const SizedBox(height: 28),
                        Text(
                          widget.desarrollo!,
                          style: TextStyle(
                            color: _beige.withValues(alpha: 0.6),
                            fontSize: 14,
                            fontWeight: FontWeight.w300,
                            height: 1.85,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                      if (_expansion != null) ...[
                        const SizedBox(height: 28),
                        ..._expansion!.split('\n\n').where((p) => p.trim().isNotEmpty).map((p) =>
                          Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: Text(
                              p.trim(),
                              style: TextStyle(
                                color: _beige.withValues(alpha: 0.55),
                                fontSize: 14,
                                fontWeight: FontWeight.w300,
                                height: 1.85,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 56),
                      Divider(color: _beige.withValues(alpha: 0.1)),
                      const SizedBox(height: 48),
                    ],

                    // ── Tu carta natal ──────────────────────────────────────
                    Text('TU CARTA', style: _etiqueta),
                    const SizedBox(height: 20),

                    _filaPilar('SOL',        _signoSolar, simbolosSignos[_signoSolar] ?? ''),
                    const SizedBox(height: 14),
                    _filaPilar('LUNA',       _signoLunar, simbolosSignos[_signoLunar] ?? ''),
                    const SizedBox(height: 14),
                    _filaPilar('ASCENDENTE', _ascendente, simbolosSignos[_ascendente] ?? ''),

                    const SizedBox(height: 48),
                    Divider(color: _beige.withValues(alpha: 0.1)),
                    const SizedBox(height: 40),

                    // ── Aspectos dominantes ─────────────────────────────────
                    Text('ASPECTOS DOMINANTES', style: _etiqueta),
                    const SizedBox(height: 8),
                    Text('Los ángulos más exactos entre tus planetas al nacer.',
                        style: TextStyle(color: _beige.withValues(alpha: 0.3),
                            fontSize: 12, height: 1.6)),
                    const SizedBox(height: 28),

                    ..._aspectos.map((a) => _filaAspecto(a)),

                    const SizedBox(height: 48),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _filaPilar(String etiqueta, String signo, String simbolo) {
    return Row(children: [
      SizedBox(width: 100,
          child: Text(etiqueta, style: TextStyle(color: _beige.withValues(alpha: 0.3),
              fontSize: 11, letterSpacing: 2))),
      Text('$simbolo\uFE0E', style: TextStyle(fontSize: 16, color: _beige.withValues(alpha: 0.5))),
      const SizedBox(width: 10),
      Text(signo, style: const TextStyle(color: _beige, fontSize: 15,
          fontWeight: FontWeight.w300, letterSpacing: 1)),
    ]);
  }

  Widget _filaAspecto(AspectoNatal a) {
    final corto = AspectosNatales.nombreCorto(a.tipo);
    final sig   = AspectosNatales.significados[corto] ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 3, height: 40, margin: const EdgeInsets.only(right: 14, top: 2),
              color: _beige.withValues(alpha: 0.1)),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${a.planeta1}  ·  $corto  ·  ${a.planeta2}',
                style: const TextStyle(color: _beige, fontSize: 13,
                    letterSpacing: 1, fontWeight: FontWeight.w300)),
            const SizedBox(height: 4),
            Text(sig, style: TextStyle(color: _beige.withValues(alpha: 0.35),
                fontSize: 12, height: 1.5)),
          ])),
          Text('${a.orbe.toStringAsFixed(1)}°',
              style: TextStyle(color: _beige.withValues(alpha: 0.25), fontSize: 11)),
        ],
      ),
    );
  }

  TextStyle get _etiqueta => TextStyle(
      color: _beigeOn.withValues(alpha: 0.35), fontSize: 10, letterSpacing: 3);
}
