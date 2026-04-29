import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/calculos_planetarios.dart';

List<PlanetaInfo> planetasDesdeSignos(Map<String, String> mapa) {
  const signos = [
    'Aries', 'Tauro', 'Géminis', 'Cáncer', 'Leo', 'Virgo',
    'Libra', 'Escorpio', 'Sagitario', 'Capricornio', 'Acuario', 'Piscis',
  ];
  const simbolosPlaneta = {
    'Sol': '☉', 'Luna': '☽', 'Mercurio': '☿', 'Venus': '♀',
    'Marte': '♂', 'Júpiter': '♃', 'Saturno': '♄',
    'Urano': '♅', 'Neptuno': '♆', 'Plutón': '♇',
    'Ascendente': '↑',
  };
  const simbolosSignos = [
    'ARI','TAU','GEM','CAN','LEO','VIR',
    'LIB','ESC','SAG','CAP','ACU','PIS',
  ];

  return mapa.entries.map((e) {
    final idx = signos.indexOf(e.value);
    final longitud = idx >= 0 ? idx * 30.0 + 15.0 : 0.0;
    final signoIdx = idx >= 0 ? idx : 0;
    return PlanetaInfo(
      nombre: e.key,
      simbolo: simbolosPlaneta[e.key] ?? '●',
      signo: e.value,
      simboloSigno: idx >= 0 ? simbolosSignos[signoIdx] : '',
      longitud: longitud,
    );
  }).toList();
}

// ─────────────────────────────────────────────────────────────────────────────

class RuedaZodiacalPainter extends CustomPainter {
  final List<PlanetaInfo> planetas;
  final String? seleccionado;

  const RuedaZodiacalPainter(this.planetas, {this.seleccionado});

  static const _nombresSignos = [
    'Aries', 'Tauro', 'Géminis', 'Cáncer', 'Leo', 'Virgo',
    'Libra', 'Escorpio', 'Sagitario', 'Capricornio', 'Acuario', 'Piscis',
  ];
  static const _dorado    = Color(0xFFB8973A);
  static const _colorSol  = Color(0xFF4DB6AC);
  static const _colorLuna = Color(0xFF9575CD);
  static const _fondo     = Color(0xFFF3EBD6);

  static TextStyle _simStyle(double size, Color color) =>
      GoogleFonts.notoSansSymbols2(fontSize: size, color: color);

