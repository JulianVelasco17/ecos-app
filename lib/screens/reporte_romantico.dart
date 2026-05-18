import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/claude_service.dart';
import '../services/calculos_astrales.dart';

const _arquetiposDebug = [
  'Jardín Sereno', 'Cruz de Caminos', 'Sen', 'Delusional',
  'Vértigo', 'Nudo Kármico', 'El Hechizo', 'Umbral',
  'Flor de Loto', 'El Espiral y el Ciclo', 'Animo Flore', 'Los Alquimistas',
  'Amor Fati', 'Sublime', 'La Maravilla', 'Sahacara',
];

// 0 = cargando  1 = carta visible (anverso)  2 = reporte
enum _Fase { cargando, carta, reporte }

class PantallaReporteRomantico extends StatefulWidget {
  final String miNombre;
  final String? miFotoUrl;
  final String miSolar;
  final String miLunar;
  final String miAsc;
  final Map<String, String> miPlanetas;
  final String amigoNombre;
  final String? amigoFotoUrl;
  final String amigoSolar;
  final String amigoLunar;
  final String amigoAsc;
  final Map<String, String> amigoPlanetas;
  final String arquetipo;
  final String miUid;
  final String amigoUid;

  const PantallaReporteRomantico({
    super.key,
    required this.miNombre,
    this.miFotoUrl,
    required this.miSolar,
    required this.miLunar,
    required this.miAsc,
    required this.miPlanetas,
    required this.amigoNombre,
    this.amigoFotoUrl,
    required this.amigoSolar,
    required this.amigoLunar,
    required this.amigoAsc,
    required this.amigoPlanetas,
    required this.arquetipo,
    required this.miUid,
    required this.amigoUid,
  });

  @override
  State<PantallaReporteRomantico> createState() => _PantallaReporteRomaticoState();
}

