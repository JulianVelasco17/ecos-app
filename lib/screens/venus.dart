import 'dart:async';
import 'package:flutter/material.dart';
import '../widgets/loading_images.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/aspectos_natales.dart';
import '../services/claude_service.dart';
import 'venus_buscar_pareja.dart';
import 'venus_suscripcion.dart';
import 'venus_actividad.dart';
import 'venus_carta_reveal.dart';

enum _EstadoVenus { cargando, sinSuscripcion, sinPareja, solicitudEnviada, solicitudRecibida, enlazado }

class PantallaVenus extends StatefulWidget {
  final void Function(bool)? onCargandoChanged;
  const PantallaVenus({super.key, this.onCargandoChanged});

  @override
  State<PantallaVenus> createState() => _PantallaVenusState();
}

class _PantallaVenusState extends State<PantallaVenus> {
  _EstadoVenus _estado = _EstadoVenus.cargando;
  Map<String, dynamic>? _enlace;
  StreamSubscription<DocumentSnapshot>? _usuarioSub;

  @override
  void initState() {
    super.initState();
    _escucharUsuario();
  }

  @override
  void dispose() {
    _usuarioSub?.cancel();
    super.dispose();
  }

  void _escucharUsuario() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _usuarioSub = FirebaseFirestore.instance
        .collection('usuarios')
        .doc(uid)
        .snapshots()
        .listen((doc) {
      if (!doc.exists || !mounted) return;
      _actualizarEstado(doc.data()!);
    });
  }

  void _actualizarEstado(Map<String, dynamic> datos) {
    final tieneVenus = datos['venusActivo'] == true;
    final enlace = datos['venusEnlace'] as Map<String, dynamic>?;

    if (!tieneVenus) {
      final estadoEnlace = enlace?['estado'] as String?;
      if (estadoEnlace != 'pendiente_recibida') {
        setState(() => _estado = _EstadoVenus.sinSuscripcion);
        widget.onCargandoChanged?.call(false);
        return;
      }
    }

    if (enlace == null) {
      setState(() => _estado = _EstadoVenus.sinPareja);
      widget.onCargandoChanged?.call(false);
      return;
    }

    setState(() {
      _enlace = enlace;
      _estado = switch (enlace['estado'] as String) {
        'pendiente_enviada'  => _EstadoVenus.solicitudEnviada,
        'pendiente_recibida' => _EstadoVenus.solicitudRecibida,
        'activo'             => _EstadoVenus.enlazado,
        _                    => _EstadoVenus.sinPareja,
      };
    });
    widget.onCargandoChanged?.call(false);
  }

  Future<void> _cargar() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance.collection('usuarios').doc(uid).get();
    if (!doc.exists || !mounted) return;
    _actualizarEstado(doc.data()!);
  }

  Future<void> _cancelarDebug() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance.collection('usuarios').doc(uid).update({
      'venusActivo': false,
      'venusPagador': FieldValue.delete(),
    });
    if (mounted) setState(() => _estado = _EstadoVenus.sinSuscripcion);
  }

  Future<void> _cancelarORechar() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _enlace == null) return;

    final parejaUid = _enlace!['uid'] as String;

    // Si el que cancela es el pagador, desactivar Venus para ambos
    final miDoc = await FirebaseFirestore.instance.collection('usuarios').doc(uid).get();
    final esPagador = miDoc.data()?['venusPagador'] == uid;

    await FirebaseFirestore.instance.collection('usuarios').doc(uid).update({
      'venusEnlace': FieldValue.delete(),
      if (esPagador) 'venusActivo': false,
    });
    await FirebaseFirestore.instance.collection('usuarios').doc(parejaUid).update({
      'venusEnlace': FieldValue.delete(),
      if (esPagador) 'venusActivo': false,
    });

    setState(() { _enlace = null; _estado = esPagador ? _EstadoVenus.sinSuscripcion : _EstadoVenus.sinPareja; });
  }

  Future<void> _aceptar() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _enlace == null) return;

    final parejaUid = _enlace!['uid'] as String;
    final miDoc = await FirebaseFirestore.instance.collection('usuarios').doc(uid).get();
    final miNombre = miDoc.data()?['nombre'] ?? '';
    final miUsuario = miDoc.data()?['usuario'] ?? '';
    final miFoto = miDoc.data()?['fotoUrl'];

    await FirebaseFirestore.instance.collection('usuarios').doc(uid).update({
      'venusEnlace': {..._enlace!, 'estado': 'activo'},
      'venusActivo': true,
    });
    await FirebaseFirestore.instance.collection('usuarios').doc(parejaUid).update({
      'venusEnlace': {
        'uid': uid,
        'nombre': miNombre,
        'usuario': miUsuario,
        'fotoUrl': miFoto,
        'estado': 'activo',
      },
      'venusActivo': true,
    });

    setState(() { _enlace = {..._enlace!, 'estado': 'activo'}; _estado = _EstadoVenus.enlazado; });
  }

  Future<void> _disolver() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFFF3EBD6),
        title: const Text('disolver conexión', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w300, letterSpacing: 1)),
        content: const Text('esta acción no se puede deshacer.', style: TextStyle(color: Colors.black54)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('cancelar', style: TextStyle(color: Colors.black45))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('disolver', style: TextStyle(color: Colors.black87))),
        ],
      ),
    );
    if (confirmar != true) return;
    await _cancelarORechar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3EBD6),
      body: SafeArea(
        child: Stack(
          children: [
            switch (_estado) {
              _EstadoVenus.cargando           => const LoadingImages(),
              _EstadoVenus.sinSuscripcion     => PantallaVenusSuscripcion(onSuscrito: _cargar),
              _EstadoVenus.sinPareja          => _SinPareja(onBuscar: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => const PantallaVenusBuscarPareja())); _cargar(); }),
              _EstadoVenus.solicitudEnviada   => _SolicitudEnviada(enlace: _enlace!, onCancelar: _cancelarORechar),
              _EstadoVenus.solicitudRecibida  => _SolicitudRecibida(enlace: _enlace!, onAceptar: _aceptar, onRechazar: _cancelarORechar),
              _EstadoVenus.enlazado           => _Enlazada(enlace: _enlace!, onDisolver: _disolver),
            },
            Positioned(
              bottom: 16,
              right: 32,
              child: GestureDetector(
                onTap: _cancelarDebug,
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('debug: cancelar venus →', style: TextStyle(color: Colors.black26, fontSize: 11, letterSpacing: 1.5)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// Vistas
// ─────────────────────────────────────────

class _SinPareja extends StatelessWidget {
  final VoidCallback onBuscar;
  const _SinPareja({required this.onBuscar});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('venus', style: TextStyle(color: Colors.black, fontSize: 32, fontWeight: FontWeight.w300, letterSpacing: 3)),
          const SizedBox(height: 12),
          const Text('conecta con tu pareja\npara empezar', style: TextStyle(color: Colors.black45, fontSize: 13, letterSpacing: 1, height: 1.8)),
          const Spacer(),
          const Center(child: Icon(Icons.favorite_border, color: Colors.black12, size: 48)),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onBuscar,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: const Color(0xFFF3EBD6), padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2))),
              child: const Text('CONECTAR', style: TextStyle(letterSpacing: 3, fontSize: 12)),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SolicitudEnviada extends StatelessWidget {
  final Map<String, dynamic> enlace;
  final VoidCallback onCancelar;
  const _SolicitudEnviada({required this.enlace, required this.onCancelar});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('venus', style: TextStyle(color: Colors.black, fontSize: 32, fontWeight: FontWeight.w300, letterSpacing: 3)),
          const Spacer(),
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: Colors.black12,
                  backgroundImage: enlace['fotoUrl'] != null ? NetworkImage(enlace['fotoUrl']) : null,
                  child: enlace['fotoUrl'] == null ? const Icon(Icons.person, color: Colors.black45, size: 36) : null,
                ),
                const SizedBox(height: 20),
                Text(enlace['nombre'] ?? '', style: const TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.w300, letterSpacing: 2)),
                const SizedBox(height: 8),
                Text('@${enlace['usuario'] ?? ''}', style: const TextStyle(color: Colors.black45, fontSize: 13, letterSpacing: 1)),
                const SizedBox(height: 32),
                const Text('solicitud enviada', style: TextStyle(color: Colors.black26, fontSize: 12, letterSpacing: 3)),
              ],
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: onCancelar,
            behavior: HitTestBehavior.opaque,
            child: const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Text('cancelar solicitud', style: TextStyle(color: Colors.black26, fontSize: 12, letterSpacing: 2)),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SolicitudRecibida extends StatelessWidget {
  final Map<String, dynamic> enlace;
  final VoidCallback onAceptar;
  final VoidCallback onRechazar;
  const _SolicitudRecibida({required this.enlace, required this.onAceptar, required this.onRechazar});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('venus', style: TextStyle(color: Colors.black, fontSize: 32, fontWeight: FontWeight.w300, letterSpacing: 3)),
          const Spacer(),
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: Colors.black12,
                  backgroundImage: enlace['fotoUrl'] != null ? NetworkImage(enlace['fotoUrl']) : null,
                  child: enlace['fotoUrl'] == null ? const Icon(Icons.person, color: Colors.black45, size: 36) : null,
                ),
                const SizedBox(height: 20),
                Text(enlace['nombre'] ?? '', style: const TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.w300, letterSpacing: 2)),
                const SizedBox(height: 8),
                Text('@${enlace['usuario'] ?? ''}', style: const TextStyle(color: Colors.black45, fontSize: 13, letterSpacing: 1)),
                const SizedBox(height: 32),
                const Text('quiere conectar contigo', style: TextStyle(color: Colors.black45, fontSize: 13, letterSpacing: 1)),
              ],
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onAceptar,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: const Color(0xFFF3EBD6), padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2))),
              child: const Text('ACEPTAR', style: TextStyle(letterSpacing: 3, fontSize: 12)),
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: onRechazar,
            behavior: HitTestBehavior.opaque,
            child: const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Text('rechazar', style: TextStyle(color: Colors.black26, fontSize: 12, letterSpacing: 2)),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _Enlazada extends StatefulWidget {
  final Map<String, dynamic> enlace;
  final VoidCallback onDisolver;
  const _Enlazada({required this.enlace, required this.onDisolver});

  @override
  State<_Enlazada> createState() => _EnlazadaState();
}

