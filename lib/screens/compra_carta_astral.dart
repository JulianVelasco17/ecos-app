import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:video_player/video_player.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../services/debug_config.dart';
import '../services/purchases_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'lectura_carta_astral.dart';
import 'constelacion_widget.dart';
import 'home.dart';
import 'login.dart';
import 'crear_credenciales.dart';
import '../services/calculos_astrales.dart';
import '../services/aspectos_natales.dart';
import '../services/claude_service.dart';

class PantallaCompraCarta extends StatefulWidget {
  final VideoPlayerController? videoExterno;

  const PantallaCompraCarta({
    super.key,
    this.videoExterno,
  });

  @override
  State<PantallaCompraCarta> createState() => _PantallaCompraCartaState();
}

class _PantallaCompraCartaState extends State<PantallaCompraCarta> {
  bool _activando = false;
  VideoPlayerController? _videoPropio;
  VideoPlayerController? _videoSolin;
  String _precioStr = r'$59';
  String _unidadStr = 'pago único';

  Future<void> _cargarPrecio() async {
    try {
      await PurchasesService.ensureConfigured();
      final productos = await Purchases.getProducts(['com.ecos.astroapp.carta_profunda']);
      if (mounted && productos.isNotEmpty) {
        setState(() { _precioStr = '${productos.first.priceString} ${productos.first.currencyCode}'; });
      }
    } catch (_) {}
  }

  static const _url =
      'https://firebasestorage.googleapis.com/v0/b/astro-fd0bf.firebasestorage.app/o/Assets%2Fonboard.mp4?alt=media&token=4dc6d672-2bb1-43b5-933b-47fda187ac9c';
  static const _urlSolin =
      'https://firebasestorage.googleapis.com/v0/b/astro-fd0bf.firebasestorage.app/o/Assets%2Fsolinvert.mov?alt=media&token=459f6a7d-0890-4f3a-8656-9937d323b7fa';

  VideoPlayerController get _video => widget.videoExterno ?? _videoPropio!;

  @override
  void initState() {
    super.initState();
    if (widget.videoExterno == null) {
      _videoPropio = VideoPlayerController.networkUrl(Uri.parse(_url))
        ..setLooping(true)
        ..setVolume(0)
        ..initialize().then((_) {
          if (mounted) { setState(() {}); _videoPropio!.play(); }
        });
    }
    _videoSolin = VideoPlayerController.networkUrl(Uri.parse(_urlSolin))
      ..setLooping(false)
      ..setVolume(0)
      ..initialize();
    _cargarPrecio();
  }

  @override
  void dispose() {
    _videoPropio?.dispose();
    _videoSolin?.dispose();
    super.dispose();
  }

  Future<void> _irAConstelacion(String uid) async {
    final userDoc = await FirebaseFirestore.instance.collection('usuarios').doc(uid).get();
    if (!mounted || !userDoc.exists) return;
    final datos = userDoc.data()!;
    final fechaTs = datos['fechaNacimiento'] as dynamic;
    final fecha   = fechaTs.toDate() as DateTime;
    final horaParts = ((datos['horaNacimiento'] as String?) ?? '12:00').split(':');
    final hora = int.tryParse(horaParts[0]) ?? 12;
    final min  = int.tryParse(horaParts.length > 1 ? horaParts[1] : '0') ?? 0;
    final lat  = (datos['latitud']  as num?)?.toDouble() ?? 0.0;
    final lon  = (datos['longitud'] as num?)?.toDouble() ?? 0.0;
    final carta = CalculosAstrales.calcular(fechaNacimiento: fecha, hora: hora, minutos: min, latitud: lat, longitud: lon);

    final cargaFuture = () async {
      final cached = await FirebaseFirestore.instance
          .collection('lecturasProfundas').doc('${uid}_carta_v3').get();
      if (cached.exists) return;
      final etiquetas = AspectosNatales.calcular(fecha, hora, min)
          .map((a) => '${a.planeta1} ${a.tipo} ${a.planeta2} (orbe ${a.orbe.toStringAsFixed(1)}°)').toList();
      await ClaudeService.generarLecturaCartaProfunda(
        nombre: datos['usuario'] as String? ?? '',
        signoSolar: carta.signoSolar, signoLunar: carta.signoLunar,
        ascendente: carta.ascendente, aspectos: etiquetas, planetas: carta.planetas,
      );
    }();

    if (!mounted) return;
    // Marcar video como visto para que lectura_carta_astral lo salte
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('carta_astral_video_visto', true);
    if (!mounted) return;

    Navigator.pushReplacement(context, MaterialPageRoute(
      builder: (_) => PantallaConstelacion(
        signo: carta.signoSolar, nombre: datos['usuario'] as String? ?? '',
        signoSolar: carta.signoSolar, signoLunar: carta.signoLunar,
        ascendente: carta.ascendente, planetas: carta.planetas,
        casas: carta.casas, fechaNacimiento: fecha, hora: hora, minutos: min,
        esperarCarga: cargaFuture,
        onContinuar: (ctx) => PantallaLecturaCartaAstral.navigateTo(ctx, Offset.zero),
      ),
    ));
  }

