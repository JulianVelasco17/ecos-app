import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:video_player/video_player.dart';

const _beige = Color(0xFFF2E8D5);

class PantallaCompraEcosPlus extends StatefulWidget {
  const PantallaCompraEcosPlus({super.key});

  @override
  State<PantallaCompraEcosPlus> createState() => _PantallaCompraEcosPlusState();
}

class _PantallaCompraEcosPlusState extends State<PantallaCompraEcosPlus>
    with SingleTickerProviderStateMixin {
  bool _activando = false;
  late VideoPlayerController _video;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  static const _videoUrl =
      'https://firebasestorage.googleapis.com/v0/b/astro-fd0bf.firebasestorage.app/o/Assets%2Ffondo.mp4?alt=media&token=ffe0ff5e-a14f-4bdf-ae8f-a4aadeddcd63';

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);

    _video = VideoPlayerController.networkUrl(Uri.parse(_videoUrl))
      ..setLooping(true)
      ..setVolume(0)
      ..initialize().then((_) {
        if (mounted) {
          setState(() {});
          _video.play();
          _fadeCtrl.forward();
        }
      });
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _video.dispose();
    super.dispose();
  }

  Future<void> _activarDebug() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _activando = true);
    try {
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(uid)
          .set({'ecosPlusActivo': true}, SetOptions(merge: true));
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _activando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final topHalf = size.height * 0.78;

    return Scaffold(
      backgroundColor: _beige,
      body: Stack(
        children: [
          // ── Fondo beige sólido (mitad inferior) ────────────────────────
          Positioned(
            bottom: 0, left: 0, right: 0,
            height: size.height * 0.55,
            child: const ColoredBox(color: _beige),
          ),

          // ── Video mitad superior con fade in ───────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            height: topHalf,
            child: ClipRect(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: _video.value.isInitialized
                    ? FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: _video.value.size.width,
                          height: _video.value.size.height,
                          child: VideoPlayer(_video),
                        ),
                      )
                    : const ColoredBox(color: Colors.black),
              ),
            ),
          ),

          // ── Capa oscura sobre el video ──────────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            height: topHalf,
            child: ColoredBox(color: Colors.black.withValues(alpha: 0.65)),
          ),

          // ── Gradiente video → beige ─────────────────────────────────────
          Positioned(
            top: topHalf * 0.35,
            left: 0, right: 0,
            height: topHalf * 0.65,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    _beige.withValues(alpha: 0.6),
                    _beige,
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),

          // ── Contenido ────────────────────────────────────────────────────
          SafeArea(
            child: SizedBox(
              height: size.height,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),

                    // Título
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          behavior: HitTestBehavior.opaque,
                          child: const Padding(
                            padding: EdgeInsets.only(right: 12, top: 6),
                            child: Icon(Icons.arrow_back_ios, color: Colors.white54, size: 18),
                          ),
                        ),
                        const Text(
                          'ecos+',
                          style: TextStyle(
                            fontFamily: 'PlayfairDisplay',
                            color: Colors.white,
                            fontSize: 42,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 1.0,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    const Text(
                      'profundiza en lo que el cielo tiene para ti',
                      style: TextStyle(color: Colors.white60, fontSize: 16, letterSpacing: 0.5, height: 1.8),
                    ),

                    const SizedBox(height: 32),

                    // Beneficios
                    const _Beneficio(
                      icono: Icons.auto_awesome_outlined,
                      titulo: 'trascender',
                      descripcion: 'Expande cada lectura diaria. Reflexiones, arquetipos y el porqué detrás de tu mensaje.',
                    ),
                    const SizedBox(height: 24),
                    const _Beneficio(
                      icono: Icons.wb_sunny_outlined,
                      titulo: 'navega el clima astral',
                      descripcion: 'Cómo afecta el cielo de hoy a tu carta natal — casas activadas, tránsitos personales y cómo moverte.',
                    ),

                    const Spacer(flex: 3),

                    // Precio
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: const [
                        Text(
                          '\$79',
                          style: TextStyle(
                            color: Color(0xFF2C2015),
                            fontSize: 40,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'MXN · mes',
                          style: TextStyle(color: Color(0xFF7A6A52), fontSize: 13, letterSpacing: 0.5),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),
                    const Text(
                      'cancela cuando quieras',
                      style: TextStyle(color: Color(0xFFAA9878), fontSize: 11, letterSpacing: 0.5),
                    ),

                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _activando ? null : _activarDebug,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2C2015),
                          foregroundColor: _beige,
                          disabledBackgroundColor: const Color(0xFF2C2015).withValues(alpha: 0.4),
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
                          elevation: 0,
                        ),
                        child: _activando
                            ? const SizedBox(width: 18, height: 18,
                                child: CircularProgressIndicator(color: _beige, strokeWidth: 1.5))
                            : const Text('SUSCRIBIRME A ECOS+',
                                style: TextStyle(letterSpacing: 3, fontSize: 12)),
                      ),
                    ),

                    const SizedBox(height: 12),

                    Center(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        behavior: HitTestBehavior.opaque,
                        child: const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text(
                            'ahora no',
                            style: TextStyle(color: Color(0xFFAA9878), fontSize: 12, letterSpacing: 1),
                          ),
                        ),
                      ),
                    ),

                    Center(
                      child: GestureDetector(
                        onTap: _activarDebug,
                        behavior: HitTestBehavior.opaque,
                        child: const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text(
                            'debug: activar ecos+ →',
                            style: TextStyle(color: Color(0xFFAA9878), fontSize: 11, letterSpacing: 2),
                          ),
                        ),
                      ),
                    ),

                    const Spacer(flex: 1),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
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
                  style: const TextStyle(color: Colors.white, fontSize: 15, letterSpacing: 0.5)),
              const SizedBox(height: 4),
              Text(descripcion,
                  style: const TextStyle(color: Colors.white60, fontSize: 14, height: 1.6)),
            ],
          ),
        ),
      ],
    );
  }
}