  @override
  void paint(Canvas canvas, Size size) {
    final c   = Offset(size.width / 2, size.height / 2);
    final rEx = size.width / 2 - 4;   // borde exterior del anillo de signos
    final rEi = rEx * 0.76;           // borde interior del anillo de signos
    final rPx = rEi * 0.93;           // borde exterior del anillo de planetas (fino)
    final rPi = rEi * 0.78;           // borde interior del anillo de planetas (fino)
    final rA  = rPi;                  // líneas de aspecto nacen del borde interior del anillo

    final pintaLinea = Paint()
      ..color = Colors.black12
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    // ── Relleno del anillo exterior (signos) ─────────────────────────────────
    canvas.drawCircle(c, rEx, Paint()..color = const Color(0xFFEDE4CE)..style = PaintingStyle.fill);
    // Recortar relleno para dejar centro transparente
    canvas.drawCircle(c, rEi, Paint()..color = _fondo..style = PaintingStyle.fill);

    // ── Aros ─────────────────────────────────────────────────────────────────
    canvas.drawCircle(c, rEx, pintaLinea);
    canvas.drawCircle(c, rEi, pintaLinea);
    // Anillo fino de planetas
    canvas.drawCircle(c, rPx, Paint()..color = Colors.black.withValues(alpha: 0.10)..strokeWidth = 0.7..style = PaintingStyle.stroke);
    canvas.drawCircle(c, rPi, Paint()..color = Colors.black.withValues(alpha: 0.10)..strokeWidth = 0.7..style = PaintingStyle.stroke);

    // ── 12 divisores del anillo exterior ─────────────────────────────────────
    for (int i = 0; i < 12; i++) {
      final ang = (i * 30 - 90) * pi / 180;
      final p1 = Offset(c.dx + rEi * cos(ang), c.dy + rEi * sin(ang));
      final p2 = Offset(c.dx + rEx * cos(ang), c.dy + rEx * sin(ang));
      canvas.drawLine(p1, p2, Paint()..color = Colors.black.withValues(alpha: 0.18)..strokeWidth = 0.7);
    }

    // ── Texto curvo de signos ─────────────────────────────────────────────────
    _dibujarNombresSignos(canvas, c, rEi, rEx);

    // ── Cruz dorada cardinal ──────────────────────────────────────────────────
    final paintCruz = Paint()..color = _dorado..strokeWidth = 0.8..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(c.dx, c.dy - rEx), Offset(c.dx, c.dy - rEi), paintCruz);
    canvas.drawLine(Offset(c.dx, c.dy + rEi), Offset(c.dx, c.dy + rEx), paintCruz);
    canvas.drawLine(Offset(c.dx - rEx, c.dy), Offset(c.dx - rEi, c.dy), paintCruz);
    canvas.drawLine(Offset(c.dx + rEi, c.dy), Offset(c.dx + rEx, c.dy), paintCruz);
    _estrella4(canvas, Offset(c.dx, c.dy - rEx), 5.5);
    _estrella4(canvas, Offset(c.dx + rEx, c.dy), 5.5);
    _estrella4(canvas, Offset(c.dx, c.dy + rEx), 5.5);
    _estrella4(canvas, Offset(c.dx - rEx, c.dy), 5.5);

    // ── Líneas de aspecto ────────────────────────────────────────────────────
    _aspectos(canvas, c, rA);

