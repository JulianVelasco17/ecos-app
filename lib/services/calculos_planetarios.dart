import 'dart:math';

class PlanetaInfo {
  final String nombre;
  final String simbolo;
  final String signo;
  final String simboloSigno;
  final double longitud; // 0–360 grados eclípticos

  const PlanetaInfo({
    required this.nombre,
    required this.simbolo,
    required this.signo,
    required this.simboloSigno,
    required this.longitud,
  });
}

class CalculosPlanetarios {
  static const _signos = [
    'Aries', 'Tauro', 'Géminis', 'Cáncer', 'Leo', 'Virgo',
    'Libra', 'Escorpio', 'Sagitario', 'Capricornio', 'Acuario', 'Piscis',
  ];
  static const _simbolosSignos = [
    'ARI','TAU','GEM','CAN','LEO','VIR',
    'LIB','ESC','SAG','CAP','ACU','PIS',
  ];

  static List<PlanetaInfo> calcularPosiciones(DateTime fecha) {
    final jd = _julianDate(fecha);
    final T = (jd - 2451545.0) / 36525.0;

    // Longitudes medias eclípticas (Jean Meeus, Astronomical Algorithms)
    final raw = [
      ('Sol',      '☉', _sol(T)),
      ('Luna',     '☽', _luna(T)),
      ('Mercurio', '☿', _norm(252.2507 + 149474.0699 * T)),
      ('Venus',    '♀', _norm(181.9798 +  58517.8156 * T)),
      ('Marte',    '♂', _norm(355.4330 +  19140.2993 * T)),
      ('Júpiter',  '♃', _norm( 34.3510 +   3034.9057 * T)),
      ('Saturno',  '♄', _norm( 50.0774 +   1222.1138 * T)),
    ];

    return raw.map((p) {
      final idx = (p.$3 / 30).floor() % 12;
      return PlanetaInfo(
        nombre: p.$1,
        simbolo: p.$2,
        signo: _signos[idx],
        simboloSigno: _simbolosSignos[idx],
        longitud: p.$3,
      );
    }).toList();
  }

  // Sol con corrección de ecuación del centro
  static double _sol(double T) {
    final L0 = _norm(280.46646 + 36000.76983 * T);
    final M  = _norm(357.52911 + 35999.05029 * T) * pi / 180;
    final C  = (1.914602 - 0.004817 * T) * sin(M)
             + 0.019993 * sin(2 * M);
    return _norm(L0 + C);
  }

  // Luna — fórmula extendida de Meeus (Astronomical Algorithms cap. 47)
  static double _luna(double T) {
    final L  = _norm(218.3164477 + 481267.88123421 * T - 0.0015786 * T * T);
    final M  = _norm(357.5291092 +  35999.0502909 * T) * pi / 180;  // anomalía Sol
    final Mp = _norm(134.9633964 + 477198.8675055 * T + 0.0087414 * T * T) * pi / 180;
    final D  = _norm(297.8501921 + 445267.1114034 * T - 0.0018819 * T * T) * pi / 180;
    final F  = _norm( 93.2720950 + 483202.0175233 * T - 0.0036539 * T * T) * pi / 180;

    // 30 términos principales (Meeus Tabla 47.A), en grados
    final corr =
        6.288774 * sin(Mp)
      - 1.274027 * sin(2*D - Mp)
      + 0.658314 * sin(2*D)
      + 0.213618 * sin(2*Mp)          // 4to término — faltaba
      - 0.185116 * sin(M)
      - 0.114332 * sin(2*F)           // coeficiente corregido (era -0.046)
      + 0.058793 * sin(2*D - 2*Mp)
      + 0.057066 * sin(2*D - M - Mp)
      + 0.053322 * sin(2*D + Mp)
      + 0.045758 * sin(2*D - M)
      - 0.040923 * sin(M - Mp)
      - 0.034720 * sin(D)
      - 0.030383 * sin(M + Mp)
      + 0.015327 * sin(2*D - 2*F)
      - 0.012528 * sin(Mp + 2*F)
      + 0.010980 * sin(Mp - 2*F)
      + 0.010675 * sin(4*D - Mp)
      + 0.010034 * sin(3*Mp)
      + 0.008548 * sin(4*D - 2*Mp)
      - 0.007888 * sin(2*D + M - Mp)
      - 0.006766 * sin(2*D + M)
      - 0.005163 * sin(D - Mp)
      + 0.004987 * sin(D + M)
      + 0.004036 * sin(2*D - M + Mp)
      + 0.003994 * sin(2*D + 2*Mp)
      + 0.003861 * sin(4*D)
      + 0.003665 * sin(2*D - 3*Mp)
      - 0.002689 * sin(M - 2*Mp)
      - 0.002602 * sin(2*D - Mp + 2*F)
      + 0.002390 * sin(2*D - M - 2*Mp);

    return _norm(L + corr);
  }

  static double _norm(double deg) => ((deg % 360) + 360) % 360;

  static double _julianDate(DateTime f) {
    int y = f.year, m = f.month;
    final d = f.day + f.hour / 24.0;
    if (m <= 2) { y--; m += 12; }
    final A = (y / 100).floor();
    final B = 2 - A + (A / 4).floor();
    return (365.25 * (y + 4716)).floor()
         + (30.6001 * (m + 1)).floor()
         + d + B - 1524.5;
  }
}
