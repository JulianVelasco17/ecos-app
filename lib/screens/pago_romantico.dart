import 'package:flutter/material.dart';
import 'reporte_romantico.dart';

class PantallaPagoRomantico extends StatelessWidget {
  final String miNombre;
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
          miSolar:       miSolar,
          miLunar:       miLunar,
          miAsc:         miAsc,
          amigoNombre:   amigoNombre,
          amigoFotoUrl:  amigoFotoUrl,
          amigoSolar:    amigoSolar,
          amigoLunar:    amigoLunar,
          amigoAsc:      amigoAsc,
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.arrow_back_ios, color: Color(0x66F3EBD6), size: 18),
              ),

              const Spacer(),

              const Text(
                'COMPATIBILIDAD\nROMÁNTICA',
                style: TextStyle(
                  color: Color(0xFFF3EBD6),
                  fontSize: 28,
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
                  fontSize: 14,
                  fontWeight: FontWeight.w300,
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
                child: Center(
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

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
