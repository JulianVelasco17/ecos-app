import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'pago_romantico.dart';
import '../services/calculos_astrales.dart';
import '../services/claude_service.dart';

// ─── Pantalla de Afinidad ─────────────────────────────────────────────────────

class PantallaAfinidad extends StatelessWidget {
  final String miNombre;
  final String? miFotoUrl;
  final String miSolar;
  final String miLunar;
  final String miAsc;
  final Map<String, String> miPlanetas;

  final String amigoNombre;
  final String amigoUsername;
  final String? amigoFotoUrl;
  final String amigoSolar;
  final String amigoLunar;
  final String amigoAsc;
  final Map<String, String> amigoPlanetas;

  final String captionHoy;
  final String miUid;
  final String amigoUid;

  const PantallaAfinidad({
    super.key,
    required this.miNombre,
    this.miFotoUrl,
    required this.miSolar,
    required this.miLunar,
    required this.miAsc,
    required this.miPlanetas,
    required this.amigoNombre,
    required this.amigoUsername,
    this.amigoFotoUrl,
    required this.amigoSolar,
    required this.amigoLunar,
    required this.amigoAsc,
    required this.amigoPlanetas,
    required this.captionHoy,
    required this.miUid,
    required this.amigoUid,
  });

  // ── Compatibilidad por elementos ─────────────────────────────────────────────
  static const _elementos = {
    'Aries': 'fuego', 'Leo': 'fuego', 'Sagitario': 'fuego',
    'Tauro': 'tierra', 'Virgo': 'tierra', 'Capricornio': 'tierra',
    'Géminis': 'aire', 'Libra': 'aire', 'Acuario': 'aire',
    'Cáncer': 'agua', 'Escorpio': 'agua', 'Piscis': 'agua',
  };

  int _compatBase(String s1, String s2) {
    if (s1 == s2) return 88;
    final e1 = _elementos[s1] ?? '';
    final e2 = _elementos[s2] ?? '';
    if (e1 == e2) return 80;
    const compatibles = {'fuego': 'aire', 'aire': 'fuego', 'tierra': 'agua', 'agua': 'tierra'};
    if (compatibles[e1] == e2) return 68;
    return 36;
  }

  int _score(String s1, String s2, String cat) {
    final base = _compatBase(s1, s2);
    final seed = (miUid + amigoUid + cat).codeUnits.fold<int>(0, (a, b) => a + b);
    return (base + (seed % 15) - 7).clamp(15, 97);
  }

  String _p(Map<String, String> p, String key) => p[key] ?? 'Aries';

  List<(String, int)> get _categorias => [
    ('Identidades',              _score(_p(miPlanetas, 'Sol'),      _p(amigoPlanetas, 'Sol'),      'id')),
    ('Intelecto y comunicación', _score(_p(miPlanetas, 'Mercurio'), _p(amigoPlanetas, 'Mercurio'), 'int')),
    ('Amor y placer',            _score(_p(miPlanetas, 'Venus'),    _p(amigoPlanetas, 'Venus'),    'amor')),
    ('Sexo',                     _score(_p(miPlanetas, 'Marte'),    _p(amigoPlanetas, 'Venus'),    'sex')),
    ('Filosofía de vida',        _score(_p(miPlanetas, 'Júpiter'),  _p(amigoPlanetas, 'Júpiter'),  'filo')),
    ('Emociones',                _score(_p(miPlanetas, 'Luna'),     _p(amigoPlanetas, 'Luna'),     'emo')),
    ('Responsabilidad',          _score(_p(miPlanetas, 'Saturno'),  _p(amigoPlanetas, 'Saturno'),  'resp')),
  ];

  @override
  Widget build(BuildContext context) {
    final hoy = DateTime.now();
    final fechaStr = '${_mes(hoy.month)} ${hoy.day}, ${hoy.year}';
    final primerNombre = amigoNombre.split(' ').first;
    final arquetipo = calcularArquetipo(
      miSolar: miSolar, amigoSolar: amigoSolar,
      miLunar: miLunar, amigoLunar: amigoLunar,
      miAsc: miAsc, amigoAsc: amigoAsc,
      miPlanetas: miPlanetas, amigoPlanetas: amigoPlanetas,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF3EBD6),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Back ──────────────────────────────────────────────────────────
              GestureDetector(
                onTap: () => Navigator.pop(context),
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Icon(Icons.arrow_back_ios, color: Colors.black38, size: 18),
                ),
              ),
              const SizedBox(height: 40),

