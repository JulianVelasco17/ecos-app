import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PantallaVenusSuscripcion extends StatefulWidget {
  const PantallaVenusSuscripcion({super.key});

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
    Navigator.pop(context, true); // true = activado
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
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.arrow_back_ios, color: Colors.black45, size: 18),
              ),

              const SizedBox(height: 48),

              const Text(
                'venus',
                style: TextStyle(color: Colors.black, fontSize: 32, fontWeight: FontWeight.w300, letterSpacing: 3),
              ),

              const SizedBox(height: 12),

              const Text(
                'una sección íntima para ti\ny tu pareja',
                style: TextStyle(color: Colors.black45, fontSize: 13, letterSpacing: 1, height: 1.8),
              ),

              const SizedBox(height: 48),

              // Beneficios
              const _Beneficio(
                icono: Icons.favorite_border,
                titulo: 'enlace de pareja',
                descripcion: 'Conecta con una sola persona. Solo una de las dos necesita la suscripción.',
              ),
              const SizedBox(height: 28),
              const _Beneficio(
                icono: Icons.calendar_today_outlined,
                titulo: 'actividades diarias',
                descripcion: 'Cada día del mes, una propuesta distinta: preguntas, cartas, planes, frases.',
              ),
              const SizedBox(height: 28),
              const _Beneficio(
                icono: Icons.auto_awesome_outlined,
                titulo: 'frase de pareja',
                descripcion: 'Los viernes, una lectura generada con las cartas astrales de los dos.',
              ),
              const SizedBox(height: 28),
              const _Beneficio(
                icono: Icons.mail_outline,
                titulo: 'carta acumulada',
                descripcion: 'Los domingos, una carta de amor construida con todo lo que vivieron juntos.',
              ),

              const SizedBox(height: 56),

              // Precio
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black26),
                  borderRadius: BorderRadius.circular(2),
                  color: Colors.black.withValues(alpha: 0.03),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'venus premium',
                      style: TextStyle(color: Colors.black, fontSize: 14, letterSpacing: 2, fontWeight: FontWeight.w300),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '\$3.99 / mes',
                      style: TextStyle(color: Colors.black, fontSize: 28, fontWeight: FontWeight.w200, letterSpacing: 1),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'acceso completo a la sección venus.\ncancela cuando quieras.',
                      style: TextStyle(color: Colors.black45, fontSize: 12, height: 1.7, letterSpacing: 0.5),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Botón principal
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        backgroundColor: const Color(0xFFF3EBD6),
                        title: const Text('próximamente', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w300, letterSpacing: 2)),
                        content: const Text('Los pagos estarán disponibles pronto.', style: TextStyle(color: Colors.black54)),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('ok', style: TextStyle(color: Colors.black45)),
                          ),
                        ],
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: const Color(0xFFF3EBD6),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
                  ),
                  child: const Text('SUSCRIBIRSE', style: TextStyle(letterSpacing: 3, fontSize: 12)),
                ),
              ),

              const SizedBox(height: 40),

              const Divider(color: Colors.black12),

              const SizedBox(height: 24),

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

              const SizedBox(height: 32),
            ],
          ),
        ),
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
        Icon(icono, color: Colors.black45, size: 18),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: const TextStyle(color: Colors.black87, fontSize: 13, letterSpacing: 1, fontWeight: FontWeight.w300)),
              const SizedBox(height: 4),
              Text(descripcion, style: const TextStyle(color: Colors.black45, fontSize: 12, height: 1.6, letterSpacing: 0.3)),
            ],
          ),
        ),
      ],
    );
  }
}
