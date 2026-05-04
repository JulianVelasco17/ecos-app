import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'perfil_propio.dart';

class PantallaCompraCarta extends StatefulWidget {
  const PantallaCompraCarta({super.key});

  @override
  State<PantallaCompraCarta> createState() => _PantallaCompraCartaState();
}

class _PantallaCompraCartaState extends State<PantallaCompraCarta> {
  bool _activando = false;

  Future<void> _activarDebug() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _activando = true);
    await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(uid)
        .update({'cartaActiva': true});
    if (!mounted) return;
    setState(() => _activando = false);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const PantallaPerfilPropio()),
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
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.arrow_back_ios, color: Colors.black45, size: 18),
              ),

              const SizedBox(height: 48),

              const Text(
                'tu carta\nastral',
                style: TextStyle(
                  fontFamily: 'PlayfairDisplay',
                  color: Color(0xFF222222),
                  fontSize: 42,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 1.0,
                  height: 1.2,
                ),
              ),

              const SizedBox(height: 12),

              const Text(
                'una lectura profunda, una sola vez',
                style: TextStyle(color: Colors.black45, fontSize: 13, letterSpacing: 0.5, height: 1.8),
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

              // Precio
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: const [
                  Text(
                    '\$49',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 40,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'MXN · pago único',
                    style: TextStyle(color: Colors.black45, fontSize: 13, letterSpacing: 0.5),
                  ),
                ],
              ),

              const SizedBox(height: 8),
              const Text(
                'sin suscripción, sin cobros futuros',
                style: TextStyle(color: Colors.black26, fontSize: 11, letterSpacing: 0.5),
              ),

              const SizedBox(height: 32),

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

              const SizedBox(height: 16),

              Center(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Text(
                    'ahora no',
                    style: TextStyle(color: Colors.black26, fontSize: 12, letterSpacing: 1),
                  ),
                ),
              ),
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
        Icon(icono, size: 20, color: Colors.black38),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo,
                  style: const TextStyle(color: Colors.black87, fontSize: 13, letterSpacing: 0.5)),
              const SizedBox(height: 4),
              Text(descripcion,
                  style: const TextStyle(color: Colors.black38, fontSize: 12, height: 1.6)),
            ],
          ),
        ),
      ],
    );
  }
}
