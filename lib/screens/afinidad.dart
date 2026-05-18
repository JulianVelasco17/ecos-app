import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'pago_romantico.dart';
import '../services/calculos_astrales.dart';
import '../services/claude_service.dart';
import '../widgets/rueda_zodiacal.dart';

class PantallaAfinidad extends StatefulWidget {
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

  @override
  State<PantallaAfinidad> createState() => _PantallaAfinidadState();
}

class _PantallaAfinidadState extends State<PantallaAfinidad>
    with SingleTickerProviderStateMixin {
  bool _cargando = true;
  Map<String, double> _longitudes = {};
  double _ascLon = 0.0;
  CartaAstral? _carta;
  String _lugarNacimiento = '';
  String _fechaNacimientoStr = '';
  String _horaNacimiento = '';
  String? _planetaSeleccionado;
  String _tab = 'afinidad'; // 'afinidad' | 'carta'

  // Slide rueda ↔ tabla
  late AnimationController _slideCtrl;
  int _paginaCarta = 0;
  double _dragStartX = 0;

  // ── Compatibilidad ──────────────────────────────────────────────────────────
  static const _elementos = {
    'Aries': 'fuego', 'Leo': 'fuego', 'Sagitario': 'fuego',
    'Tauro': 'tierra', 'Virgo': 'tierra', 'Capricornio': 'tierra',
    'Géminis': 'aire', 'Libra': 'aire', 'Acuario': 'aire',
    'Cáncer': 'agua', 'Escorpio': 'agua', 'Piscis': 'agua',
  };

  int _compatBase(String s1, String s2) {
    if (s1 == s2) return 92;
    final e1 = _elementos[s1] ?? '';
    final e2 = _elementos[s2] ?? '';
    if (e1 == e2) return 78;
    const compatibles = {'fuego': 'aire', 'aire': 'fuego', 'tierra': 'agua', 'agua': 'tierra'};
    if (compatibles[e1] == e2) return 58;
    return 22;
  }

  int _score(String s1, String s2, String cat) {
    final base = _compatBase(s1, s2);
    final seed = (widget.miUid + widget.amigoUid + cat).codeUnits.fold<int>(0, (a, b) => a + b);
    return (base + (seed % 25) - 12).clamp(8, 98);
  }

  String _p(Map<String, String> p, String key) => p[key] ?? 'Aries';

  List<(String, int)> get _categorias => [
    ('Identidades',              _score(_p(widget.miPlanetas, 'Sol'),      _p(widget.amigoPlanetas, 'Sol'),      'id')),
    ('Intelecto y comunicación', _score(_p(widget.miPlanetas, 'Mercurio'), _p(widget.amigoPlanetas, 'Mercurio'), 'int')),
    ('Amor y placer',            _score(_p(widget.miPlanetas, 'Venus'),    _p(widget.amigoPlanetas, 'Venus'),    'amor')),
    ('Sexo',                     _score(_p(widget.miPlanetas, 'Marte'),    _p(widget.amigoPlanetas, 'Venus'),    'sex')),
    ('Filosofía de vida',        _score(_p(widget.miPlanetas, 'Júpiter'),  _p(widget.amigoPlanetas, 'Júpiter'),  'filo')),
    ('Emociones',                _score(_p(widget.miPlanetas, 'Luna'),     _p(widget.amigoPlanetas, 'Luna'),     'emo')),
    ('Responsabilidad',          _score(_p(widget.miPlanetas, 'Saturno'),  _p(widget.amigoPlanetas, 'Saturno'),  'resp')),
  ];

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _slideCtrl.addListener(() {
      final p = (_slideCtrl.value + 0.5).floor().clamp(0, 1);
      if (p != _paginaCarta) setState(() => _paginaCarta = p);
    });
    _cargarAmigo();
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarAmigo() async {
    final doc = await FirebaseFirestore.instance
        .collection('usuarios').doc(widget.amigoUid).get();
    if (!doc.exists || !mounted) return;
    final d = doc.data()!;

    final fecha   = (d['fechaNacimiento'] as dynamic).toDate() as DateTime;
    final horaStr = (d['horaNacimiento'] as String?) ?? '12:00';
    final partes  = horaStr.split(':');
    final hora    = int.tryParse(partes[0]) ?? 12;
    final min     = int.tryParse(partes.length > 1 ? partes[1] : '0') ?? 0;
    final lat     = (d['latitud']  as num?)?.toDouble() ?? 0.0;
    final lon     = (d['longitud'] as num?)?.toDouble() ?? 0.0;

    final carta  = CalculosAstrales.calcular(fechaNacimiento: fecha, hora: hora, minutos: min, latitud: lat, longitud: lon);
    final lons   = CalculosAstrales.calcularLongitudes(fecha, hora, min);
    final ascLon = CalculosAstrales.calcularLongitudAscendente(fecha, hora, min, lat, lon);

    if (mounted) {
      setState(() {
        _carta              = carta;
        _longitudes         = lons;
        _ascLon             = ascLon;
        _lugarNacimiento    = (d['lugarNacimiento'] as String?) ?? '';
        _horaNacimiento     = horaStr;
        _fechaNacimientoStr = _formatFecha(fecha);
        _cargando           = false;
      });
    }
  }

  String _formatFecha(DateTime f) {
    const m = ['', 'ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN',
                'JUL', 'AGO', 'SEP', 'OCT', 'NOV', 'DIC'];
    return '${f.day} ${m[f.month]} ${f.year}';
  }

  String _mesLargo(int m) => const [
    '', 'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
    'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
  ][m];

  @override
  Widget build(BuildContext context) {
    final primerNombre = widget.amigoNombre.split(' ').first;
    final hoy      = DateTime.now();
    final fechaStr = '${_mesLargo(hoy.month)} ${hoy.day}, ${hoy.year}';
    final arquetipo = calcularArquetipo(
      miSolar: widget.miSolar, amigoSolar: widget.amigoSolar,
      miLunar: widget.miLunar, amigoLunar: widget.amigoLunar,
      miAsc: widget.miAsc, amigoAsc: widget.amigoAsc,
      miPlanetas: widget.miPlanetas, amigoPlanetas: widget.amigoPlanetas,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF3EBD6),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Back ─────────────────────────────────────────────────────
              GestureDetector(
                onTap: () => Navigator.pop(context),
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Icon(Icons.arrow_back_ios, color: Colors.black38, size: 18),
                ),
              ),
              const SizedBox(height: 8),

              // ── Perfil del amigo ─────────────────────────────────────────
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 58,
                      backgroundColor: Colors.black12,
                      backgroundImage: widget.amigoFotoUrl != null
                          ? NetworkImage(widget.amigoFotoUrl!)
                          : null,
                      child: widget.amigoFotoUrl == null
                          ? Text(
                              widget.amigoNombre[0].toLowerCase(),
                              style: const TextStyle(color: Colors.black54, fontSize: 24, fontWeight: FontWeight.w300),
                            )
                          : null,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          widget.amigoNombre,
                          style: const TextStyle(
                            color: Color(0xFF222222),
                            fontSize: 28,
                            fontFamily: 'PlayfairDisplay',
                            fontWeight: FontWeight.w400,
                            letterSpacing: 1.0,
                          ),
                        ),
                        if (widget.amigoUsername.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            '@${widget.amigoUsername}',
                            style: GoogleFonts.montserrat(
                              color: Colors.black38,
                              fontSize: 11,
                              fontWeight: FontWeight.w300,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (!_cargando) ...[
                      const SizedBox(height: 8),
                      Text(
                        '$_fechaNacimientoStr  ·  $_horaNacimiento  ·  ${_lugarNacimiento.toUpperCase()}',
                        style: GoogleFonts.courierPrime(
                          color: const Color(0xFF777777),
                          fontSize: 11,
                          letterSpacing: 2.0,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 20),
              const Divider(color: Colors.black12),
              const SizedBox(height: 20),

              // ── Tabs ─────────────────────────────────────────────────────
              Container(
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0x1A000000), width: 1)),
                ),
                child: Row(
                  children: [
                    Expanded(child: _TabBtn(label: 'Afinidad',     selected: _tab == 'afinidad', onTap: () => setState(() => _tab = 'afinidad'))),
                    Expanded(child: _TabBtn(label: 'Carta Astral', selected: _tab == 'carta',    onTap: () => setState(() => _tab = 'carta'))),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // ── Contenido del tab ─────────────────────────────────────────
              if (_tab == 'carta') _buildCarta()
              else _buildAfinidad(primerNombre, fechaStr, arquetipo),
            ],
          ),
        ),
      ),
    );
  }

  // ── Tab: Carta Astral ───────────────────────────────────────────────────────
  Widget _buildCarta() {
    if (_cargando) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(child: CircularProgressIndicator(color: Color(0xFFB8973A), strokeWidth: 1.5)),
      );
    }
    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      const simPlanetas = {
        'Sol': '☉︎', 'Luna': '☽︎', 'Mercurio': '☿︎',
        'Venus': '♀︎', 'Marte': '♂︎', 'Júpiter': '♃︎',
        'Saturno': '♄︎', 'Urano': '♅︎', 'Neptuno': '♆︎',
        'Plutón': '♇︎', 'Ascendente': '↑',
      };
      const signosLista = ['Aries','Tauro','Géminis','Cáncer','Leo','Virgo',
        'Libra','Escorpio','Sagitario','Capricornio','Acuario','Piscis'];
      final chipEntries = _longitudes.entries.toList();
      final chipW = (w - 16) / 3;
      final rows = <Widget>[];
      for (var i = 0; i < chipEntries.length; i += 3) {
        final rowItems = chipEntries.skip(i).take(3).toList();
        rows.add(Row(
          children: List.generate(3, (j) {
            if (j >= rowItems.length) return SizedBox(width: chipW + (j < 2 ? 8 : 0));
            final e      = rowItems[j];
            final nombre = e.key;
            final lon    = e.value;
            final grado  = (lon % 30).floor();
            final signo  = signosLista[((lon % 360) / 30).floor() % 12];
            final selec  = _planetaSeleccionado == nombre;
            return _ChipPlaneta(
              width: chipW,
              margin: EdgeInsets.only(right: j < 2 ? 8 : 0),
              simbolo: simPlanetas[nombre] ?? '·',
              nombre: nombre,
              grado: grado,
              signo: signo,
              seleccionado: selec,
              onTap: () => setState(() => _planetaSeleccionado = selec ? null : nombre),
            );
          }),
        ));
        if (i + 3 < chipEntries.length) rows.add(const SizedBox(height: 8));
      }
      final chipsWidget = Column(children: rows);

      final totalPlanetas = 3 + (_carta?.planetas.length ?? 8);
      final tableH = totalPlanetas * 43.0 + 96.0;
      final chipsH = 272.0;
      final wheelH = w + 12.0 + chipsH;

      return Column(
        children: [
          AnimatedBuilder(
            animation: _slideCtrl,
            builder: (context, _) {
              final p = _slideCtrl.value;
              final height = wheelH + (tableH - wheelH) * p;
              return GestureDetector(
                onHorizontalDragStart: (d) => _dragStartX = d.localPosition.dx,
                onHorizontalDragUpdate: (d) {
                  final delta = (d.localPosition.dx - _dragStartX) / w;
                  _slideCtrl.value = (_slideCtrl.value - delta).clamp(0.0, 1.0);
                  _dragStartX = d.localPosition.dx;
                },
                onHorizontalDragEnd: (d) {
                  final vel = d.primaryVelocity ?? 0;
                  if (vel < -200 || (_slideCtrl.value >= 0.4 && vel >= -200)) {
                    _slideCtrl.animateTo(1.0, curve: Curves.easeOut);
                  } else {
                    _slideCtrl.animateTo(0.0, curve: Curves.easeOut);
                  }
                },
                child: ClipRect(
                  child: SizedBox(
                    height: height,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          left: -p * w, top: 0, width: w,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              RepaintBoundary(
                                child: SizedBox(
                                  width: w, height: w,
                                  child: CustomPaint(
                                    painter: RuedaZodiacalPainter(
                                      planetasDesdeLongitudes(_longitudes, _ascLon),
                                      seleccionado: _planetaSeleccionado,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              chipsWidget,
                            ],
                          ),
                        ),
                        Positioned(
                          left: (1 - p) * w, top: 0, width: w,
                          child: _TablaNatal(carta: _carta!),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(2, (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: _paginaCarta == i ? 16 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: _paginaCarta == i ? Colors.black54 : Colors.black12,
                borderRadius: BorderRadius.circular(3),
              ),
            )),
          ),
          const SizedBox(height: 48),
        ],
      );
    });
  }

  // ── Tab: Afinidad ───────────────────────────────────────────────────────────
  Widget _buildAfinidad(String primerNombre, String fechaStr, String arquetipo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),

        // ── Tarjeta principal ─────────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.black.withValues(alpha: 0.07)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 28, height: 20,
                    child: CustomPaint(painter: _MiniVennPainter()),
                  ),
                  const SizedBox(width: 10),
                  const Text('Afinidad',
                    style: TextStyle(
                      fontFamily: 'PlayfairDisplay',
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF222222),
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text('Cómo interactúan sus cartas astrales.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.black.withValues(alpha: 0.4),
                  fontWeight: FontWeight.w300,
                ),
              ),
              const SizedBox(height: 24),
              _VennAfinidad(
                nombreA:    widget.miNombre.split(' ').first,
                nombreB:    primerNombre,
                fotoUrlA:   widget.miFotoUrl,
                fotoUrlB:   widget.amigoFotoUrl,
                categorias: _categorias,
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),

        // CTA premium
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PantallaPagoRomantico(
                miNombre:      widget.miNombre,
                miFotoUrl:     widget.miFotoUrl,
                miSolar:       widget.miSolar,
                miLunar:       widget.miLunar,
                miAsc:         widget.miAsc,
                miPlanetas:    widget.miPlanetas,
                amigoNombre:   widget.amigoNombre,
                amigoFotoUrl:  widget.amigoFotoUrl,
                amigoSolar:    widget.amigoSolar,
                amigoLunar:    widget.amigoLunar,
                amigoAsc:      widget.amigoAsc,
                amigoPlanetas: widget.amigoPlanetas,
                arquetipo:     arquetipo,
                miUid:         widget.miUid,
                amigoUid:      widget.amigoUid,
              ),
            ),
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
            decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(4)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('¿Qué tan románticos podrían ser tú y $primerNombre?',
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w300, height: 1.6)),
                const SizedBox(height: 10),
                const Text('Descubrir mi compatibilidad romántica  →',
                    style: TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: 1)),
              ],
            ),
          ),
        ),

        const SizedBox(height: 40),
        Divider(color: Colors.black.withValues(alpha: 0.07)),
        const SizedBox(height: 28),

        // Planetas
        const Text('PLANETAS',
            style: TextStyle(color: Colors.black38, fontSize: 10, letterSpacing: 3)),
        const SizedBox(height: 20),
        FutureBuilder<Map<String, String>>(
          future: () async {
            final ids = [widget.miUid, widget.amigoUid]..sort();
            final cacheRef = FirebaseFirestore.instance
                .collection('afinidades').doc('${ids[0]}_${ids[1]}');
            final cacheDoc = await cacheRef.get();
            if (cacheDoc.exists) return Map<String, String>.from(cacheDoc.data()!);
            final resultado = await ClaudeService.generarComparacionPlanetas(
              nombre1: widget.miNombre,   nombre2: widget.amigoNombre,
              solar1:  widget.miSolar,    solar2:  widget.amigoSolar,
              lunar1:  widget.miLunar,    lunar2:  widget.amigoLunar,
              planetas1: widget.miPlanetas, planetas2: widget.amigoPlanetas,
            );
            await cacheRef.set(resultado);
            return resultado;
          }(),
          builder: (context, snap) {
            final comp = snap.data ?? {};
            final planetas = [
              ('SOL',      'sol',      widget.miSolar,                       widget.amigoSolar),
              ('LUNA',     'luna',     widget.miLunar,                       widget.amigoLunar),
              ('MERCURIO', 'mercurio', widget.miPlanetas['Mercurio'] ?? '?', widget.amigoPlanetas['Mercurio'] ?? '?'),
              ('VENUS',    'venus',    widget.miPlanetas['Venus']    ?? '?', widget.amigoPlanetas['Venus']    ?? '?'),
              ('MARTE',    'marte',    widget.miPlanetas['Marte']    ?? '?', widget.amigoPlanetas['Marte']    ?? '?'),
              ('JÚPITER',  'jupiter',  widget.miPlanetas['Júpiter']  ?? '?', widget.amigoPlanetas['Júpiter']  ?? '?'),
            ];
            return Column(
              children: planetas.map((p) {
                final texto = comp[p.$2];
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
                          Text(p.$1, style: TextStyle(color: Colors.black.withValues(alpha: 0.35), fontSize: 10, letterSpacing: 3)),
                          const Spacer(),
                          Text('Tú: ${p.$3}', style: const TextStyle(color: Colors.black54, fontSize: 11)),
                          Text('  ·  $primerNombre: ${p.$4}', style: const TextStyle(color: Colors.black54, fontSize: 11)),
                        ],
                      ),
                      if (texto != null) ...[
                        const SizedBox(height: 12),
                        Text(texto, style: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w300, height: 1.7)),
                      ] else
                        const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: SizedBox(height: 12, child: LinearProgressIndicator(
                            backgroundColor: Color(0x18000000), color: Color(0x40000000))),
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
    );
  }
}

