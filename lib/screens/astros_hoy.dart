import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/calculos_astrales.dart';
import '../services/claude_service.dart';
import '../services/banco_frases.dart';
import 'buscar_amigos.dart';
import 'notificaciones.dart';
import 'color_del_dia.dart';
import '../services/notification_service.dart';
import 'mas_alla.dart';
import 'package:home_widget/home_widget.dart';
import 'configuracion.dart';
import 'afinidad.dart';

class PantallaAstrosHoy extends StatefulWidget {
  final String nombre;

  const PantallaAstrosHoy({super.key, required this.nombre});

  @override
  State<PantallaAstrosHoy> createState() => _PantallaAstrosHoyState();
}

const _signosList = [
  'Aries', 'Tauro', 'Géminis', 'Cáncer', 'Leo', 'Virgo',
  'Libra', 'Escorpio', 'Sagitario', 'Capricornio', 'Acuario', 'Piscis',
];

class _PantallaAstrosHoyState extends State<PantallaAstrosHoy> {
  final _keyMasAlla = GlobalKey();
  String? _frase;
  String? _desarrollo;
  List<Map<String, dynamic>> _amigos = [];
  Map<String, String> _compatibilidades = {};
  bool _cargando = true;
  String _miUid = '';
  String _miSolar = '';
  String _miLunar = '';
  String _miAsc = '';
  Map<String, String> _miPlanetas = {};
  final _blobKey = GlobalKey();
  bool _colorRevelado = false;

  String _fraseBase = '';
  String _areaFrase = 'identidad';

  int _debugColorOffset = 0;

  // Debug
  bool _mostrarDebug = false;
  bool _mostrarLoadingDebug = false;
  String _debugSolar = 'Aries';
  String _debugLunar = 'Aries';
  String _debugAsc = 'Aries';

  @override
  void initState() {
    super.initState();
    _cargarTodo();
    _cargarColorRevelado();
  }

  Future<void> _refrescarCompatibilidades() async {
    final miUid = FirebaseAuth.instance.currentUser?.uid;
    if (miUid == null) return;
    final hoy = DateTime.now();
    final fechaHoy = '${hoy.year}-${hoy.month.toString().padLeft(2, '0')}-${hoy.day.toString().padLeft(2, '0')}';

    // Borra el caché de la frase del día y las compatibilidades
    await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(miUid)
        .collection('lecturas')
        .doc(fechaHoy)
        .delete();

    for (final amigo in _amigos) {
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(miUid)
          .collection('lecturas')
          .doc(fechaHoy)
          .collection('compatibilidades')
          .doc(amigo['uid'] as String)
          .delete();
    }

    setState(() { _amigos = []; _compatibilidades = {}; });
    await _cargarTodo();
  }