  Future<void> _activarDebug() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _activando = true);
    try {
      if (DebugConfig.instance.activo) {
        await FirebaseFirestore.instance
            .collection('usuarios').doc(uid)
            .set({'cartaActiva': true}, SetOptions(merge: true));
      } else {
        await PurchasesService.ensureConfigured();
        final products = await Purchases.getProducts(['com.ecos.astroapp.carta_profunda']);
        if (products.isEmpty) throw Exception('producto no disponible');
        await Purchases.purchaseStoreProduct(products.first);
        await FirebaseFirestore.instance
            .collection('usuarios').doc(uid)
            .set({'cartaActiva': true}, SetOptions(merge: true));
      }
      if (!mounted) return;
      await _irAConstelacion(uid);
    } on PurchasesErrorCode catch (_) {
      if (mounted) setState(() => _activando = false);
    } catch (_) {
      if (mounted) setState(() => _activando = false);
    }
  }

  void _irADescuento() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => _PantallaDescuento(videoExterno: widget.videoExterno),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (_, __) => _irADescuento(),
      child: Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Video background
          if ((widget.videoExterno?.value.isInitialized ?? false) || (_videoPropio?.value.isInitialized ?? false))
            Positioned.fill(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _video.value.size.width,
                  height: _video.value.size.height,
                  child: VideoPlayer(_video),
                ),
              ),
            ),

          // 85% dark overlay
          Positioned.fill(
            child: Container(color: Colors.black.withValues(alpha: 0.90)),
          ),

          // Content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(32, 16, 32, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: _irADescuento,
                        behavior: HitTestBehavior.opaque,
                        child: const Padding(
                          padding: EdgeInsets.only(right: 12, top: 8),
                          child: Icon(Icons.arrow_back_ios, color: Colors.white38, size: 18),
                        ),
                      ),
                      const Expanded(
                        child: Text(
                          'tu carta\nnatal',
                          style: TextStyle(
                            fontFamily: 'PlayfairDisplay',
                            color: Color(0xFFE8DFD0),
                            fontSize: 48,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 1.0,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  const Text(
                    'una lectura profunda, revisita cuando quieras',
                    style: TextStyle(color: Colors.white38, fontSize: 15, letterSpacing: 0.5, height: 1.8),
                  ),

                  const SizedBox(height: 48),

                  const _Beneficio(
                    icono: Icons.auto_awesome_outlined,
                    titulo: 'tu big 3 en profundidad',
                    descripcion: 'Sol, Luna y Ascendente interpretados juntos como un sistema, no por separado.',
                  ),
                  const SizedBox(height: 24),
                  const _Beneficio(
                    icono: Icons.hub_outlined,
                    titulo: 'aspectos natales',
                    descripcion: 'Las tensiones y armonías entre tus planetas que definen cómo experimentas el mundo.',
                  ),
                  const SizedBox(height: 24),
                  const _Beneficio(
                    icono: Icons.place_outlined,
                    titulo: 'lectura por ámbitos',
                    descripcion: 'Amor, amistad, suerte, familia y dinero — cada uno desde tu configuración natal.',
                  ),

                  const SizedBox(height: 56),

                  // Beige card: precio + botón
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3EBD6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              _precioStr,
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 40,
                                fontWeight: FontWeight.w300,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _unidadStr,
                              style: const TextStyle(color: Colors.black45, fontSize: 13, letterSpacing: 0.5),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),
                        const Text(
                          'sin suscripción, sin cobros futuros',
                          style: TextStyle(color: Colors.black38, fontSize: 13, letterSpacing: 0.5),
                        ),

                        const SizedBox(height: 24),

                        SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _activando ? null : _activarDebug,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                foregroundColor: const Color(0xFFF3EBD6),
                                disabledBackgroundColor: Colors.black26,
                                padding: const EdgeInsets.symmetric(vertical: 18),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
                                elevation: 0,
                              ),
                              child: _activando
                                  ? const SizedBox(width: 18, height: 18,
                                      child: CircularProgressIndicator(color: Colors.black54, strokeWidth: 1.5))
                                  : const Text('DESBLOQUEAR MI CARTA',
                                      style: TextStyle(letterSpacing: 3, fontSize: 12)),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  Center(
                    child: GestureDetector(
                      onTap: _irADescuento,
                      behavior: HitTestBehavior.opaque,
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text(
                          'ahora no',
                          style: TextStyle(color: Colors.white24, fontSize: 12, letterSpacing: 1),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ));
  }
}

