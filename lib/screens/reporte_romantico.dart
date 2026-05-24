import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../widgets/fade_avatar.dart';
import '../services/debug_config.dart';
import '../widgets/debug_boton_carga.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
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

  bool _imagenesListas = false;

  // Facts
  int _factIndex = 0;
  Timer? _factTimer;

  // Slide-up de la carta
  late final AnimationController _slideCtrl;
  late final Animation<Offset> _slideAnim;

  // Flip de la carta (drag-driven)
  double _flipProgress = 0.0; // 0.0 → 1.0
  AnimationController? _flipSnapCtrl;
  CurvedAnimation? _flipCurved;

  // Fade del reporte al entrar
  late final AnimationController _reporteFadeCtrl;
  late final Animation<double> _reporteFadeAnim;

  static const _gifUrl =
      'https://firebasestorage.googleapis.com/v0/b/astro-fd0bf.firebasestorage.app/o/Assets%2Ffondo2.gif?alt=media&token=ef484e31-3c7d-4873-93bf-707188cd687c';
  static const _anversoUrl =
      'https://firebasestorage.googleapis.com/v0/b/astro-fd0bf.firebasestorage.app/o/Assets%2Fanverso.png?alt=media&token=88b0101a-9661-4079-a776-2472ced1daa3';

  static const _arquetipoImgUrls = <String, String>{
    'Los Alquimistas':      'https://firebasestorage.googleapis.com/v0/b/astro-fd0bf.firebasestorage.app/o/Assets%2FAngie%2Fsideral_ALQUIMISTAS.png?alt=media&token=9f5a54bb-b947-4997-8f29-9f73eb042bd0',
    'Amor Fati':            'https://firebasestorage.googleapis.com/v0/b/astro-fd0bf.firebasestorage.app/o/Assets%2FAngie%2Fsideral_AMOR%20FATI.png?alt=media&token=35b832e1-483f-435f-9794-bb3d95aa1b9e',
    'Animo Flore':          'https://firebasestorage.googleapis.com/v0/b/astro-fd0bf.firebasestorage.app/o/Assets%2FAngie%2Fsideral_ANIMO%20FLORE.png?alt=media&token=017f12c9-0382-4924-87c4-31861e1c2612',
    'Delusional':           'https://firebasestorage.googleapis.com/v0/b/astro-fd0bf.firebasestorage.app/o/Assets%2FAngie%2Fsideral_DELUSIONAL.png?alt=media&token=5428df3c-be61-4981-954e-5c21e7047ebf',
    'El Hechizo':           'https://firebasestorage.googleapis.com/v0/b/astro-fd0bf.firebasestorage.app/o/Assets%2FAngie%2Fsideral_EL%20HECHIZO.png?alt=media&token=d3ce04af-abbe-4fc1-ace9-a68c42b78786',
    'El Espiral y el Ciclo':'https://firebasestorage.googleapis.com/v0/b/astro-fd0bf.firebasestorage.app/o/Assets%2FAngie%2Fsideral_ESPIRAL.png?alt=media&token=b9150ec1-8324-49c9-8442-47f443971eff',
    'Flor de Loto':         'https://firebasestorage.googleapis.com/v0/b/astro-fd0bf.firebasestorage.app/o/Assets%2FAngie%2Fsideral_FLOR%20DE%20LOTO.png?alt=media&token=4328c160-7b46-49b6-b000-42cfb565872b',
    'Jardín Sereno':        'https://firebasestorage.googleapis.com/v0/b/astro-fd0bf.firebasestorage.app/o/Assets%2FAngie%2Fsideral_JARDIN%20SERENO.png?alt=media&token=fa670b03-fbb9-4b7f-b267-351875885a65',
    'La Maravilla':         'https://firebasestorage.googleapis.com/v0/b/astro-fd0bf.firebasestorage.app/o/Assets%2FAngie%2Fsideral_LA%20MARAVILLA.png?alt=media&token=ce263433-c7b8-487c-a62b-1811cfb3ea6d',
    'Nudo Kármico':         'https://firebasestorage.googleapis.com/v0/b/astro-fd0bf.firebasestorage.app/o/Assets%2FAngie%2Fsideral_NUDO%20K.png?alt=media&token=bf356802-e3cf-4361-b63b-800dbd2d2723',
    'Sahacara':             'https://firebasestorage.googleapis.com/v0/b/astro-fd0bf.firebasestorage.app/o/Assets%2FAngie%2Fsideral_SAHACARA.png?alt=media&token=362299b5-57c1-4316-96ba-a6d3a9e07eab',
    'Sublime':              'https://firebasestorage.googleapis.com/v0/b/astro-fd0bf.firebasestorage.app/o/Assets%2FAngie%2Fsideral_SUBLIME.png?alt=media&token=fa642731-bd3e-49e4-977b-763480d6a977',
    'Umbral':               'https://firebasestorage.googleapis.com/v0/b/astro-fd0bf.firebasestorage.app/o/Assets%2FAngie%2Fsideral_UMBRAL.png?alt=media&token=e595844f-851e-4d97-921a-5f7299d0d421',
    'Sen':                  'https://firebasestorage.googleapis.com/v0/b/astro-fd0bf.firebasestorage.app/o/Assets%2FAngie%2Fsideral_ZEN.png?alt=media&token=551cb0c7-7ce8-472c-b4f5-95aa2036d3e8',
  };

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

  bool get _listoParaRevelar => !_cargando && _imagenesListas;
  String get _arquetipoActivo => _arquetipoDebug ?? widget.arquetipo;
  String get _arquetipoImgUrl =>
      _arquetipoImgUrls[_arquetipoActivo] ?? _arquetipoImgUrls.values.first;

  @override
  void initState() {
    super.initState();

    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _slideAnim = Tween<Offset>(begin: const Offset(0, 1.2), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));

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
    await Future.wait([
      precacheImage(const NetworkImage(_anversoUrl), context),
      // ignore: use_build_context_synchronously
      precacheImage(NetworkImage(_arquetipoImgUrl), context),
    ]);
    if (mounted) setState(() => _imagenesListas = true);
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
    _flipCurved?.dispose();
    _flipSnapCtrl?.dispose();
    _reporteFadeCtrl.dispose();
    super.dispose();
  }

  // ── Tap "Revelar reporte" ────────────────────────────────────────────────
  void _revelar() {
    _factTimer?.cancel();
    setState(() => _fase = _Fase.carta);
    _slideCtrl.forward();
  }

  // ── Pan para girar la carta ──────────────────────────────────────────────
  void _onPanUpdate(DragUpdateDetails d) {
    if (_fase != _Fase.carta) return;
    // Solo eje horizontal; si el gesto es más vertical lo ignoramos
    if (d.delta.dy.abs() > d.delta.dx.abs() * 1.5) return;
    _flipSnapCtrl?.stop();
    setState(() {
      _flipProgress = (_flipProgress + d.delta.dx / 220.0).clamp(0.0, 1.0);
    });
  }

  void _onPanEnd(DragEndDetails d) {
    if (_fase != _Fase.carta) return;
    final vx = d.velocity.pixelsPerSecond.dx;
    // Completa si pasó la mitad, o si viene con suficiente velocidad hacia adelante
    if (_flipProgress >= 0.5 || vx > 300) {
      _snapFlip(1.0);
    } else {
      _snapFlip(0.0);
    }
  }

  void _snapFlip(double target) {
    _flipSnapCtrl?.dispose();
    final remaining = (target - _flipProgress).abs();
    // Duración proporcional a distancia restante, mínimo 150 ms
    final ms = (remaining * 520).clamp(150, 520).toInt();
    _flipSnapCtrl = AnimationController(vsync: this, duration: Duration(milliseconds: ms));
    _flipCurved?.dispose();
    _flipCurved = CurvedAnimation(parent: _flipSnapCtrl!, curve: Curves.easeOutCubic);
    final start = _flipProgress;

    _flipCurved!.addListener(() {
      if (!mounted) return;
      setState(() => _flipProgress = (start + (target - start) * _flipCurved!.value).clamp(0.0, 1.0));
    });

    if (target == 1.0) {
      HapticFeedback.mediumImpact();
      _flipSnapCtrl!.addStatusListener((s) {
        if (s == AnimationStatus.completed && mounted) {
          HapticFeedback.heavyImpact();
          Future.delayed(const Duration(milliseconds: 350), () {
            if (mounted) {
              setState(() => _fase = _Fase.reporte);
              _reporteFadeCtrl.forward(from: 0);
            }
          });
        }
      });
    }

    _flipSnapCtrl!.forward(from: 0);
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
                                child: FadeAvatar(
                                  radius: 52,
                                  backgroundColor: Colors.white10,
                                  fotoUrl: widget.amigoFotoUrl,
                                  fallbackChild: const Icon(Icons.person, color: Colors.white38, size: 32),
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
                    arquetipoUrl: _arquetipoImgUrl,
                    cardWidth: size.width * 0.85,
                    cardHeight: size.height * 0.74,
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
                  child: Column(
                    children: [
                      Text(
                        'desliza la carta →',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color.lerp(
                            Colors.black87,
                            Colors.white70,
                            _flipProgress,
                          ),
                          fontSize: 14,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w400,
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
                    padding: const EdgeInsets.fromLTRB(24, 56, 24, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header: avatares + nombres + ícono config
                        Row(
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                FadeAvatar(
                                  radius: 18,
                                  backgroundColor: Colors.white10,
                                  fotoUrl: _miFotoUrlResolved,
                                  fallbackChild: const Icon(Icons.person, color: Colors.white38, size: 16),
                                ),
                                Positioned(
                                  left: 22,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.black, width: 1.5),
                                    ),
                                    child: FadeAvatar(
                                      radius: 18,
                                      backgroundColor: Colors.white10,
                                      fotoUrl: widget.amigoFotoUrl,
                                      fallbackChild: const Icon(Icons.person, color: Colors.white38, size: 16),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 48),
                            Text('Tú · $primerNombre',
                                style: const TextStyle(
                                  color: Color(0xCCF3EBD6), fontSize: 16,
                                  fontWeight: FontWeight.w300, letterSpacing: 0.5,
                                )),
                            const Spacer(),
                          ],
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 20,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              const Divider(color: Color(0x33F3EBD6)),
                              Container(
                                color: Colors.black,
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                child: const Text('✦',
                                    style: TextStyle(color: Color(0xFFB8973A), fontSize: 13)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Arquetipo
                        Text('ARQUETIPO',
                            style: const TextStyle(
                                color: Color(0xFFB8973A),
                                fontSize: 10, letterSpacing: 3,
                                fontWeight: FontWeight.w500)),
                        const SizedBox(height: 10),
                        Text(_arquetipoActivo,
                            style: const TextStyle(
                              fontFamily: 'PlayfairDisplay',
                              color: Color(0xFFF3EBD6), fontSize: 40,
                              fontWeight: FontWeight.w400, height: 1.15,
                            )),
                        const SizedBox(height: 28),
                      ],
                    ),
                  ),

                  // Imagen del arquetipo
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 32),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.network(
                          _arquetipoImgUrl,
                          width: size.width * 0.86,
                          fit: BoxFit.fitWidth,
                          errorBuilder: (_, e, st) => SizedBox(
                            width: size.width * 0.86,
                            height: size.width * 0.86 * 1.5,
                            child: const ColoredBox(color: Color(0xFF1A1A1A)),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Frase + CTA
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0x22F3EBD6)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 38, height: 38,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFFB8973A).withValues(alpha: 0.12),
                                ),
                                child: const Center(
                                  child: Text('✦',
                                      style: TextStyle(color: Color(0xFFB8973A), fontSize: 16)),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  _fraseArquetipo(_arquetipoActivo),
                                  style: const TextStyle(
                                    color: Color(0xCCF3EBD6), fontSize: 13,
                                    fontWeight: FontWeight.w300, height: 1.7,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 48),
                      ],
                    ),
                  ),
                  // ── Contenido del reporte ──────────────────────────────
                  _ReporteContenido(
                    reporte: _reporte,
                    scores: _scoresSinastria,
                    escenarios: _escenarios,
                    amigoNombre: primerNombre,
                    onDebug: _regenerarReporte,
                    cargando: _cargando,
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
                  DebugBotonCarga(
                    onTap: () => setState(() => _cargando = true),
                    color: Color(0x44F3EBD6),
                  ),
                  const Spacer(),
                  if (DebugConfig.instance.activo)
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

  static String _fraseArquetipo(String arquetipo) => const {
    'Los Alquimistas':       'Lo que crean juntos no existía antes de que se encontraran.',
    'Amor Fati':             'Hay patrones entre ustedes que aparecen para que los elijan, no para que los repitan.',
    'Animo Flore':           'El crecimiento que se vive al lado del otro no siempre se ve, pero siempre se siente.',
    'Delusional':            'A veces lo que parece ilusión es solo una verdad que aún no ha llegado.',
    'El Hechizo':            'Hay cosas entre dos personas que no necesitan explicación. Solo presencia.',
    'El Espiral y el Ciclo': 'Hay patrones que se repiten para que los entiendan,\nno para que se queden ahí.',
    'Flor de Loto':          'La conexión más profunda nace de sostener al otro en lo que no es fácil.',
    'Jardín Sereno':         'No todo amor es tormenta. Este es el tipo que permite respirar.',
    'La Maravilla':          'Quedarse con alguien que todavía te sorprende es un acto de valentía.',
    'Nudo Kármico':          'Cuando algo se repite, es porque todavía tiene algo que enseñar.',
    'Sahacara':              'Algunas conexiones no buscan explicarse. Solo piden ser vividas.',
    'Sublime':               'Lo que alcanzan juntos supera lo que cualquiera de los dos podría imaginar solo.',
    'Umbral':                'Estar en el umbral no es estar perdido. Es estar a punto de algo.',
    'Sen':                   'El silencio cómodo entre dos personas es una de las formas más raras del amor.',
    'Cruz de Caminos':       'Encontrarse en la encrucijada no es accidente. Es el inicio de una elección.',
    'Vértigo':               'La intensidad no es el problema. Lo que hacen con ella, sí importa.',
  }[arquetipo] ?? 'Cada conexión tiene su propio lenguaje. Este es el suyo.';

  Widget _inicialWidget(String nombre) => Container(
    color: Colors.white10,
    child: Center(
      child: Text(
        nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
        style: const TextStyle(color: Colors.white38, fontSize: 22),
      ),
    ),
  );

}