              // ── Foto + nombre + @username ──────────────────────────────────────
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.black12,
                    backgroundImage: amigoFotoUrl != null ? NetworkImage(amigoFotoUrl!) : null,
                    child: amigoFotoUrl == null
                        ? const Icon(Icons.person, color: Colors.black45, size: 26)
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(amigoNombre,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w400, letterSpacing: 0.2)),
                      if (amigoUsername.isNotEmpty)
                        Text('@$amigoUsername',
                            style: const TextStyle(
                                fontSize: 13, color: Colors.black38, letterSpacing: 0.3)),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 32),
              Divider(color: Colors.black.withValues(alpha: 0.07)),
              const SizedBox(height: 28),

              // ── Hoy ───────────────────────────────────────────────────────────
              Text('HOY · $fechaStr',
                  style: const TextStyle(color: Colors.black38, fontSize: 10, letterSpacing: 3)),
              const SizedBox(height: 14),
              Text(captionHoy.isNotEmpty ? captionHoy : 'El cielo guarda silencio hoy.',
                  style: const TextStyle(
                      color: Colors.black87, fontSize: 15,
                      fontWeight: FontWeight.w300, height: 1.75, letterSpacing: 0.2)),

              const SizedBox(height: 40),
              Divider(color: Colors.black.withValues(alpha: 0.07)),
              const SizedBox(height: 32),

              // ── Venn de afinidad ───────────────────────────────────────────────
              _VennAfinidad(
                nombreA: miNombre.split(' ').first,
                nombreB: primerNombre,
                categorias: _categorias,
              ),

              const SizedBox(height: 40),
              Divider(color: Colors.black.withValues(alpha: 0.07)),
              const SizedBox(height: 28),

              // ── CTA premium ────────────────────────────────────────────────────
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PantallaPagoRomantico(
                      miNombre:      miNombre,
                      miFotoUrl:     miFotoUrl,
                      miSolar:       miSolar,
                      miLunar:       miLunar,
                      miAsc:         miAsc,
                      miPlanetas:    miPlanetas,
                      amigoNombre:   amigoNombre,
                      amigoFotoUrl:  amigoFotoUrl,
                      amigoSolar:    amigoSolar,
                      amigoLunar:    amigoLunar,
                      amigoAsc:      amigoAsc,
                      amigoPlanetas: amigoPlanetas,
                      arquetipo:     arquetipo,
                      miUid:         miUid,
                      amigoUid:      amigoUid,
                    ),
                  ),
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '¿Qué tan románticos podrían ser tú y $primerNombre?',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 15,
                            fontWeight: FontWeight.w300, height: 1.6),
                      ),
                      const SizedBox(height: 10),
                      const Text('Descubrir mi compatibilidad romántica  →',
                          style: TextStyle(
                              color: Colors.white54, fontSize: 12, letterSpacing: 1)),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 40),
              Divider(color: Colors.black.withValues(alpha: 0.07)),
              const SizedBox(height: 28),

              // ── Comparación de planetas ───────────────────────────────────
              Text('PLANETAS',
                  style: const TextStyle(
                      color: Colors.black38, fontSize: 10, letterSpacing: 3)),
              const SizedBox(height: 20),
              FutureBuilder<Map<String, String>>(
                future: () async {
                  final ids = [miUid, amigoUid]..sort();
                  final cacheKey = '${ids[0]}_${ids[1]}';
                  final cacheRef = FirebaseFirestore.instance
                      .collection('afinidades').doc(cacheKey);
                  final cacheDoc = await cacheRef.get();
                  if (cacheDoc.exists) {
                    return Map<String, String>.from(cacheDoc.data()!);
                  }
                  final resultado = await ClaudeService.generarComparacionPlanetas(
                    nombre1:   miNombre,   nombre2:   amigoNombre,
                    solar1:    miSolar,    solar2:    amigoSolar,
                    lunar1:    miLunar,    lunar2:    amigoLunar,
                    planetas1: miPlanetas, planetas2: amigoPlanetas,
                  );
                  await cacheRef.set(resultado);
                  return resultado;
                }(),
                builder: (context, snap) {
                  final comparaciones = snap.data ?? {};
                  final planetas = [
                    ('SOL',      'sol',      miSolar,                    amigoSolar),
                    ('LUNA',     'luna',     miLunar,                    amigoLunar),
                    ('MERCURIO', 'mercurio', miPlanetas['Mercurio'] ?? '?', amigoPlanetas['Mercurio'] ?? '?'),
                    ('VENUS',    'venus',    miPlanetas['Venus']    ?? '?', amigoPlanetas['Venus']    ?? '?'),
                    ('MARTE',    'marte',    miPlanetas['Marte']    ?? '?', amigoPlanetas['Marte']    ?? '?'),
                    ('JÚPITER',  'jupiter',  miPlanetas['Júpiter']  ?? '?', amigoPlanetas['Júpiter']  ?? '?'),
                  ];
                  return Column(
                    children: planetas.map((p) {
                      final label  = p.$1;
                      final key    = p.$2;
                      final signo1 = p.$3;
                      final signo2 = p.$4;
                      final texto  = comparaciones[key];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(label,
                                    style: TextStyle(
                                        color: Colors.black.withValues(alpha: 0.35),
                                        fontSize: 10, letterSpacing: 3)),
                                const Spacer(),
                                Text('Tú: $signo1',
                                    style: const TextStyle(
                                        color: Colors.black54, fontSize: 11)),
                                Text('  ·  $primerNombre: $signo2',
                                    style: const TextStyle(
                                        color: Colors.black54, fontSize: 11)),
                              ],
                            ),
                            if (texto != null) ...[
                              const SizedBox(height: 12),
                              Text(texto,
                                  style: const TextStyle(
                                      color: Colors.black87, fontSize: 14,
                                      fontWeight: FontWeight.w300, height: 1.7)),
                            ] else
                              const Padding(
                                padding: EdgeInsets.only(top: 12),
                                child: SizedBox(
                                  height: 12,
                                  child: LinearProgressIndicator(
                                    backgroundColor: Color(0x18000000),
                                    color: Color(0x40000000),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              ),

              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

  String _mes(int m) => const [
    '', 'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
    'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
  ][m];
}

// ─── Venn de afinidad ─────────────────────────────────────────────────────────

class _VennAfinidad extends StatelessWidget {
  final String nombreA;
  final String nombreB;
  final List<(String, int)> categorias;

  const _VennAfinidad({
    required this.nombreA,
    required this.nombreB,
    required this.categorias,
  });

  @override
  Widget build(BuildContext context) {
    final compatibles = categorias.where((c) => c.$2 >= 50).map((c) => c.$1).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('AFINIDAD',
            style: const TextStyle(
                color: Colors.black38, fontSize: 10, letterSpacing: 3)),
        const SizedBox(height: 28),
        SizedBox(
          height: 220,
          child: CustomPaint(
            painter: _VennPainter(
              nombreA: nombreA,
              nombreB: nombreB,
              compatibles: compatibles,
            ),
            size: Size.infinite,
          ),
        ),
        if (compatibles.isEmpty) ...[
          const SizedBox(height: 20),
          const Text(
            'No hay ámbitos con alta compatibilidad.',
            style: TextStyle(
                color: Colors.black38, fontSize: 13,
                fontWeight: FontWeight.w300, letterSpacing: 0.3),
          ),
        ],
      ],
    );
  }
}

class _VennPainter extends CustomPainter {
  final String nombreA;
  final String nombreB;
  final List<String> compatibles;

  const _VennPainter({
    required this.nombreA,
    required this.nombreB,
    required this.compatibles,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    final r  = size.height * 0.42;
    final cx = size.width / 2;
    final offset = r * 0.52;

    final cA = Offset(cx - offset, cy);
    final cB = Offset(cx + offset, cy);

    final paintFill = Paint()..style = PaintingStyle.fill;

    // Círculo A
    paintFill.color = Colors.black.withValues(alpha: 0.04);
    canvas.drawCircle(cA, r, paintFill);

    // Círculo B
    paintFill.color = Colors.black.withValues(alpha: 0.04);
    canvas.drawCircle(cB, r, paintFill);

    // Bordes
    final paintStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = Colors.black.withValues(alpha: 0.18);
    canvas.drawCircle(cA, r, paintStroke);
    canvas.drawCircle(cB, r, paintStroke);

    // Nombres en extremos
    _text(canvas, nombreA,
        Offset(cA.dx - r * 0.45, cy),
        fontSize: 12, alpha: 0.55, bold: false);
    _text(canvas, nombreB,
        Offset(cB.dx + r * 0.45, cy),
        fontSize: 12, alpha: 0.55, bold: false);

    // Categorías compatibles en la intersección
    final interX = cx;
    final startY = cy - (compatibles.length - 1) * 13.0 / 2;
    for (int i = 0; i < compatibles.length; i++) {
      _text(canvas, compatibles[i],
          Offset(interX, startY + i * 16.0),
          fontSize: 10, alpha: 0.75, bold: false);
    }

    if (compatibles.isEmpty) {
      _text(canvas, '—', Offset(interX, cy),
          fontSize: 13, alpha: 0.25, bold: false);
    }
  }

  void _text(Canvas canvas, String s, Offset center,
      {double fontSize = 11, double alpha = 1.0, bool bold = false}) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          fontSize: fontSize,
          color: Colors.black.withValues(alpha: alpha),
          fontWeight: bold ? FontWeight.w500 : FontWeight.w300,
          letterSpacing: 0.3,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 90);
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_VennPainter old) =>
      old.compatibles != compatibles ||
      old.nombreA != nombreA ||
      old.nombreB != nombreB;
}
