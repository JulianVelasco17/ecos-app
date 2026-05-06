import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PantallaVenusSuscripcion extends StatefulWidget {
  // Cuando se pasa, la pantalla está embebida en Venus (sin flecha de regresar)
  final VoidCallback? onSuscrito;
  const PantallaVenusSuscripcion({super.key, this.onSuscrito});

  @override
  State<PantallaVenusSuscripcion> createState() => _PantallaVenusSuscripcionState();
}

class _PantallaVenusSuscripcionState extends State<PantallaVenusSuscripcion> {
  bool _activando = false;

  Future<void> _activarDebug() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _activando = true);
    await FirebaseFirestore.instance.collection('usuarios').doc(uid).update({
      'venusActivo': true,
      'venusPagador': uid,
    });
    if (!mounted) return;
    setState(() => _activando = false);
    if (widget.onSuscrito != null) {
      widget.onSuscrito!();
    } else {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stack = Stack(
      fit: StackFit.expand,
        children: [
          // Imagen con zoom 10%
          Transform.scale(
            scale: 1.1,
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.65), BlendMode.darken),
              child: Image.network(
                'https://res.cloudinary.com/dwemowboc/image/upload/v1777590407/07fa4b06a8763df8b8dfac0d4ddb1977_a07dje.jpg',
                fit: BoxFit.cover,
                alignment: Alignment.centerRight,
              ),
            ),
          ),
          // Fade negro desde abajo hasta el 50%
          Positioned.fill(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: 0.65,
                widthFactor: 1.0,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Color(0xFFF3EBD6), Color(0xFFF3EBD6), Colors.transparent],
                      stops: [0.0, 0.6, 1.0],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (widget.onSuscrito == null) ...[
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Icon(Icons.arrow_back_ios, color: Colors.white54, size: 18),
                        ),
                        const SizedBox(width: 8),
                      ],
                      const Text(
                        'venus',
                        style: TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w400, letterSpacing: 2, fontFamily: 'PlayfairDisplay'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  const Padding(
                    padding: EdgeInsets.only(left: 40),
                    child: Text(
                      'hay algo entre ustedes\nvenus solo lo hace más evidente',
                      style: TextStyle(color: Colors.white60, fontSize: 15, letterSpacing: 1, height: 1.7),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Beneficios
                  const _Beneficio(
                    icono: Icons.favorite_border,
                    titulo: 'enlace de pareja',
                    descripcion: 'Conecta con una sola persona. Solo una de las dos necesita la suscripción.',
                  ),
                  const SizedBox(height: 14),
                  const _Beneficio(
                    icono: Icons.auto_awesome_outlined,
                    titulo: 'lectura de pareja',
                    descripcion: 'una lectura breve para entender lo que hay entre ustedes',
                  ),
                  const SizedBox(height: 14),
                  const _Beneficio(
                    icono: Icons.calendar_today_outlined,
                    titulo: 'idea del día',
                    descripcion: 'una idea al día para acercarse sin pensarlo tanto',
                  ),
                  const SizedBox(height: 32),

                  // Precio
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '\$99 MXN / mes',
                        style: TextStyle(color: Colors.black87, fontSize: 30, fontWeight: FontWeight.w200, letterSpacing: 1),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'acceso completo a la sección venus. cancela cuando quieras.',
                        style: TextStyle(color: Colors.black45, fontSize: 14, height: 1.6, letterSpacing: 0.3),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Botón principal
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            backgroundColor: Colors.black87,
                            title: const Text('próximamente', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w300, letterSpacing: 2)),
                            content: const Text('Los pagos estarán disponibles pronto.', style: TextStyle(color: Colors.white54)),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('ok', style: TextStyle(color: Colors.white38)),
                              ),
                            ],
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
                      ),
                      child: const Text('Conectar con Venus', style: TextStyle(letterSpacing: 3, fontSize: 12)),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Botón debug
                  Center(
                    child: _activando
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black26, strokeWidth: 1.5))
                        : GestureDetector(
                            onTap: _activarDebug,
                            child: const Text(
                              'debug: activar venus →',
                              style: TextStyle(color: Colors.black26, fontSize: 11, letterSpacing: 2),
                            ),
                          ),
                  ),

                  const SizedBox(height: 48),

                  // Screenshots
                  const Text(
                    'screenshots',
                    style: TextStyle(color: Colors.black45, fontSize: 12, letterSpacing: 2, fontWeight: FontWeight.w300),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 420,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: 3,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (_, i) => Container(
                        width: 200,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.black12),
                        ),
                        child: const Center(
                          child: Text('placeholder', style: TextStyle(color: Colors.black26, fontSize: 12, letterSpacing: 1.5)),
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
      );
    if (widget.onSuscrito != null) return stack;
    return Scaffold(body: stack);
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
        Icon(icono, color: Colors.white54, size: 24),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: const TextStyle(color: Colors.white, fontSize: 15, letterSpacing: 1, fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(descripcion, style: const TextStyle(color: Colors.white54, fontSize: 14, height: 1.5, letterSpacing: 0.3)),
            ],
          ),
        ),
      ],
    );
  }
}