  Future<void> _cargarColorRevelado() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final hoy = DateTime.now();
    final clave = 'color_revelado_${uid}_${hoy.year}-${hoy.month}-${hoy.day}';
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _colorRevelado = prefs.getBool(clave) ?? false);
  }

  Future<void> _marcarColorRevelado() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final hoy = DateTime.now();
    final clave = 'color_revelado_${uid}_${hoy.year}-${hoy.month}-${hoy.day}';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(clave, true);
    if (mounted) setState(() => _colorRevelado = true);
  }

  Future<void> _cargarTodo() async {
    final miUid = FirebaseAuth.instance.currentUser?.uid;
    if (miUid == null) return;

    // Cargamos los datos del usuario desde Firestore
    final doc = await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(miUid)
        .get();

    if (!doc.exists) return;
    final datos = doc.data()!;

    final fecha = (datos['fechaNacimiento'] as dynamic).toDate() as DateTime;
    final horaParts = (datos['horaNacimiento'] as String).split(':');
    final hora = int.parse(horaParts[0]);
    final minutos = int.parse(horaParts[1]);

    final latitud = (datos['latitud'] as num?)?.toDouble() ?? 0.0;
    final longitud = (datos['longitud'] as num?)?.toDouble() ?? 0.0;

    final carta = CalculosAstrales.calcular(
      fechaNacimiento: fecha,
      hora: hora,
      minutos: minutos,
      latitud: latitud,
      longitud: longitud,
    );

    // Guardar datos del usuario para el widget en background
    HomeWidget.saveWidgetData<String>('widget_uid',    miUid);
    HomeWidget.saveWidgetData<String>('widget_nombre', widget.nombre);
    HomeWidget.saveWidgetData<String>('widget_solar',  carta.signoSolar);
    HomeWidget.saveWidgetData<String>('widget_lunar',  carta.signoLunar);
    HomeWidget.saveWidgetData<String>('widget_asc',    carta.ascendente);

    // Revisamos si ya hay una lectura guardada para hoy
    final hoy = DateTime.now();
    final fechaHoy = '${hoy.year}-${hoy.month.toString().padLeft(2, '0')}-${hoy.day.toString().padLeft(2, '0')}';

    final lecturaDoc = await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(miUid)
        .collection('lecturas')
        .doc(fechaHoy)
        .get();

    final usuarioRef = FirebaseFirestore.instance.collection('usuarios').doc(miUid);

    String fraseBase;
    String areaFrase;
    String lectura;

    if (lecturaDoc.exists) {
      // Usar la frase y lectura ya guardadas para hoy
      final cached = lecturaDoc.data()!;
      fraseBase = cached['fraseBase'] as String? ?? '';
      areaFrase = cached['areaFrase'] as String? ?? 'identidad';
      lectura   = cached['texto']     as String? ?? '';
    } else {
      // Avanzar la cola y generar nueva lectura
      final usuarioSnap  = await usuarioRef.get();
      final usuarioDatos = usuarioSnap.data() ?? {};
      List<int> cola = List<int>.from(usuarioDatos['frasesQueue'] ?? []);
      if (cola.isEmpty) cola = BancoFrases.generarColaMezclada();
      final idSeleccionado = cola.removeAt(0);
      await usuarioRef.update({'frasesQueue': cola});

      final fraseSeleccionada = BancoFrases.porId(idSeleccionado);
      fraseBase = fraseSeleccionada['frase'] as String;
      areaFrase = fraseSeleccionada['area']  as String? ?? 'identidad';

      lectura = await ClaudeService.generarAstrosDelDia(
        nombre:     widget.nombre,
        signoSolar: carta.signoSolar,
        signoLunar: carta.signoLunar,
        ascendente: carta.ascendente,
        fraseBase:  fraseBase,
        areaFrase:  areaFrase,
        planetas:   carta.planetas,
      );
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(miUid)
          .collection('lecturas')
          .doc(fechaHoy)
          .set({'texto': lectura, 'fraseBase': fraseBase, 'areaFrase': areaFrase});
    }

    // Cargamos los amigos
    final amigosSnap = await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(miUid)
        .collection('amigos')
        .get();

    final amigos = <Map<String, dynamic>>[];
    final compatibilidades = <String, String>{};

    for (final amigoDoc in amigosSnap.docs) {
      final amigoUid = amigoDoc['uid'] as String;
      final amigoData = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(amigoUid)
          .get();

      if (!amigoData.exists) continue;
      final ad = amigoData.data()!;

      final amigoFecha = (ad['fechaNacimiento'] as dynamic).toDate() as DateTime;
      final amigoHoraParts = ((ad['horaNacimiento'] as String?) ?? '12:00').split(':');
      final amigoHora = int.tryParse(amigoHoraParts[0]) ?? 12;
      final amigoMin  = int.tryParse(amigoHoraParts.length > 1 ? amigoHoraParts[1] : '0') ?? 0;
      final amigoLat  = (ad['latitud']  as num?)?.toDouble() ?? 0.0;
      final amigoLon  = (ad['longitud'] as num?)?.toDouble() ?? 0.0;
      final amigoCarta = CalculosAstrales.calcular(
        fechaNacimiento: amigoFecha, hora: amigoHora, minutos: amigoMin,
        latitud: amigoLat, longitud: amigoLon,
      );
      final amigoSigno = amigoCarta.signoSolar;
      final amigoNombre = ad['nombre'] ?? 'alguien';

      amigos.add({
        'uid':       amigoUid,
        'nombre':    amigoNombre,
        'username':  ad['username'] ?? '',
        'fotoUrl':   ad['fotoUrl'],
        'solar':     amigoCarta.signoSolar,
        'lunar':     amigoCarta.signoLunar,
        'asc':       amigoCarta.ascendente,
        'planetas':  amigoCarta.planetas,
      });

      // Revisamos si ya hay compatibilidad guardada para hoy con este amigo
      final compatibilidadDoc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(miUid)
          .collection('lecturas')
          .doc(fechaHoy)
          .collection('compatibilidades')
          .doc(amigoUid)
          .get();

      String compatibilidad;
      if (compatibilidadDoc.exists) {
        compatibilidad = compatibilidadDoc.data()!['texto'] as String;
      } else {
        final tipo = Random().nextBool() ? 'solo' : 'interaccion';
        compatibilidad = await ClaudeService.generarCompatibilidad(
          nombre1:      widget.nombre,
          signoSolar1:  carta.signoSolar,
          signoLunar1:  carta.signoLunar,
          nombre2:      amigoNombre,
          signoSolar2:  amigoSigno,
          signoLunar2:  amigoCarta.signoLunar,
          tipo:         tipo,
        );
        await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(miUid)
            .collection('lecturas')
            .doc(fechaHoy)
            .collection('compatibilidades')
            .doc(amigoUid)
            .set({'texto': compatibilidad});
      }
      compatibilidades[amigoUid] = compatibilidad;
    }

    if (mounted) {
      setState(() {
        try {
          final limpia = lectura
              .replaceAll(RegExp(r'```json|```'), '')
              .trim();
          final json = jsonDecode(limpia);
          _frase = fraseBase;
          _desarrollo = json['parrafo'] as String?;
        } catch (_) {
          _frase = fraseBase;
        }
        if (_frase != null) {
          NotificationService.programarNotificacionDelDia(_frase!);
          HomeWidget.saveWidgetData('widget_frase', _frase);
          HomeWidget.updateWidget(androidName: 'AstrosWidget');
        }
        _miUid      = miUid;
        _miSolar    = carta.signoSolar;
        _miLunar    = carta.signoLunar;
        _miAsc      = carta.ascendente;
        _miPlanetas = carta.planetas;
        _fraseBase  = fraseBase;
        _areaFrase  = areaFrase;
        _amigos = amigos;
        _compatibilidades = compatibilidades;
        _cargando = false;
      });
    }
  }

  Widget _buildBlob() {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final (color, nombre, nombreEs) = colorDelDia(uid: uid, offset: _debugColorOffset);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const Text(
              'COLOR DEL DÍA',
              style: TextStyle(
                color: Color(0xFFB8973A),
                fontSize: 10,
                letterSpacing: 2,
              ),
            ),
            if (_mostrarDebug) ...[
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => setState(() => _debugColorOffset = (_debugColorOffset + 1) % totalColores()),
                child: const Text('›', style: TextStyle(color: Colors.black38, fontSize: 18)),
              ),
              const SizedBox(width: 4),
              Text(
                '$_debugColorOffset',
                style: const TextStyle(color: Colors.black26, fontSize: 10),
              ),
            ],
          ],
        ),
        Stack(
          clipBehavior: Clip.none,
          children: [
            RepaintBoundary(
              child: BlobColorDelDia(
                key: _blobKey,
                color: color,
                revelado: _colorRevelado,
                onTap: () {
                  HapticFeedback.lightImpact();
                  Future.delayed(const Duration(milliseconds: 150), () => HapticFeedback.lightImpact());
                  Future.delayed(const Duration(milliseconds: 300), () => HapticFeedback.mediumImpact());
                  Future.delayed(const Duration(milliseconds: 500), () => HapticFeedback.mediumImpact());
                  Future.delayed(const Duration(milliseconds: 700), () => HapticFeedback.heavyImpact());
                  Future.delayed(const Duration(milliseconds: 900), () => HapticFeedback.heavyImpact());
                  Future.delayed(const Duration(milliseconds: 1000), () {
                    if (!mounted) return;
                    final renderBox = _blobKey.currentContext!.findRenderObject() as RenderBox;
                    final pos = renderBox.localToGlobal(Offset.zero);
                    final size = renderBox.size;
                    final centro = Offset(pos.dx + size.width / 2, pos.dy + size.height / 2);
                    Navigator.push(
                      context,
                      CircularRevealRoute(
                        color: color,
                        nombre: nombre,
                        nombreEs: nombreEs,
                        origen: centro,
                      ),
                    ).then((_) => _marcarColorRevelado());
                  });
                },
              ),
            ),
            // Estrellas de 4 puntas
            const Positioned(top: -6, right: 2,  child: _Estrella(size: 8)),
            const Positioned(top: 10, right: -10, child: _Estrella(size: 6)),
            const Positioned(top: -2, right: -16, child: _Estrella(size: 5)),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3EBD6),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Fila superior: título + íconos
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'tus astros de hoy',
                    style: TextStyle(
                      color: Colors.black45,
                      fontSize: 11,
                      letterSpacing: 3,
                    ),
                  ),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const PantallaConfiguracion()),
                        ),
                        child: const Icon(Icons.tune, color: Colors.black45, size: 20),
                      ),
                      const SizedBox(width: 16),
                      _CampanaNotificaciones(),
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const PantallaBuscarAmigos()),
                        ),
                        child: const Icon(Icons.search,
                            color: Colors.black45, size: 20),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Color del día
              if (!_cargando) ...[
                _buildBlob(),
                const SizedBox(height: 8),
                // DEBUG — borrar antes de publicar
              GestureDetector(
                onTap: () => setState(() => _mostrarDebug = !_mostrarDebug),
                child: const Text(
                  'debug ▾',
                  style: TextStyle(color: Colors.black26, fontSize: 11, letterSpacing: 1),
                ),
              ),
              if (_mostrarDebug) ...[
                const SizedBox(height: 12),
                _DebugSignoRow(
                  label: 'Solar',
                  valor: _debugSolar,
                  onChanged: (v) => setState(() => _debugSolar = v),
                ),
                _DebugSignoRow(
                  label: 'Lunar',
                  valor: _debugLunar,
                  onChanged: (v) => setState(() => _debugLunar = v),
                ),
                _DebugSignoRow(
                  label: 'Asc',
                  valor: _debugAsc,
                  onChanged: (v) => setState(() => _debugAsc = v),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => setState(() => _mostrarLoadingDebug = !_mostrarLoadingDebug),
                  child: Text(
                    _mostrarLoadingDebug ? 'loading ▴' : 'loading ▾',
                    style: const TextStyle(color: Colors.black26, fontSize: 11, letterSpacing: 1),
                  ),
                ),
                if (_mostrarLoadingDebug)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: _LoadingImages(),
                  ),
                GestureDetector(
                  onTap: () async {
                    setState(() => _cargando = true);
                    final debugCola = BancoFrases.generarColaMezclada();
                    final debugFrase = BancoFrases.porId(debugCola.first);
                    final lectura = await ClaudeService.generarAstrosDelDia(
                      nombre: widget.nombre,
                      signoSolar: _debugSolar,
                      signoLunar: _debugLunar,
                      ascendente: _debugAsc,
                      fraseBase: debugFrase['frase'] as String,
                      areaFrase: debugFrase['area'] as String? ?? 'identidad',
                    );
                    setState(() {
                      try {
                        final limpia = lectura.replaceAll(RegExp(r'```json|```'), '').trim();
                        final json = jsonDecode(limpia);
                        _frase = debugFrase['frase'] as String?;
                        _desarrollo = json['parrafo'] as String?;
                      } catch (_) {
                        _frase = debugFrase['frase'] as String?;
                      }
                      _cargando = false;
                    });
                  },
                  child: const Text(
                    'generar →',
                    style: TextStyle(color: Colors.black45, fontSize: 11, letterSpacing: 2),
                  ),
                ),
              ],
              ],

              const SizedBox(height: 24),

              // ── Tarjeta de lectura del día ──────────────────────────────────
              if (_cargando)
                const _LoadingImages()
              else Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F3E8),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _frase ?? '',
                      style: const TextStyle(
                        fontFamily: 'PlayfairDisplay',
                        color: Color(0xFF222222),
                        fontSize: 36,
                        fontWeight: FontWeight.w400,
                        height: 1.2,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: 32,
                      height: 1.5,
                      color: const Color(0xFFB8973A),
                    ),
                    if (_desarrollo != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _desarrollo!,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          height: 1.8,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!_cargando) ...[
                const SizedBox(height: 20),
                GestureDetector(
                  key: _keyMasAlla,
                  onTap: () {
                    final box = _keyMasAlla.currentContext!
                        .findRenderObject() as RenderBox;
                    final origen = box.localToGlobal(
                        box.size.center(Offset.zero));
                    Navigator.of(context).push(
                      MasAllaRoute(
                        origen: origen,
                        frase: _frase,
                        desarrollo: _desarrollo,
                      ),
                    );
                  },
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.55,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C2C2C),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      children: [
                        Text(
                          'Trascender',
                          style: TextStyle(
                            color: Color(0xFFB8973A),
                            fontSize: 13,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const Spacer(),
                        const SizedBox(width: 8),
                        const Text(
                          '→',
                          style: TextStyle(color: Color(0xFFB8973A), fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // Divisor con estrella
              if (!_cargando) ...[
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Expanded(child: Divider(color: Colors.black12)),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('✦', style: TextStyle(color: Colors.black26, fontSize: 12)),
                    ),
                    const Expanded(child: Divider(color: Colors.black12)),
                  ],
                ),
              ],

              // Sección de amigos
              if (!_cargando && _amigos.isNotEmpty) ...[
                const SizedBox(height: 32),
                const SizedBox(height: 32),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'TUS AMIGOS HOY',
                      style: TextStyle(
                        color: Colors.black45,
                        fontSize: 11,
                        letterSpacing: 3,
                      ),
                    ),
                    GestureDetector(
                      onTap: _refrescarCompatibilidades,
                      child: const Text(
                        'debug: refrescar',
                        style: TextStyle(color: Colors.black26, fontSize: 10, letterSpacing: 1),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                ...List.generate(_amigos.length, (i) {
                  final amigo = _amigos[i];
                  final uid      = amigo['uid']      as String;
                  final nombre   = amigo['nombre']   as String;
                  final username = amigo['username'] as String;
                  final solar    = amigo['solar']    as String;
                  final lunar    = amigo['lunar']    as String;
                  final asc      = amigo['asc']      as String;
                  final caption  = _compatibilidades[uid] ?? '';
                  final simbolo  = simbolosSignos[solar] ?? '';

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (i > 0) const Divider(color: Colors.black12),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 26,
                                  backgroundColor: Colors.black.withValues(alpha: 0.06),
                                  backgroundImage: amigo['fotoUrl'] != null
                                      ? NetworkImage(amigo['fotoUrl'] as String)
                                      : null,
                                  child: amigo['fotoUrl'] == null
                                      ? const Icon(Icons.person, color: Colors.black26, size: 22)
                                      : null,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.baseline,
                                        textBaseline: TextBaseline.alphabetic,
                                        children: [
                                          Text(nombre,
                                              style: const TextStyle(
                                                  color: Colors.black87, fontSize: 15,
                                                  fontWeight: FontWeight.w400, letterSpacing: 0.2)),
                                          if (username.isNotEmpty) ...[
                                            const SizedBox(width: 6),
                                            Text('@$username',
                                                style: const TextStyle(
                                                    color: Colors.black38, fontSize: 12,
                                                    fontWeight: FontWeight.w300)),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Wrap(
                                        spacing: 4,
                                        children: [
                                          Text('$simbolo $solar',
                                              style: const TextStyle(color: Colors.black38, fontSize: 11)),
                                          const Text('·', style: TextStyle(color: Colors.black26, fontSize: 11)),
                                          Text('${simbolosSignos[lunar] ?? ''} $lunar',
                                              style: const TextStyle(color: Colors.black38, fontSize: 11)),
                                          const Text('·', style: TextStyle(color: Colors.black26, fontSize: 11)),
                                          Text('↑ $asc',
                                              style: const TextStyle(color: Colors.black38, fontSize: 11)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => PantallaAfinidad(
                                        miNombre:      widget.nombre,
                                        miSolar:       _miSolar,
                                        miLunar:       _miLunar,
                                        miAsc:         _miAsc,
                                        miPlanetas:    _miPlanetas,
                                        amigoNombre:   nombre,
                                        amigoUsername: username,
                                        amigoFotoUrl:  amigo['fotoUrl'] as String?,
                                        amigoSolar:    solar,
                                        amigoLunar:    lunar,
                                        amigoAsc:      asc,
                                        amigoPlanetas: (amigo['planetas'] as Map?)?.cast<String, String>() ?? const {},
                                        captionHoy:    caption,
                                        miUid:         _miUid,
                                        amigoUid:      uid,
                                      ),
                                    ),
                                  ),
                                  child: const Text(
                                    'ver perfil  →',
                                    style: TextStyle(
                                        color: Colors.black38, fontSize: 11,
                                        letterSpacing: 1),
                                  ),
                                ),
                              ],
                            ),
                            if (caption.isNotEmpty) ...[
                              const SizedBox(height: 14),
                              Text(caption,
                                  style: const TextStyle(
                                      color: Colors.black54, fontSize: 13,
                                      height: 1.7, letterSpacing: 0.2)),
                            ],
                          ],
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CampanaNotificaciones extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('solicitudes')
          .where('para', isEqualTo: uid)
          .where('estado', isEqualTo: 'pendiente')
          .snapshots(),
      builder: (context, snap) {
        final count = snap.data?.docs.length ?? 0;
        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PantallaNotificaciones()),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                count > 0 ? Icons.notifications : Icons.notifications_none,
                color: count > 0 ? Colors.black : Colors.black45,
                size: 20,
              ),
              if (count > 0)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        count > 9 ? '9+' : '$count',
                        style: const TextStyle(
                          color: Color(0xFFF3EBD6),
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _DebugSignoRow extends StatelessWidget {
  final String label;
  final String valor;
  final ValueChanged<String> onChanged;

  const _DebugSignoRow({required this.label, required this.valor, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(label, style: const TextStyle(color: Colors.black26, fontSize: 11, letterSpacing: 1)),
          ),
          const SizedBox(width: 8),
          DropdownButton<String>(
            value: valor,
            dropdownColor: const Color(0xFF111111),
            style: const TextStyle(color: Colors.black54, fontSize: 12),
            underline: const SizedBox(),
            items: _signosList.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
            onChanged: (v) { if (v != null) onChanged(v); },
          ),
        ],
      ),
    );
  }
}

// ─── Estrella de 4 puntas ─────────────────────────────────────────────────────

class _Estrella extends StatelessWidget {
  final double size;
  const _Estrella({required this.size});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _EstrellaPainter(),
    );
  }
}

class _EstrellaPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFB8973A)
      ..style = PaintingStyle.fill;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;
    final ri = r * 0.25;

    final path = Path();
    for (int i = 0; i < 8; i++) {
      final angle = (i * pi / 4) - pi / 2;
      final radius = i.isEven ? r : ri;
      final x = cx + radius * cos(angle);
      final y = cy + radius * sin(angle);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_EstrellaPainter _) => false;
}