class _Beneficio extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String descripcion;

  const _Beneficio({required this.icono, required this.titulo, required this.descripcion});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icono, size: 20, color: Colors.white38),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo,
                  style: const TextStyle(color: Color(0xFFE8DFD0), fontSize: 15, fontWeight: FontWeight.w500, letterSpacing: 0.3)),
              const SizedBox(height: 4),
              Text(descripcion,
                  style: const TextStyle(color: Color(0x99E8DFD0), fontSize: 14, height: 1.6)),
            ],
          ),
        ),
      ],
    );
  }
}

class _PantallaDescuento extends StatefulWidget {
  final VideoPlayerController? videoExterno;

  const _PantallaDescuento({this.videoExterno});

  @override
  State<_PantallaDescuento> createState() => _PantallaDescuentoState();
}

class _PantallaDescuentoState extends State<_PantallaDescuento> {
  bool _activando = false;
  VideoPlayerController? _videoPropio;
  VideoPlayerController? _videoSolin;
  String _precioStr = r'$39';
  String _precioOrigStr = r'$59';

  Future<void> _cargarPrecio() async {
    try {
      await PurchasesService.ensureConfigured();
      final productos = await Purchases.getProducts([
        'com.ecos.astroapp.carta_profunda_descuento',
        'com.ecos.astroapp.carta_profunda',
      ]);
      if (!mounted) return;
      setState(() {
        final desc = productos.where((p) => p.identifier.contains('descuento')).firstOrNull;
        final orig = productos.where((p) => !p.identifier.contains('descuento')).firstOrNull;
        if (desc != null) _precioStr = '${desc.priceString} ${desc.currencyCode}';
        if (orig != null) _precioOrigStr = '${orig.priceString} ${orig.currencyCode}';
      });
    } catch (_) {}
  }

  static const _url =
      'https://firebasestorage.googleapis.com/v0/b/astro-fd0bf.firebasestorage.app/o/Assets%2Fonboard.mp4?alt=media&token=4dc6d672-2bb1-43b5-933b-47fda187ac9c';
  static const _urlSolin =
      'https://firebasestorage.googleapis.com/v0/b/astro-fd0bf.firebasestorage.app/o/Assets%2Fsolinvert.mov?alt=media&token=459f6a7d-0890-4f3a-8656-9937d323b7fa';

  VideoPlayerController get _video => widget.videoExterno ?? _videoPropio!;
  bool get _videoListo =>
      (widget.videoExterno?.value.isInitialized ?? false) ||
      (_videoPropio?.value.isInitialized ?? false);

  @override
  void initState() {
    super.initState();
    if (widget.videoExterno == null) {
      _videoPropio = VideoPlayerController.networkUrl(Uri.parse(_url))
        ..setLooping(true)
        ..setVolume(0)
        ..initialize().then((_) {
          if (mounted) { setState(() {}); _videoPropio!.play(); }
        });
    }
    _videoSolin = VideoPlayerController.networkUrl(Uri.parse(_urlSolin))
      ..setLooping(false)
      ..setVolume(0)
      ..initialize();
    _cargarPrecio();
  }

  @override
  void dispose() {
    _videoPropio?.dispose();
    _videoSolin?.dispose();
    super.dispose();
  }

