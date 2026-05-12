import 'package:flutter/material.dart';
import 'reporte_romantico.dart';

class PantallaPagoRomantico extends StatelessWidget {
  final String miNombre;
  final String? miFotoUrl;
  final String miSolar;
  final String miLunar;
  final String miAsc;
  final Map<String, String> miPlanetas;
  final String amigoNombre;
  final String? amigoFotoUrl;
  final String amigoSolar;
  final String amigoLunar;
  final String amigoAsc;
  final Map<String, String> amigoPlanetas;
  final String arquetipo;
  final String miUid;
  final String amigoUid;

  const PantallaPagoRomantico({
    super.key,
    required this.miNombre,
    this.miFotoUrl,
    required this.miSolar,
    required this.miLunar,
    required this.miAsc,
    required this.miPlanetas,
    required this.amigoNombre,
    this.amigoFotoUrl,
    required this.amigoSolar,
    required this.amigoLunar,
    required this.amigoAsc,
    required this.amigoPlanetas,
    required this.arquetipo,
    required this.miUid,
    required this.amigoUid,
  });

  void _simularPago(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => PantallaReporteRomantico(
          miNombre:      miNombre,
          miFotoUrl:     miFotoUrl,
          miSolar:       miSolar,
          miLunar:       miLunar,
          miAsc:         miAsc,
          miPlanetas:    miPlanetas,
          amigoNombre:   amigoNombre,
          amigoFotoUrl:  amigoFotoUrl,
          amigoSolar:    amigoSolar,
          amigoLunar:    amigoLunar,
          amigoAsc:      amigoAsc,
          amigoPlanetas: amigoPlanetas,
          arquetipo:     arquetipo,
          miUid:         miUid,
          amigoUid:      amigoUid,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primerNombre = amigoNombre.split(' ').first;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── GIF fondo completo con capa oscura 65% ───────────────────────
          Positioned.fill(
            child: Stack(
              fit: StackFit.expand,
              children: [
                RotatedBox(
                  quarterTurns: 1,
                  child: Image.network(
                    'https://firebasestorage.googleapis.com/v0/b/astro-fd0bf.firebasestorage.app/o/Assets%2Ffondo2.gif?alt=media&token=ef484e31-3c7d-4873-93bf-707188cd687c',
                    fit: BoxFit.cover,
                  ),
                ),
                const ColoredBox(color: Color(0xA6000000)),
                // Degradado: transparente arriba → negro justo antes del $29
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.0, 0.55, 0.75],
                      colors: [Colors.transparent, Colors.transparent, Colors.black],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Contenido ────────────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Icon(Icons.arrow_back_ios, color: Color(0x66F3EBD6), size: 18),
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                'COMPATIBILIDAD\nROMÁNTICA',
                style: TextStyle(
                  color: Color(0xFFF3EBD6),
                  fontSize: 36,
                  fontWeight: FontWeight.w300,
                  height: 1.3,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Descubre qué tan profundo puede ser el vínculo entre tú y $primerNombre — '
                'atracción, comunicación, desafíos y lo que podrían construir juntos.',
                style: TextStyle(
                  color: const Color(0xFFF3EBD6).withValues(alpha: 0.5),
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  height: 1.8,
                ),
              ),

              const Spacer(),

              const Text(
                '\$29',
                style: TextStyle(
                  color: Color(0xFFF3EBD6),
                  fontSize: 42,
                  fontWeight: FontWeight.w200,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'pago único · reporte completo',
                style: TextStyle(
                  color: const Color(0xFFF3EBD6).withValues(alpha: 0.35),
                  fontSize: 12,
                  letterSpacing: 2,
                ),
              ),

              const SizedBox(height: 32),

              GestureDetector(
                onTap: () => _simularPago(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3EBD6),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: const Center(
                    child: Text(
                      'Obtener mi reporte',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 14,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              GestureDetector(
                onTap: () => _simularPago(context),
                behavior: HitTestBehavior.opaque,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'debug: simular cobro',
                      style: TextStyle(
                        color: const Color(0xFFF3EBD6).withValues(alpha: 0.2),
                        fontSize: 11,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
        ],
      ),
    );
  }
}
