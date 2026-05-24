import 'package:flutter/material.dart';
import '../widgets/fade_avatar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/calculos_astrales.dart';
import 'afinidad.dart';
import 'buscar_amigos.dart';

class PantallaAmigos extends StatefulWidget {
  const PantallaAmigos({super.key});

  @override
  State<PantallaAmigos> createState() => _PantallaAmigosState();
}

class _PantallaAmigosState extends State<PantallaAmigos> {
  static const _beige  = Color(0xFFF3EBD6);
  static const _gold   = Color(0xFFB8973A);

  final _scrollCtrl = ScrollController();
  final Map<String, GlobalKey> _letraKeys = {};

  List<_AmigoData> _amigos = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final miUid = FirebaseAuth.instance.currentUser?.uid;
    if (miUid == null) return;

    FirebaseFirestore.instance
        .collection('usuarios')
        .doc(miUid)
        .collection('amigos')
        .snapshots()
        .listen((snap) async {
      final futures = snap.docs.map((d) async {
        final uid  = d['uid'] as String;
        final doc  = await FirebaseFirestore.instance.collection('usuarios').doc(uid).get();
        if (!doc.exists) return null;
        final data = doc.data()!;
        return _AmigoData(
          uid:      uid,
          nombre:   data['nombre'] as String? ?? '',
          usuario:  data['usuario'] as String? ?? '',
          fotoUrl:  data['fotoUrl'] as String?,
          rawData:  data,
        );
      });
      final results = (await Future.wait(futures)).whereType<_AmigoData>().toList();
      results.sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
      if (mounted) setState(() { _amigos = results; _cargando = false; });
    });
  }

  Map<String, List<_AmigoData>> get _grupos {
    final map = <String, List<_AmigoData>>{};
    for (final a in _amigos) {
      final letra = a.nombre.isEmpty ? '#' : a.nombre[0].toUpperCase();
      map.putIfAbsent(letra, () => []).add(a);
    }
    return Map.fromEntries(map.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
  }

  void _irALetra(String letra) {
    final key = _letraKeys[letra];
    if (key == null) return;
    final ctx = key.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(ctx,
        duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  Future<void> _abrirAfinidad(_AmigoData amigo) async {
    final miUid = FirebaseAuth.instance.currentUser?.uid;
    if (miUid == null) return;
    final miDoc = await FirebaseFirestore.instance.collection('usuarios').doc(miUid).get();
    if (!miDoc.exists || !mounted) return;
    final mi = miDoc.data()!;

    CartaAstral cartaDe(Map<String, dynamic> d) {
      final ts   = d['fechaNacimiento'];
      final fecha = (ts).toDate() as DateTime;
      final p    = ((d['horaNacimiento'] as String?) ?? '12:00').split(':');
      return CalculosAstrales.calcular(
        fechaNacimiento: fecha,
        hora:     int.tryParse(p[0]) ?? 12,
        minutos:  int.tryParse(p.length > 1 ? p[1] : '0') ?? 0,
        latitud:  (d['latitud']  as num?)?.toDouble() ?? 0,
        longitud: (d['longitud'] as num?)?.toDouble() ?? 0,
      );
    }

    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => PantallaAfinidad(
        miUid:         miUid,
        miNombre:      mi['nombre'] ?? '',
        miFotoUrl:     (mi['fotoUrl'] as String?) ?? FirebaseAuth.instance.currentUser?.photoURL,
        miSolar:       cartaDe(mi).signoSolar,
        miLunar:       cartaDe(mi).signoLunar,
        miAsc:         cartaDe(mi).ascendente,
        miPlanetas:    cartaDe(mi).planetas,
        amigoUid:      amigo.uid,
        amigoNombre:   amigo.nombre,
        amigoUsername: amigo.usuario,
        amigoFotoUrl:  amigo.fotoUrl,
        amigoSolar:    cartaDe(amigo.rawData).signoSolar,
        amigoLunar:    cartaDe(amigo.rawData).signoLunar,
        amigoAsc:      cartaDe(amigo.rawData).ascendente,
        amigoPlanetas: cartaDe(amigo.rawData).planetas,
        captionHoy:    '',
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final grupos = _grupos;
    final letrasDisponibles = grupos.keys.toList();

    // registrar keys para cada letra
    for (final l in letrasDisponibles) {
      _letraKeys.putIfAbsent(l, () => GlobalKey());
    }

    return Scaffold(
      backgroundColor: _beige,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 36, 20, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(width: 2, height: 22, color: _gold),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Tus amigos',
                          style: TextStyle(
                              fontFamily: 'PlayfairDisplay',
                              color: Color(0xFF222222),
                              fontSize: 18,
                              fontWeight: FontWeight.w400,
                              letterSpacing: 0.3)),
                      const SizedBox(height: 2),
                      Text('${_amigos.length} personas',
                          style: GoogleFonts.manrope(
                              color: Colors.black.withValues(alpha: 0.3),
                              fontSize: 11)),
                    ],
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const PantallaBuscarAmigos())),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withValues(alpha: 0.06),
                      ),
                      child: Icon(Icons.search,
                          color: Colors.black.withValues(alpha: 0.4), size: 18),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),

            const SizedBox(height: 12),
            Divider(color: Colors.black.withValues(alpha: 0.07), thickness: 1),

            // ── lista + índice ──
            Expanded(
              child: _cargando
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 1.5))
                  : _amigos.isEmpty
                      ? Center(
                          child: Text('aún no tienes amigos\nbusca a alguien con la lupa',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.manrope(
                                  color: Colors.black26, fontSize: 13, height: 2)))
                      : Row(
                          children: [
                            // lista principal
                            Expanded(
                              child: ListView(
                                controller: _scrollCtrl,
                                padding: const EdgeInsets.only(left: 28, right: 8, bottom: 40),
                                children: [
                                  for (final letra in letrasDisponibles) ...[
                                    // encabezado de letra
                                    Padding(
                                      key: _letraKeys[letra],
                                      padding: const EdgeInsets.only(top: 24, bottom: 10),
                                      child: Text(letra,
                                          style: TextStyle(
                                              fontFamily: 'PlayfairDisplay',
                                              color: _gold.withValues(alpha: 0.7),
                                              fontSize: 18,
                                              fontWeight: FontWeight.w400)),
                                    ),
                                    // amigos de esa letra
                                    for (final amigo in grupos[letra]!)
                                      _AmigoTile(
                                        amigo: amigo,
                                        onTap: () => _abrirAfinidad(amigo),
                                      ),
                                    Divider(
                                        color: Colors.black.withValues(alpha: 0.06),
                                        thickness: 1,
                                        height: 1),
                                  ],
                                ],
                              ),
                            ),

                            // barra índice A–Z completo
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: 'ABCDEFGHIJKLMNÑOPQRSTUVWXYZ'.split('').map((l) {
                                  final tiene = letrasDisponibles.contains(l);
                                  return GestureDetector(
                                    onTap: tiene ? () => _irALetra(l) : null,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 1.5, horizontal: 6),
                                      child: Text(l,
                                          style: TextStyle(
                                              color: tiene
                                                  ? _gold.withValues(alpha: 0.75)
                                                  : Colors.black.withValues(alpha: 0.12),
                                              fontSize: 9,
                                              fontWeight: tiene ? FontWeight.w700 : FontWeight.w400,
                                              letterSpacing: 0.3)),
                                    ),
                                  );
                                }).toList(),
                              ),
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