  Future<void> _irAConstelacion(String uid) async {
    final userDoc = await FirebaseFirestore.instance.collection('usuarios').doc(uid).get();
    if (!mounted || !userDoc.exists) return;
    final datos = userDoc.data()!;
    final fechaTs = datos['fechaNacimiento'] as dynamic;
    final fecha   = fechaTs.toDate() as DateTime;
    final horaParts = ((datos['horaNacimiento'] as String?) ?? '12:00').split(':');
    final hora = int.tryParse(horaParts[0]) ?? 12;
    final min  = int.tryParse(horaParts.length > 1 ? horaParts[1] : '0') ?? 0;
    final lat  = (datos['latitud']  as num?)?.toDouble() ?? 0.0;
    final lon  = (datos['longitud'] as num?)?.toDouble() ?? 0.0;
    final carta = CalculosAstrales.calcular(fechaNacimiento: fecha, hora: hora, minutos: min, latitud: lat, longitud: lon);

    final cargaFuture = () async {
      final cached = await FirebaseFirestore.instance
          .collection('lecturasProfundas').doc('${uid}_carta_v3').get();
      if (cached.exists) return;
      final etiquetas = AspectosNatales.calcular(fecha, hora, min)
          .map((a) => '${a.planeta1} ${a.tipo} ${a.planeta2} (orbe ${a.orbe.toStringAsFixed(1)}°)').toList();
      await ClaudeService.generarLecturaCartaProfunda(
        nombre: datos['usuario'] as String? ?? '',
        signoSolar: carta.signoSolar, signoLunar: carta.signoLunar,
        ascendente: carta.ascendente, aspectos: etiquetas, planetas: carta.planetas,
      );
    }();

    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('carta_astral_video_visto', true);
    if (!mounted) return;

    Navigator.pushReplacement(context, MaterialPageRoute(
      builder: (_) => PantallaConstelacion(
        signo: carta.signoSolar, nombre: datos['usuario'] as String? ?? '',
        signoSolar: carta.signoSolar, signoLunar: carta.signoLunar,
        ascendente: carta.ascendente, planetas: carta.planetas,
        casas: carta.casas, fechaNacimiento: fecha, hora: hora, minutos: min,
        esperarCarga: cargaFuture,
        onContinuar: (ctx) => PantallaLecturaCartaAstral.navigateTo(ctx, Offset.zero),
      ),
    ));
  }