    // ── Planetas en el anillo interior ───────────────────────────────────────
    _dibujarPlanetas(canvas, c, rPi, rPx);
  }

  // ── Texto curvo para cada signo ───────────────────────────────────────────

  void _dibujarNombresSignos(Canvas canvas, Offset c, double rInt, double rExt) {
    const fontSize = 7.0;

    for (int i = 0; i < 12; i++) {
      final nombre    = _nombresSignos[i];
      final angCentro = (i * 30 + 15 - 90) * pi / 180;

      // En la mitad inferior (90°–270°) el texto saldría al revés:
      // lo colocamos en el radio interior y giramos 180° extra
      final angCanvas = i * 30 + 15 - 90;
      final enParteBaja = angCanvas > 0 && angCanvas < 180;
      final rTexto      = enParteBaja ? rInt + (rExt - rInt) * 0.38 : (rInt + rExt) / 2 + 1;
      final rotExtra    = enParteBaja ? pi : 0.0;

      final charAngRad = fontSize * 0.85 / rTexto;
      final totalAng   = charAngRad * nombre.length;
      // En parte baja invertimos el orden para que las letras queden bien
      final startAng   = enParteBaja
          ? angCentro + totalAng / 2
          : angCentro - totalAng / 2;
      final paso       = enParteBaja ? -charAngRad : charAngRad;

      for (int j = 0; j < nombre.length; j++) {
        final charAng = startAng + paso * (j + 0.5);
        final x = c.dx + rTexto * cos(charAng);
        final y = c.dy + rTexto * sin(charAng);

        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(charAng + pi / 2 + rotExtra);

        final tp = TextPainter(
          text: TextSpan(
            text: nombre[j],
            style: const TextStyle(
              fontSize: fontSize,
              color: Color(0xFF6B5E42),
              fontWeight: FontWeight.w500,
              letterSpacing: 0,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
        canvas.restore();
      }
    }
  }

  // ── Planetas con separación para solapamiento ─────────────────────────────

  void _dibujarPlanetas(Canvas canvas, Offset c, double rInt, double rExt) {
    final rMedio = (rInt + rExt) / 2;

    // Agrupar por sector de 10°
    final Map<int, List<PlanetaInfo>> sectores = {};
    for (final p in planetas) {
      sectores.putIfAbsent((p.longitud / 10).floor(), () => []).add(p);
    }

    for (final lista in sectores.values) {
      for (int k = 0; k < lista.length; k++) {
        final p     = lista[k];
        final esSel = seleccionado == null || seleccionado == p.nombre;
        final alpha = esSel ? 1.0 : 0.20;

        // Separar verticalmente si hay varios en el mismo sector
        final offset = (k - (lista.length - 1) / 2) * 11.0;
        final angRad = (p.longitud - 90) * pi / 180;
        final r      = rMedio + offset;
        final pos    = Offset(c.dx + r * cos(angRad), c.dy + r * sin(angRad));
        final nombre = p.nombre.toLowerCase();

        if (nombre == 'sol') {
          _dibujarPlaneta(canvas, pos, _colorSol, alpha, p.simbolo, blanco: true);
        } else if (nombre == 'luna') {
          _dibujarPlaneta(canvas, pos, _colorLuna, alpha, p.simbolo, blanco: true);
        } else if (nombre == 'ascendente') {
          _dibujarAscendente(canvas, pos, alpha, p.simbolo);
        } else {
          _dibujarPlanetaGenerico(canvas, pos, alpha, p.simbolo);
        }

        // Etiqueta de grados si está seleccionado
        if (seleccionado == p.nombre) {
          final grados = (p.longitud % 30).toStringAsFixed(1);
          final lbl = TextPainter(
            text: TextSpan(
              text: '$grados°',
              style: const TextStyle(fontSize: 8, color: _dorado, fontWeight: FontWeight.w600),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          lbl.paint(canvas, pos + Offset(-lbl.width / 2, 12));
        }
      }
    }
  }

  void _dibujarPlaneta(Canvas canvas, Offset pos, Color color, double alpha,
      String simbolo, {bool blanco = false}) {
    canvas.drawCircle(pos, 13, Paint()..color = color.withValues(alpha: 0.12 * alpha));
    canvas.drawCircle(pos, 8,  Paint()..color = color.withValues(alpha: 0.28 * alpha));
    canvas.drawCircle(pos, 5,  Paint()..color = color.withValues(alpha: alpha));
    _pintarSimbolo(canvas, pos, simbolo, 10, Colors.white.withValues(alpha: 0.9 * alpha));
  }

  void _dibujarPlanetaGenerico(Canvas canvas, Offset pos, double alpha, String simbolo) {
    canvas.drawCircle(pos, 8, Paint()
      ..color = const Color(0xFFF3EBD6).withValues(alpha: alpha));
    canvas.drawCircle(pos, 8, Paint()
      ..color = Colors.black.withValues(alpha: 0.14 * alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8);
    _pintarSimbolo(canvas, pos, simbolo, 11, Colors.black.withValues(alpha: 0.65 * alpha));
  }

  void _dibujarAscendente(Canvas canvas, Offset pos, double alpha, String simbolo) {
    canvas.drawCircle(pos, 8, Paint()
      ..color = const Color(0xFF7EB8C9).withValues(alpha: 0.25 * alpha));
    canvas.drawCircle(pos, 8, Paint()
      ..color = const Color(0xFF7EB8C9).withValues(alpha: 0.6 * alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0);
    _pintarSimbolo(canvas, pos, simbolo, 11, const Color(0xFF7EB8C9).withValues(alpha: alpha));
  }

  void _pintarSimbolo(Canvas canvas, Offset pos, String simbolo, double fontSize, Color color) {
    final sym = TextPainter(
      text: TextSpan(text: simbolo, style: _simStyle(fontSize, color)),
      textDirection: TextDirection.ltr,
    )..layout();
    sym.paint(canvas, pos - Offset(sym.width / 2, sym.height / 2));
  }

  // ── Líneas de aspecto ────────────────────────────────────────────────────

  // Aspectos: usamos posiciones de centro de signo (múltiplos exactos de 30°),
  // por lo que los aspectos entre signos son exactos — orb ±3° para capturar
  // solo pares que realmente forman el aspecto.
  void _aspectos(Canvas canvas, Offset centro, double radio) {
    if (planetas.length < 2) return;
    for (int i = 0; i < planetas.length; i++) {
      for (int j = i + 1; j < planetas.length; j++) {
        final diff = (planetas[i].longitud - planetas[j].longitud).abs() % 360;
        final d    = diff > 180 ? 360 - diff : diff;

        // Ignorar planetas en el mismo signo (línea de longitud cero)
        if (d < 3) continue;

        final a1 = (planetas[i].longitud - 90) * pi / 180;
        final a2 = (planetas[j].longitud - 90) * pi / 180;
        final p1 = Offset(centro.dx + radio * cos(a1), centro.dy + radio * sin(a1));
        final p2 = Offset(centro.dx + radio * cos(a2), centro.dy + radio * sin(a2));

        // Sextil 60° — línea punteada suave
        if ((d - 60).abs() < 3) {
          _lineaEstilizada(canvas, p1, p2,
              Paint()..color = Colors.black.withValues(alpha: 0.20)..strokeWidth = 0.7,
              dashOn: 2.0, dashOff: 5.0);
        }
        // Cuadratura 90° — guiones medianos
        else if ((d - 90).abs() < 3) {
          _lineaEstilizada(canvas, p1, p2,
              Paint()..color = Colors.black.withValues(alpha: 0.35)..strokeWidth = 0.9,
              dashOn: 6.0, dashOff: 4.0);
        }
        // Trígono 120° — línea sólida suave
        else if ((d - 120).abs() < 3) {
          canvas.drawLine(p1, p2,
              Paint()..color = Colors.black.withValues(alpha: 0.22)..strokeWidth = 0.8);
        }
        // Oposición 180° — guiones largos
        else if ((d - 180).abs() < 3) {
          _lineaEstilizada(canvas, p1, p2,
              Paint()..color = Colors.black.withValues(alpha: 0.40)..strokeWidth = 1.0,
              dashOn: 12.0, dashOff: 5.0);
        }
      }
    }
  }

  void _lineaEstilizada(Canvas canvas, Offset p1, Offset p2, Paint paint,
      {double dashOn = 3.0, double dashOff = 4.0}) {
    final dx  = p2.dx - p1.dx;
    final dy  = p2.dy - p1.dy;
    final len = sqrt(dx * dx + dy * dy);
    if (len == 0) return;
    final ux = dx / len;
    final uy = dy / len;
    double dist = 0;
    bool on = true;
    while (dist < len) {
      final step = on ? dashOn : dashOff;
      final end  = dist + step;
      if (on) {
        canvas.drawLine(
          Offset(p1.dx + ux * dist,            p1.dy + uy * dist),
          Offset(p1.dx + ux * (end < len ? end : len), p1.dy + uy * (end < len ? end : len)),
          paint,
        );
      }
      dist += step;
      on = !on;
    }
  }

  void _estrella4(Canvas canvas, Offset c, double r) {
    final path = Path();
    for (int i = 0; i < 4; i++) {
      final ap = (i * 90 - 90) * pi / 180;
      final ai = (i * 90 - 45) * pi / 180;
      final px = c.dx + r * cos(ap);
      final py = c.dy + r * sin(ap);
      final ix = c.dx + r * 0.3 * cos(ai);
      final iy = c.dy + r * 0.3 * sin(ai);
      if (i == 0) { path.moveTo(px, py); } else { path.lineTo(px, py); }
      path.lineTo(ix, iy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = _dorado..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(RuedaZodiacalPainter old) =>
      old.planetas != planetas || old.seleccionado != seleccionado;
}