class _PantallaReporteRomaticoState extends State<PantallaReporteRomantico>
    with TickerProviderStateMixin {

  _Fase _fase = _Fase.cargando;
  bool _cargando = true;
  Map<String, String> _reporte = {};
  String? _arquetipoDebug;
  String? _miFotoUrlResolved;
  late final Map<String, double> _scoresSinastria;
  Map<String, String> _escenarios = {};

  // Facts
  int _factIndex = 0;
  Timer? _factTimer;

  // Slide-up de la carta
  late final AnimationController _slideCtrl;
  late final Animation<Offset> _slideAnim;

  // Flip de la carta (drag-driven)
  double _flipProgress = 0.0; // 0.0 → 1.0
  AnimationController? _flipSnapCtrl;

  // Estrellas al revelar
  late final AnimationController _starCtrl;
  late final List<_Particle> _particles;

  // Fade del reporte al entrar
  late final AnimationController _reporteFadeCtrl;
  late final Animation<double> _reporteFadeAnim;

  static const _gifUrl =
      'https://firebasestorage.googleapis.com/v0/b/astro-fd0bf.firebasestorage.app/o/Assets%2Ffondo2.gif?alt=media&token=ef484e31-3c7d-4873-93bf-707188cd687c';
  static const _anversoUrl =
      'https://firebasestorage.googleapis.com/v0/b/astro-fd0bf.firebasestorage.app/o/Assets%2Fanverso.png?alt=media&token=88b0101a-9661-4079-a776-2472ced1daa3';
  static const _arquetipoUrl =
      'https://firebasestorage.googleapis.com/v0/b/astro-fd0bf.firebasestorage.app/o/Assets%2Falquimistas.png?alt=media&token=cb123d2d-38d5-4a7d-85bc-2bd0280f1e79';

  static const _beige = Color(0xFFF3EBD6);

  List<String> get _facts {
    final yo   = widget.miNombre.split(' ').first;
    final otro = widget.amigoNombre.split(' ').first;
    final p1   = widget.miPlanetas;
    final p2   = widget.amigoPlanetas;
    return [
      '$yo tiene su Sol en ${widget.miSolar}',
      '$otro tiene su Sol en ${widget.amigoSolar}',
      '$yo tiene su Luna en ${widget.miLunar}',
      '$otro tiene su Luna en ${widget.amigoLunar}',
      if (p1['Mercurio'] != null) '$yo tiene Mercurio en ${p1['Mercurio']}',
      if (p2['Mercurio'] != null) '$otro tiene Mercurio en ${p2['Mercurio']}',
      if (p1['Venus'] != null) '$yo tiene Venus en ${p1['Venus']}',
      if (p2['Venus'] != null) '$otro tiene Venus en ${p2['Venus']}',
      if (p1['Marte'] != null) '$yo tiene Marte en ${p1['Marte']}',
      if (p2['Marte'] != null) '$otro tiene Marte en ${p2['Marte']}',
      if (p1['Júpiter'] != null) '$yo tiene Júpiter en ${p1['Júpiter']}',
      if (p2['Júpiter'] != null) '$otro tiene Júpiter en ${p2['Júpiter']}',
      '$yo tiene su Ascendente en ${widget.miAsc}',
      '$otro tiene su Ascendente en ${widget.amigoAsc}',
    ];
  }

  bool get _listoParaRevelar => !_cargando;
  String get _arquetipoActivo => _arquetipoDebug ?? widget.arquetipo;

  @override
  void initState() {
    super.initState();

    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _slideAnim = Tween<Offset>(begin: const Offset(0, 1.2), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));

    _starCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    final rng = math.Random();
    _particles = List.generate(30, (_) => _Particle(
      angle: rng.nextDouble() * 2 * math.pi,
      speed: 0.4 + rng.nextDouble() * 0.6,
      size:  3.0 + rng.nextDouble() * 5.0,
    ));

    _reporteFadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _reporteFadeAnim = CurvedAnimation(parent: _reporteFadeCtrl, curve: Curves.easeOut);

    _scoresSinastria = calcularScoresSinastria(
      miSolar:       widget.miSolar,
      amigoSolar:    widget.amigoSolar,
      miLunar:       widget.miLunar,
      amigoLunar:    widget.amigoLunar,
      miAsc:         widget.miAsc,
      amigoAsc:      widget.amigoAsc,
      miPlanetas:    widget.miPlanetas,
      amigoPlanetas: widget.amigoPlanetas,
    );
    _miFotoUrlResolved = widget.miFotoUrl;
    _iniciarFacts();
    _cargar();
    _resolverMiFoto();
    WidgetsBinding.instance.addPostFrameCallback((_) => _precargar());
  }

  Future<void> _resolverMiFoto() async {
    if (_miFotoUrlResolved != null) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance.collection('usuarios').doc(uid).get();
    final url = doc.data()?['fotoUrl'] as String?
        ?? FirebaseAuth.instance.currentUser?.photoURL;
    if (mounted && url != null) setState(() => _miFotoUrlResolved = url);
  }

  Future<void> _precargar() async {
    if (!mounted) return;
    await precacheImage(const NetworkImage(_anversoUrl), context);
    // ignore: use_build_context_synchronously
    if (!mounted) return;
    await precacheImage(const NetworkImage(_arquetipoUrl), context);
  }

  void _iniciarFacts() {
    _factTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted) return;
      setState(() => _factIndex = (_factIndex + 1) % _facts.length);
    });
  }

  @override
  void dispose() {
    _factTimer?.cancel();
    _slideCtrl.dispose();
    _flipSnapCtrl?.dispose();
    _starCtrl.dispose();
    _reporteFadeCtrl.dispose();
    super.dispose();
  }

  // ── Tap "Revelar reporte" ────────────────────────────────────────────────
  void _revelar() {
    _factTimer?.cancel();
    setState(() => _fase = _Fase.carta);
    _slideCtrl.forward();
  }

  // ── Pan para girar la carta (cualquier dirección) ───────────────────────
  void _onPanUpdate(DragUpdateDetails d) {
    if (_fase != _Fase.carta) return;
    final delta = (d.delta.dx.abs() > d.delta.dy.abs() ? d.delta.dx : d.delta.dy);
    setState(() {
      _flipProgress = (_flipProgress + delta / 160.0).clamp(0.0, 1.0);
    });
  }

  void _onPanEnd(DragEndDetails d) {
    if (_fase != _Fase.carta) return;
    final speed = d.velocity.pixelsPerSecond;
    final velocidadSuficiente = speed.dx.abs() > 200 || speed.dy.abs() > 200;
    if (_flipProgress > 0.35 || velocidadSuficiente) {
      _snapFlip(1.0);
    } else {
      _snapFlip(0.0);
    }
  }

  void _snapFlip(double target) {
    if (target == 1.0) HapticFeedback.mediumImpact();
    _flipSnapCtrl?.dispose();
    _flipSnapCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    final start = _flipProgress;
    _flipSnapCtrl!.addListener(() {
      if (!mounted) return;
      setState(() {
        _flipProgress = start + (target - start) * _flipSnapCtrl!.value;
      });
    });
    if (target == 1.0) {
      _flipSnapCtrl!.addStatusListener((s) {
        if (s == AnimationStatus.completed && mounted) {
          HapticFeedback.heavyImpact();
          _starCtrl.forward(from: 0);
          Future.delayed(const Duration(milliseconds: 400), () {
            if (mounted) {
              setState(() => _fase = _Fase.reporte);
              _reporteFadeCtrl.forward(from: 0);
            }
          });
        }
      });
    }
    _flipSnapCtrl!.forward();
  }

  Future<void> _regenerarReporte() async {
    if (_cargando) return;
    final cacheKey = 'romantico_${widget.miUid}_${widget.amigoUid}';
    setState(() { _reporte = {}; _cargando = true; });

    await FirebaseFirestore.instance.collection('lecturasProfundas').doc(cacheKey).delete();

    // Generar reporte y escenarios en paralelo sin caché
    final resultados = await Future.wait([
      ClaudeService.generarCompatibilidadRomantica(
        nombre1:     widget.miNombre,
        signoSolar1: widget.miSolar,
        signoLunar1: widget.miLunar,
        asc1:        widget.miAsc,
        nombre2:     widget.amigoNombre,
        signoSolar2: widget.amigoSolar,
        signoLunar2: widget.amigoLunar,
        asc2:        widget.amigoAsc,
        arquetipo:   widget.arquetipo,
      ),
      ClaudeService.generarEscenariosVida(
        nombre1:   widget.miNombre,   nombre2:   widget.amigoNombre,
        solar1:    widget.miSolar,    solar2:    widget.amigoSolar,
        lunar1:    widget.miLunar,    lunar2:    widget.amigoLunar,
        asc1:      widget.miAsc,      asc2:      widget.amigoAsc,
        planetas1: widget.miPlanetas, planetas2: widget.amigoPlanetas,
        arquetipo: widget.arquetipo,
      ),
    ]);

    final raw        = resultados[0] as String;
    final escenarios = resultados[1] as Map<String, String>;

    Map<String, String> reporte = {};
    try {
      final start = raw.indexOf('{');
      final end   = raw.lastIndexOf('}');
      final json  = jsonDecode(raw.substring(start, end + 1));
      reporte = {
        'intro':              json['intro']              as String? ?? '',
        'atraccion':          json['atraccion']          as String? ?? '',
        'comunicacion':       json['comunicacion']       as String? ?? '',
        'conexion_emocional': json['conexion_emocional'] as String? ?? '',
        'potencial':          json['potencial']          as String? ?? '',
      };
    } catch (_) {
      reporte = {'intro': raw};
    }

    await FirebaseFirestore.instance
        .collection('lecturasProfundas').doc(cacheKey)
        .set({'reporte': reporte, 'escenarios': escenarios, 'fecha': FieldValue.serverTimestamp()});

    if (mounted) setState(() { _reporte = reporte; _escenarios = escenarios; _cargando = false; });
  }

  Future<void> _cargar() async {
    final cacheKey = 'romantico_${widget.miUid}_${widget.amigoUid}';
    final cacheDoc = await FirebaseFirestore.instance
        .collection('lecturasProfundas').doc(cacheKey).get();

    if (cacheDoc.exists) {
      final data = cacheDoc.data()!;
      if (mounted) {
        setState(() {
          _reporte    = Map<String, String>.from(data['reporte'] as Map);
          if (data['escenarios'] != null) {
            _escenarios = Map<String, String>.from(data['escenarios'] as Map);
          }
          _cargando = false;
        });
      }
      // Si faltan escenarios en caché, generarlos
      if (!cacheDoc.data()!.containsKey('escenarios')) {
        final esc = await ClaudeService.generarEscenariosVida(
          nombre1:   widget.miNombre,   nombre2:   widget.amigoNombre,
          solar1:    widget.miSolar,    solar2:    widget.amigoSolar,
          lunar1:    widget.miLunar,    lunar2:    widget.amigoLunar,
          asc1:      widget.miAsc,      asc2:      widget.amigoAsc,
          planetas1: widget.miPlanetas, planetas2: widget.amigoPlanetas,
          arquetipo: widget.arquetipo,
        );
        await FirebaseFirestore.instance
            .collection('lecturasProfundas').doc(cacheKey)
            .update({'escenarios': esc});
        if (mounted) setState(() => _escenarios = esc);
      }
      return;
    }

    // Generar reporte y escenarios en paralelo
    final resultados = await Future.wait([
      ClaudeService.generarCompatibilidadRomantica(
        nombre1:     widget.miNombre,
        signoSolar1: widget.miSolar,
        signoLunar1: widget.miLunar,
        asc1:        widget.miAsc,
        nombre2:     widget.amigoNombre,
        signoSolar2: widget.amigoSolar,
        signoLunar2: widget.amigoLunar,
        asc2:        widget.amigoAsc,
        arquetipo:   widget.arquetipo,
      ),
      ClaudeService.generarEscenariosVida(
        nombre1:   widget.miNombre,   nombre2:   widget.amigoNombre,
        solar1:    widget.miSolar,    solar2:    widget.amigoSolar,
        lunar1:    widget.miLunar,    lunar2:    widget.amigoLunar,
        asc1:      widget.miAsc,      asc2:      widget.amigoAsc,
        planetas1: widget.miPlanetas, planetas2: widget.amigoPlanetas,
        arquetipo: widget.arquetipo,
      ),
    ]);

    final raw        = resultados[0] as String;
    final escenarios = resultados[1] as Map<String, String>;

    Map<String, String> reporte = {};
    try {
      final start = raw.indexOf('{');
      final end   = raw.lastIndexOf('}');
      final json  = jsonDecode(raw.substring(start, end + 1));
      reporte = {
        'intro':              json['intro']              as String? ?? '',
        'atraccion':          json['atraccion']          as String? ?? '',
        'comunicacion':       json['comunicacion']       as String? ?? '',
        'conexion_emocional': json['conexion_emocional'] as String? ?? '',
        'potencial':          json['potencial']          as String? ?? '',
      };
    } catch (_) {
      reporte = {'intro': raw};
    }

    await FirebaseFirestore.instance
        .collection('lecturasProfundas').doc(cacheKey)
        .set({'reporte': reporte, 'escenarios': escenarios, 'fecha': FieldValue.serverTimestamp()});

    if (mounted) setState(() { _reporte = reporte; _escenarios = escenarios; _cargando = false; });
  }

  void _mostrarDebugMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Text('DEBUG · arquetipos',
                style: TextStyle(color: Colors.white38, fontSize: 11, letterSpacing: 2)),
          ),
          ..._arquetiposDebug.map((a) => ListTile(
            dense: true,
            title: Text(a,
                style: TextStyle(
                    color: a == _arquetipoActivo ? _beige : Colors.white54,
                    fontSize: 14,
                    fontWeight: FontWeight.w300)),
            onTap: () {
              setState(() => _arquetipoDebug = a);
              Navigator.pop(context);
            },
          )),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final primerNombre = widget.amigoNombre.split(' ').first;
    final facts = _facts;
    final listo = _listoParaRevelar;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [

          // ═══════════════════════════════════════════════════════════════════
          // FASE 0: Pantalla de carga con facts
          // ═══════════════════════════════════════════════════════════════════
          if (_fase == _Fase.cargando) ...[
            SizedBox.expand(
              child: RotatedBox(
                quarterTurns: 1,
                child: Image.network(_gifUrl, fit: BoxFit.cover),
              ),
            ),
            const SizedBox.expand(child: ColoredBox(color: Color(0x80000000))),

            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 48),

                    // Fotos traslapadas
                    Center(
                      child: SizedBox(
                        width: 210,
                        height: 108,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            ClipOval(
                              child: SizedBox(
                                width: 104, height: 104,
                                child: _miFotoUrlResolved != null
                                    ? Image.network(
                                        _miFotoUrlResolved!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, e, st) => _inicialWidget(widget.miNombre),
                                      )
                                    : _inicialWidget(widget.miNombre),
                              ),
                            ),
                            Positioned(
                              left: 72,
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.black, width: 2),
                                ),
                                child: CircleAvatar(
                                  radius: 52,
                                  backgroundColor: Colors.white10,
                                  backgroundImage: widget.amigoFotoUrl != null
                                      ? NetworkImage(widget.amigoFotoUrl!) : null,
                                  child: widget.amigoFotoUrl == null
                                      ? const Icon(Icons.person, color: Colors.white38, size: 32)
                                      : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 56),

                    SizedBox(
                      height: 80,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 600),
                        transitionBuilder: (child, anim) =>
                            FadeTransition(opacity: anim, child: child),
                        child: Text(
                          facts[_factIndex],
                          key: ValueKey(_factIndex),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w300,
                            height: 1.6,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),

                    const Spacer(),

                    AnimatedOpacity(
                      opacity: listo ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 600),
                      child: GestureDetector(
                        onTap: listo ? _revelar : null,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: const Center(
                            child: Text(
                              'Revelar reporte',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 13,
                                letterSpacing: 3,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],

          // ═══════════════════════════════════════════════════════════════════
          // FASE 1: Carta sube y se puede voltear arrastrando
          // ═══════════════════════════════════════════════════════════════════
          if (_fase == _Fase.carta) ...[
            SizedBox.expand(
              child: RotatedBox(
                quarterTurns: 1,
                child: Image.network(_gifUrl, fit: BoxFit.cover),
              ),
            ),
            const SizedBox.expand(child: ColoredBox(color: Color(0x80000000))),
            // Beige→negro: entra con el slide, oscurece con el flip
            AnimatedBuilder(
              animation: _slideCtrl,
              builder: (_, child) => SizedBox.expand(
                child: ColoredBox(
                  color: Color.lerp(
                    const Color(0xFFF3EBD6).withValues(alpha: _slideCtrl.value),
                    Colors.black,
                    _flipProgress,
                  )!,
                ),
              ),
            ),

            Center(
              child: SlideTransition(
                position: _slideAnim,
                child: GestureDetector(
                  onPanUpdate: _onPanUpdate,
                  onPanEnd: _onPanEnd,
                  child: _CartaAnimada(
                    flipProgress: _flipProgress,
                    anversoUrl: _anversoUrl,
                    arquetipoUrl: _arquetipoUrl,
                    cardWidth: size.width * 0.85,
                    cardHeight: size.height * 0.74,
                  ),
                ),
              ),
            ),

            // Estrellas al revelar
            AnimatedBuilder(
              animation: _starCtrl,
              builder: (_, ch) => IgnorePointer(
                child: CustomPaint(
                  size: Size(size.width, size.height),
                  painter: _StarPainter(
                    particles: _particles,
                    progress: _starCtrl.value,
                    center: Offset(size.width / 2, size.height / 2),
                    maxRadius: size.width * 0.75,
                  ),
                ),
              ),
            ),

            // Hint "desliza →"
            Positioned(
              bottom: 60,
              left: 0, right: 0,
              child: AnimatedBuilder(
                animation: _slideCtrl,
                builder: (_, ch) => AnimatedOpacity(
                  opacity: _slideCtrl.isCompleted ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 500),
                  child: const Column(
                    children: [
                      Text(
                        'desliza →',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 13,
                          letterSpacing: 3,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],

          // ═══════════════════════════════════════════════════════════════════
          // FASE 2: Reporte
          // ═══════════════════════════════════════════════════════════════════
          if (_fase == _Fase.reporte) ...[
            const SizedBox.expand(child: ColoredBox(color: Colors.black)),
            FadeTransition(
              opacity: _reporteFadeAnim,
              child: SlideTransition(
                position: Tween(begin: const Offset(0, 0.04), end: Offset.zero)
                    .animate(_reporteFadeAnim),
                child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 56, 28, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: Colors.black12,
                              backgroundImage: widget.amigoFotoUrl != null
                                  ? NetworkImage(widget.amigoFotoUrl!) : null,
                              child: widget.amigoFotoUrl == null
                                  ? const Icon(Icons.person, color: Colors.black38, size: 20)
                                  : null,
                            ),
                            const SizedBox(width: 14),
                            Text('Tú y $primerNombre',
                                style: const TextStyle(
                                  color: Color(0xCCF3EBD6), fontSize: 18,
                                  fontWeight: FontWeight.w300, letterSpacing: 1,
                                )),
                          ],
                        ),
                        const SizedBox(height: 28),
                        Text('ARQUETIPO',
                            style: TextStyle(
                                color: const Color(0xFFF3EBD6).withValues(alpha: 0.35),
                                fontSize: 10, letterSpacing: 3)),
                        const SizedBox(height: 8),
                        Text(_arquetipoActivo,
                            style: const TextStyle(
                              color: Color(0xFFF3EBD6), fontSize: 32,
                              fontWeight: FontWeight.w200, letterSpacing: 1, height: 1.2,
                            )),
                        const SizedBox(height: 28),
                      ],
                    ),
                  ),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 40),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: size.width * 0.85,
                          height: size.height * 0.74,
                          child: Image.network(
                            _arquetipoUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, e, st) =>
                                const ColoredBox(color: Color(0xFF1A1A1A)),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Divider(color: const Color(0xFFF3EBD6).withValues(alpha: 0.08)),
                        const SizedBox(height: 40),
                        if (_reporte['intro']?.isNotEmpty == true)
                          Text(_reporte['intro']!,
                              style: const TextStyle(
                                color: Color(0xCCF3EBD6), fontSize: 16,
                                fontWeight: FontWeight.w300, height: 1.8, letterSpacing: 0.2,
                              )),
                        const SizedBox(height: 48),
                        _CompatibilidadVisual(scores: _scoresSinastria),
                        const SizedBox(height: 48),
                        Divider(color: Colors.black.withValues(alpha: 0.08)),
                        const SizedBox(height: 40),
                        _seccion('ATRACCIÓN FÍSICA',     _reporte['atraccion']          ?? ''),
                        _seccion('COMUNICACIÓN',         _reporte['comunicacion']       ?? ''),
                        _seccion('CONEXIÓN EMOCIONAL',   _reporte['conexion_emocional'] ?? ''),
                        _seccion('POTENCIAL',             _reporte['potencial']          ?? ''),
                        const SizedBox(height: 48),
                        _EscenariosVida(escenarios: _escenarios),
                        const SizedBox(height: 48),
                        GestureDetector(
                          onTap: _regenerarReporte,
                          behavior: HitTestBehavior.opaque,
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(
                                _cargando ? 'generando…' : 'debug: regenerar reporte',
                                style: TextStyle(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  fontSize: 11,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ],
              ),
            ),
              ),
            ),
          ],

          // ── Botones flotantes (siempre visibles) ─────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    behavior: HitTestBehavior.opaque,
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Icon(Icons.arrow_back_ios,
                          color: Color(0x66F3EBD6), size: 18),
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _mostrarDebugMenu,
                    behavior: HitTestBehavior.opaque,
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Icon(Icons.bug_report,
                          color: Color(0x33F3EBD6), size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _inicialWidget(String nombre) => Container(
    color: Colors.white10,
    child: Center(
      child: Text(
        nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
        style: const TextStyle(color: Colors.white38, fontSize: 22),
      ),
    ),
  );

  Widget _seccion(String titulo, String texto) {
    if (texto.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo,
              style: const TextStyle(
                  color: Color(0x66F3EBD6),
                  fontSize: 10,
                  letterSpacing: 3)),
          const SizedBox(height: 14),
          Text(texto,
              style: const TextStyle(
                  color: Color(0xCCF3EBD6),
                  fontSize: 14,
                  fontWeight: FontWeight.w300,
                  height: 1.85,
                  letterSpacing: 0.2)),
        ],
      ),
    );
  }
}