// ── Tabla "Su futuro juntos" ──────────────────────────────────────────────────
class _EscenariosVida extends StatelessWidget {
  final Map<String, String> escenarios;

  static const _beige = Color(0xFFF3EBD6);
  static const _gold  = Color(0xFFB8973A);

  static const _filas = [
    ('EN CASA',       'en_casa',       Icons.home_outlined),
    ('EN PÚBLICO',    'en_publico',    Icons.people_outline),
    ('EN UNA PELEA',  'en_una_pelea',  Icons.bolt_outlined),
    ('DE VIAJE',      'de_viaje',      Icons.flight_outlined),
    ('CON DINERO',    'con_dinero',    Icons.diamond_outlined),
    ('EN LA VEJEZ',   'en_la_vejez',   Icons.favorite_border),
  ];

  const _EscenariosVida({required this.escenarios});

  @override
  Widget build(BuildContext context) {
    final cargando = escenarios.isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // encabezado estilo carta
        Row(children: [
          Icon(Icons.auto_awesome_outlined, color: _gold.withValues(alpha: 0.6), size: 14),
          const SizedBox(width: 10),
          const Text('SU FUTURO JUNTOS',
              style: TextStyle(
                fontFamily: 'PlayfairDisplay',
                color: _gold,
                fontSize: 18, letterSpacing: 2, fontWeight: FontWeight.w700,
              )),
        ]),
        const SizedBox(height: 6),
        Text('Cómo se verían en distintos momentos de la vida.',
            style: TextStyle(color: _beige.withValues(alpha: 0.3), fontSize: 12, height: 1.5)),
        const SizedBox(height: 24),
        // filas dentro de una tarjeta
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0A0A0A),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _beige.withValues(alpha: 0.07), width: 1),
          ),
          child: Column(
            children: List.generate(_filas.length, (i) {
              final (label, key, icon) = _filas[i];
              final texto = escenarios[key] ?? '';
              final isLast = i == _filas.length - 1;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _gold.withValues(alpha: 0.07),
                            border: Border.all(color: _gold.withValues(alpha: 0.25), width: 1),
                          ),
                          child: Icon(icon, color: _gold.withValues(alpha: 0.65), size: 16),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(label,
                                  style: TextStyle(
                                    color: _beige.withValues(alpha: 0.45),
                                    fontSize: 8, letterSpacing: 2,
                                    fontWeight: FontWeight.w600,
                                  )),
                              const SizedBox(height: 6),
                              cargando || texto.isEmpty
                                  ? Container(
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: _beige.withValues(alpha: 0.06),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    )
                                  : Text(texto,
                                      style: TextStyle(
                                        color: _beige.withValues(alpha: 0.78),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w300,
                                        height: 1.6,
                                      )),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isLast)
                    Divider(height: 1, color: _beige.withValues(alpha: 0.06)),
                ],
              );
            }),
          ),
        ),
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
    final scaleX = flipProgress < 0.5
        ? 1.0 - flipProgress * 2.0
        : (flipProgress - 0.5) * 2.0;

    // Sneak peek: arquetipo se asoma de 0.3→0.5, luego queda opaco
    final arquetipoOpacity = ((flipProgress - 0.3) / 0.2).clamp(0.0, 1.0);

    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.diagonal3Values(scaleX.clamp(0.0, 1.0), 1.0, 1.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: cardWidth,
          height: cardHeight,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Anverso siempre en el árbol — sin entrada/salida costosa
              Image.network(
                anversoUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, e, st) => const ColoredBox(color: Color(0xFF1A1A1A)),
              ),
              // Arquetipo siempre en el árbol, solo cambia su opacidad
              Opacity(
                opacity: arquetipoOpacity,
                child: Image.network(
                  arquetipoUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, e, st) => const ColoredBox(color: Color(0xFF1A1A1A)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Compatibilidad visual: 4 anillos + barra total ───────────────────────────
class _CompatibilidadVisual extends StatelessWidget {
  final Map<String, double> scores;

  static const _beige = Color(0xFFF3EBD6);
  static const _gold  = Color(0xFFB8973A);

  static const _datos = [
    ('IDENTIDAD', 'identidad', Icons.person_outline),
    ('EMOCIÓN',   'emocion',   Icons.water_drop_outlined),
    ('ATRACCIÓN', 'atraccion', Icons.favorite_border),
    ('PRESENCIA', 'presencia', Icons.visibility_outlined),
  ];

  const _CompatibilidadVisual({required this.scores});

  @override
  Widget build(BuildContext context) {
    final s = _datos.map((d) => scores[d.$2] ?? 0.5).toList();
    final total = s.reduce((a, b) => a + b) / s.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // título sección
        Row(children: [
          Expanded(child: Divider(color: _gold.withValues(alpha: 0.18), thickness: 0.5)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text('AFINIDAD', style: TextStyle(
              color: _gold.withValues(alpha: 0.5), fontSize: 9, letterSpacing: 3)),
          ),
          Expanded(child: Divider(color: _gold.withValues(alpha: 0.18), thickness: 0.5)),
        ]),
        const SizedBox(height: 28),
        // anillos
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(4, (i) => _Anillo(
            label: _datos[i].$1,
            icon: _datos[i].$3,
            value: s[i],
          )),
        ),
        const SizedBox(height: 36),
        // barra total
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF0A0A0A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _gold.withValues(alpha: 0.15), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.auto_awesome, color: _gold.withValues(alpha: 0.6), size: 14),
                const SizedBox(width: 8),
                Text('AFINIDAD TOTAL', style: TextStyle(
                  color: _beige.withValues(alpha: 0.4),
                  fontSize: 9, letterSpacing: 3)),
                const Spacer(),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: total),
                  duration: const Duration(milliseconds: 1300),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, child) => Text(
                    '${(v * 100).round()}%',
                    style: TextStyle(
                      color: _beige.withValues(alpha: 0.85),
                      fontSize: 20,
                      fontFamily: 'PlayfairDisplay',
                      fontWeight: FontWeight.w400,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 14),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: total),
                duration: const Duration(milliseconds: 1300),
                curve: Curves.easeOutCubic,
                builder: (_, v, child) => ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: Stack(children: [
                    Container(height: 5,
                        color: _beige.withValues(alpha: 0.08)),
                    FractionallySizedBox(
                      widthFactor: v,
                      child: Container(
                        height: 5,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            _gold.withValues(alpha: 0.5),
                            _gold,
                          ]),
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Anillo extends StatelessWidget {
  final String label;
  final IconData icon;
  final double value;

  static const _beige = Color(0xFFF3EBD6);
  static const _gold  = Color(0xFFB8973A);

  const _Anillo({required this.label, required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: const Duration(milliseconds: 1100),
      curve: Curves.easeOutCubic,
      builder: (ctx, v, _) => Column(
        children: [
          SizedBox(
            width: 72,
            height: 72,
            child: CustomPaint(
              painter: _AnilloPainter(value: v),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: _gold.withValues(alpha: 0.7 + v * 0.3), size: 18),
                    const SizedBox(height: 2),
                    Text(
                      '${(v * 100).round()}',
                      style: TextStyle(
                        color: _beige.withValues(alpha: 0.8),
                        fontSize: 11,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: TextStyle(
                color: _beige.withValues(alpha: 0.4),
                fontSize: 7,
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

// ── Contenido del reporte — estilo carta astral ───────────────────────────────
class _ReporteContenido extends StatelessWidget {
  final Map<String, String> reporte;
  final Map<String, double> scores;
  final Map<String, String> escenarios;
  final String amigoNombre;
  final VoidCallback onDebug;
  final bool cargando;

  static const _beige = Color(0xFFF3EBD6);
  static const _gold  = Color(0xFFB8973A);

  const _ReporteContenido({
    required this.reporte,
    required this.scores,
    required this.escenarios,
    required this.amigoNombre,
    required this.onDebug,
    required this.cargando,
  });

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final screenH = MediaQuery.of(context).size.height;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Intro — tarjeta con cita en PlayfairDisplay ──────────────────
        if ((reporte['intro'] ?? '').isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 48),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF0D0D0D),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _gold.withValues(alpha: 0.28), width: 1),
                boxShadow: [
                  BoxShadow(color: _gold.withValues(alpha: 0.08), blurRadius: 36),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // header ornamental
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: _gold.withValues(alpha: 0.12))),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 48, height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _gold.withValues(alpha: 0.08),
                            border: Border.all(color: _gold.withValues(alpha: 0.4), width: 1),
                            boxShadow: [BoxShadow(color: _gold.withValues(alpha: 0.22), blurRadius: 16)],
                          ),
                          child: const Center(
                            child: Text('♡', style: TextStyle(color: _gold, fontSize: 20)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          amigoNombre,
                          style: const TextStyle(
                            fontFamily: 'PlayfairDisplay',
                            color: _gold,
                            fontSize: 20,
                            fontWeight: FontWeight.w400,
                            fontStyle: FontStyle.italic,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'lo que los une tiene una forma única.',
                          style: TextStyle(
                            color: _beige.withValues(alpha: 0.3),
                            fontSize: 11,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: _TextoReporte(texto: reporte['intro']!, color: _beige.withValues(alpha: 0.82)),
                  ),
                ],
              ),
            ),
          ),

        // ── Afinidad visual ──────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 56),
          child: _CompatibilidadVisual(scores: scores),
        ),

        // ── Secciones tap-to-reveal ──────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DividerOro(gold: _gold),
              const Text(
                'ENTRE USTEDES',
                style: TextStyle(
                  fontFamily: 'PlayfairDisplay',
                  color: _gold,
                  fontSize: 22,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Toca cada área para explorarla.',
                style: TextStyle(color: _beige.withValues(alpha: 0.35), fontSize: 12, height: 1.5),
              ),
              const SizedBox(height: 28),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
          child: _SeccionesReveal(reporte: reporte, beige: _beige, gold: _gold),
        ),

        // ── Potencial — tarjeta estilo "futuro" ──────────────────────────
        if ((reporte['potencial'] ?? '').isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 48, 28, 0),
            child: _PotencialCard(texto: reporte['potencial']!, beige: _beige, gold: _gold),
          ),

        // ── Su futuro juntos ─────────────────────────────────────────────
        if (escenarios.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 56, 28, 0),
            child: _EscenariosVida(escenarios: escenarios),
          ),

        // ── Despedida ────────────────────────────────────────────────────
        const SizedBox(height: 72),
        Builder(builder: (ctx) {
          return ClipPath(
            clipper: _CierreClipper(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: screenH * 0.72, minWidth: screenW),
              child: Container(
                width: screenW,
                color: const Color(0xFFF0EBE3),
                padding: const EdgeInsets.fromLTRB(28, 56, 28, 60),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Lo que encontraron tiene nombre.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'PlayfairDisplay',
                        color: Color(0xFF1A1410),
                        fontSize: 22,
                        fontWeight: FontWeight.w400,
                        height: 1.8,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 36),
                    Text(
                      'La astrología no crea la conexión entre dos personas. Solo le da un nombre, una forma, una manera de mirarse con más claridad.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: const Color(0xFF1A1410).withValues(alpha: 0.52),
                        fontSize: 15,
                        fontWeight: FontWeight.w300,
                        height: 2.0,
                        letterSpacing: 0.1,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'No hay dos vínculos iguales. Este es solo suyo. Úsenlo como quieran.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: const Color(0xFF1A1410).withValues(alpha: 0.52),
                        fontSize: 15,
                        fontWeight: FontWeight.w300,
                        height: 2.0,
                        letterSpacing: 0.1,
                      ),
                    ),
                    const SizedBox(height: 56),
                    const Text(
                      'Con cariño — El equipo de ecos',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFB8973A),
                        fontSize: 16,
                        letterSpacing: 2.5,
                        fontWeight: FontWeight.w700,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      '<3',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: const Color(0xFFB8973A).withValues(alpha: 0.5),
                        fontSize: 18,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w300,
                      ),
                    ),

                    // Debug
                    if (DebugConfig.instance.activo) ...[
                    const SizedBox(height: 40),
                    GestureDetector(
                      onTap: onDebug,
                      behavior: HitTestBehavior.opaque,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            cargando ? 'generando…' : 'debug: regenerar reporte',
                            style: TextStyle(
                              color: const Color(0xFF1A1410).withValues(alpha: 0.18),
                              fontSize: 11,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                  ], // end if DebugConfig
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

// ── Secciones tap-to-reveal (estilo Ámbitos) ─────────────────────────────────
class _SeccionesReveal extends StatefulWidget {
  final Map<String, String> reporte;
  final Color beige;
  final Color gold;
  const _SeccionesReveal({required this.reporte, required this.beige, required this.gold});

  @override
  State<_SeccionesReveal> createState() => _SeccionesRevealState();
}

class _SeccionesRevealState extends State<_SeccionesReveal>
    with SingleTickerProviderStateMixin {

  static const _datos = [
    ('atraccion',         'ATRACCIÓN',   '♡', Icons.favorite_border),
    ('comunicacion',      'COMUNICACIÓN','◦', Icons.chat_bubble_outline),
    ('conexion_emocional','EMOCIÓN',     '☽', Icons.water_drop_outlined),
  ];

  int? _abierto;
  final Set<int> _vistos = {};
  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeIn);
  }

  @override
  void dispose() { _animCtrl.dispose(); super.dispose(); }

  void _tap(int i) {
    if (_abierto == i) {
      _animCtrl.reverse().then((_) => setState(() => _abierto = null));
    } else {
      setState(() { _abierto = i; _vistos.add(i); });
      _animCtrl.forward(from: 0);
    }
  }

  Widget _circulo(int i) {
    final gold  = widget.gold;
    final beige = widget.beige;
    final entry = _datos[i];
    final selec = _abierto == i;
    final visto = _vistos.contains(i);
    final hasText = (widget.reporte[entry.$1] ?? '').isNotEmpty;

    final iconColor = visto
        ? (selec ? gold : gold.withValues(alpha: 0.7))
        : (hasText ? beige.withValues(alpha: 0.4) : Colors.grey.withValues(alpha: 0.2));
    final borderColor = visto
        ? (selec ? gold.withValues(alpha: 0.85) : gold.withValues(alpha: 0.35))
        : beige.withValues(alpha: 0.15);

    return GestureDetector(
      onTap: hasText ? () => _tap(i) : null,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            width: 72, height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF0D0D0D),
              border: Border.all(color: borderColor, width: 1),
              boxShadow: selec ? [
                BoxShadow(color: gold.withValues(alpha: 0.38), blurRadius: 20),
                BoxShadow(color: gold.withValues(alpha: 0.15), blurRadius: 40),
              ] : [],
            ),
            child: Icon(entry.$4, size: 26, color: iconColor),
          ),
          const SizedBox(height: 9),
          Text(
            entry.$2,
            style: TextStyle(
              color: visto ? beige.withValues(alpha: 0.85) : beige.withValues(alpha: 0.45),
              fontSize: 8,
              letterSpacing: 1.8,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gold  = widget.gold;
    final beige = widget.beige;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(_datos.length, _circulo),
        ),
        if (_abierto != null) ...[
          const SizedBox(height: 28),
          FadeTransition(
            opacity: _fadeAnim,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: const Color(0xFF0D0D0D),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: gold.withValues(alpha: 0.3), width: 1),
                boxShadow: [
                  BoxShadow(color: gold.withValues(alpha: 0.1), blurRadius: 20),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42, height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: gold.withValues(alpha: 0.08),
                          border: Border.all(color: gold.withValues(alpha: 0.5), width: 1),
                          boxShadow: [BoxShadow(color: gold.withValues(alpha: 0.2), blurRadius: 12)],
                        ),
                        child: Icon(_datos[_abierto!].$4, size: 20, color: gold),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        _datos[_abierto!].$2,
                        style: TextStyle(
                          fontFamily: 'PlayfairDisplay',
                          color: gold,
                          fontSize: 16, letterSpacing: 2.5, fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => _animCtrl.reverse().then((_) => setState(() => _abierto = null)),
                        child: Icon(Icons.close, size: 16, color: beige.withValues(alpha: 0.25)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Divider(color: gold.withValues(alpha: 0.1), thickness: 0.5),
                  const SizedBox(height: 14),
                  _TextoReporte(
                    texto: widget.reporte[_datos[_abierto!].$1] ?? '',
                    color: beige.withValues(alpha: 0.8),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }
}

// ── Potencial — tarjeta estilo "futuro" ───────────────────────────────────────
class _PotencialCard extends StatelessWidget {
  final String texto;
  final Color beige;
  final Color gold;
  const _PotencialCard({required this.texto, required this.beige, required this.gold});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('SU POTENCIAL',
            style: TextStyle(
              fontFamily: 'PlayfairDisplay',
              color: gold.withValues(alpha: 0.9),
              fontSize: 22, letterSpacing: 2, fontWeight: FontWeight.w700,
            )),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF080808),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: gold.withValues(alpha: 0.2), width: 1),
            boxShadow: [BoxShadow(color: gold.withValues(alpha: 0.07), blurRadius: 32)],
          ),
          child: Stack(
            children: [
              Positioned(
                left: 0, top: 16, bottom: 16,
                child: Container(
                  width: 2,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        gold.withValues(alpha: 0.0),
                        gold.withValues(alpha: 0.55),
                        gold.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Lo que pueden construir',
                        style: TextStyle(
                          fontFamily: 'PlayfairDisplay',
                          color: gold.withValues(alpha: 0.6),
                          fontSize: 13, letterSpacing: 1.2, fontWeight: FontWeight.w400,
                          fontStyle: FontStyle.italic,
                        )),
                    const SizedBox(height: 6),
                    Divider(color: gold.withValues(alpha: 0.1), thickness: 0.5),
                    const SizedBox(height: 14),
                    _TextoReporte(texto: texto, color: beige.withValues(alpha: 0.82)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Divisor ornamental ────────────────────────────────────────────────────────
class _DividerOro extends StatelessWidget {
  final Color gold;
  const _DividerOro({required this.gold});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 40),
    child: Row(children: [
      Expanded(child: Divider(color: gold.withValues(alpha: 0.25), thickness: 0.5)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text('✦', style: TextStyle(color: gold.withValues(alpha: 0.4), fontSize: 12)),
      ),
      Expanded(child: Divider(color: gold.withValues(alpha: 0.25), thickness: 0.5)),
    ]),
  );
}

// ── Clipper curvo para la despedida ───────────────────────────────────────────
class _CierreClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    const arc = 40.0;
    return Path()
      ..moveTo(0, arc)
      ..quadraticBezierTo(size.width / 2, -arc, size.width, arc)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
  }
  @override
  bool shouldReclip(_CierreClipper old) => false;
}

// ── Texto con negritas y dorado aleatorio ─────────────────────────────────────
class _TextoReporte extends StatefulWidget {
  final String texto;
  final Color color;
  const _TextoReporte({required this.texto, required this.color});

  @override
  State<_TextoReporte> createState() => _TextoReporteState();
}

class _TextoReporteState extends State<_TextoReporte> {
  late List<Set<int>> _negritaPorParrafo;
  late List<int?> _doradoPorParrafo;

  static const _gold = Color(0xFFB8973A);

  @override
  void initState() {
    super.initState();
    final rng = math.Random();
    final parrafos = widget.texto.split(RegExp(r'\n\n+'));
    _negritaPorParrafo = parrafos.map((p) {
      final palabras = p.trim().split(RegExp(r'\s+'));
      final candidatos = palabras.asMap().entries
          .where((e) => e.value.replaceAll(RegExp(r'[^\wáéíóúüñÁÉÍÓÚÜÑ]'), '').length >= 6)
          .map((e) => e.key)
          .toList()..shuffle(rng);
      return candidatos.take(3).toSet();
    }).toList();
    _doradoPorParrafo = parrafos.map((p) {
      final palabras = p.trim().split(RegExp(r'\s+'));
      final candidatos = palabras.asMap().entries
          .where((e) => e.value.replaceAll(RegExp(r'[^\wáéíóúüñÁÉÍÓÚÜÑ]'), '').length >= 8)
          .map((e) => e.key)
          .toList()..shuffle(rng);
      return candidatos.isNotEmpty ? candidatos.first : null;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final parrafos = widget.texto.split(RegExp(r'\n\n+'));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var pi = 0; pi < parrafos.length; pi++) ...[
          if (pi > 0) const SizedBox(height: 14),
          RichText(
            text: TextSpan(
              children: () {
                final palabras = parrafos[pi].trim().split(RegExp(r'\s+'));
                final negrita = _negritaPorParrafo[pi];
                final dorado  = pi < _doradoPorParrafo.length ? _doradoPorParrafo[pi] : null;
                return List.generate(palabras.length, (i) => TextSpan(
                  text: i < palabras.length - 1 ? '${palabras[i]} ' : palabras[i],
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    color: i == dorado ? _gold : widget.color,
                    fontSize: 14,
                    fontWeight: negrita.contains(i) ? FontWeight.w700 : FontWeight.w300,
                    height: 1.75,
                  ),
                ));
              }(),
            ),
          ),
        ],
      ],
    );
  }
}