// ─── Secuencia animada de imágenes de carga ───────────────────────────────────

class _LoadingImages extends StatefulWidget {
  const _LoadingImages();

  @override
  State<_LoadingImages> createState() => _LoadingImagesState();
}

class _LoadingImagesState extends State<_LoadingImages> {
  static const _imagenes = [
    'assets/Load_1.png',
    'assets/Load_2.png',
    'assets/Load_3.png',
  ];

  int _indice = 0;

  @override
  void initState() {
    super.initState();
    _animar();
  }

  Future<void> _animar() async {
    while (mounted) {
      await Future.delayed(const Duration(milliseconds: 250));
      if (!mounted) return;
      setState(() => _indice = (_indice + 1) % _imagenes.length);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.of(context).size.width;
    final alto = ancho * 1.3;
    return SizedBox(
      width: ancho,
      height: alto,
      child: OverflowBox(
        maxWidth: ancho * 1.15,
        maxHeight: alto + 40,
        alignment: Alignment.bottomLeft,
        child: Transform.translate(
          offset: const Offset(-30, 40),
          child: Transform.scale(
            scaleX: -1,
            child: Image.asset(
              _imagenes[_indice],
              width: ancho * 1.15,
              fit: BoxFit.contain,
              alignment: Alignment.bottomLeft,
            ),
          ),
        ),
      ),
    );
  }
}

