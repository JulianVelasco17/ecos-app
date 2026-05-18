import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/claude_service.dart';
import 'compra_carta_astral.dart';

class _Constelacion {
  final List<Offset> estrellas;
  final List<(int, int)> lineas;
  final Set<int> brillantes;
  const _Constelacion(this.estrellas, this.lineas, [this.brillantes = const <int>{}]);
}

// Coordenadas trazadas manualmente sobre diagramas reales de cada constelación
const _constelaciones = {

  // Aries: gancho de 4 estrellas, curva suave
  'Aries': _Constelacion([
    Offset(0.08, 0.75), // γ Mesarthim
    Offset(0.36, 0.50), // β Sheratan
    Offset(0.58, 0.38), // α Hamal (más brillante)
    Offset(0.74, 0.30),
    Offset(0.88, 0.52),
  ], [(0,1),(1,2),(2,3),(3,4)]),

  // Tauro: dos cuernos arriba-izq desde el cluster Híades, Aldebarán a la derecha con rama
  'Tauro': _Constelacion([
    Offset(0.26, 0.00), // 0 — β Tau Elnath (cuerno superior grande)
    Offset(0.05, 0.04), // 1 — ε Tau (cuerno izquierdo)
    Offset(0.40, 0.29), // 2 — ζ Tau (estrella media superior)
    Offset(0.24, 0.55), // 3 — γ Tau (cluster Híades 1)
    Offset(0.40, 0.46), // 4 — δ Tau (cluster pequeño)
    Offset(0.45, 0.38), // 5 — θ1 Tau (cluster pequeño)
    Offset(0.38, 0.38), // 6 — cluster inferior
    Offset(0.40, 0.30), // 7 — α Tau Aldebarán (más brillante)
    Offset(0.79, 0.50), // 8 — rama derecha
    Offset(0.92, 0.77), // 9 — punta rama
  ], [(0,2),(1,3),(3,4),(4,5),(5,6),(6,7),(8,4),(8,9)], {9}),

  // Géminis: Cástor arriba-izq → estrella media → Pólux, rama sup-der desde Pólux,
  // dos cadenas paralelas con dos cruces horizontales, tres pies en la base
  'Géminis': _Constelacion([
    Offset(0.35, 0.07), // 0  α Cástor (cabeza izq, la más alta)
    Offset(0.36, 0.18), // 1  estrella intermedia superior
    Offset(0.56, 0.20), // 2  β Pólux (cabeza der)
    Offset(0.75, 0.16), // 3  rama sup-der 1
    Offset(0.94, 0.08), // 4  rama sup-der 2 (punta)
    Offset(0.16, 0.62), // 5  cadena izq alta
    Offset(0.32, 0.56), // 6  cadena der alta
    Offset(0.16, 0.62), // 7  cadena izq baja
    Offset(0.42, 0.63), // 8  cadena der baja
    Offset(0.08, 0.80), // 9  pie izq externo
    Offset(0.24, 1.00), // 10 pie izq interno
    Offset(0.50, 1.00), // 11 pie derecho
    Offset(0.12, 0.30), // 12 pie derecho
    Offset(0.74, 0.08), // 13 pie derecho
    Offset(0.72, 0.03), // 14 pie derecho
    Offset(0.70, 0.50), // 15 pie derecho
    Offset(0.68, 0.95), // 16 pie derecho
    Offset(0.80, 0.82), // 17 pie derecho
    Offset(0.85, 0.91), // 18 pie derecho
    Offset(0.92, 0.98), // 19 pie derecho
  ], [
    (0,1),(1,2),(2,3),(3,4),(1,6),(1,12),(3,13),(13,14),(3,15),(16,15),(17,15),(17,18),(18,19),  // cadena superior: Cástor→media→Pólux→rama
    (5,7),(7,10),  // cadena izquierda + dos pies
    (6,8),(8,11),        // cadena derecha + pie
    (5,6),(7,8),               // cruces horizontales
  ]),

  // Cáncer: diagonal arriba-izq → centro, rama derecha y rama abajo
  'Cáncer': _Constelacion([
    Offset(0.74, 0.40), // 0 — estrella superior izquierda
    Offset(0.52, 0.45), // 1 — estrella intermedia
    Offset(0.34, 0.45), // 2 — centro (más brillante)
    Offset(0.18, 0.38), // 3 — estrella derecha
    Offset(0.06, 0.70), // 4 — estrella inferior
  ], [(0,1),(1,2),(2,3),(2,4)]),

  // Leo: hoz (interrogación invertida) + Denébola en la cola
  'Leo': _Constelacion([
    Offset(0.26, 0.72), // α Leo Régulo (base hoz)
    Offset(0.20, 0.56), // η Leo
    Offset(0.18, 0.40), // γ Leo Algieba
    Offset(0.24, 0.24), // ζ Leo
    Offset(0.42, 0.18), // μ Leo
    Offset(0.56, 0.28), // ε Leo
    Offset(0.50, 0.46), // δ Leo
    Offset(0.74, 0.62), // β Leo Denébola
  ], [(0,1),(1,2),(2,3),(3,4),(4,5),(5,6),(6,1),(6,7)]),

  // Virgo: figura alargada, Spica abajo, brazos extendidos
  'Virgo': _Constelacion([
    Offset(0.50, 0.84), // α Vir Spica
    Offset(0.48, 0.66),
    Offset(0.34, 0.52), // rama izq
    Offset(0.22, 0.38),
    Offset(0.48, 0.44),
    Offset(0.62, 0.36), // rama der
    Offset(0.76, 0.22),
    Offset(0.50, 0.26),
  ], [(0,1),(1,2),(2,3),(1,4),(4,5),(5,6),(4,7),(7,5)]),

  // Libra: triángulo de balanza con base
  'Libra': _Constelacion([
    Offset(0.52, 0.00), // β Lib (arriba)
    Offset(0.14, 0.26), // α Lib (platillo izq)
    Offset(0.88, 0.47), // γ Lib (platillo der)
    Offset(0.14, 0.50),
    Offset(1.00, 0.88),
    Offset(0.88, 0.80),
    Offset(0.12, 0.64),
    Offset(0.04, 0.70),
  ], [(0,1),(0,2),(1,3),(4,5),(2,5),(1,2),(3,6),(6,7)]),

  // Escorpio: β/γ arriba-der → Antares → cola curva abajo-izq → gancho
  'Escorpio': _Constelacion([
    Offset(0.82, 0.06), // 0  β Sco Beta (tope)
    Offset(0.76, 0.14), // 1  γ Sco Gamma
    Offset(0.88, 0.20), // 2  rama derecha de Gamma
    Offset(0.64, 0.26), // 3  bajando hacia Antares
    Offset(0.56, 0.36), // 4  α Sco Antares (más brillante)
    Offset(0.68, 0.34), // 5  pequeña rama der de Antares
    Offset(0.76, 0.40), // 6  extremo rama
    Offset(0.46, 0.44), // 7  cola inicia
    Offset(0.38, 0.52), // 8
    Offset(0.30, 0.60), // 9
    Offset(0.22, 0.68), // 10 codo brillante
    Offset(0.14, 0.76), // 11
    Offset(0.08, 0.82), // 12 fondo curva
    Offset(0.04, 0.72), // 13 gancho
    Offset(0.10, 0.64), // 14 aguijón
  ], [
    (0,1),(1,2),                               // cluster superior
    (1,3),(3,4),                               // hacia Antares
    (4,5),(5,6),                               // rama derecha Antares
    (4,7),(7,8),(8,9),(9,10),(10,11),(11,12),  // cola
    (12,13),(13,14),                           // gancho/aguijón
  ]),

  // Sagitario: tetera — muy reconocible
  'Sagitario': _Constelacion([
    Offset(0.22, 0.64), // pico (δ Sgr)
    Offset(0.32, 0.50),
    Offset(0.42, 0.40), // tapa izq (λ Sgr)
    Offset(0.56, 0.30), // cima (φ Sgr)
    Offset(0.66, 0.38),
    Offset(0.72, 0.52),
    Offset(0.68, 0.66), // asa arriba
    Offset(0.58, 0.72), // asa abajo
    Offset(0.40, 0.64), // base der (σ Sgr)
    Offset(0.28, 0.66), // base izq (ε Sgr)
  ], [(0,1),(1,2),(2,3),(3,4),(4,5),(5,6),(6,7),(7,8),(8,9),(9,1),(8,2)]),

  // Capricornio: triángulo con pico arriba-derecha, dos cadenas paralelas
  'Capricornio': _Constelacion([
    Offset(0.82, 0.06), // 0 — pico superior derecho (α Cap)
    Offset(0.06, 0.46), // 1 — estrella izquierda grande
    Offset(0.20, 0.48), // 2 — junto a la izquierda
    Offset(0.38, 0.34), // 3 — cadena superior izq
    Offset(0.54, 0.30), // 4 — cadena superior der
    Offset(0.22, 0.64), // 5 — cadena inferior izq
    Offset(0.40, 0.70), // 6 — cadena inferior mid
    Offset(0.58, 0.65), // 7 — cadena inferior der
    Offset(0.68, 0.52), // 8 — flanco derecho
  ], [(0,4),(4,3),(3,1),(1,2),(2,5),(5,6),(6,7),(7,8),(8,0)]),

  // Acuario: cadena top-der → junction → rama der + cadena abajo → cuadrilátero
  'Acuario': _Constelacion([
    Offset(0.48, 0.00), // 0 — tope
    Offset(0.32, 0.18), // 1
    Offset(0.18, 0.38), // 2 — junction (más brillante)
    Offset(0.37, 0.42), // 3 — rama derecha 1
    Offset(0.56, 0.40), // 4 — rama derecha 2
    Offset(0.18, 0.50), // 5 — bajando izq
    Offset(0.10, 0.50), // 6
    Offset(0.12, 0.65), // 7
    Offset(0.24, 0.80), // 8
    Offset(0.36, 0.75), // 9 — estrella brillante inferior (grande)
    Offset(0.61, 0.72), // 10 — rama arriba-der 1
    Offset(0.74, 0.80), // 11 — rama arriba-der 2
    Offset(0.54, 0.88), // 12 — rama abajo-der
  ], [
    (0,1),(1,2),                   // cadena superior
    (2,3),(3,4),                   // rama derecha
    (2,5),(5,6),(6,7),(7,8),(8,9), // cadena inferior
    (9,10),(10,11),(9,12),         // fork inferior
  ]),

  // Piscis: vértice abajo-izq, rama izq con cluster, rama der al cordón y pentágono
  'Piscis': _Constelacion([
    Offset(0.10, 0.76), // 0 — vértice V (estrella brillante inferior)
    Offset(0.06, 0.56), // 1 — rama izquierda sube
    Offset(0.14, 0.38), // 2 — cluster: estrella principal
    Offset(0.04, 0.32), // 3 — cluster: rama izq del fork
    Offset(0.20, 0.22), // 4 — tope rama izquierda
    Offset(0.22, 0.60), // 5 — rama derecha hacia cordón
    Offset(0.36, 0.52), // 6 — cordón
    Offset(0.50, 0.46), // 7 — cordón medio
    Offset(0.64, 0.40), // 8 — cordón
    Offset(0.74, 0.34), // 9 — entrada pentágono
    Offset(0.84, 0.26), // 10 — pentágono arriba
    Offset(0.90, 0.36), // 11 — pentágono derecha
    Offset(0.86, 0.48), // 12 — pentágono abajo-derecha
    Offset(0.74, 0.46), // 13 — pentágono abajo-izquierda
  ], [
    (0,1),(1,2),(2,3),(2,4),(3,4),     // rama izquierda con triángulo
    (0,5),(5,6),(6,7),(7,8),(8,9),     // rama derecha + cordón
    (9,10),(10,11),(11,12),(12,13),(13,9), // pentágono
  ]),
};

