import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/calculos_astrales.dart';
import '../services/claude_service.dart';

// ─── Imágenes decorativas — rotan cada día ────────────────────────────────────

const _imagenesDecorativas = [
  'https://res.cloudinary.com/dwemowboc/image/upload/v1777497436/monk_xlypui.png',
  // añade más URLs aquí para que roten
];

String _imagenDelDia() {
  final dia = DateTime.now().difference(DateTime(2025)).inDays;
  return _imagenesDecorativas[dia % _imagenesDecorativas.length];
}

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
  String? _expansion;
  String? _reaccion;
  bool _guardado = false;

  static const _beige = Color(0xFFE7D8C9);
  static const _gold  = Color(0xFFB8973A);

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

    final fechaTs = datos['fechaNacimiento'] as dynamic;
    final horaStr = datos['horaNacimiento'] as String? ?? '12:00';
    final partes  = horaStr.split(':');
    final hora    = int.tryParse(partes[0]) ?? 12;
    final min     = int.tryParse(partes.length > 1 ? partes[1] : '0') ?? 0;
    final lat     = (datos['latitud']  as num?)?.toDouble() ?? 0.0;
    final lon     = (datos['longitud'] as num?)?.toDouble() ?? 0.0;
    final fecha   = (fechaTs).toDate() as DateTime;

    final carta = CalculosAstrales.calcular(
        fechaNacimiento: fecha, hora: hora, minutos: min, latitud: lat, longitud: lon);

    String? expansion;
    if (widget.frase != null && widget.desarrollo != null) {
      final hoy    = DateTime.now();
      final expKey = '${uid}_exp_${hoy.year}-${hoy.month.toString().padLeft(2,'0')}-${hoy.day.toString().padLeft(2,'0')}';
      final expDoc = await FirebaseFirestore.instance
          .collection('lecturasProfundas').doc(expKey).get();
      if (expDoc.exists) {
        expansion = expDoc.data()!['expansion'] as String?;
      } else {
        expansion = await ClaudeService.generarExpansionDiaria(
          signoSolar:     carta.signoSolar,
          signoLunar:     carta.signoLunar,
          ascendente:     carta.ascendente,
          fraseBase:      widget.frase!,
          desarrolloBase: widget.desarrollo!,
        );
        await FirebaseFirestore.instance
            .collection('lecturasProfundas').doc(expKey)
            .set({'expansion': expansion, 'fecha': FieldValue.serverTimestamp()});
      }
    }

    if (mounted) {
      setState(() {
        _expansion = expansion;
        _cargando  = false;
      });
    }
  }

  Future<void> _guardar() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _guardado) return;

    await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(uid)
        .collection('lecturasGuardadas')
        .add({
      'frase':      widget.frase ?? '',
      'desarrollo': widget.desarrollo ?? '',
      'expansion':  _expansion ?? '',
      'fecha':      FieldValue.serverTimestamp(),
    });

    if (mounted) setState(() => _guardado = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back_ios, color: Color(0x55F3EBD6), size: 18),
                  ),
                ),

                // Contenido
                Expanded(
                  child: _cargando
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.fromLTRB(28, 28, 28, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              if (widget.frase != null)
                                Text(
                                  widget.frase!,
                                  maxLines: 4,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: 'PlayfairDisplay',
                                    color: Color(0xFFF3EBD6),
                                    fontSize: 36,
                                    fontWeight: FontWeight.w400,
                                    height: 1.2,
                                    letterSpacing: 1.0,
                                  ),
                                ),

                              const SizedBox(height: 16),
                              Container(width: 32, height: 1.5, color: _gold),
                              const SizedBox(height: 20),

                              if (widget.desarrollo != null)
                                Text(
                                  widget.desarrollo!,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: _beige.withValues(alpha: 0.6),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    height: 1.8,
                                    letterSpacing: 0.2,
                                  ),
                                ),

                              if (_expansion != null) ...[
                                const Spacer(),
                                ...() {
                                  final parrafos = _expansion!
                                      .split('\n\n')
                                      .where((p) => p.trim().isNotEmpty)
                                      .toList();
                                  return parrafos.asMap().entries.map((e) {
                                    final isLast = e.key == parrafos.length - 1;
                                    final texto = Text(
                                      e.value.trim(),
                                      maxLines: 6,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: _beige.withValues(alpha: 0.45),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w400,
                                        height: 1.8,
                                        letterSpacing: 0.2,
                                      ),
                                    );
                                    if (!isLast) {
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 16),
                                        child: texto,
                                      );
                                    }
                                    // Último párrafo: monje a la izquierda, texto a la derecha
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 16),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          Opacity(
                                            opacity: 0.35,
                                            child: Image.network(
                                              _imagenDelDia(),
                                              width: 100,
                                              fit: BoxFit.contain,
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(child: texto),
                                        ],
                                      ),
                                    );
                                  });
                                }(),
                              ],
                            ],
                          ),
                        ),
                ),

                // Botones fijos abajo
                Container(
                  padding: EdgeInsets.fromLTRB(
                      16, 12, 16, MediaQuery.of(context).padding.bottom + 16),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: _beige.withValues(alpha: 0.07))),
                  ),
                  child: Row(
                    children: [
                      _BotonReaccion(
                        icono: Icons.favorite_border,
                        iconoActivo: Icons.favorite,
                        label: 'Lo siento',
                        activo: _reaccion == 'siento',
                        onTap: () => setState(() =>
                            _reaccion = _reaccion == 'siento' ? null : 'siento'),
                      ),
                      const SizedBox(width: 8),
                      _BotonReaccion(
                        icono: Icons.sentiment_neutral_outlined,
                        iconoActivo: Icons.sentiment_neutral,
                        label: 'No conecto',
                        activo: _reaccion == 'noConecto',
                        onTap: () => setState(() =>
                            _reaccion = _reaccion == 'noConecto' ? null : 'noConecto'),
                      ),
                      const SizedBox(width: 8),
                      _BotonReaccion(
                        icono: Icons.bookmark_border,
                        iconoActivo: Icons.bookmark,
                        label: _guardado ? 'Guardado' : 'Guardar',
                        activo: _guardado,
                        onTap: _guardar,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BotonReaccion extends StatelessWidget {
  final IconData icono;
  final IconData iconoActivo;
  final String label;
  final bool activo;
  final VoidCallback onTap;

  const _BotonReaccion({
    required this.icono,
    required this.iconoActivo,
    required this.label,
    required this.activo,
    required this.onTap,
  });

  static const _beige = Color(0xFFE7D8C9);
  static const _gold  = Color(0xFFB8973A);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: activo
                ? _gold.withValues(alpha: 0.12)
                : _beige.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                activo ? iconoActivo : icono,
                size: 18,
                color: activo ? _gold : _beige.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 5),
              Text(
                label,
                style: TextStyle(
                  color: activo ? _gold : _beige.withValues(alpha: 0.4),
                  fontSize: 10,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
