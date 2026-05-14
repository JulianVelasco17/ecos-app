import 'dart:io';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import '../widgets/ouroboros_loader.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../services/calculos_astrales.dart';
import '../services/claude_service.dart';

// ─── Imágenes decorativas — rotan cada día ────────────────────────────────────

const _imagenesDecorativas = [
  'https://res.cloudinary.com/dwemowboc/image/upload/v1778719612/monk_rm8gvy.png',
  // añade más URLs aquí (todas 1080x1080)
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
  bool _bookmarkPressed = false;
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
      final imagen = await _screenshotCtrl.captureFromWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: _TarjetaCompartir(frase: widget.frase!),
        ),
        pixelRatio: 1.0,
        targetSize: const Size(1080, 3000),
      );
      final dir  = await getTemporaryDirectory();
      final file = File('${dir.path}/ecos_frase.png');
      await file.writeAsBytes(imagen);
      await Share.shareXFiles([XFile(file.path)], text: widget.frase);
    } finally {
      if (mounted) setState(() => _compartiendo = false);
    }
  }

  Future<void> _guardar() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    if (_guardado) {
      // Buscar y eliminar el documento guardado
      final snap = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(uid)
          .collection('lecturasGuardadas')
          .where('frase', isEqualTo: widget.frase ?? '')
          .limit(1)
          .get();
      for (final doc in snap.docs) {
        await doc.reference.delete();
      }
      if (mounted) setState(() => _guardado = false);
    } else {
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
  }

  @override
  Widget build(BuildContext context) {
    final parrafos = _expansion != null
        ? _expansion!.split('\n\n').where((p) => p.trim().isNotEmpty).toList()
        : <String>[];

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    behavior: HitTestBehavior.opaque,
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.arrow_back_ios, color: Color(0x55F3EBD6), size: 18),
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () async {
                      setState(() => _bookmarkPressed = true);
                      await Future.delayed(const Duration(milliseconds: 150));
                      if (mounted) setState(() => _bookmarkPressed = false);
                      _guardar();
                    },
                    behavior: HitTestBehavior.opaque,
                    child: AnimatedScale(
                      scale: _bookmarkPressed ? 0.78 : 1.0,
                      duration: const Duration(milliseconds: 150),
                      curve: Curves.easeOut,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          border: Border.all(color: _beige.withValues(alpha: 0.15)),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          _guardado ? Icons.bookmark : Icons.bookmark_border,
                          color: _guardado ? _gold : _beige.withValues(alpha: 0.4),
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Contenido ─────────────────────────────────────────────────
            Expanded(
              child: _cargando
                  ? const Center(child: OuroborosLoader(size: 260))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Label
                          Text(
                            'RESONANCIA PROFUNDA',
                            style: TextStyle(
                              color: _gold.withValues(alpha: 0.7),
                              fontSize: 10,
                              letterSpacing: 3,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Frase + ilustración
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: widget.frase != null
                                    ? _FraseDorada(frase: widget.frase!)
                                    : const SizedBox.shrink(),
                              ),
                              Opacity(
                                opacity: 0.55,
                                child: Image.network(
                                  _imagenDelDia(),
                                  width: 150,
                                  height: 150,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // Divisor
                          Container(width: 28, height: 1, color: _gold.withValues(alpha: 0.5)),

                          const SizedBox(height: 28),

                          // Desarrollo
                          if (widget.desarrollo != null)
                            _ParrafoConLinea(
                              texto: widget.desarrollo!,
                              color: _beige.withValues(alpha: 0.65),
                            ),

                          // Expansión — todos excepto el último con línea normal
                          if (parrafos.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            ...parrafos.sublist(0, parrafos.length - 1).map((p) =>
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: _ParrafoConLinea(
                                  texto: p,
                                  color: _beige.withValues(alpha: 0.45),
                                ),
                              ),
                            ),

                            // Último párrafo en tarjeta oscura
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.fromLTRB(16, 20, 20, 16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF111111),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _beige.withValues(alpha: 0.07)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _ParrafoConLinea(
                                    texto: parrafos.last,
                                    color: _beige.withValues(alpha: 0.45),
                                  ),
                                  const SizedBox(height: 12),
                                  GestureDetector(
                                    onTap: () => setState(() => _cargando = true),
                                    behavior: HitTestBehavior.opaque,
                                    child: Text(
                                      'debug: ver animación →',
                                      style: TextStyle(
                                        color: _gold.withValues(alpha: 0.3),
                                        fontSize: 10,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
            ),

            // ── Botones fijos abajo ───────────────────────────────────────
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
    );
  }
}

class _TarjetaCompartir extends StatelessWidget {
  final String frase;
  const _TarjetaCompartir({required this.frase});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1080,
      color: const Color(0xFFF3EBD6),
      padding: const EdgeInsets.fromLTRB(96, 120, 96, 96),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            frase,
            style: const TextStyle(
              fontFamily: 'PlayfairDisplay',
              color: Color(0xFF222222),
              fontSize: 36,
              fontWeight: FontWeight.w400,
              height: 1.2,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 56),
          const Divider(color: Color(0x22000000), thickness: 1),
          const SizedBox(height: 32),
          const Align(
            alignment: Alignment.centerRight,
            child: Text(
              'ecos',
              style: TextStyle(
                color: Color(0x44000000),
                fontSize: 32,
                letterSpacing: 12,
                fontWeight: FontWeight.w300,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FraseDorada extends StatefulWidget {
  final String frase;
  const _FraseDorada({required this.frase});

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
      fontSize: 36,
      fontWeight: FontWeight.w400,
      height: 1.2,
      letterSpacing: 1.0,
    );
    final dorado = TextStyle(
      fontFamily: 'PlayfairDisplay',
      color: const Color(0xFFB8973A),
      fontSize: 36,
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

class _ParrafoConLinea extends StatelessWidget {
  final String texto;
  final Color color;
  const _ParrafoConLinea({required this.texto, required this.color});

  static const _gold = Color(0xFFB8973A);

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Text('✦', style: TextStyle(color: _gold.withValues(alpha: 0.5), fontSize: 18)),
              const SizedBox(height: 6),
              Expanded(
                child: Container(
                  width: 1,
                  color: _gold.withValues(alpha: 0.15),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: _TextoDestacado(texto: texto, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _TextoDestacado extends StatefulWidget {
  final String texto;
  final Color color;
  const _TextoDestacado({required this.texto, required this.color});

  @override
  State<_TextoDestacado> createState() => _TextoDestacadoState();
}

class _TextoDestacadoState extends State<_TextoDestacado> {
  late Set<int> _indicesNegrita;

  @override
  void initState() {
    super.initState();
    final palabras = widget.texto.split(' ');
    final candidatos = palabras.asMap().entries
        .where((e) => e.value.replaceAll(RegExp(r'[^\wáéíóúüñÁÉÍÓÚÜÑ]'), '').length >= 6)
        .map((e) => e.key)
        .toList()..shuffle(Random());
    _indicesNegrita = candidatos.take(2).toSet();
  }

  @override
  Widget build(BuildContext context) {
    final palabras = widget.texto.split(' ');
    final spans = <TextSpan>[];
    for (int i = 0; i < palabras.length; i++) {
      final negrita = _indicesNegrita.contains(i);
      spans.add(TextSpan(
        text: i < palabras.length - 1 ? '${palabras[i]} ' : palabras[i],
        style: GoogleFonts.manrope(
          color: widget.color,
          fontSize: 16,
          fontWeight: negrita ? FontWeight.w700 : FontWeight.w300,
          height: 1.65,
          letterSpacing: -0.19,
        ),
      ));
    }
    return RichText(text: TextSpan(children: spans));
  }
}

class _BotonReaccion extends StatefulWidget {
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

  @override
  State<_BotonReaccion> createState() => _BotonReaccionState();
}

class _BotonReaccionState extends State<_BotonReaccion> {
  bool _pressed = false;

  static const _beige = Color(0xFFE7D8C9);
  static const _gold  = Color(0xFFB8973A);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: () async {
          setState(() => _pressed = true);
          await Future.delayed(const Duration(milliseconds: 150));
          if (mounted) setState(() => _pressed = false);
          widget.onTap();
        },
        child: AnimatedScale(
          scale: _pressed ? 0.78 : 1.0,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: widget.activo
                  ? _gold.withValues(alpha: 0.12)
                  : _beige.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.activo ? widget.iconoActivo : widget.icono,
                  size: 18,
                  color: widget.activo ? _gold : _beige.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 5),
                Text(
                  widget.label,
                  style: TextStyle(
                    color: widget.activo ? _gold : _beige.withValues(alpha: 0.4),
                    fontSize: 10,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
