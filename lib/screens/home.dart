import 'package:flutter/material.dart';
import 'astros_hoy.dart';
import 'amigos.dart';
import 'perfil_propio.dart';
import 'venus.dart';
import 'clima_astral.dart';

class PantallaHome extends StatefulWidget {
  final String nombre;

  const PantallaHome({super.key, required this.nombre});

  @override
  State<PantallaHome> createState() => _PantallaHomeState();
}

class _PantallaHomeState extends State<PantallaHome> {
  // 0 = amigos, 1 = venus, 2 = astros (centro), 3 = clima, 4 = tú
  int _tabActual = 2;
  late final List<Widget> _pantallas;

  @override
  void initState() {
    super.initState();
    _pantallas = [
      const PantallaAmigos(),
      const PantallaVenus(),
      PantallaAstrosHoy(nombre: widget.nombre),
      const PantallaClimaAstral(),
      const PantallaPerfilPropio(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3EBD6),
      body: IndexedStack(
        index: _tabActual,
        children: _pantallas,
      ),
      bottomNavigationBar: _BarraNavegacion(
        tabActual: _tabActual,
        onTap: (i) => setState(() => _tabActual = i),
      ),
    );
  }
}

class _BarraNavegacion extends StatelessWidget {
  final int tabActual;
  final ValueChanged<int> onTap;

  const _BarraNavegacion({required this.tabActual, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF8F3E8),
        border: Border(top: BorderSide(color: Colors.black12)),
      ),
      height: 88,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // Amigos
          _BotonNav(
            icono: Icons.people_outline,
            activo: tabActual == 0,
            onTap: () => onTap(0),
          ),

          // Venus
          _BotonNav(
            icono: Icons.favorite_border,
            activo: tabActual == 1,
            onTap: () => onTap(1),
          ),

          // Astros del día — centro con círculo elevado
          GestureDetector(
            onTap: () => onTap(2),
            child: SizedBox(
              width: 72,
              height: 72,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Círculo de fondo
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black,
                      border: Border.all(color: Colors.black, width: 1),
                      boxShadow: tabActual == 2
                          ? [
                              BoxShadow(
                                color: const Color(0xFFF3EBD6),
                                blurRadius: 0,
                                spreadRadius: 9,
                              ),
                            ]
                          : [],
                    ),
                  ),
                  // Ojo animado
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: tabActual == 2
                        ? Icon(
                            Icons.visibility,
                            key: const ValueKey(true),
                            size: 30,
                            color: const Color(0xFFF3EBD6),
                          )
                        : SizedBox(
                            key: const ValueKey(false),
                            width: 30,
                            height: 30,
                            child: CustomPaint(
                              painter: _OjoCerradoPainter(),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),

          // Clima astral
          _BotonNavCustom(
            activo: tabActual == 3,
            onTap: () => onTap(3),
          ),

          // Tú
          _BotonNav(
            icono: Icons.person_outline,
            activo: tabActual == 4,
            onTap: () => onTap(4),
          ),
        ],
      ),
    );
  }
}

class _BotonNavCustom extends StatelessWidget {
  final bool activo;
  final VoidCallback onTap;

  const _BotonNavCustom({required this.activo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        height: 64,
        child: Center(
          child: CustomPaint(
            size: const Size(22, 22),
            painter: _ConstelacionNavPainter(
              color: activo ? Colors.black : Colors.black26,
            ),
          ),
        ),
      ),
    );
  }
}

class _ConstelacionNavPainter extends CustomPainter {
  final Color color;
  const _ConstelacionNavPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paintLinea = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final paintPunto = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;

    final puntos = [
      Offset(w * 0.15, h * 0.25),
      Offset(w * 0.50, h * 0.05),
      Offset(w * 0.85, h * 0.30),
      Offset(w * 0.65, h * 0.70),
      Offset(w * 0.25, h * 0.90),
    ];

    final conexiones = [
      [0, 1], [1, 2], [2, 3], [3, 4], [4, 0], [1, 3],
    ];

    for (final c in conexiones) {
      canvas.drawLine(puntos[c[0]], puntos[c[1]], paintLinea);
    }

    for (final p in puntos) {
      canvas.drawCircle(p, 2.0, paintPunto);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _OjoCerradoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x99F3EBD6)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final cx = size.width / 2;
    final cy = size.height / 2;

    // Curva hacia abajo (ojo cerrado al revés)
    final path = Path();
    path.moveTo(cx - 10, cy);
    path.cubicTo(cx - 4, cy + 5, cx + 4, cy + 5, cx + 10, cy);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _BotonNav extends StatelessWidget {
  final IconData icono;
  final bool activo;
  final VoidCallback onTap;

  const _BotonNav({
    required this.icono,
    required this.activo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        height: 64,
        child: Center(
          child: Icon(
            icono,
            size: 22,
            color: activo ? Colors.black : Colors.black26,
          ),
        ),
      ),
    );
  }
}
