import 'dart:math';
import 'package:flutter/material.dart';
import 'constelacion_widget.dart';

class CartaRevealScreen extends StatefulWidget {
  final String remitente;
  final String mensaje;
  final String? imagenUrl;

  const CartaRevealScreen({
    super.key,
    required this.remitente,
    required this.mensaje,
    this.imagenUrl,
  });

  @override
  State<CartaRevealScreen> createState() => _CartaRevealScreenState();
}

class _CartaRevealScreenState extends State<CartaRevealScreen>
    with TickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _solapaAnim;
  late final Animation<double> _cartaSubeAnim;
  late final Animation<double> _cartaExpandeAnim;
  late final Animation<double> _sobreDesvanece;
  late final Animation<double> _contenidoAparece;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );

    // 1. Solapa se abre (0 → 0.28)
    _solapaAnim = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.08, 0.38, curve: Curves.easeInOut),
    );

    // 2. Carta sube (0.35 → 0.60)
    _cartaSubeAnim = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.35, 0.60, curve: Curves.easeOut),
    );

    // 3. Sobre se desvanece (0.58 → 0.70)
    _sobreDesvanece = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.58, 0.72, curve: Curves.easeIn),
    );

    // 4. Carta se expande (0.62 → 0.85)
    _cartaExpandeAnim = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.62, 0.85, curve: Curves.easeOut),
    );

    // 5. Contenido aparece (0.82 → 1.0)
    _contenidoAparece = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.82, 1.0, curve: Curves.easeIn),
    );

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    const beige = Color(0xFFF3EBD6);

    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          final sobreVisible = 1.0 - _sobreDesvanece.value;
          final cartaProgress = _cartaExpandeAnim.value; // 0→1

          // Sobre dimensions
          const sobreW = 260.0;
          const sobreH = 170.0;

          // Carta dimensions: empieza pequeña (dentro del sobre) → expande a pantalla casi completa
          final cartaW = lerpDouble(sobreW - 20, size.width - 48, cartaProgress)!;
          final cartaH = lerpDouble(80.0, size.height * 0.72, cartaProgress)!;

          // Carta vertical offset: empieza en el centro del sobre, sube
          final cartaSubeOffset = lerpDouble(0.0, -sobreH * 0.55, _cartaSubeAnim.value)!;
          final cartaFinalOffset = lerpDouble(cartaSubeOffset, 0.0, cartaProgress)!;

          return SizedBox(
            width: size.width,
            height: size.height,
            child: Stack(
            alignment: Alignment.center,
            children: [
              const Positioned.fill(child: CieloEstrellado()),
              // ── Sobre ─────────────────────────────────────────────────
              if (sobreVisible > 0.0)
                Opacity(
                  opacity: sobreVisible.clamp(0.0, 1.0),
                  child: SizedBox(
                    width: sobreW,
                    height: sobreH,
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        // Cuerpo del sobre
                        Positioned.fill(
                          child: CustomPaint(painter: _SobrePainter()),
                        ),

                        // Solapa (se dobla hacia abajo)
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: Transform(
                            alignment: Alignment.topCenter,
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, 0.001)
                              ..rotateX(_solapaAnim.value * pi),
                            child: CustomPaint(
                              size: const Size(sobreW, sobreH * 0.5),
                              painter: _SolapaPainter(abierta: _solapaAnim.value > 0.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // ── Carta ──────────────────────────────────────────────────
              if (_cartaSubeAnim.value > 0)
                Transform.translate(
                  offset: Offset(0, cartaFinalOffset),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(lerpDouble(2, 8, cartaProgress)!),
                    child: Container(
                      width: cartaW,
                      height: cartaH,
                      color: beige,
                      child: Opacity(
                        opacity: _contenidoAparece.value,
                        child: _ContenidoCarta(
                          remitente: widget.remitente,
                          mensaje:   widget.mensaje,
                          imagenUrl: widget.imagenUrl,
                          onCerrar:  () => Navigator.of(context).pop(),
                        ),
                      ),
                    ),
                  ),
                ),

              // ── Botón cerrar (aparece al final) ────────────────────────
              if (_contenidoAparece.value > 0.5)
                Positioned(
                  bottom: 48,
                  child: Opacity(
                    opacity: ((_contenidoAparece.value - 0.5) * 2).clamp(0.0, 1.0),
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                            color: Colors.white,
                            child: const Text(
                              'cerrar y disolver',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 12,
                                letterSpacing: 3,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Esta acción eliminará la carta para siempre',
                          style: TextStyle(
                            color: Colors.white24,
                            fontSize: 11,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          );
        },
      ),
    );
  }
}

double? lerpDouble(double a, double b, double t) => a + (b - a) * t;

// ── Contenido de la carta ────────────────────────────────────────────────────

class _ContenidoCarta extends StatelessWidget {
  final String remitente;
  final String mensaje;
  final String? imagenUrl;
  final VoidCallback onCerrar;

  const _ContenidoCarta({
    required this.remitente,
    required this.mensaje,
    required this.imagenUrl,
    required this.onCerrar,
  });

  @override
  Widget build(BuildContext context) {
    final nombre = remitente.split(' ').first;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 36, 28, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            nombre,
            style: const TextStyle(
              fontFamily: 'PlayfairDisplay',
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: Color(0xFF888070),
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'te escribió:',
            style: TextStyle(
              color: Color(0xFFB0A890),
              fontSize: 11,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 28),
          if (imagenUrl != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.network(
                imagenUrl!,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 24),
          ],
          if (mensaje.isNotEmpty)
            Text(
              mensaje,
              style: const TextStyle(
                color: Color(0xFF2A2420),
                fontSize: 16,
                fontWeight: FontWeight.w300,
                height: 1.75,
                letterSpacing: 0.2,
              ),
            ),
          const SizedBox(height: 32),
          const Align(
            alignment: Alignment.centerRight,
            child: Text(
              '♥',
              style: TextStyle(
                color: Color(0xFFB0A890),
                fontSize: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Painters ─────────────────────────────────────────────────────────────────

class _SobrePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFE8DEC4);
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(3),
    );
    canvas.drawRRect(rrect, paint);

    // Líneas internas (pliegues del sobre)
    final linePaint = Paint()
      ..color = const Color(0xFFCDC3A8)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    // Triángulo inferior (solapa de cierre)
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width / 2, size.height * 0.52)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFFD8CEBC));
    canvas.drawPath(path, linePaint);

    // Líneas laterales
    final left = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height * 0.52);
    final right = Path()
      ..moveTo(size.width, 0)
      ..lineTo(size.width / 2, size.height * 0.52);
    canvas.drawPath(left, linePaint);
    canvas.drawPath(right, linePaint);
  }

  @override
  bool shouldRepaint(_SobrePainter old) => false;
}

class _SolapaPainter extends CustomPainter {
  final bool abierta;
  const _SolapaPainter({required this.abierta});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFDDD3B8);
    final shadow = Paint()
      ..color = const Color(0x22000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();

    canvas.drawPath(path, shadow);
    canvas.drawPath(path, paint);

    final linePaint = Paint()
      ..color = const Color(0xFFCDC3A8)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(_SolapaPainter old) => old.abierta != abierta;
}
