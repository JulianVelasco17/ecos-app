import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/aspectos_natales.dart';
import '../services/claude_service.dart';
import 'venus_buscar_pareja.dart';
import 'venus_suscripcion.dart';
import 'venus_actividad.dart';

enum _EstadoVenus { cargando, sinSuscripcion, sinPareja, solicitudEnviada, solicitudRecibida, enlazado }

class PantallaVenus extends StatefulWidget {
  const PantallaVenus({super.key});

  @override
  State<PantallaVenus> createState() => _PantallaVenusState();
}

class _PantallaVenusState extends State<PantallaVenus> {
  _EstadoVenus _estado = _EstadoVenus.cargando;
  Map<String, dynamic>? _enlace;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final doc = await FirebaseFirestore.instance.collection('usuarios').doc(uid).get();
    if (!doc.exists) return;
    final datos = doc.data()!;

    final tieneVenus = datos['venusActivo'] == true;
    if (!tieneVenus) {
      setState(() => _estado = _EstadoVenus.sinSuscripcion);
      return;
    }

    final enlace = datos['venusEnlace'] as Map<String, dynamic>?;
    if (enlace == null) {
      setState(() => _estado = _EstadoVenus.sinPareja);
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
  }

  Future<void> _cancelarORechar() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _enlace == null) return;

    final parejaUid = _enlace!['uid'] as String;
    await FirebaseFirestore.instance.collection('usuarios').doc(uid).update({'venusEnlace': FieldValue.delete()});
    await FirebaseFirestore.instance.collection('usuarios').doc(parejaUid).update({'venusEnlace': FieldValue.delete()});

    setState(() { _enlace = null; _estado = _EstadoVenus.sinPareja; });
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
    });
    await FirebaseFirestore.instance.collection('usuarios').doc(parejaUid).update({
      'venusEnlace': {
        'uid': uid,
        'nombre': miNombre,
        'usuario': miUsuario,
        'fotoUrl': miFoto,
        'estado': 'activo',
      },
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
        child: switch (_estado) {
          _EstadoVenus.cargando           => const Center(child: CircularProgressIndicator(color: Colors.black12)),
          _EstadoVenus.sinSuscripcion     => _Paywall(onSuscribirse: () async { final activado = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const PantallaVenusSuscripcion())); if (activado == true) _cargar(); }),
          _EstadoVenus.sinPareja          => _SinPareja(onBuscar: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => const PantallaVenusBuscarPareja())); _cargar(); }),
          _EstadoVenus.solicitudEnviada   => _SolicitudEnviada(enlace: _enlace!, onCancelar: _cancelarORechar),
          _EstadoVenus.solicitudRecibida  => _SolicitudRecibida(enlace: _enlace!, onAceptar: _aceptar, onRechazar: _cancelarORechar),
          _EstadoVenus.enlazado           => _Enlazada(enlace: _enlace!, onDisolver: _disolver),
        },
      ),
    );
  }
}

// ─────────────────────────────────────────
// Vistas
// ─────────────────────────────────────────

class _Paywall extends StatelessWidget {
  final VoidCallback onSuscribirse;
  const _Paywall({required this.onSuscribirse});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('venus', style: TextStyle(color: Colors.black, fontSize: 32, fontWeight: FontWeight.w300, letterSpacing: 3)),
          const SizedBox(height: 12),
          const Text('conecta con tu pareja', style: TextStyle(color: Colors.black45, fontSize: 13, letterSpacing: 1, height: 1.8)),
          const Spacer(),
          const Center(child: Icon(Icons.favorite_border, color: Colors.black12, size: 48)),
          const SizedBox(height: 24),
          const Center(child: Text('sección premium', style: TextStyle(color: Colors.black26, fontSize: 12, letterSpacing: 3))),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onSuscribirse,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: const Color(0xFFF3EBD6), padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2))),
              child: const Text('SUSCRIBIRSE', style: TextStyle(letterSpacing: 3, fontSize: 12)),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

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
            child: const Center(child: Text('cancelar solicitud', style: TextStyle(color: Colors.black26, fontSize: 12, letterSpacing: 2))),
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
            child: const Center(child: Text('rechazar', style: TextStyle(color: Colors.black26, fontSize: 12, letterSpacing: 2))),
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
  String? _lectura;
  String _miNombre   = '';
  String _parejaName = '';

  @override
  void initState() {
    super.initState();
    _cargarSinastria();
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

    if (mounted) {
      setState(() {
        _aspectos   = aspectos;
        _lectura    = lectura;
        _miNombre   = miNombre;
        _parejaName = parejaName;
        _cargando   = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final enlace = widget.enlace;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('venus', style: TextStyle(color: Colors.black, fontSize: 32, fontWeight: FontWeight.w300, letterSpacing: 3)),
              GestureDetector(
                onTap: widget.onDisolver,
                child: const Text('disolver', style: TextStyle(color: Colors.black26, fontSize: 11, letterSpacing: 2)),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // ── Perfil pareja ───────────────────────────────────────────────
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: Colors.black12,
                backgroundImage: enlace['fotoUrl'] != null ? NetworkImage(enlace['fotoUrl']) : null,
                child: enlace['fotoUrl'] == null ? const Icon(Icons.person, color: Colors.black45, size: 22) : null,
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(enlace['nombre'] ?? '', style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w300, letterSpacing: 1)),
                  Text('@${enlace['usuario'] ?? ''}', style: const TextStyle(color: Colors.black45, fontSize: 12, letterSpacing: 1)),
                ],
              ),
            ],
          ),

          const SizedBox(height: 48),
          const Divider(color: Colors.black12),
          const SizedBox(height: 36),

          if (_cargando)
            const Center(child: CircularProgressIndicator(color: Colors.black26, strokeWidth: 1.5))
          else ...[

            // ── Lectura de sinastría ────────────────────────────────────
            const Text('HOY JUNTOS',
                style: TextStyle(color: Colors.black26, fontSize: 10, letterSpacing: 3)),
            const SizedBox(height: 16),
            if (_lectura != null)
              Text(
                _lectura!,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 15,
                  fontWeight: FontWeight.w300,
                  height: 1.8,
                  letterSpacing: 0.2,
                ),
              ),

            const SizedBox(height: 40),
            const Divider(color: Colors.black12),
            const SizedBox(height: 32),

            // ── Aspectos de sinastría ───────────────────────────────────
            const Text('VUESTRA SINASTRÍA',
                style: TextStyle(color: Colors.black26, fontSize: 10, letterSpacing: 3)),
            const SizedBox(height: 6),
            const Text(
              'Los ángulos entre vuestras cartas natales.',
              style: TextStyle(color: Colors.black38, fontSize: 12, height: 1.6),
            ),
            const SizedBox(height: 24),

            if (_aspectos.isEmpty)
              const Text('Pocas tensiones — vuestras cartas se ignoran en su mayor parte.',
                  style: TextStyle(color: Colors.black38, fontSize: 13, height: 1.6))
            else
              ..._aspectos.map((a) {
                final corto = AspectosNatales.nombreCorto(a.tipo);
                final sig   = AspectosNatales.significados[corto] ?? '';
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

            // ── Actividad diaria ────────────────────────────────────────
            const Divider(color: Colors.black12),
            const SizedBox(height: 32),

            VenusActividadDiaria(
              miUid:      FirebaseAuth.instance.currentUser?.uid ?? '',
              parejaUid:  widget.enlace['uid'] as String? ?? '',
              miNombre:   _miNombre,
              parejaName: _parejaName,
            ),

            const SizedBox(height: 32),
          ],
        ],
      ),
    );
  }
}