// ─── Painter ─────────────────────────────────────────────────────────────────

class ConstelacionPainter extends CustomPainter {
  final String signo;
  final double progreso;
  final bool debugGrid;
  ConstelacionPainter({required this.signo, required this.progreso, this.debugGrid = false});

  // Estrella tipo brújula: 4 puntas largas + 4 cortas diagonales + centro
  void _dibujarCompass(Canvas canvas, Offset c, double radio, Paint paint) {
    final strokePaint = Paint()
      ..color = paint.color
      ..strokeWidth = 1.1
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // 4 puntas largas (N/S/E/W)
    for (int i = 0; i < 4; i++) {
      final a = i * pi / 2 - pi / 4;
      canvas.drawLine(
        c + Offset(cos(a) * 2.5, sin(a) * 2.5),
        c + Offset(cos(a) * radio, sin(a) * radio),
        strokePaint,
      );
    }
    // 4 puntas cortas diagonales
    for (int i = 0; i < 4; i++) {
      final a = i * pi / 2 + pi / 4;
      canvas.drawLine(
        c + Offset(cos(a) * 2.0, sin(a) * 2.0),
        c + Offset(cos(a) * radio * 0.48, sin(a) * radio * 0.48),
        strokePaint..strokeWidth = 0.8,
      );
    }
    // Centro relleno
    canvas.drawCircle(c, 2.2, Paint()..color = paint.color);
  }

