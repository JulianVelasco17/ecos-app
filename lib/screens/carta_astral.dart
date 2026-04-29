import 'package:flutter/material.dart';
import '../services/calculos_astrales.dart';
import 'home.dart';

class PantallaCartaAstral extends StatelessWidget {
  final String nombre;
  final DateTime fechaNacimiento;
  final TimeOfDay horaNacimiento;
  final String lugarNacimiento;

  const PantallaCartaAstral({
    super.key,
    required this.nombre,
    required this.fechaNacimiento,
    required this.horaNacimiento,
    required this.lugarNacimiento,
  });

  @override
  Widget build(BuildContext context) {
    // Calculamos la carta astral con los datos reales del usuario
    // Por ahora usamos latitud/longitud 0 — cuando integremos geocodificación
    // del lugar de nacimiento, esto será preciso también para el ascendente
    final carta = CalculosAstrales.calcular(
      fechaNacimiento: fechaNacimiento,
      hora: horaNacimiento.hour,
      minutos: horaNacimiento.minute,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF3EBD6),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Saludo
              Text(
                'hola, $nombre.',
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 28,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'esta es tu carta astral',
                style: TextStyle(
                  color: Colors.black45,
                  fontSize: 13,
                  letterSpacing: 2,
                ),
              ),

              const SizedBox(height: 48),

              _seccionSigno(
                planeta: 'SOL',
                signo: carta.signoSolar,
                descripcion: descripcionesSignos[carta.signoSolar]?['sol'] ?? '',
              ),

              const SizedBox(height: 32),

              _seccionSigno(
                planeta: 'LUNA',
                signo: carta.signoLunar,
                descripcion: descripcionesSignos[carta.signoLunar]?['luna'] ?? '',
              ),

              const SizedBox(height: 32),

              _seccionSigno(
                planeta: 'ASCENDENTE',
                signo: carta.ascendente,
                descripcion: descripcionesSignos[carta.ascendente]?['ascendente'] ?? '',
              ),

              const SizedBox(height: 64),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PantallaHome(nombre: nombre),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: const Color(0xFFF3EBD6),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    'TUS ASTROS DE HOY',
                    style: TextStyle(letterSpacing: 3),
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

  Widget _seccionSigno({
    required String planeta,
    required String signo,
    required String descripcion,
  }) {
    final simbolo = simbolosSignos[signo] ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          planeta,
          style: const TextStyle(
            color: Colors.black45,
            fontSize: 11,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$simbolo $signo',
          style: const TextStyle(
            color: Colors.black,
            fontSize: 22,
            fontWeight: FontWeight.w300,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          descripcion,
          style: const TextStyle(
            color: Colors.black54,
            fontSize: 14,
            height: 1.7,
          ),
        ),
      ],
    );
  }
}