class _AmigoTile extends StatelessWidget {
  final _AmigoData amigo;
  final VoidCallback onTap;
  const _AmigoTile({required this.amigo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            FadeAvatar(
              radius: 24,
              backgroundColor: Colors.black.withValues(alpha: 0.08),
              fotoUrl: amigo.fotoUrl,
              fallbackChild: amigo.fotoUrl == null
                  ? Text(
                      amigo.nombre.isNotEmpty ? amigo.nombre[0].toUpperCase() : '?',
                      style: TextStyle(
                          color: Colors.black.withValues(alpha: 0.4),
                          fontFamily: 'PlayfairDisplay',
                          fontSize: 16))
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(amigo.nombre,
                      style: GoogleFonts.manrope(
                          color: Colors.black.withValues(alpha: 0.8),
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0.3)),
                  const SizedBox(height: 2),
                  Text('@${amigo.usuario}',
                      style: GoogleFonts.manrope(
                          color: Colors.black.withValues(alpha: 0.3),
                          fontSize: 11,
                          letterSpacing: 0.5)),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                color: Colors.black.withValues(alpha: 0.15), size: 18),
          ],
        ),
      ),
    );
  }
}

class _AmigoData {
  final String uid;
  final String nombre;
  final String usuario;
  final String? fotoUrl;
  final Map<String, dynamic> rawData;
  const _AmigoData({
    required this.uid, required this.nombre, required this.usuario,
    required this.fotoUrl, required this.rawData,
  });
}
