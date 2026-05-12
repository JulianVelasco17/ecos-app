import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
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
  bool _compartiendo = false;
  final _screenshotCtrl = ScreenshotController();

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

  Future<void> _compartir() async {
    if (widget.frase == null || _compartiendo) return;
    setState(() => _compartiendo = true);

    try {
      final imagen = await _screenshotCtrl.captureFromLongWidget(
        _TarjetaCompartir(frase: widget.frase!),
        pixelRatio: 3.0,
        context: context,
      );
      final dir  = await getTemporaryDirectory();
      final file = File('${dir.path}/ecos_frase.png');
      await file.writeAsBytes(imagen);
      await Share.shareXFiles([XFile(file.path)], text: 'ecos');
    } finally {
      if (mounted) setState(() => _compartiendo = false);
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
                    behavior: HitTestBehavior.opaque,
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Icon(Icons.arrow_back_ios, color: Color(0x55F3EBD6), size: 18),
                    ),
                  ),
                ),

                // Contenido scrolleable
                Expanded(
                  child: _cargando
                      ? const SizedBox.shrink()
                      : SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(28, 28, 28, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (widget.frase != null)
                                _FraseDorada(frase: widget.frase!),

                              const SizedBox(height: 16),
                              Container(width: 32, height: 1.5, color: _gold),
                              const SizedBox(height: 20),

                              if (widget.desarrollo != null)
                                Text(
                                  widget.desarrollo!,
                                  style: TextStyle(
                                    color: _beige.withValues(alpha: 0.6),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    height: 1.8,
                                    letterSpacing: 0.2,
                                  ),
                                ),

                              if (_expansion != null) ...[
                                const SizedBox(height: 32),
                                ...() {
                                  final parrafos = _expansion!
                                      .split('\n\n')
                                      .where((p) => p.trim().isNotEmpty)
                                      .toList();
                                  return parrafos.asMap().entries.map((e) {
                                    final isLast = e.key == parrafos.length - 1;
                                    final textoStyle = TextStyle(
                                      color: _beige.withValues(alpha: 0.45),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w400,
                                      height: 1.8,
                                      letterSpacing: 0.2,
                                    );
                                    if (!isLast) {
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 24),
                                        child: Text(e.value.trim(), style: textoStyle),
                                      );
                                    }
                                    // Último párrafo: imagen a la izquierda, texto sangrado al mismo nivel
                                    return Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
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
                                        Expanded(
                                          child: Text(e.value.trim(), style: textoStyle),
                                        ),
                                      ],
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
                      const SizedBox(width: 8),
                      _BotonReaccion(
                        icono: Icons.ios_share_outlined,
                        iconoActivo: Icons.ios_share,
                        label: _compartiendo ? '...' : 'Compartir',
                        activo: false,
                        onTap: _compartir,
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

class _TarjetaCompartir extends StatelessWidget {
  final String frase;
  const _TarjetaCompartir({required this.frase});

  @override
  Widget build(BuildContext context) {
    // Formato Story 9:16 — 1080×1920
    return Container(
      width: 1080,
      height: 1920,
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 96),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(flex: 3),
          _FraseDorada(frase: frase, fontSize: 88),
          const Spacer(flex: 4),
          const Divider(color: Color(0x22F3EBD6), thickness: 1),
          const SizedBox(height: 40),
          const Text(
            'ecos',
            style: TextStyle(
              color: Color(0x55F3EBD6),
              fontSize: 32,
              letterSpacing: 12,
              fontWeight: FontWeight.w300,
            ),
          ),
          const SizedBox(height: 96),
        ],
      ),
    );
  }
}

class _FraseDorada extends StatefulWidget {
  final String frase;
  final double fontSize;
  const _FraseDorada({required this.frase, this.fontSize = 36});

  @override
  State<_FraseDorada> createState() => _FraseDoradaState();
}

class _FraseDoradaState extends State<_FraseDorada> {
  late Set<int> _indicesDorados;

  @override
  void initState() {
    super.initState();
    final palabras = widget.frase.split(' ');
    final candidatos = List<int>.from(
      palabras.asMap().entries
          .where((e) => e.value.replaceAll(RegExp(r'[^\w]'), '').length >= 4)
          .map((e) => e.key),
    )..shuffle(Random());
    _indicesDorados = candidatos.take(2).toSet();
  }

  @override
  Widget build(BuildContext context) {
    final base  = TextStyle(
      fontFamily: 'PlayfairDisplay',
      color: const Color(0xFFF3EBD6),
      fontSize: widget.fontSize,
      fontWeight: FontWeight.w400,
      height: 1.2,
      letterSpacing: 1.0,
    );
    final dorado = TextStyle(
      fontFamily: 'PlayfairDisplay',
      color: const Color(0xFFB8973A),
      fontSize: widget.fontSize,
      fontWeight: FontWeight.w400,
      height: 1.2,
      letterSpacing: 1.0,
    );

    final palabras = widget.frase.split(' ');
    final spans = <TextSpan>[];
    for (int i = 0; i < palabras.length; i++) {
      final esDorado = _indicesDorados.contains(i);
      final esDoradoSig = i + 1 < palabras.length && _indicesDorados.contains(i + 1);
      // El espacio va con el estilo de la palabra siguiente para evitar gaps
      final texto = i < palabras.length - 1
          ? (esDorado == esDoradoSig ? '${palabras[i]} ' : palabras[i])
          : palabras[i];
      spans.add(TextSpan(text: texto, style: esDorado ? dorado : base));
      // Si cambió el estilo, agregar el espacio con el estilo de la siguiente
      if (i < palabras.length - 1 && esDorado != esDoradoSig) {
        spans.add(TextSpan(text: ' ', style: esDoradoSig ? dorado : base));
      }
    }

    return RichText(text: TextSpan(children: spans));
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