  Future<void> _activarDebug() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _activando = true);
    try {
      if (DebugConfig.instance.activo) {
        await FirebaseFirestore.instance
            .collection('usuarios').doc(uid)
            .set({'cartaActiva': true}, SetOptions(merge: true));
      } else {
        await PurchasesService.ensureConfigured();
        final products = await Purchases.getProducts(['com.ecos.astroapp.carta_profunda_descuento']);
        if (products.isEmpty) throw Exception('producto no disponible');
        await Purchases.purchaseStoreProduct(products.first);
        await FirebaseFirestore.instance
            .collection('usuarios').doc(uid)
            .set({'cartaActiva': true}, SetOptions(merge: true));
      }
      if (!mounted) return;
      await _irAConstelacion(uid);
    } on PurchasesErrorCode catch (_) {
      if (mounted) setState(() => _activando = false);
    } catch (_) {
      if (mounted) setState(() => _activando = false);
    }
  }

  void _irAGracias() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const _PantallaGracias()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (_, __) => _irAGracias(),
      child: Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (_videoListo)
            Positioned.fill(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _video.value.size.width,
                  height: _video.value.size.height,
                  child: VideoPlayer(_video),
                ),
              ),
            ),
          Positioned.fill(
            child: Container(color: Colors.black.withValues(alpha: 0.90)),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 48),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: _irAGracias,
                        behavior: HitTestBehavior.opaque,
                        child: const Padding(
                          padding: EdgeInsets.only(right: 12, top: 6),
                          child: Icon(Icons.arrow_back_ios, color: Colors.white38, size: 18),
                        ),
                      ),
                      const Expanded(
                        child: Text(
                          'espera,\ntenemos algo\npara ti',
                          style: TextStyle(
                            fontFamily: 'PlayfairDisplay',
                            color: Color(0xFFE8DFD0),
                            fontSize: 48,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 1.0,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  const Text(
                    'por ser tu primera carta natal, te dejamos un precio especial.\nsolo por esta vez ;)',
                    style: TextStyle(color: Colors.white38, fontSize: 15, letterSpacing: 0.3, height: 1.8),
                  ),

                  const SizedBox(height: 56),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3EBD6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              _precioStr,
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 40,
                                fontWeight: FontWeight.w300,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'pago único',
                              style: TextStyle(color: Colors.black45, fontSize: 13, letterSpacing: 0.5),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              _precioOrigStr,
                              style: const TextStyle(
                                color: Colors.black26,
                                fontSize: 13,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                            SizedBox(width: 6),
                            Text(
                              '34% de descuento',
                              style: TextStyle(color: Colors.black45, fontSize: 12, letterSpacing: 0.3),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'sin suscripción, sin cobros futuros',
                          style: TextStyle(color: Colors.black38, fontSize: 13, letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _activando ? null : _activarDebug,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                foregroundColor: const Color(0xFFF3EBD6),
                                disabledBackgroundColor: Colors.black26,
                                padding: const EdgeInsets.symmetric(vertical: 18),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
                                elevation: 0,
                              ),
                              child: _activando
                                  ? const SizedBox(width: 18, height: 18,
                                      child: CircularProgressIndicator(color: Colors.black54, strokeWidth: 1.5))
                                  : const Text('DESBLOQUEAR MI CARTA',
                                      style: TextStyle(letterSpacing: 3, fontSize: 12)),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  Center(
                    child: GestureDetector(
                      onTap: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const _PantallaGracias()),
                      ),
                      behavior: HitTestBehavior.opaque,
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text(
                          'no, gracias',
                          style: TextStyle(color: Colors.white24, fontSize: 12, letterSpacing: 1),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ));
  }
}

class _PantallaGracias extends StatelessWidget {
  const _PantallaGracias();

  Future<void> _irAlPerfil(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const PantallaLogin()),
        (_) => false,
      );
      return;
    }

    final proveedores = user.providerData.map((p) => p.providerId).toSet();
    final tieneSocial = proveedores.contains('google.com') || proveedores.contains('apple.com');
    final tienePassword = proveedores.contains('password');

    if (tieneSocial || tienePassword) {
      // Ya tiene cuenta vinculada → ir al feed
      final doc = await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get();
      final nombre = doc.data()?['usuario'] ?? 'viajero';
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => PantallaHome(nombre: nombre, paginaInicial: 4)),
          (_) => false,
        );
      }
    } else {
      // Usuario anónimo → vincular correo con datos ya guardados en Firestore
      final doc = await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get();
      if (!context.mounted) return;
      final d = doc.data() ?? {};
      final fechaTs = d['fechaNacimiento'];
      final fecha = fechaTs != null ? (fechaTs as dynamic).toDate() as DateTime : DateTime(2000);
      final horaParts = ((d['horaNacimiento'] as String?) ?? '12:00').split(':');
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => PantallaCrearCredenciales(
          nombre:          d['usuario'] as String? ?? '',
          usuario:         d['usuario'] as String? ?? '',
          fechaNacimiento: fecha,
          horaNacimiento:  TimeOfDay(
            hour:   int.tryParse(horaParts[0]) ?? 12,
            minute: int.tryParse(horaParts.length > 1 ? horaParts[1] : '0') ?? 0,
          ),
          lugarNacimiento: d['lugarNacimiento'] as String? ?? '',
          latitud:         (d['latitud']  as num?)?.toDouble() ?? 0.0,
          longitud:        (d['longitud'] as num?)?.toDouble() ?? 0.0,
        )),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'tu carta\nsiempre\nestará aquí.',
                style: TextStyle(
                  fontFamily: 'PlayfairDisplay',
                  color: Colors.white,
                  fontSize: 38,
                  fontWeight: FontWeight.w400,
                  height: 1.2,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'cuando quieras, puedes desbloquearla desde tu perfil.',
                style: TextStyle(color: Colors.white38, fontSize: 13, height: 1.8, letterSpacing: 0.3),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _irAlPerfil(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF3EBD6),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
                    elevation: 0,
                  ),
                  child: const Text('VER MI PERFIL', style: TextStyle(letterSpacing: 3, fontSize: 12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