// ── Tabla "Su futuro juntos" ──────────────────────────────────────────────────
class _EscenariosVida extends StatelessWidget {
  final Map<String, String> escenarios;

  static const _filas = [
    ('EN CASA',       'en_casa'),
    ('EN PÚBLICO',    'en_publico'),
    ('EN UNA PELEA',  'en_una_pelea'),
    ('DE VIAJE',      'de_viaje'),
    ('CON DINERO',    'con_dinero'),
    ('EN LA VEJEZ',   'en_la_vejez'),
  ];

  const _EscenariosVida({required this.escenarios});

  @override
  Widget build(BuildContext context) {
    final cargando = escenarios.isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('SU FUTURO JUNTOS',
            style: const TextStyle(
                color: Color(0x66F3EBD6),
                fontSize: 10, letterSpacing: 3)),
        const SizedBox(height: 20),
        ...List.generate(_filas.length * 2 - 1, (i) {
          if (i.isOdd) {
            return const Divider(height: 1, color: Color(0x15F3EBD6));
          }
          final (label, key) = _filas[i ~/ 2];
          final texto = escenarios[key] ?? '';
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 100,
                  child: Text(label,
                      style: const TextStyle(
                          color: Color(0x66F3EBD6),
                          fontSize: 9, letterSpacing: 1.5,
                          fontWeight: FontWeight.w500)),
                ),
                Expanded(
                  child: cargando || texto.isEmpty
                      ? Container(
                          height: 12,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3EBD6).withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        )
                      : Text(texto,
                          style: const TextStyle(
                              color: Color(0xCCF3EBD6),
                              fontSize: 13,
                              fontWeight: FontWeight.w300,
                              height: 1.6,
                              letterSpacing: 0.1)),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

// ── Widget de carta con flip drag-driven ──────────────────────────────────────
class _CartaAnimada extends StatelessWidget {
  final double flipProgress; // 0.0 → 1.0
  final String anversoUrl;
  final String arquetipoUrl;
  final double cardWidth;
  final double cardHeight;

  const _CartaAnimada({
    required this.flipProgress,
    required this.anversoUrl,
    required this.arquetipoUrl,
    required this.cardWidth,
    required this.cardHeight,
  });

  @override
  Widget build(BuildContext context) {
    // 0→0.5: anverso se achica (scaleX 1→0)
    // 0.5→1: arquetipo crece (scaleX 0→1)
    final showAnverso = flipProgress < 0.5;
    final scaleX = showAnverso
        ? 1.0 - flipProgress * 2.0
        : (flipProgress - 0.5) * 2.0;

    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.diagonal3Values(scaleX.clamp(0.0, 1.0), 1.0, 1.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: cardWidth,
          height: cardHeight,
          child: Image.network(
            showAnverso ? anversoUrl : arquetipoUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, e, st) => const ColoredBox(color: Color(0xFF1A1A1A)),
          ),
        ),
      ),
    );
  }
}