// ─── Tab button ───────────────────────────────────────────────────────────────

class _TabBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TabBtn({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 180),
              style: TextStyle(
                color: selected ? Colors.black87 : Colors.black38,
                fontSize: 14,
                letterSpacing: 0.3,
                fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                fontFamily: 'PlayfairDisplay',
              ),
              child: Text(label, textAlign: TextAlign.center),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 1.5,
            color: selected ? Colors.black87 : Colors.transparent,
          ),
        ],
      ),
    );
  }
}

// ─── Chip de planeta ──────────────────────────────────────────────────────────

class _ChipPlaneta extends StatefulWidget {
  final double width;
  final EdgeInsets margin;
  final String simbolo;
  final String nombre;
  final int grado;
  final String signo;
  final bool seleccionado;
  final VoidCallback onTap;

  const _ChipPlaneta({
    required this.width, required this.margin, required this.simbolo,
    required this.nombre, required this.grado, required this.signo,
    required this.seleccionado, required this.onTap,
  });

  @override
  State<_ChipPlaneta> createState() => _ChipPlanetaState();
}

class _ChipPlanetaState extends State<_ChipPlaneta> {
  bool _pressed = false;

  void _handleTap() async {
    setState(() => _pressed = true);
    await Future.delayed(const Duration(milliseconds: 120));
    if (mounted) setState(() => _pressed = false);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final selec = widget.seleccionado;
    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: widget.width,
          margin: widget.margin,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: selec ? Colors.black : Colors.black.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(widget.simbolo,
                  style: TextStyle(fontSize: 15, color: selec ? Colors.white70 : Colors.black54)),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${widget.grado}°',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w400,
                            color: selec ? Colors.white : Colors.black87, height: 1.1)),
                    Text(widget.signo,
                        style: TextStyle(fontSize: 10, height: 1.2,
                            color: selec ? Colors.white54 : Colors.black.withValues(alpha: 0.4))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Tabla natal ──────────────────────────────────────────────────────────────

class _TablaNatal extends StatelessWidget {
  final CartaAstral carta;
  const _TablaNatal({required this.carta});

  static const _simbolosPlaneta = {
    'Ascendente': '↑', 'Sol': '☉', 'Luna': '☽', 'Mercurio': '☿',
    'Venus': '♀', 'Marte': '♂', 'Júpiter': '♃', 'Saturno': '♄',
    'Urano': '♅', 'Neptuno': '♆', 'Plutón': '♇',
  };

  static const _acento = Color(0xFFB8973A);

  @override
  Widget build(BuildContext context) {
    final entradas = <(String, String)>[
      ('Ascendente', carta.ascendente),
      ...carta.planetas.entries
          .where((e) => e.key != 'Sol' && e.key != 'Luna')
          .map((e) => (e.key, e.value)),
      ('Sol',  carta.signoSolar),
      ('Luna', carta.signoLunar),
    ];

    final Map<String, List<String>> porSigno = {};
    for (final e in entradas) {
      porSigno.putIfAbsent(e.$2, () => []).add(e.$1);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  SizedBox(width: 100, child: Text('SIGNS', style: TextStyle(color: _acento, fontSize: 9, letterSpacing: 2))),
                  Text('PLANET / POINT', style: TextStyle(color: _acento, fontSize: 9, letterSpacing: 2)),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(color: Colors.black12, height: 1),
              ...porSigno.entries.map((entry) {
                final signo    = entry.key;
                final planetas = entry.value;
                return Column(
                  children: planetas.asMap().entries.map((pe) {
                    final idx     = pe.key;
                    final planeta = pe.value;
                    final simPlan = _simbolosPlaneta[planeta] ?? '●';
                    final casa    = planeta == 'Ascendente' ? 1 : carta.casas[planeta];
                    return Container(
                      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black12))),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 100,
                            child: idx == 0
                                ? Text(signo, style: const TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.w300, letterSpacing: 0.3))
                                : const SizedBox.shrink(),
                          ),
                          Expanded(
                            child: Row(children: [
                              Text('$simPlan ', style: TextStyle(color: Colors.black.withValues(alpha: 0.35), fontSize: 13)),
                              Text(planeta.toUpperCase(), style: const TextStyle(color: Colors.black54, fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 1.5)),
                            ]),
                          ),
                          SizedBox(
                            width: 28,
                            child: casa != null
                                ? Text('$casa', textAlign: TextAlign.right,
                                    style: TextStyle(color: Colors.black.withValues(alpha: 0.35), fontSize: 13, fontWeight: FontWeight.w500))
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        ),
        Container(
          width: 22,
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: RotatedBox(
            quarterTurns: 1,
            child: Text('CASAS', style: TextStyle(color: Colors.black.withValues(alpha: 0.2), fontSize: 8, letterSpacing: 3)),
          ),
        ),
      ],
    );
  }
}

// ─── Venn ─────────────────────────────────────────────────────────────────────

class _VennAfinidad extends StatelessWidget {
  final String nombreA;
  final String nombreB;
  final String? fotoUrlA;
  final String? fotoUrlB;
  final List<(String, int)> categorias;

  const _VennAfinidad({
    required this.nombreA,
    required this.nombreB,
    required this.categorias,
    this.fotoUrlA,
    this.fotoUrlB,
  });

  static const _colores = {
    'Identidades':              Color(0xFFB8973A),
    'Intelecto y comunicación': Color(0xFFA07850),
    'Amor y placer':            Color(0xFFE87090),
    'Sexo':                     Color(0xFF4AADA0),
    'Filosofía de vida':        Color(0xFF9B72CF),
    'Emociones':                Color(0xFF5580CC),
    'Responsabilidad':          Color(0xFFE07840),
  };

  static const _iconos = {
    'Identidades':              '☉',
    'Intelecto y comunicación': '☿',
    'Amor y placer':            '♡',
    'Sexo':                     '♂',
    'Filosofía de vida':        '♃',
    'Emociones':                '☽',
    'Responsabilidad':          '♄',
  };

  @override
  Widget build(BuildContext context) {
    final compatibles = categorias.where((c) => c.$2 >= 50).map((c) => c.$1).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Venn diagram ───────────────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
          child: LayoutBuilder(builder: (context, constraints) {
            final w   = constraints.maxWidth;
            final r   = w * 0.38;
            final off = r * 0.5;
            final h   = r * 2 + 16;
            final cAx = w / 2 - off;
            final cBx = w / 2 + off;
            final cy  = h / 2;
            return SizedBox(
              height: h,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Círculo izquierdo (beige cálido)
                  Positioned(
                    left: cAx - r, top: 0,
                    child: Container(
                      width: r * 2, height: r * 2,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFF0E6D0).withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                  // Intersección más notoria
                  Positioned(
                    left: w / 2 - off * 0.6, top: cy - r * 0.7,
                    child: Container(
                      width: off * 1.2, height: r * 1.4,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(r),
                        color: const Color(0xFFD4B896).withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                  // Círculo derecho (gris)
                  Positioned(
                    left: cBx - r, top: 0,
                    child: Container(
                      width: r * 2, height: r * 2,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFDDDDDD).withValues(alpha: 0.75),
                      ),
                    ),
                  ),
                  // Foto A — orillada a la izquierda
                  Positioned(
                    left: cAx - r * 0.65, top: cy - 30,
                    child: CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.black12,
                      backgroundImage: fotoUrlA != null ? NetworkImage(fotoUrlA!) : null,
                      child: fotoUrlA == null
                          ? Text(nombreA[0], style: const TextStyle(color: Colors.black45, fontSize: 22, fontWeight: FontWeight.w300))
                          : null,
                    ),
                  ),
                  // Nombre A
                  Positioned(
                    left: cAx - r * 0.65 - 20, top: cy + 38,
                    child: SizedBox(
                      width: 100,
                      child: Text(nombreA,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14, color: Color(0xFF555555),
                          fontFamily: 'PlayfairDisplay', fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                  // Foto B — orillada a la derecha
                  Positioned(
                    left: cBx + r * 0.65 - 30, top: cy - 30,
                    child: CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.black12,
                      backgroundImage: fotoUrlB != null ? NetworkImage(fotoUrlB!) : null,
                      child: fotoUrlB == null
                          ? Text(nombreB[0], style: const TextStyle(color: Colors.black45, fontSize: 22, fontWeight: FontWeight.w300))
                          : null,
                    ),
                  ),
                  // Nombre B
                  Positioned(
                    left: cBx + r * 0.65 - 50, top: cy + 38,
                    child: SizedBox(
                      width: 100,
                      child: Text(nombreB,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14, color: Color(0xFF555555),
                          fontFamily: 'PlayfairDisplay', fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                  // Texto intersección
                  Positioned(
                    left: w / 2 - 44, top: 0, width: 88, height: h,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (compatibles.isEmpty)
                          Text('—', style: TextStyle(fontSize: 13, color: Colors.black.withValues(alpha: 0.25)))
                        else
                          ...compatibles.map((c) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 1.5),
                            child: Text(c,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 9.5, color: Color(0xFF8B6914),
                                letterSpacing: 0.2, height: 1.4,
                              ),
                            ),
                          )),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ),

        const SizedBox(height: 28),

        // ── Círculos por categoría (4 columnas) ───────────────────────────
        LayoutBuilder(builder: (context, constraints) {
          final itemW = (constraints.maxWidth - 24) / 4;
          return Wrap(
            spacing: 8,
            runSpacing: 20,
            alignment: WrapAlignment.center,
            children: categorias.map((cat) {
              final label = cat.$1;
              final score = cat.$2;
              final color = _colores[label] ?? const Color(0xFFB8973A);
              final icono = _iconos[label] ?? '·';
              return SizedBox(
                width: itemW,
                child: Column(
                  children: [
                    SizedBox(
                      width: itemW - 8, height: itemW - 8,
                      child: CustomPaint(
                        painter: _CirculoPainter(score / 100, color),
                        child: Center(
                          child: Text(icono,
                            style: TextStyle(fontSize: (itemW - 8) * 0.28, color: color.withValues(alpha: 0.85)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 9, color: Colors.black45, letterSpacing: 0.2, height: 1.3),
                    ),
                    const SizedBox(height: 2),
                    Text('$score%',
                      style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600, letterSpacing: 0.3),
                    ),
                  ],
                ),
              );
            }).toList(),
          );
        }),
      ],
    );
  }
}

class _MiniVennPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    final r  = size.height * 0.46;
    final cx = size.width / 2;

    final fillA = Paint()..style = PaintingStyle.fill..color = const Color(0xFFF0E6D0);
    final fillB = Paint()..style = PaintingStyle.fill..color = const Color(0xFFCCCCCC);
    final stroke = Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = Colors.black.withValues(alpha: 0.25);

    canvas.drawCircle(Offset(cx - r * 0.42, cy), r, fillA);
    canvas.drawCircle(Offset(cx + r * 0.42, cy), r, fillB);
    canvas.drawCircle(Offset(cx - r * 0.42, cy), r, stroke);
    canvas.drawCircle(Offset(cx + r * 0.42, cy), r, stroke);
  }

  @override
  bool shouldRepaint(_MiniVennPainter old) => false;
}

class _CirculoPainter extends CustomPainter {
  final double valor;
  final Color color;
  const _CirculoPainter(this.valor, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = size.width / 2 - 4;
    const start = -1.5707963;

    canvas.drawCircle(
      Offset(cx, cy), r,
      Paint()..style = PaintingStyle.stroke
             ..strokeWidth = 3.5
             ..color = color.withValues(alpha: 0.12),
    );

    if (valor > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        start,
        valor * 6.2831853,
        false,
        Paint()..style = PaintingStyle.stroke
               ..strokeWidth = 3.5
               ..strokeCap = StrokeCap.round
               ..color = color,
      );
    }

    canvas.drawCircle(
      Offset(cx, cy), r - 2,
      Paint()..style = PaintingStyle.fill
             ..color = color.withValues(alpha: 0.04 + valor * 0.06),
    );
  }

  @override
  bool shouldRepaint(_CirculoPainter old) => old.valor != valor || old.color != color;
}