class _EnlazadaState extends State<_Enlazada> {
  bool _cargando = true;
  List<AspectoNatal> _aspectos = [];
  String _miNombre   = '';
  String _parejaName = '';
  String? _miFotoUrl;
  String? _parejaFotoUrl;
  String? _fraseCompat;
  String? _textoCompat;
  String? _cierreCompat;
  bool _regenerando = false;

  // Carta no leída
  Map<String, dynamic>? _cartaPendiente;
  String? _cartaDocId;
  StreamSubscription<QuerySnapshot>? _cartaSub;

  @override
  void initState() {
    super.initState();
    _cargarSinastria();
    _escucharCartas();
  }

  @override
  void dispose() {
    _cartaSub?.cancel();
    super.dispose();
  }

  void _escucharCartas() {
    final miUid = FirebaseAuth.instance.currentUser?.uid;
    if (miUid == null) return;
    _cartaSub = FirebaseFirestore.instance
        .collection('venus_cartas')
        .doc(miUid)
        .collection('cartas')
        .where('leida', isEqualTo: false)
        .limit(1)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      if (snap.docs.isNotEmpty) {
        setState(() {
          _cartaPendiente = snap.docs.first.data();
          _cartaDocId     = snap.docs.first.id;
        });
      } else {
        setState(() { _cartaPendiente = null; _cartaDocId = null; });
      }
    });
  }

  Future<void> _marcarCartaLeida() async {
    final miUid = FirebaseAuth.instance.currentUser?.uid;
    if (miUid == null || _cartaDocId == null) return;
    await FirebaseFirestore.instance
        .collection('venus_cartas')
        .doc(miUid)
        .collection('cartas')
        .doc(_cartaDocId!)
        .update({'leida': true});
  }

  Future<void> _regenerarCompat() async {
    setState(() => _regenerando = true);
    final resultado = await ClaudeService.generarFraseCompatibilidad(parejaName: _parejaName);
    if (!mounted) return;
    setState(() {
      _fraseCompat  = resultado['frase'];
      _textoCompat  = resultado['cuerpo'];
      _cierreCompat = resultado['cierre'];
      _regenerando  = false;
    });
  }

  Future<void> _cargarSinastria() async {
    final miUid     = FirebaseAuth.instance.currentUser?.uid;
    final parejaUid = widget.enlace['uid'] as String?;
    if (miUid == null || parejaUid == null) return;

    final miDoc     = await FirebaseFirestore.instance.collection('usuarios').doc(miUid).get();
    final parejaDoc = await FirebaseFirestore.instance.collection('usuarios').doc(parejaUid).get();
    if (!miDoc.exists || !parejaDoc.exists || !mounted) return;

    DateTime fechaDe(Map<String, dynamic> d) =>
        (d['fechaNacimiento'] as Timestamp).toDate();
    (int, int) horaDe(Map<String, dynamic> d) {
      final s = (d['horaNacimiento'] as String? ?? '12:0').split(':');
      return (int.tryParse(s[0]) ?? 12, int.tryParse(s.length > 1 ? s[1] : '0') ?? 0);
    }

    final miDatos     = miDoc.data()!;
    final parejaDatos = parejaDoc.data()!;
    final (mH, mM)    = horaDe(miDatos);
    final (pH, pM)    = horaDe(parejaDatos);
    final miNombre    = miDatos['nombre'] as String? ?? '';
    final parejaName  = parejaDatos['nombre'] as String? ?? widget.enlace['nombre'] as String? ?? '';

    final aspectos = AspectosNatales.calcularSinastria(
      fechaDe(miDatos), mH, mM,
      fechaDe(parejaDatos), pH, pM,
    );

    // Cache diario de sinastría
    final hoy      = DateTime.now();
    final cacheKey = '${miUid}_${parejaUid}_${hoy.year}-${hoy.month.toString().padLeft(2,'0')}-${hoy.day.toString().padLeft(2,'0')}';
    final cacheDoc = await FirebaseFirestore.instance
        .collection('sinastrias').doc(cacheKey).get();

    String lectura;
    if (cacheDoc.exists) {
      lectura = cacheDoc.data()!['lectura'] as String;
    } else {
      final etiquetas = aspectos.map((a) =>
        '${a.planeta1} ${a.tipo} ${a.planeta2} de la otra persona'
      ).toList();
      lectura = await ClaudeService.generarSinastria(
        nombre1: miNombre,
        nombre2: parejaName,
        aspectos: etiquetas,
      );
      await FirebaseFirestore.instance
          .collection('sinastrias').doc(cacheKey)
          .set({'lectura': lectura, 'fecha': FieldValue.serverTimestamp()});
    }

    // Cache diario de frase de compatibilidad
    final compatKey = '${miUid}_${parejaUid}_compat_${hoy.year}-${hoy.month.toString().padLeft(2,'0')}-${hoy.day.toString().padLeft(2,'0')}';
    final compatDoc = await FirebaseFirestore.instance.collection('sinastrias').doc(compatKey).get();

    String fraseCompat  = '';
    String textoCompat  = '';
    String cierreCompat = '';
    if (compatDoc.exists) {
      fraseCompat  = compatDoc.data()!['frase']  as String? ?? '';
      textoCompat  = compatDoc.data()!['cuerpo'] as String? ?? compatDoc.data()!['texto'] as String? ?? '';
      cierreCompat = compatDoc.data()!['cierre'] as String? ?? '';
    } else {
      final resultado = await ClaudeService.generarFraseCompatibilidad(parejaName: parejaName);
      fraseCompat  = resultado['frase']  ?? '';
      textoCompat  = resultado['cuerpo'] ?? '';
      cierreCompat = resultado['cierre'] ?? '';
      await FirebaseFirestore.instance.collection('sinastrias').doc(compatKey)
          .set({'frase': fraseCompat, 'cuerpo': textoCompat, 'cierre': cierreCompat, 'fecha': FieldValue.serverTimestamp()});
    }

    if (mounted) {
      setState(() {
        _aspectos      = aspectos;
        _miNombre      = miNombre;
        _parejaName    = parejaName;
        _miFotoUrl     = miDatos['fotoUrl'] as String?;
        _parejaFotoUrl = parejaDatos['fotoUrl'] as String?;
        _fraseCompat   = fraseCompat;
        _textoCompat   = textoCompat;
        _cierreCompat  = cierreCompat;
        _cargando      = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'venus',
                style: TextStyle(
                  fontFamily: 'PlayfairDisplay',
                  fontWeight: FontWeight.w400,
                  fontSize: 44,
                  letterSpacing: 1.2,
                  height: 1.05,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              GestureDetector(
                onTap: widget.onDisolver,
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('disolver', style: TextStyle(color: Colors.black26, fontSize: 11, letterSpacing: 2)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // ── Banner carta pendiente ──────────────────────────────────────
          if (_cartaPendiente != null) ...[
            GestureDetector(
              onTap: () async {
                final remitente = _cartaPendiente!['de'] as String? ?? _parejaName;
                final mensaje   = _cartaPendiente!['mensaje'] as String? ?? '';
                final imagenUrl = _cartaPendiente!['imagenUrl'] as String?;
                final nav = Navigator.of(context);
                await _marcarCartaLeida();
                if (!mounted) return;
                nav.push(
                  PageRouteBuilder(
                    pageBuilder: (ctx, a, b) => CartaRevealScreen(
                      remitente: remitente,
                      mensaje:   mensaje,
                      imagenUrl: imagenUrl,
                    ),
                    transitionsBuilder: (ctx, anim, a, child) =>
                        FadeTransition(opacity: anim, child: child),
                    transitionDuration: const Duration(milliseconds: 400),
                  ),
                );
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'tienes una carta de amor 💌',
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 13,
                          fontWeight: FontWeight.w300,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const Text(
                      'abrir',
                      style: TextStyle(
                        color: Colors.black45,
                        fontSize: 12,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_ios, size: 10, color: Colors.black38),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // ── Avatares centrados ──────────────────────────────────────────
          Center(
            child: SizedBox(
              height: 80,
              width: 136,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.black12,
                    backgroundImage: _miFotoUrl != null ? NetworkImage(_miFotoUrl!) : null,
                    child: _miFotoUrl == null ? const Icon(Icons.person, color: Colors.black38, size: 32) : null,
                  ),
                  Positioned(
                    left: 56,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFF3EBD6), width: 2),
                      ),
                      child: CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.black12,
                        backgroundImage: _parejaFotoUrl != null ? NetworkImage(_parejaFotoUrl!) : null,
                        child: _parejaFotoUrl == null ? const Icon(Icons.person, color: Colors.black38, size: 32) : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 40),
          const Divider(color: Colors.black12),
          const SizedBox(height: 32),

          if (_cargando)
            const LoadingImages()
          else ...[

            // ── Frase de compatibilidad ─────────────────────────────────
            GestureDetector(
              onTap: _regenerando ? null : _regenerarCompat,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: _regenerando
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.black26, strokeWidth: 1.2))
                    : const Text('debug: regenerar →', style: TextStyle(color: Colors.black26, fontSize: 11, letterSpacing: 1.5)),
              ),
            ),
            const SizedBox(height: 12),
            if (_fraseCompat != null && _fraseCompat!.isNotEmpty) ...[
              Center(
                child: Text(
                  _fraseCompat!.replaceAll('tu pareja', _parejaName.split(' ').first),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'PlayfairDisplay',
                    color: Color(0xFF222222),
                    fontSize: 36,
                    fontWeight: FontWeight.w400,
                    height: 1.3,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (_textoCompat != null && _textoCompat!.isNotEmpty) ...[
              Text(
                _textoCompat!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 13,
                  fontWeight: FontWeight.w300,
                  height: 1.7,
                ),
              ),
              if (_cierreCompat != null && _cierreCompat!.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  _cierreCompat!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.black38,
                    fontSize: 13,
                    fontWeight: FontWeight.w300,
                    height: 1.7,
                  ),
                ),
              ],
              const SizedBox(height: 32),
              const Divider(color: Colors.black12),
              const SizedBox(height: 32),
            ],

            // ── Actividad diaria ────────────────────────────────────────
            VenusActividadDiaria(
              miUid:      FirebaseAuth.instance.currentUser?.uid ?? '',
              parejaUid:  widget.enlace['uid'] as String? ?? '',
              miNombre:   _miNombre,
              parejaName: _parejaName,
            ),

            const SizedBox(height: 40),
            const Divider(color: Colors.black12),
            const SizedBox(height: 32),

            // ── Aspectos de sinastría ───────────────────────────────────
            const Text('SU SINASTRÍA',
                style: TextStyle(color: Colors.black26, fontSize: 10, letterSpacing: 3)),
            const SizedBox(height: 6),
            const Text(
              'Los ángulos entre sus cartas natales.',
              style: TextStyle(color: Colors.black38, fontSize: 12, height: 1.6),
            ),
            const SizedBox(height: 24),

            if (_aspectos.isEmpty)
              const Text('Pocas tensiones — vuestras cartas se ignoran en su mayor parte.',
                  style: TextStyle(color: Colors.black38, fontSize: 13, height: 1.6))
            else
              ..._aspectos.map((a) {
                final corto = AspectosNatales.nombreCorto(a.tipo);
                final sig   = AspectosNatales.significadoAleatorio(corto);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(width: 3, height: 40, margin: const EdgeInsets.only(right: 14, top: 2), color: Colors.black12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${a.planeta1}  ·  $corto  ·  ${a.planeta2}',
                                style: const TextStyle(color: Colors.black, fontSize: 13, letterSpacing: 1, fontWeight: FontWeight.w300)),
                            const SizedBox(height: 3),
                            Text(sig, style: const TextStyle(color: Colors.black38, fontSize: 12, height: 1.5)),
                          ],
                        ),
                      ),
                      Text('${a.orbe.toStringAsFixed(1)}°',
                          style: const TextStyle(color: Colors.black26, fontSize: 11)),
                    ],
                  ),
                );
              }),

            const SizedBox(height: 32),
          ],
        ],
      ),
    );
  }
}