// ── Compatibilidad visual: 4 anillos + barra total ───────────────────────────
class _CompatibilidadVisual extends StatelessWidget {
  final Map<String, double> scores;

  static const _labels = ['IDENTIDAD', 'EMOCIÓN', 'ATRACCIÓN', 'PRESENCIA'];
  static const _keys   = ['identidad', 'emocion', 'atraccion', 'presencia'];

  const _CompatibilidadVisual({required this.scores});

  @override
  Widget build(BuildContext context) {
    final s = _keys.map((k) => scores[k] ?? 0.5).toList();
    final total = s.reduce((a, b) => a + b) / s.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(4, (i) => _Anillo(
            label: _labels[i],
            value: s[i],
          )),
        ),
        const SizedBox(height: 36),
        const Text('AFINIDAD TOTAL',
            style: TextStyle(
                color: Color(0x66F3EBD6),
                fontSize: 10, letterSpacing: 3)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: total),
                duration: const Duration(milliseconds: 1200),
                curve: Curves.easeOutCubic,
                builder: (ctx, v, ch) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: Stack(
                        children: [
                          Container(height: 3,
                              color: const Color(0xFFF3EBD6).withValues(alpha: 0.12)),
                          FractionallySizedBox(
                            widthFactor: v,
                            child: Container(height: 3, color: const Color(0xFFF3EBD6)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: total),
              duration: const Duration(milliseconds: 1200),
              curve: Curves.easeOutCubic,
              builder: (ctx, v, ch) => Text(
                '${(v * 100).round()}%',
                style: const TextStyle(
                  color: Color(0xCCF3EBD6),
                  fontSize: 13,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Anillo extends StatelessWidget {
  final String label;
  final double value; // 0.0–1.0

  const _Anillo({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: const Duration(milliseconds: 1100),
      curve: Curves.easeOutCubic,
      builder: (ctx, v, ch) => Column(
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: CustomPaint(
              painter: _AnilloPainter(value: v),
              child: Center(
                child: Text(
                  '${(v * 100).round()}%',
                  style: const TextStyle(
                    color: Color(0xCCF3EBD6),
                    fontSize: 12,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: const TextStyle(
                color: Color(0x66F3EBD6),
                fontSize: 8,
                letterSpacing: 1.5,
              )),
        ],
      ),
    );
  }
}

class _AnilloPainter extends CustomPainter {
  final double value;
  const _AnilloPainter({required this.value});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 10) / 2;
    const stroke = 4.0;
    const start = -math.pi / 2;

    // Fondo
    canvas.drawCircle(center, radius,
        Paint()
          ..color = const Color(0xFFF3EBD6).withValues(alpha: 0.12)
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke);

    // Arco de valor
    if (value > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        2 * math.pi * value,
        false,
        Paint()
          ..color = const Color(0xCCF3EBD6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_AnilloPainter old) => old.value != value;
}

// ── Partícula de estrella ─────────────────────────────────────────────────────
class _Particle {
  final double angle;
  final double speed;
  final double size;
  const _Particle({required this.angle, required this.speed, required this.size});
}

// ── Painter de estrellas ──────────────────────────────────────────────────────
class _StarPainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;   // 0→1
  final Offset center;
  final double maxRadius;

  const _StarPainter({
    required this.particles,
    required this.progress,
    required this.center,
    required this.maxRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress == 0) return;
    final eased = Curves.easeOut.transform(progress);
    for (final p in particles) {
      final dist = eased * maxRadius * p.speed;
      final opacity = (1.0 - progress).clamp(0.0, 1.0);
      final paint = Paint()
        ..color = const Color(0xFFF3EBD6).withValues(alpha: opacity)
        ..style = PaintingStyle.fill;

      final cx = center.dx + math.cos(p.angle) * dist;
      final cy = center.dy + math.sin(p.angle) * dist;
      final s = p.size * (1.0 - progress * 0.5);

      // Estrella de 4 puntas
      final path = Path();
      for (int i = 0; i < 8; i++) {
        final r = i.isEven ? s : s * 0.35;
        final a = i * math.pi / 4 - math.pi / 8;
        final x = cx + math.cos(a) * r;
        final y = cy + math.sin(a) * r;
        if (i == 0) { path.moveTo(x, y); } else { path.lineTo(x, y); }
      }
      path.close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_StarPainter old) => old.progress != progress;
}