  // Estrella de 8 puntas para estrellas prominentes
  void _dibujar8Puntas(Canvas canvas, Offset c, double radio, Paint paint) {
    final path = Path();
    for (int i = 0; i < 8; i++) {
      final angPunta = (i * 45 - 90) * pi / 180;
      final angInter = (i * 45 - 90 + 22.5) * pi / 180;
      final px = c.dx + radio * cos(angPunta);
      final py = c.dy + radio * sin(angPunta);
      final ix = c.dx + radio * 0.38 * cos(angInter);
      final iy = c.dy + radio * 0.38 * sin(angInter);
      if (i == 0) { path.moveTo(px, py); } else { path.lineTo(px, py); }
      path.lineTo(ix, iy);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  // Anillo de puntos para la estrella principal
  void _dibujarAnillo(Canvas canvas, Offset c, double radio, Paint paint) {
    final numPuntos = 12;
    for (int i = 0; i < numPuntos; i++) {
      final a = i * 2 * pi / numPuntos;
      final p = c + Offset(cos(a) * radio, sin(a) * radio);
      canvas.drawCircle(p, 1.2, Paint()..color = paint.color);
    }
  }

  // 0 = pequeña brújula, 1 = brújula media, 2 = brújula grande (principal)
  int _tipo(int index) {
    final seed = signo.codeUnits.fold(0, (a, b) => a + b) + index * 13;
    return seed % 3;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final data = _constelaciones[signo];
    if (data == null) return;

    final estrellas = data.estrellas
        .map((e) => Offset(e.dx * size.width, e.dy * size.height))
        .toList();

    // Fase 1 (0–0.35): estrellas aparecen una a una
    final faseEstrellas = (progreso / 0.35).clamp(0.0, 1.0);

    // Fase 2 (0.35–1.0): líneas con puntitos
    final faseLineas = progreso <= 0.35
        ? 0.0
        : ((progreso - 0.35) / 0.65).clamp(0.0, 1.0);

    // ── Líneas con puntitos ───────────────────────────────────────────────────
    final totalLineas = data.lineas.length;
    for (int i = 0; i < totalLineas; i++) {
      final t0 = i / totalLineas;
      final t1 = (i + 1) / totalLineas;
      if (faseLineas < t0) break;
      final (a, b) = data.lineas[i];
      final p1 = estrellas[a];
      final p2 = estrellas[b];
      final tLinea = faseLineas >= t1 ? 1.0 : (faseLineas - t0) / (t1 - t0);
      final pFin = Offset.lerp(p1, p2, tLinea)!;

      // Halo difuso debajo de la línea (efecto brillo)
      canvas.drawLine(p1, pFin,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.18)
            ..strokeWidth = 10.0
            ..style = PaintingStyle.stroke
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
      // Halo medio
      canvas.drawLine(p1, pFin,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.30)
            ..strokeWidth = 4.0
            ..style = PaintingStyle.stroke
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
      // Línea principal nítida
      canvas.drawLine(p1, pFin,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.90)
            ..strokeWidth = 1.5
            ..style = PaintingStyle.stroke);
    }

    // ── Estrellas tipo brújula ────────────────────────────────────────────────
    for (int i = 0; i < estrellas.length; i++) {
      final t = (faseEstrellas - i / estrellas.length).clamp(0.0, 1.0);
      if (t <= 0) continue;

      final esBrillante = data.brillantes.contains(i);
      final tipo  = esBrillante ? 2 : _tipo(i);
      final radio = (tipo == 2 ? 10.0 : tipo == 1 ? 7.5 : 5.5) * t;
      final paint = Paint()..color = Colors.white.withValues(alpha: t);

      if (esBrillante) {
        // Halo exterior muy difuso
        canvas.drawCircle(estrellas[i], radio * 4.0,
            Paint()
              ..color = Colors.white.withValues(alpha: t * 0.10)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18));
        // Halo medio
        canvas.drawCircle(estrellas[i], radio * 2.5,
            Paint()
              ..color = Colors.white.withValues(alpha: t * 0.30)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
      }

      // Halo suave estándar
      canvas.drawCircle(estrellas[i], radio * 1.8,
          Paint()
            ..color = Colors.white.withValues(alpha: t * (esBrillante ? 0.40 : 0.18))
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));

      _dibujarCompass(canvas, estrellas[i], radio, paint);

      // Estrella de 8 puntas en prominentes (tipo 1 y 2)
      if (tipo >= 1) {
        final r8 = (tipo == 2 ? radio * 2.2 : radio * 1.6);
        canvas.drawCircle(estrellas[i], r8 * 0.8,
            Paint()
              ..color = Colors.white.withValues(alpha: t * (esBrillante ? 0.35 : 0.15))
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
        _dibujar8Puntas(canvas, estrellas[i], r8,
            Paint()..color = Colors.white.withValues(alpha: t * 0.9));
      }

      // Anillo de puntos en tipo 2 y brillantes
      if (tipo == 2) {
        _dibujarAnillo(canvas, estrellas[i], radio * (esBrillante ? 3.5 : 2.8),
            Paint()..color = Colors.white.withValues(alpha: t * (esBrillante ? 0.6 : 0.4)));
      }
    }

    if (debugGrid) _dibujarDebugGrid(canvas, size);
  }

  void _dibujarDebugGrid(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.45)
      ..strokeWidth = 0.8;

    // Líneas cada 0.1 (10 divisiones)
    for (int i = 0; i <= 10; i++) {
      final x = size.width * i / 10;
      final y = size.height * i / 10;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Labels de coordenadas en los cruces
    for (int xi = 0; xi <= 10; xi += 2) {
      for (int yi = 0; yi <= 10; yi += 2) {
        final x = size.width * xi / 10;
        final y = size.height * yi / 10;
        final label = '${(xi / 10).toStringAsFixed(1)},${(yi / 10).toStringAsFixed(1)}';
        final tp = TextPainter(
          text: TextSpan(text: label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
          textDirection: TextDirection.ltr,
        )..layout();
        // Fondo negro para legibilidad
        canvas.drawRect(
          Rect.fromLTWH(x + 2, y + 2, tp.width + 2, tp.height + 1),
          Paint()..color = Colors.black.withValues(alpha: 0.6),
        );
        tp.paint(canvas, Offset(x + 3, y + 2));
      }
    }

    // Índice de cada estrella
    final data = _constelaciones[signo];
    if (data == null) return;
    for (int i = 0; i < data.estrellas.length; i++) {
      final pos = Offset(data.estrellas[i].dx * size.width, data.estrellas[i].dy * size.height);
      // Círculo con fondo sólido
      canvas.drawCircle(pos, 13, Paint()..color = Colors.black.withValues(alpha: 0.75));
      canvas.drawCircle(pos, 13, Paint()..color = Colors.yellowAccent..style = PaintingStyle.stroke..strokeWidth = 1.5);
      // Número
      final tp = TextPainter(
        text: TextSpan(text: '$i', style: const TextStyle(color: Colors.yellowAccent, fontSize: 11, fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
      // Coordenadas debajo con fondo
      final coords = '(${data.estrellas[i].dx.toStringAsFixed(2)}, ${data.estrellas[i].dy.toStringAsFixed(2)})';
      final tp2 = TextPainter(
        text: TextSpan(text: coords, style: const TextStyle(color: Colors.yellowAccent, fontSize: 9, fontWeight: FontWeight.w600)),
        textDirection: TextDirection.ltr,
      )..layout();
      final coordOffset = Offset(pos.dx - tp2.width / 2, pos.dy + 15);
      canvas.drawRect(
        Rect.fromLTWH(coordOffset.dx - 2, coordOffset.dy - 1, tp2.width + 4, tp2.height + 2),
        Paint()..color = Colors.black.withValues(alpha: 0.7),
      );
      tp2.paint(canvas, coordOffset);
    }
  }

  @override
  bool shouldRepaint(ConstelacionPainter old) =>
      old.progreso != progreso || old.signo != signo || old.debugGrid != debugGrid;
}

// ─── Pantalla completa de constelación ───────────────────────────────────────

class PantallaConstelacion extends StatefulWidget {
  final String signo;
  final String nombre;
  final String signoSolar;
  final String signoLunar;
  final String ascendente;
  final Map<String, String> planetas;
  final Map<String, int> casas;
  final DateTime fechaNacimiento;
  final int hora;
  final int minutos;
  final void Function(BuildContext) onContinuar;

  const PantallaConstelacion({
    super.key,
    required this.signo,
    required this.nombre,
    required this.signoSolar,
    required this.signoLunar,
    required this.ascendente,
    required this.planetas,
    this.casas = const {},
    required this.fechaNacimiento,
    required this.hora,
    required this.minutos,
    required this.onContinuar,
  });

  @override
  State<PantallaConstelacion> createState() => _PantallaConstelacionState();
}

class _PantallaConstelacionState extends State<PantallaConstelacion>
    with TickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late AnimationController _arrowCtrl;
  late Animation<double> _fade;
  late Animation<double> _arrowAnim;
  final _pageCtrl = PageController();
  bool _zoomingOut = false;
  VideoPlayerController? _videoReveal;

  String? _descSol;
  String? _descLuna;
  String? _descAsc;
  bool _lecturaLista = false;

  static const _fallbackSol = {
    'Aries':       'eres alguien que actúa antes de pensar, que necesita ser el primero en todo lo que importa.',
    'Tauro':       'construyes despacio pero con una solidez que pocos pueden igualar.',
    'Géminis':     'tu mente nunca para: conectas ideas, personas y mundos que otros no ven relacionados.',
    'Cáncer':      'sientes todo con una profundidad que a veces te pesa, pero que también es tu mayor fuerza.',
    'Leo':         'necesitas brillar y que lo que haces importe — no por vanidad, sino porque te juegas el alma en ello.',
    'Virgo':       'ves los detalles que todos ignoran y sientes una responsabilidad constante de mejorar lo que te rodea.',
    'Libra':       'buscas el equilibrio en todo, especialmente en las relaciones, aunque eso a veces signifique posponer tus propias decisiones.',
    'Escorpio':    'vas directo al fondo de las cosas y de las personas — la superficie nunca te ha bastado.',
    'Sagitario':   'necesitas espacio, libertad y un horizonte que valga la pena perseguir.',
    'Capricornio': 'te defines por lo que construyes: tu ambición no es arrogancia, es vocación.',
    'Acuario':     'piensas distinto, sientes distinto y necesitas que tu vida tenga un propósito más grande que tú.',
    'Piscis':      'absorbes el mundo emocional de los demás como una esponja y lo transformas en algo hermoso.',
  };
  static const _fallbackLuna = {
    'Aries':       'procesas las emociones en movimiento — necesitas acción para calmarte, no reflexión.',
    'Tauro':       'encuentras seguridad en la rutina y en lo físico: el cuerpo es tu ancla emocional.',
    'Géminis':     'hablar es tu forma de sentir — poner las emociones en palabras es lo que las hace reales.',
    'Cáncer':      'tus emociones son intensas y tienen memoria larga; los lazos familiares te definen más de lo que crees.',
    'Leo':         'necesitas sentirte visto y apreciado para estar bien — el reconocimiento no es un lujo, es una necesidad real.',
    'Virgo':       'te cuidas preocupándote — el análisis es tu manera de gestionar la ansiedad emocional.',
    'Libra':       'los conflictos te desequilibran profundamente; la armonía no es superficialidad, es supervivencia.',
    'Escorpio':    'sientes con una intensidad que pocas personas comprenden y que tú mismo a veces evitas.',
    'Sagitario':   'necesitas que las emociones tengan sentido filosófico; sin significado, la tristeza se vuelve insoportable.',
    'Capricornio': 'controlas más de lo que expresas — el mundo emocional interno es mucho más rico de lo que muestras.',
    'Acuario':     'observas tus emociones desde fuera antes de vivirlas, lo que te da claridad pero a veces te desconecta.',
    'Piscis':      'sientes todo lo que hay en el ambiente y necesitas momentos de soledad para saber qué es tuyo y qué es de otros.',
  };
  static const _fallbackAsc = {
    'Aries':       'proyectas energía, directness y confianza — la gente te percibe como alguien que sabe lo que quiere.',
    'Tauro':       'transmites calma y presencia física — los demás te ven como alguien en quien se puede confiar.',
    'Géminis':     'eres el primero en hablar, en preguntar, en conectar — tu primera impresión es de curiosidad viva.',
    'Cáncer':      'irradias calidez y cuidado desde el primer momento — la gente se siente segura a tu lado.',
    'Leo':         'entras a cualquier espacio con una presencia que se nota — tienes el don de hacer que la gente se sienta especial.',
    'Virgo':       'das una impresión de competencia y atención al detalle — eres la persona que parece tener todo bajo control.',
    'Libra':       'la gente te percibe como encantador y equilibrado — tu diplomacia natural te abre puertas.',
    'Escorpio':    'proyectas intensidad e intriga — la gente intuye que hay mucho más detrás de lo que muestras.',
    'Sagitario':   'transmites optimismo y apertura — los demás te ven como alguien con quien se puede ir a cualquier parte.',
    'Capricornio': 'das una impresión de seriedad y fiabilidad — la gente confía en ti antes de conocerte bien.',
    'Acuario':     'proyectas originalidad y una ligera distancia — la gente te percibe como alguien diferente, difícil de encasillar.',
    'Piscis':      'irradias suavidad y empatía — los demás sienten que pueden contarte cualquier cosa.',
  };

  // ── Debug ────────────────────────────────────────────────────────────────
  static const _todosSignos = [
    'Aries','Tauro','Géminis','Cáncer','Leo','Virgo',
    'Libra','Escorpio','Sagitario','Capricornio','Acuario','Piscis',
  ];
  String? _debugSolar;
  String? _debugLunar;
  String? _debugAsc;
  bool _debugGrid = false;

  String get _signoSolarActivo  => _debugSolar ?? widget.signoSolar;
  String get _signoLunarActivo  => _debugLunar ?? widget.signoLunar;
  String get _ascendenteActivo  => _debugAsc   ?? widget.ascendente;
  // ─────────────────────────────────────────────────────────────────────────

  static const _beige = Color(0xFFF3EBD6);

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
    _fadeCtrl.forward();

    _arrowCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 800))..repeat(reverse: true);
    _arrowAnim = Tween(begin: 0.0, end: 8.0).animate(
        CurvedAnimation(parent: _arrowCtrl, curve: Curves.easeInOut));

    _generarLectura();
    _precargarImagenes();
    _precargarVideo();
  }

  void _precargarVideo() {
    const url = 'https://firebasestorage.googleapis.com/v0/b/astro-fd0bf.firebasestorage.app/o/Assets%2Fonboard.mp4?alt=media&token=4dc6d672-2bb1-43b5-933b-47fda187ac9c';
    _videoReveal = VideoPlayerController.networkUrl(Uri.parse(url))
      ..setLooping(true)
      ..setVolume(0)
      ..initialize();
  }

  void _precargarImagenes() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final signo in [_signoSolarActivo, _signoLunarActivo, _ascendenteActivo]) {
        final url = _imagenesDescripcion[signo];
        if (url != null) precacheImage(NetworkImage(url), context);
        final urlSigno = _imagenesSigno[signo];
        if (urlSigno != null) precacheImage(NetworkImage(urlSigno), context);
      }
    });
  }

  Future<String?> _descPosicionCacheada(String planeta, String signo, int? casa) async {
    final key = '${planeta}_${signo}_c${casa ?? 0}';
    final doc = await FirebaseFirestore.instance.collection('descSignos').doc(key).get();
    if (doc.exists) return doc.data()!['texto'] as String?;
    final texto = await ClaudeService.generarDescripcionPosicion(
      planeta: planeta,
      signo: signo,
      casa: casa,
    );
    await FirebaseFirestore.instance.collection('descSignos').doc(key).set({'texto': texto});
    return texto;
  }

  Future<void> _generarLectura() async {
    try {
      final results = await Future.wait([
        _descPosicionCacheada('Sol',        widget.signoSolar,  widget.casas['Sol']),
        _descPosicionCacheada('Luna',       widget.signoLunar,  widget.casas['Luna']),
        _descPosicionCacheada('Ascendente', widget.ascendente,  widget.casas['Ascendente']),
      ]);

      if (mounted) {
        setState(() {
          _descSol  = results[0]?.trim().isNotEmpty == true ? results[0] : null;
          _descLuna = results[1]?.trim().isNotEmpty == true ? results[1] : null;
          _descAsc  = results[2]?.trim().isNotEmpty == true ? results[2] : null;
        });
      }
    } catch (_) {}
    if (mounted) {
      setState(() {
        _descSol  ??= _fallbackSol[widget.signoSolar]  ?? '';
        _descLuna ??= _fallbackLuna[widget.signoLunar] ?? '';
        _descAsc  ??= _fallbackAsc[widget.ascendente]  ?? '';
        _lecturaLista = true;
      });
    }
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _arrowCtrl.dispose();
    _pageCtrl.dispose();
    _videoReveal?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // página 0 = carrusel horizontal (solar→lunar→ascendente)
    // páginas 1-3 = descripción Sol/Luna/Asc
    // página 4 = descubre relaciones
    // página 5 = descubre resto de astros
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedScale(
        scale: _zoomingOut ? 0.85 : 1.0,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeIn,
        child: AnimatedOpacity(
          opacity: _zoomingOut ? 0.0 : 1.0,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeIn,
          child: FadeTransition(
            opacity: _fade,
            child: PageView.builder(
          controller: _pageCtrl,
          scrollDirection: Axis.vertical,
          itemCount: 6,
          itemBuilder: (_, i) {
            if (i == 0) return _paginaSignos();
            if (i == 1) { return _paginaDescripcionSigno(
              titulo: 'TU SIGNO SOLAR',
              signo: _signoSolarActivo,
              descripcion: _descSol,
              esUltimo: false,
            ); }
            if (i == 2) { return _paginaDescripcionSigno(
              titulo: 'TU SIGNO LUNAR',
              signo: _signoLunarActivo,
              descripcion: _descLuna,
              esUltimo: false,
            ); }
            if (i == 3) { return _paginaDescripcionSigno(
              titulo: 'TU ASCENDENTE',
              signo: _ascendenteActivo,
              descripcion: _descAsc,
              esUltimo: true,
            ); }
            if (i == 4) return _paginaDescubreRelaciones();
            return _paginaDescubreAstros();
          },
        ),
      ),
        ),
      ),
    );
  }


  Future<void> _iniciarTransicion() async {
    setState(() => _zoomingOut = true);
    await Future.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    // Armar lista de datos planetarios
    final datos = <String>[
      'su Sol en ${widget.signoSolar}',
      'su Luna en ${widget.signoLunar}',
      'su Ascendente en ${widget.ascendente}',
      ...widget.planetas.entries.map((e) => 'su ${e.key} en ${e.value}'),
    ];
    await Navigator.of(context).push(PageRouteBuilder(
      pageBuilder: (_, __, ___) => _PantallaVideoReveal(
        nombre:       widget.nombre,
        datos:        datos,
        videoPreload: _videoReveal,
      ),
      transitionsBuilder: (_, anim, _, child) =>
          FadeTransition(opacity: anim, child: child),
      transitionDuration: const Duration(milliseconds: 800),
    ));
    if (mounted) setState(() => _zoomingOut = false);
  }

  int _paginaSigno = 0;
  double _dragAcumulado = 0;

  static const _slidesSignos = [
    ('signoSolar', 'TU SIGNO SOLAR', 'Esto es quién eres.'),
    ('signoLunar', 'TU SIGNO LUNAR', 'Así es como sientes.'),
    ('ascendente', 'TU ASCENDENTE',  'Así te percibe el mundo.'),
  ];

  void _mostrarDebugMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('DEBUG · constelaciones',
                  style: TextStyle(color: Colors.white38, fontSize: 11, letterSpacing: 2)),
              const SizedBox(height: 20),
              _debugDropdown(ctx, setModal, 'SOLAR',      _debugSolar ?? widget.signoSolar,  (v) { setState(() => _debugSolar = v); }),
              const SizedBox(height: 12),
              _debugDropdown(ctx, setModal, 'LUNAR',      _debugLunar ?? widget.signoLunar,  (v) { setState(() => _debugLunar = v); }),
              const SizedBox(height: 12),
              _debugDropdown(ctx, setModal, 'ASCENDENTE', _debugAsc   ?? widget.ascendente,  (v) { setState(() => _debugAsc   = v); }),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('CUADRÍCULA', style: TextStyle(color: Colors.white54, fontSize: 11, letterSpacing: 1)),
                  GestureDetector(
                    onTap: () { setState(() => _debugGrid = !_debugGrid); setModal(() {}); },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _debugGrid ? Colors.yellowAccent.withValues(alpha: 0.2) : Colors.white10,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(_debugGrid ? 'ON' : 'OFF',
                          style: TextStyle(color: _debugGrid ? Colors.yellowAccent : Colors.white38, fontSize: 11, letterSpacing: 1)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () { setState(() { _debugSolar = null; _debugLunar = null; _debugAsc = null; _debugGrid = false; }); Navigator.pop(ctx); },
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('· resetear a valores reales',
                      style: TextStyle(color: Colors.white38, fontSize: 12, letterSpacing: 0.5)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _debugDropdown(BuildContext ctx, StateSetter setModal, String label, String valor, ValueChanged<String> onChange) {
    return Row(
      children: [
        SizedBox(width: 100, child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11, letterSpacing: 1))),
        Expanded(
          child: DropdownButton<String>(
            value: _todosSignos.contains(valor) ? valor : _todosSignos.first,
            dropdownColor: const Color(0xFF2A2A2A),
            style: const TextStyle(color: Colors.white, fontSize: 13),
            underline: Container(height: 1, color: Colors.white24),
            isExpanded: true,
            items: _todosSignos.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
            onChanged: (v) { if (v != null) { onChange(v); setModal(() {}); } },
          ),
        ),
      ],
    );
  }

  String _signoParaIdx(int i) {
    if (i == 0) return _signoSolarActivo;
    if (i == 1) return _signoLunarActivo;
    return _ascendenteActivo;
  }

  Widget _paginaSignos() {
    final signoActivo = _signoParaIdx(_paginaSigno);
    final etiqueta    = _slidesSignos[_paginaSigno].$2;
    final frase       = _slidesSignos[_paginaSigno].$3;
    final urlImagen   = _imagenesSigno[signoActivo];

    return NotificationListener<ScrollNotification>(
      onNotification: (_) => _paginaSigno < 2, // bloquea scroll exterior hasta llegar al ascendente
      child: GestureDetector(
      onVerticalDragUpdate: (d) => _dragAcumulado += d.delta.dy,
      onVerticalDragEnd: (_) {
        if (_dragAcumulado < -40) {
          if (_paginaSigno < 2) {
            setState(() { _paginaSigno++; });
          } else {
            // En ascendente → avanzar al PageView exterior
            _pageCtrl.nextPage(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
            );
          }
        } else if (_dragAcumulado > 40 && _paginaSigno > 0) {
          setState(() { _paginaSigno--; });
        }
        _dragAcumulado = 0;
      },
      child: Stack(
        children: [
          const Positioned.fill(child: ColoredBox(color: Colors.black)),
          const Positioned.fill(child: CieloEstrellado()),

          // ── Indicadores verticales (derecha) ─────────────────────────────
          Positioned(
            right: 20,
            top: 0, bottom: 0,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  width:  6,
                  height: _paginaSigno == i ? 16 : 6,
                  decoration: BoxDecoration(
                    color: _paginaSigno == i
                        ? const Color(0xFFF3EBD6)
                        : const Color(0x44F3EBD6),
                    borderRadius: BorderRadius.circular(3),
                  ),
                )),
              ),
            ),
          ),

          // ── Botón debug (esquina superior derecha) ───────────────────────
          Positioned(
            top: 48, right: 16,
            child: GestureDetector(
              onTap: () => _mostrarDebugMenu(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Text('debug', style: TextStyle(color: Colors.white54, fontSize: 11, letterSpacing: 1)),
              ),
            ),
          ),

          SafeArea(
            child: Builder(builder: (context) {
            final sw       = MediaQuery.of(context).size.width;
            final diametro = sw * 1.15;
            return Column(
              children: [
                const SizedBox(height: 16),
                const Spacer(),

                // ── Etiqueta + nombre (fade al cambiar) ───────────────────
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: Column(
                    key: ValueKey(_paginaSigno),
                    children: [
                      Text(etiqueta,
                          style: const TextStyle(
                            color: Color(0xFFD4AF6A),
                            fontSize: 11,
                            letterSpacing: 4,
                            fontWeight: FontWeight.w400,
                          )),
                      const SizedBox(height: 10),
                      Text(signoActivo.toUpperCase(),
                          style: const TextStyle(
                            color: Color(0xFFF3EBD6),
                            fontSize: 42,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w400,
                            fontFamily: 'PlayfairDisplay',
                            height: 1,
                          )),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // ── Círculo fijo con fade interno ─────────────────────────
                SizedBox(
                  width: sw,
                  height: diametro,
                  child: OverflowBox(
                    maxWidth: diametro,
                    maxHeight: diametro,
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFFE2D4B8),
                            Color(0xFFD9C9A8),
                            Color(0xFFC4B08A),
                          ],
                          stops: [0.0, 0.55, 1.0],
                        ),
                      ),
                      child: ClipOval(
                        child: SizedBox(
                          width: diametro,
                          height: diametro,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Imagen mitológica — fade al cambiar
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 500),
                                child: urlImagen != null
                                    ? Opacity(
                                        key: ValueKey('img_$signoActivo'),
                                        opacity: 0.23,
                                        child: Transform.scale(
                                          scaleX: signoActivo == 'Capricornio' ? -1.0 : 1.0,
                                          child: Image.network(
                                            urlImagen,
                                            width: diametro, height: diametro,
                                            fit: BoxFit.contain,
                                            frameBuilder: (ctx, child, frame, sync) {
                                              if (sync) return child;
                                              return AnimatedOpacity(
                                                opacity: frame == null ? 0.0 : 1.0,
                                                duration: const Duration(milliseconds: 600),
                                                curve: Curves.easeIn,
                                                child: child,
                                              );
                                            },
                                          ),
                                        ),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                              // Constelación — fade al cambiar
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 500),
                                child: Padding(
                                  key: ValueKey('con_$signoActivo'),
                                  padding: EdgeInsets.all(diametro * 0.12),
                                  child: ConstelacionWidget(
                                    signo: signoActivo,
                                    duracion: const Duration(milliseconds: 2400),
                                    debugGrid: _debugGrid,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // ── Frase debajo del círculo ───────────────────────────────
                const SizedBox(height: 20),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: Text(
                    frase,
                    key: ValueKey('frase_$_paginaSigno'),
                    style: GoogleFonts.manrope(
                      color: const Color(0xFFF3EBD6).withValues(alpha: 0.5),
                      fontSize: 26,
                      fontWeight: FontWeight.w300,
                      height: 1.65,
                      letterSpacing: -0.18,
                    ),
                  ),
                ),

                const Spacer(),
                // ── Flecha deslizar ────────────────────────────────────────
                AnimatedBuilder(
                  animation: _arrowAnim,
                  builder: (ctx, _) => Transform.translate(
                    offset: Offset(0, _paginaSigno < 2 ? _arrowAnim.value : -_arrowAnim.value),
                    child: Icon(
                      _paginaSigno < 2 ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                      color: const Color(0x44F3EBD6), size: 22,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            );
          }),
          ),  // SafeArea
        ],
      ),   // Stack
    ));   // NotificationListener
  }

  static const _imagenesSigno = <String, String>{
    'Aries':       'https://res.cloudinary.com/dwemowboc/image/upload/v1776884078/aries_fnkftj.png',
    'Tauro':       'https://res.cloudinary.com/dwemowboc/image/upload/v1776889477/tauro_vkm5gj.png',
    'Géminis':     'https://res.cloudinary.com/dwemowboc/image/upload/v1776973311/gemini_ldisgs.png',
    'Cáncer':      'https://res.cloudinary.com/dwemowboc/image/upload/v1776976664/cancer_uthi8z.png',
    'Leo':         'https://res.cloudinary.com/dwemowboc/image/upload/v1776973595/leo_vttg0e.png',
    'Virgo':       'https://res.cloudinary.com/dwemowboc/image/upload/v1776974901/virgo_cnoxxy.png',
    'Libra':       'https://res.cloudinary.com/dwemowboc/image/upload/v1776976673/libra_ixcj0y.png',
    'Escorpio':    'https://res.cloudinary.com/dwemowboc/image/upload/v1776894705/scorpio_wfjchc.png',
    'Sagitario':   'https://res.cloudinary.com/dwemowboc/image/upload/v1776976667/sagitario_vgnvpw.png',
    'Capricornio': 'https://res.cloudinary.com/dwemowboc/image/upload/v1776891000/capricornio_x3ik0z.png',
    'Acuario':     'https://res.cloudinary.com/dwemowboc/image/upload/v1776976670/acuario_gbdd3v.png',
    'Piscis':      'https://res.cloudinary.com/dwemowboc/image/upload/v1776894271/piscis_ejokfj.png',
  };

  static const _imagenesDescripcion = <String, String>{
    'Aries':       'https://firebasestorage.googleapis.com/v0/b/astro-fd0bf.firebasestorage.app/o/Assets%2Fariespng.png?alt=media&token=7df4a37c-1542-4e9b-98c2-1fb002865c90',
    'Tauro':       'https://firebasestorage.googleapis.com/v0/b/astro-fd0bf.firebasestorage.app/o/Assets%2Ftauruspng.png?alt=media&token=4a3c4fb2-3e33-424c-a208-bd3ea738a5a7',
    'Géminis':     'https://firebasestorage.googleapis.com/v0/b/astro-fd0bf.firebasestorage.app/o/Assets%2Fgemini%20png.png?alt=media&token=919f5978-04de-44db-8ede-b4c3e0361546',
    'Cáncer':      'https://firebasestorage.googleapis.com/v0/b/astro-fd0bf.firebasestorage.app/o/Assets%2Fcancerpng.png?alt=media&token=439425aa-2652-4fa4-bf97-6b3aef5b6fd5',
    'Leo':         'https://firebasestorage.googleapis.com/v0/b/astro-fd0bf.firebasestorage.app/o/Assets%2Fleo%20png.png?alt=media&token=e1481208-825c-4597-9eb2-9fda8f4bbcd0',
    'Virgo':       'https://firebasestorage.googleapis.com/v0/b/astro-fd0bf.firebasestorage.app/o/Assets%2Fvirgopng.png?alt=media&token=830a4506-66a2-411d-b05a-c49eabd97877',
    'Libra':       'https://firebasestorage.googleapis.com/v0/b/astro-fd0bf.firebasestorage.app/o/Assets%2Flibrapng.png?alt=media&token=d0b5e4d4-e114-4b9f-a9bb-515c182d482d',
    'Escorpio':    'https://firebasestorage.googleapis.com/v0/b/astro-fd0bf.firebasestorage.app/o/Assets%2Fescorpiopng.png?alt=media&token=31c52a92-6ff4-42b4-a2ff-90524f71c679',
    'Sagitario':   'https://firebasestorage.googleapis.com/v0/b/astro-fd0bf.firebasestorage.app/o/Assets%2Fsagitariopng.png?alt=media&token=9abe4df3-6d09-49e4-a9ba-c191a2d8f090',
    'Capricornio': 'https://firebasestorage.googleapis.com/v0/b/astro-fd0bf.firebasestorage.app/o/Assets%2Fcapricornio%20png.png?alt=media&token=1ad0f203-38ed-4079-9924-bb1eb74af8b5',
    'Acuario':     'https://firebasestorage.googleapis.com/v0/b/astro-fd0bf.firebasestorage.app/o/Assets%2Facuariopng.png?alt=media&token=92793087-8b68-4e00-941c-3f73551cbebc',
    'Piscis':      'https://firebasestorage.googleapis.com/v0/b/astro-fd0bf.firebasestorage.app/o/Assets%2Fpiscis%20png.png?alt=media&token=2989ac0f-2c48-4470-acff-90faa5b89fcc',
  };

  static const _dorado = Color(0xFFD4AF6A);

  TextSpan _textoConDorados(String texto) {
    final rng = Random();
    final palabras = texto.split(' ');
    final elegibles = [
      for (int i = 0; i < palabras.length; i++)
        if (palabras[i].replaceAll(RegExp(r'[^a-záéíóúüñA-ZÁÉÍÓÚÜÑ]'), '').length >= 4) i
    ];
    elegibles.shuffle(rng);
    final cantidad = 2 + rng.nextInt(3); // 2, 3 o 4
    final indices = elegibles.take(cantidad).toSet();
    final spans = <TextSpan>[];
    for (int i = 0; i < palabras.length; i++) {
      final esDorada = indices.contains(i);
      spans.add(TextSpan(
        text: i == 0 ? palabras[i] : ' ${palabras[i]}',
        style: TextStyle(
          color: esDorada ? _dorado : const Color(0xFFF3EBD6),
          fontWeight: esDorada ? FontWeight.w400 : FontWeight.w300,
        ),
      ));
    }
    return TextSpan(children: spans);
  }

  Widget _paginaDescripcionSigno({
    required String titulo,
    required String signo,
    required String? descripcion,
    required bool esUltimo,
  }) {
    final texto     = _lecturaLista ? (descripcion ?? '') : null;
    final imagenUrl = _imagenesDescripcion[signo];

    return Stack(
      children: [
        const Positioned.fill(child: ColoredBox(color: Colors.black)),
        const Positioned.fill(child: CieloEstrellado()),
        SafeArea(
          child: SizedBox.expand(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── debug ────────────────────────────────────────────────
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _descSol = null; _descLuna = null;
                          _descAsc = null; _lecturaLista = false;
                        });
                        _generarLectura();
                      },
                      child: Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: const Text('↺ debug',
                            style: TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 1)),
                      ),
                    ),
                  ),

                  const Spacer(),

                  // ── Título + imagen ───────────────────────────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(titulo,
                                style: const TextStyle(
                                  color: Color(0xFFD4AF6A),
                                  fontSize: 12,
                                  letterSpacing: 4,
                                )),
                            const SizedBox(height: 6),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(signo.toUpperCase(),
                                  style: const TextStyle(
                                    color: Color(0xFFF3EBD6),
                                    fontSize: 40,
                                    letterSpacing: 1.2,
                                    fontWeight: FontWeight.w400,
                                    fontFamily: 'PlayfairDisplay',
                                    height: 1,
                                  )),
                            ),
                          ],
                        ),
                      ),
                      if (imagenUrl != null)
                        SizedBox(
                          width: 140,
                          height: 0,
                          child: OverflowBox(
                            maxWidth: 200,
                            maxHeight: 200,
                            alignment: const Alignment(0, 0.3),
                            child: Opacity(
                              opacity: 0.28,
                              child: ColorFiltered(
                                colorFilter: const ColorFilter.matrix([
                                  -1,  0,  0, 0, 255,
                                   0, -1,  0, 0, 255,
                                   0,  0, -1, 0, 255,
                                   0,  0,  0, 1,   0,
                                ]),
                                child: Image.network(
                                  imagenUrl,
                                  width: 200,
                                  height: 200,
                                  fit: BoxFit.contain,
                                  errorBuilder: (ctx, err, _) => const SizedBox(width: 200, height: 200),
                                  frameBuilder: (ctx, child, frame, sync) {
                                    if (sync) return child;
                                    return AnimatedOpacity(
                                      opacity: frame == null ? 0.0 : 1.0,
                                      duration: const Duration(milliseconds: 800),
                                      curve: Curves.easeIn,
                                      child: child,
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Línea divisora
                  Container(
                    width: 32,
                    height: 1,
                    color: const Color(0xFFD4AF6A).withValues(alpha: 0.5),
                  ),

                  const SizedBox(height: 36),

                  // ── Cuadro negro con imagen encima ────────────────────────
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: const BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.zero,
                        ),
                        child: texto == null
                            ? const SizedBox(
                                height: 2, width: 40,
                                child: LinearProgressIndicator(
                                    color: Color(0x44F3EBD6),
                                    backgroundColor: Color(0x22F3EBD6)))
                            : RichText(
                                text: TextSpan(
                                  style: GoogleFonts.manrope(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w300,
                                    height: 1.65,
                                    letterSpacing: -0.01 * 19,
                                  ),
                                  children: [_textoConDorados(texto)],
                                ),
                              ),
                      ),
                    ],
                  ),

                  const Spacer(),

                  // ── Flecha ────────────────────────────────────────────────
                  AnimatedBuilder(
                    animation: _arrowAnim,
                    builder: (ctx, child) => Transform.translate(
                      offset: Offset(0, -_arrowAnim.value),
                      child: const Center(child: Icon(
                          Icons.keyboard_arrow_up,
                          color: Color(0x44F3EBD6), size: 22)),
                    ),
                  ),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _paginaDescubreRelaciones() {
    return Stack(
      children: [
        const Positioned.fill(child: ColoredBox(color: Colors.black)),
        const Positioned.fill(child: CieloEstrellado()),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(32, 0, 32, 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                const Spacer(),
                const Text('LO QUE TU CARTA REVELA',
                    style: TextStyle(
                      color: Color(0xFFD4AF6A),
                      fontSize: 13,
                      letterSpacing: 4,
                    )),
                const SizedBox(height: 24),
                Text(
                  'Todo en ti está conectado. Descubre cómo tu carta une lo que sientes, buscas y repites.',
                  style: GoogleFonts.manrope(
                    color: const Color(0xFFF3EBD6),
                    fontSize: 24,
                    fontWeight: FontWeight.w300,
                    height: 1.65,
                    letterSpacing: -0.18,
                  ),
                ),
                const Spacer(),
                Column(
                  children: [
                    _BotonAnimado(
                      onTap: _iniciarTransicion,
                      filled: true,
                      label: 'PROFUNDIZAR',
                      tallPadding: true,
                    ),
                    const SizedBox(height: 10),
                    _BotonAnimado(
                      onTap: () => _pageCtrl.nextPage(
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeInOut),
                      filled: false,
                      label: 'OMITIR',
                      tallPadding: false,
                    ),
                  ],
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _paginaDescubreAstros() {
    return Stack(
      children: [
        const Positioned.fill(child: ColoredBox(color: Colors.black)),
        const Positioned.fill(child: CieloEstrellado()),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(32, 0, 32, 48),
            child: Column(
              children: [
                const Spacer(),
                const Text(
                  'Descubre lo que rigen el resto de tus astros en tu perfil.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFFF3EBD6),
                    fontSize: 20,
                    fontWeight: FontWeight.w300,
                    height: 1.6,
                    letterSpacing: 0.3,
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => widget.onContinuar(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _beige,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(2)),
                      elevation: 0,
                    ),
                    child: const Text('VER MI PERFIL',
                        style: TextStyle(letterSpacing: 3, fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Widget animado ───────────────────────────────────────────────────────────

class ConstelacionWidget extends StatefulWidget {
  final String signo;
  final Duration duracion;
  final bool debugGrid;
  const ConstelacionWidget({
    super.key,
    required this.signo,
    this.duracion = const Duration(milliseconds: 3000),
    this.debugGrid = false,
  });

  @override
  State<ConstelacionWidget> createState() => _ConstelacionWidgetState();
}

class _ConstelacionWidgetState extends State<ConstelacionWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _progreso;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duracion);
    _progreso = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    Future.delayed(const Duration(milliseconds: 400), () {
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
    return AnimatedBuilder(
      animation: _progreso,
      builder: (context, w) => CustomPaint(
        painter: ConstelacionPainter(signo: widget.signo, progreso: _progreso.value, debugGrid: widget.debugGrid),
        child: const SizedBox.expand(),
      ),
    );
  }
}

// ─── Cielo estrellado con titileo ────────────────────────────────────────────

class CieloEstrellado extends StatefulWidget {
  final int cantidad;
  final Animation<Offset>? paralaje; // offset de cámara externo (opcional)
  const CieloEstrellado({super.key, this.cantidad = 55, this.paralaje});

  @override
  State<CieloEstrellado> createState() => _CieloEstrelladoState();
}

class _CieloEstrelladoState extends State<CieloEstrellado>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late List<_Estrella> _estrellas;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 6))
      ..repeat();
    final rnd = Random(42);
    // velocidad es entero (1, 2 o 3) para que sin(2π*v*t) sea siempre continuo en el loop
    _estrellas = List.generate(widget.cantidad, (i) => _Estrella(
      x:          rnd.nextDouble(),
      y:          rnd.nextDouble(),
      radio:      rnd.nextDouble() * 1.1 + 0.4,
      fase:       rnd.nextDouble() * 2 * pi,
      velocidad:  (rnd.nextInt(3) + 1).toDouble(),
    ));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Escucha tanto el titileo como el paralaje (si existe) en un solo builder
    final listenable = widget.paralaje != null
        ? Listenable.merge([_ctrl, widget.paralaje!])
        : _ctrl;
    return AnimatedBuilder(
      animation: listenable,
      builder: (context, w) => CustomPaint(
        painter: _CieloPainter(
          _estrellas,
          _ctrl.value,
          paralaje: widget.paralaje?.value ?? Offset.zero,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _Estrella {
  final double x, y, radio, fase, velocidad;
  const _Estrella({required this.x, required this.y, required this.radio,
      required this.fase, this.velocidad = 1.0});
}

class _CieloPainter extends CustomPainter {
  final List<_Estrella> estrellas;
  final double t;
  final Offset paralaje;
  const _CieloPainter(this.estrellas, this.t, {this.paralaje = Offset.zero});

  @override
  void paint(Canvas canvas, Size size) {
    for (final e in estrellas) {
      final cycle = sin(t * 2 * pi * e.velocidad + e.fase);
      final alpha = (cycle * 0.5 + 0.5) * 0.55 + 0.25;
      // Paralaje: las estrellas se mueven un 5% del desplazamiento de cámara
      final px = (e.x * size.width  + paralaje.dx * 0.05) % size.width;
      final py = (e.y * size.height + paralaje.dy * 0.05) % size.height;
      canvas.drawCircle(
        Offset(px, py),
        e.radio,
        Paint()..color = Colors.white.withValues(alpha: alpha),
      );
    }
  }

  @override
  bool shouldRepaint(_CieloPainter old) => old.t != t || old.paralaje != paralaje;
}

// ─────────────────────────────────────────────────────────────────────────────

class _BotonAnimado extends StatefulWidget {
  final VoidCallback onTap;
  final bool filled;
  final String label;
  final bool tallPadding;
  const _BotonAnimado({required this.onTap, required this.filled, required this.label, this.tallPadding = false});
  @override
  State<_BotonAnimado> createState() => _BotonAnimadoState();
}

class _BotonAnimadoState extends State<_BotonAnimado> {
  bool _pressed = false;

  void _handleTap() async {
    setState(() => _pressed = true);
    await Future.delayed(const Duration(milliseconds: 120));
    if (mounted) setState(() => _pressed = false);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: widget.tallPadding ? 24 : 14),
          decoration: BoxDecoration(
            color: widget.filled ? const Color(0xFFF3EBD6) : Colors.transparent,
            border: widget.filled ? null : Border.all(color: const Color(0x44F3EBD6)),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Center(
            child: Text(
              widget.label,
              style: TextStyle(
                color: widget.filled ? Colors.black : const Color(0x88F3EBD6),
                fontSize: widget.filled ? 14 : 11,
                letterSpacing: 3,
                fontWeight: widget.filled ? FontWeight.w500 : FontWeight.w300,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Pantalla de video reveal ──────────────────────────────────────────────────

class _PantallaVideoReveal extends StatefulWidget {
  final String nombre;
  final List<String> datos;
  final VideoPlayerController? videoPreload;

  const _PantallaVideoReveal({
    required this.nombre,
    required this.datos,
    this.videoPreload,
  });
  @override
  State<_PantallaVideoReveal> createState() => _PantallaVideoRevealState();
}

class _PantallaVideoRevealState extends State<_PantallaVideoReveal> {
  late VideoPlayerController _video;
  double _videoOpacity = 0.0;
  bool _mostrarBoton = false;
  double _opacidadBoton = 0.0;
  int _datoIndex = 0;
  double _datoOpacity = 1.0;
  Timer? _timer;
  Timer? _datoTimer;

  static const _url = 'https://firebasestorage.googleapis.com/v0/b/astro-fd0bf.firebasestorage.app/o/Assets%2Fonboard.mp4?alt=media&token=4dc6d672-2bb1-43b5-933b-47fda187ac9c';

  void _iniciarCicloDatos() {
    _datoTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!mounted) return;
      // fade out
      setState(() => _datoOpacity = 0.0);
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      setState(() {
        _datoIndex = (_datoIndex + 1) % widget.datos.length;
        _datoOpacity = 1.0;
      });
    });
  }

  void _armarTimer() {
    _timer = Timer(const Duration(seconds: 6), () async {
      if (!mounted) return;
      _datoTimer?.cancel();
      // fade out cycling text block
      setState(() => _datoOpacity = 0.0);
      await Future.delayed(const Duration(milliseconds: 450));
      if (!mounted) return;
      // show "Tu lectura está lista" + button, both at opacity 0
      setState(() { _mostrarBoton = true; _opacidadBoton = 0.0; });
      await Future.delayed(const Duration(milliseconds: 50));
      if (!mounted) return;
      // fade them in together
      setState(() => _opacidadBoton = 1.0);
      Future.delayed(const Duration(milliseconds: 1500), () {
        HapticFeedback.mediumImpact();
      });
    });
  }

  @override
  void initState() {
    super.initState();
    if (widget.videoPreload != null && widget.videoPreload!.value.isInitialized) {
      // Ya precargado — úsalo directo
      _video = widget.videoPreload!;
      _video.play();
      _videoOpacity = 1.0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) { setState(() {}); _iniciarCicloDatos(); _armarTimer(); }
      });
    } else {
      // Sin precarga — inicializar ahora
      _video = (widget.videoPreload ?? VideoPlayerController.networkUrl(Uri.parse(_url)))
        ..setLooping(true)
        ..setVolume(0);
      _video.initialize().then((_) {
        if (!mounted) return;
        _video.play();
        setState(() => _videoOpacity = 1.0);
        _iniciarCicloDatos();
        _armarTimer();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _datoTimer?.cancel();
    if (widget.videoPreload == null) _video.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Video
          AnimatedOpacity(
            opacity: _videoOpacity,
            duration: const Duration(seconds: 1),
            child: _video.value.isInitialized
                ? FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _video.value.size.width,
                      height: _video.value.size.height,
                      child: VideoPlayer(_video),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          // Overlay oscuro 50%
          Container(color: Colors.black.withValues(alpha: 0.5)),
          // Texto central
          Positioned.fill(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: _mostrarBoton
                    ? AnimatedOpacity(
                        opacity: _opacidadBoton,
                        duration: const Duration(milliseconds: 2500),
                        curve: Curves.easeIn,
                        child: Text(
                          'Tu lectura está lista',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.manrope(
                            color: const Color(0xFFF3EBD6),
                            fontSize: 24,
                            fontWeight: FontWeight.w300,
                            letterSpacing: 0.5,
                          ),
                        ),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            '${widget.nombre.split(' ').first} tiene',
                            style: GoogleFonts.manrope(
                              color: const Color(0xFFF3EBD6),
                              fontSize: 20,
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                          const SizedBox(height: 6),
                          AnimatedOpacity(
                            opacity: _datoOpacity,
                            duration: const Duration(milliseconds: 300),
                            child: Builder(builder: (_) {
                              final dato = widget.datos.isNotEmpty ? widget.datos[_datoIndex] : '';
                              final match = RegExp(r'^(su )(.*?)( en )(.*?)$').firstMatch(dato);
                              final base = GoogleFonts.manrope(fontSize: 26, fontWeight: FontWeight.w300);
                              if (match == null) {
                                return Text(dato, style: base.copyWith(color: const Color(0xFFD4AF6A)));
                              }
                              return RichText(
                                textAlign: TextAlign.center,
                                text: TextSpan(style: base, children: [
                                  TextSpan(text: match.group(1), style: const TextStyle(color: Color(0xFFF3EBD6))),
                                  TextSpan(text: match.group(2), style: const TextStyle(color: Color(0xFFD4AF6A))),
                                  TextSpan(text: match.group(3), style: const TextStyle(color: Color(0xFFF3EBD6))),
                                  TextSpan(text: match.group(4), style: const TextStyle(color: Color(0xFFD4AF6A))),
                                ]),
                              );
                            }),
                          ),
                        ],
                      ),
              ),
            ),
          ),
          // Botón revelar
          if (_mostrarBoton)
            Positioned(
              left: 32, right: 32, bottom: 64,
              child: AnimatedOpacity(
                opacity: _opacidadBoton,
                duration: const Duration(milliseconds: 2500),
                curve: Curves.easeIn,
                child: _BotonAnimado(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => PantallaCompraCarta(
                      videoExterno: _video,
                    )),
                  ),
                  filled: true,
                  label: 'REVELAR LECTURA',
                  tallPadding: true,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
