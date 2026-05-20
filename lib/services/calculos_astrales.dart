import 'dart:math';

/// Resultado de la carta astral de una persona
class CartaAstral {
  final String signoSolar;
  final String signoLunar;
  final String ascendente;
  // Signos de planetas personales y sociales (nivel de signo, ~±5°)
  final Map<String, String> planetas;
  // Casa (1–12) de cada planeta, usando sistema de casas iguales
  final Map<String, int> casas;

  CartaAstral({
    required this.signoSolar,
    required this.signoLunar,
    required this.ascendente,
    this.planetas = const {},
    this.casas = const {},
  });
}

class CalculosAstrales {

  // ── Helpers básicos ──────────────────────────────────────────────────────────

  static double _n(double d) => ((d % 360) + 360) % 360;
  static double _r(double d) => d * pi / 180;
  static double _sd(double d) => sin(_r(_n(d)));
  static double _cd(double d) => cos(_r(_n(d)));

  /// JD desde J2000.0 incluyendo fracción horaria
  static double _jd(DateTime f, [int h = 0, int m = 0]) {
    final a = (14 - f.month) ~/ 12;
    final y = f.year + 4800 - a;
    final mo = f.month + 12 * a - 3;
    final jdn = f.day + (153 * mo + 2) ~/ 5 + 365 * y +
        y ~/ 4 - y ~/ 100 + y ~/ 400 - 32045;
    return jdn - 2451545.0 + (h + m / 60.0 - 12.0) / 24.0;
  }

  /// Resuelve la ecuación de Kepler E - e·sin(E) = M (radianes)
  static double _kepler(double Mrad, double e) {
    double E = Mrad;
    for (int i = 0; i < 10; i++) {
      E -= (E - e * sin(E) - Mrad) / (1.0 - e * cos(E));
    }
    return E;
  }

  // ── Sol (Meeus cap. 27) ──────────────────────────────────────────────────────

  static double _lonSol(double T) {
    final L0 = _n(280.46646  + 36000.76983  * T);
    final M  = _n(357.52911  + 35999.05029  * T);
    final C  = (1.914602 - 0.004817 * T) * _sd(M)
             + (0.019993 - 0.000101 * T) * _sd(2 * M)
             +  0.000289                 * _sd(3 * M);
    return _n(L0 + C);
  }

  // ── Luna (ELP2000 truncado, Meeus cap. 47) ──────────────────────────────────

  static double _lonLuna(double T) {
    final Lp = _n(218.3165 + 481267.8813 * T);   // long. media
    final M  = _n(357.5291 +  35999.0503 * T);   // anomalía sol
    final Mp = _n(134.9634 + 477198.8676 * T);   // anomalía luna
    final D  = _n(297.8502 + 445267.1115 * T);   // elongación
    final F  = _n( 93.2721 + 483202.0175 * T);   // arg. latitud

    // Términos principales de longitud (Meeus tabla 47.A), en 0.000001°
    double sl = 0;
    sl += 6288774 * _sd(Mp);
    sl += 1274027 * _sd(2*D - Mp);
    sl +=  658314 * _sd(2*D);
    sl +=  213618 * _sd(2*Mp);
    sl -=  185116 * _sd(M);
    sl -=  114332 * _sd(2*F);
    sl +=   58793 * _sd(2*D - 2*Mp);
    sl +=   57066 * _sd(2*D - M - Mp);
    sl +=   53322 * _sd(2*D + Mp);
    sl +=   45758 * _sd(2*D - M);
    sl -=   40923 * _sd(M - Mp);
    sl -=   34720 * _sd(D);
    sl -=   30383 * _sd(M + Mp);
    sl +=   15327 * _sd(2*D - 2*F);
    sl -=   12528 * _sd(Mp + 2*F);
    sl +=   10980 * _sd(2*F);
    sl +=   10675 * _sd(4*D - Mp);
    sl +=   10034 * _sd(3*Mp);
    sl +=    8548 * _sd(4*D - 2*Mp);
    sl -=    7888 * _sd(2*D + M - Mp);
    sl -=    6766 * _sd(2*D + M);
    sl -=    5163 * _sd(D - Mp);
    sl +=    4987 * _sd(D + M);
    sl +=    4036 * _sd(2*D - M + Mp);
    sl +=    3994 * _sd(2*D + 2*Mp);
    sl +=    3861 * _sd(4*D);
    sl +=    3665 * _sd(2*D - 3*Mp);
    sl -=    2689 * _sd(M - 2*Mp);
    sl -=    2602 * _sd(2*D - Mp - 2*F);
    sl +=    2390 * _sd(2*D - M - 2*Mp);
    sl -=    2348 * _sd(D + Mp);
    sl +=    2236 * _sd(2*D - 2*M);
    sl -=    2120 * _sd(M + 2*Mp);
    sl -=    2069 * _sd(2*M);
    sl +=    2048 * _sd(2*D - 2*M - Mp);
    sl -=    1773 * _sd(2*D + Mp - 2*F);
    sl -=    1595 * _sd(2*D + 2*F);
    sl +=    1215 * _sd(4*D - M - Mp);
    sl -=    1110 * _sd(2*Mp + 2*F);
    sl -=     892 * _sd(3*D - Mp);
    sl -=     810 * _sd(2*D + M + Mp);
    sl +=     759 * _sd(4*D - M - 2*Mp);
    sl -=     713 * _sd(2*M - Mp);
    sl -=     700 * _sd(2*D + 2*M - Mp);
    sl +=     691 * _sd(2*D + M - 2*Mp);
    sl +=     596 * _sd(2*D - M - 2*F);
    sl +=     549 * _sd(4*D + Mp);
    sl +=     537 * _sd(4*Mp);
    sl +=     520 * _sd(4*D - M);
    sl -=     487 * _sd(D - 2*Mp);
    sl -=     399 * _sd(2*D + M - 2*F);
    sl -=     381 * _sd(2*Mp - 2*F);
    sl +=     351 * _sd(D + M + Mp);
    sl -=     340 * _sd(3*D - 2*Mp);
    sl +=     330 * _sd(4*D - 3*Mp);
    sl +=     327 * _sd(2*D - M + 2*Mp);
    sl -=     323 * _sd(2*M + Mp);
    sl +=     299 * _sd(D + M - Mp);
    sl +=     294 * _sd(2*D + 3*Mp);

    return _n(Lp + sl * 1e-6);
  }

  // ── Planetas (Meeus cap. 33, órbitas kepleranas geocéntricas) ───────────────

  // Elementos orbitales: [L0, L_rate, a, e, i, Ω, ω] en grados/AU
  static const _orbitas = <String, List<double>>{
    'Mercurio': [252.25090, 149472.67463, 0.38710, 0.20563, 7.005,  48.331,  77.456],
    'Venus':    [181.97980,  58517.81567, 0.72333, 0.00677, 3.395,  76.680, 131.564],
    'Tierra':   [100.46457,  35999.37244, 1.00000, 0.01671, 0.000,   0.000, 102.937],
    'Marte':    [355.43300,  19140.29934, 1.52366, 0.09340, 1.850,  49.558, 336.060],
    'Júpiter':  [ 34.35151,   3034.90567, 5.20336, 0.04839, 1.303, 100.464,  14.331],
    'Saturno':  [ 50.07744,   1222.11383, 9.53707, 0.05415, 2.489, 113.666,  93.057],
    'Urano':    [314.05501,    428.46895,19.19126, 0.04717, 0.773,  74.230, 173.005],
    'Neptuno':  [304.34866,    218.45945,30.06896, 0.00859, 1.770, 131.784,  48.124],
    'Plutón':   [238.92903,    145.20780,39.48168, 0.24883,17.140, 110.299, 224.068],
  };

  /// Calcula posición heliocéntrica rectangulare eclíptica para un planeta
  static List<double> _heliocentrico(String planeta, double T) {
    final o = _orbitas[planeta]!;
    final L = _n(o[0] + o[1] * T);
    final a = o[2];
    final e = o[3];
    final i = o[4];
    final Om = o[5];   // longitud nodo ascendente
    final w  = o[6];   // longitud perihelio

    final M = _r(_n(L - w));
    final E = _kepler(M, e);
    final nu = 2.0 * atan2(sqrt(1 + e) * sin(E / 2), sqrt(1 - e) * cos(E / 2));
    final r  = a * (1 - e * cos(E));

    // u = argumento de latitud = arg. perihelio + anomalía verdadera
    final iR   = _r(i);
    final OmR  = _r(Om);
    final u    = _r(_n(w - Om)) + nu;   // ω̃ - Ω = arg. perihelio
    final x = r * (cos(OmR) * cos(u) - sin(OmR) * sin(u) * cos(iR));
    final y = r * (sin(OmR) * cos(u) + cos(OmR) * sin(u) * cos(iR));
    final z = r * sin(u) * sin(iR);
    return [x, y, z];
  }

  /// Longitud geocéntrica eclíptica de un planeta exterior/interior
  static double _lonPlaneta(String planeta, double T) {
    final tierra = _heliocentrico('Tierra', T);
    final p      = _heliocentrico(planeta, T);
    final dx = p[0] - tierra[0];
    final dy = p[1] - tierra[1];
    return _n(atan2(dy, dx) * 180 / pi);
  }

  // ── API pública ──────────────────────────────────────────────────────────────

  static String calcularSignoSolar(DateTime fecha, {int hora = 0, int minutos = 0}) =>
      _gradosASigno(_lonSol(_jd(fecha, hora, minutos) / 36525.0));

  static String calcularSignoLunar(DateTime fecha, {int hora = 0, int minutos = 0}) =>
      _gradosASigno(_lonLuna(_jd(fecha, hora, minutos) / 36525.0));

  static String calcularAscendente(
    DateTime fecha, int horaN, int minutosN,
    double latitud, double longitud,
  ) => _gradosASigno(_lonAscendente(fecha, horaN, minutosN, latitud, longitud));

  static double calcularLongitudAscendente(
    DateTime fecha, int horaN, int minutosN,
    double latitud, double longitud,
  ) => _lonAscendente(fecha, horaN, minutosN, latitud, longitud);

  static CartaAstral calcular({
    required DateTime fechaNacimiento,
    required int hora,
    required int minutos,
    double latitud = 0,
    double longitud = 0,
  }) {
    final planetas = calcularPlanetas(fechaNacimiento, hora, minutos);
    final casas    = calcularCasas(fechaNacimiento, hora, minutos, latitud, longitud);
    return CartaAstral(
      signoSolar: calcularSignoSolar(fechaNacimiento, hora: hora, minutos: minutos),
      signoLunar: calcularSignoLunar(fechaNacimiento, hora: hora, minutos: minutos),
      ascendente: calcularAscendente(fechaNacimiento, hora, minutos, latitud, longitud),
      planetas: planetas,
      casas: casas,
    );
  }

  static Map<String, String> calcularPlanetas(DateTime fecha, int hora, int min) {
    final lons = calcularLongitudes(fecha, hora, min);
    return lons.map((k, v) => MapEntry(k, _gradosASigno(v)));
  }

  /// Longitudes eclípticas crudas (0–360°) de todos los planetas
  static Map<String, double> calcularLongitudes(DateTime fecha, int hora, int min) {
    final T = _jd(fecha, hora, min) / 36525.0;
    return {
      'Sol':      _lonSol(T),
      'Luna':     _lonLuna(T),
      'Mercurio': _lonPlaneta('Mercurio', T),
      'Venus':    _lonPlaneta('Venus',    T),
      'Marte':    _lonPlaneta('Marte',    T),
      'Júpiter':  _lonPlaneta('Júpiter',  T),
      'Saturno':  _lonPlaneta('Saturno',  T),
      'Urano':    _lonPlaneta('Urano',    T),
      'Neptuno':  _lonPlaneta('Neptuno',  T),
      'Plutón':   _lonPlaneta('Plutón',   T),
    };
  }

  static Map<String, int> calcularCasas(
    DateTime fecha, int hora, int min,
    double latitud, double longitud,
  ) {
    final T      = _jd(fecha, hora, min) / 36525.0;
    final ascLon = _lonAscendente(fecha, hora, min, latitud, longitud);
    final lones  = <String, double>{
      'Sol':      _lonSol(T),
      'Luna':     _lonLuna(T),
      'Mercurio': _lonPlaneta('Mercurio', T),
      'Venus':    _lonPlaneta('Venus',    T),
      'Marte':    _lonPlaneta('Marte',    T),
      'Júpiter':  _lonPlaneta('Júpiter',  T),
      'Saturno':  _lonPlaneta('Saturno',  T),
      'Urano':    _lonPlaneta('Urano',    T),
      'Neptuno':  _lonPlaneta('Neptuno',  T),
      'Plutón':   _lonPlaneta('Plutón',   T),
    };
    return lones.map((p, lon) {
      final casa = ((lon - ascLon + 360) % 360 / 30).floor() + 1;
      return MapEntry(p, casa);
    });
  }

  // ── Ascendente ───────────────────────────────────────────────────────────────

  /// Snaps longitude to nearest whole-hour UTC offset (e.g. -99° → -7h)
  static double _utcOffset(double longitud) => (longitud / 15.0).roundToDouble();

  static double _lonAscendente(
    DateTime fecha, int horaN, int minutosN,
    double latitud, double longitud,
  ) {
    // GMST at UT midnight of birth date
    final jd0  = _jd(fecha);
    final gmst = _n(280.46061837 + 360.98564736629 * jd0);

    // Convert local birth time to UT using longitude-snapped offset
    final utcOffset = _utcOffset(longitud);
    final utHours   = horaN + minutosN / 60.0 - utcOffset;

    // RAMC = GMST + UT_hours * sidereal_rate + east_longitude
    const sidRate = 360.98564736629 / 24.0; // °/hour
    final ramc = _n(gmst + utHours * sidRate + longitud);

    final latR  = _r(latitud);
    final oblR  = _r(23.4392911);
    final ramcR = _r(ramc);

    var asc = atan2(cos(ramcR),
        -(sin(ramcR) * cos(oblR) + tan(latR) * sin(oblR))) * 180 / pi;
    if (asc < 0) asc += 360;
    return asc;
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  static String _gradosASigno(double grados) {
    const signos = [
      'Aries', 'Tauro', 'Géminis', 'Cáncer', 'Leo', 'Virgo',
      'Libra', 'Escorpio', 'Sagitario', 'Capricornio', 'Acuario', 'Piscis'
    ];
    return signos[(_n(grados) / 30).floor() % 12];
  }
}

// ─────────────────────────────────────────
// DATOS: símbolo y descripción de cada signo
// ─────────────────────────────────────────

// ─────────────────────────────────────────
// ARQUETIPO ROMÁNTICO (sistema de 16 tipos)
// 4 indicadores binarios ABCD:
//   A = Sol-Sol armónico
//   B = Venus-Marte cruzado armónico (ambas direcciones)
//   C = Luna-Luna armónico
//   D = Ascendente-Ascendente armónico
// Distancias armónicas: 0 (conjunción), 4/8 (trino), 2/10 (sextil)
// ─────────────────────────────────────────

const List<String> _signosOrden = [
  'Aries', 'Tauro', 'Géminis', 'Cáncer', 'Leo', 'Virgo',
  'Libra', 'Escorpio', 'Sagitario', 'Capricornio', 'Acuario', 'Piscis',
];

const Set<int> _distanciasArmonicas = {0, 2, 4, 8, 10};

int _distanciaSignos(String s1, String s2) {
  final i1 = _signosOrden.indexOf(s1);
  final i2 = _signosOrden.indexOf(s2);
  if (i1 < 0 || i2 < 0) return 6;
  final d = (i2 - i1 + 12) % 12;
  return d <= 6 ? d : 12 - d;
}

bool _armonico(String s1, String s2) =>
    _distanciasArmonicas.contains(_distanciaSignos(s1, s2));

// Score continuo 0.0–1.0 según distancia entre signos (±3% de varianza)
double _scoreDistancia(String s1, String s2) {
  const tabla = {0: 0.97, 1: 0.30, 2: 0.82, 3: 0.12, 4: 0.94, 5: 0.18, 6: 0.55};
  final base = tabla[_distanciaSignos(s1, s2)]?.toDouble() ?? 0.50;
  final jitter = (Random().nextDouble() * 0.06) - 0.03;
  return (base + jitter).clamp(0.0, 1.0);
}

Map<String, double> calcularScoresSinastria({
  required String miSolar,    required String amigoSolar,
  required String miLunar,    required String amigoLunar,
  required String miAsc,      required String amigoAsc,
  required Map<String, String> miPlanetas,
  required Map<String, String> amigoPlanetas,
}) {
  final miVenus = miPlanetas['Venus']    ?? 'Aries';
  final miMarte = miPlanetas['Marte']    ?? 'Aries';
  final suVenus = amigoPlanetas['Venus'] ?? 'Aries';
  final suMarte = amigoPlanetas['Marte'] ?? 'Aries';

  return {
    'identidad': _scoreDistancia(miSolar, amigoSolar),
    'emocion':   _scoreDistancia(miLunar, amigoLunar),
    'atraccion': (_scoreDistancia(miVenus, suMarte) + _scoreDistancia(suVenus, miMarte)) / 2,
    'presencia': _scoreDistancia(miAsc, amigoAsc),
  };
}

const List<String> _arquetipos = [
  'Jardín Sereno',        // 0000
  'Cruz de Caminos',      // 0001
  'Sen',                  // 0010
  'Delusional',           // 0011
  'Vértigo',              // 0100
  'Nudo Kármico',         // 0101
  'El Hechizo',           // 0110
  'Umbral',               // 0111
  'Flor de Loto',         // 1000
  'El Espiral y el Ciclo',// 1001
  'Animo Flore',          // 1010
  'Los Alquimistas',      // 1011
  'Amor Fati',            // 1100
  'Sublime',              // 1101
  'La Maravilla',         // 1110
  'Sahacara',             // 1111
];

String calcularArquetipo({
  required String miSolar,    required String amigoSolar,
  required String miLunar,    required String amigoLunar,
  required String miAsc,      required String amigoAsc,
  required Map<String, String> miPlanetas,
  required Map<String, String> amigoPlanetas,
}) {
  final miVenus  = miPlanetas['Venus']    ?? 'Aries';
  final miMarte  = miPlanetas['Marte']    ?? 'Aries';
  final suVenus  = amigoPlanetas['Venus'] ?? 'Aries';
  final suMarte  = amigoPlanetas['Marte'] ?? 'Aries';

  final a = _armonico(miSolar, amigoSolar) ? 1 : 0;
  final b = (_armonico(miVenus, suMarte) && _armonico(suVenus, miMarte)) ? 1 : 0;
  final c = _armonico(miLunar, amigoLunar) ? 1 : 0;
  final d = _armonico(miAsc, amigoAsc) ? 1 : 0;

  final indice = (a << 3) | (b << 2) | (c << 1) | d;
  return _arquetipos[indice];
}

const Map<String, String> simbolosSignos = {
  'Aries': '♈',
  'Tauro': '♉',
  'Géminis': '♊',
  'Cáncer': '♋',
  'Leo': '♌',
  'Virgo': '♍',
  'Libra': '♎',
  'Escorpio': '♏',
  'Sagitario': '♐',
  'Capricornio': '♑',
  'Acuario': '♒',
  'Piscis': '♓',
};

const Map<String, Map<String, String>> descripcionesSignos = {
  'Aries': {
    'sol': 'Eres pura energía e iniciativa. Pionero por naturaleza, vas primero y preguntas después. Tu fuego interior enciende todo lo que tocas.',
    'luna': 'Tus emociones son intensas y rápidas. Reaccionas desde el instinto y te recuperas igual de rápido. Necesitas espacio para ser libre.',
    'ascendente': 'Los demás te perciben como alguien directo, enérgico y seguro de sí mismo. Tu presencia es inmediata e inconfundible.',
  },
  'Tauro': {
    'sol': 'Eres constante, sensorial y profundamente conectado con lo tangible. Construyes con paciencia y disfrutas cada paso del camino.',
    'luna': 'Encuentras paz en la estabilidad y la rutina. Tus afectos son profundos y duraderos. La belleza y el confort nutren tu alma.',
    'ascendente': 'Proyectas calma, solidez y confiabilidad. La gente siente que puede apoyarse en ti. Tu presencia es reconfortante.',
  },
  'Géminis': {
    'sol': 'Tu mente es tu mayor don. Curioso, adaptable y brillante, puedes hablar de cualquier tema con cualquier persona.',
    'luna': 'Procesas las emociones pensándolas. Necesitas variedad y estimulación mental para sentirte bien. Tu mundo interior es inquieto y vivo.',
    'ascendente': 'Te perciben como alguien inteligente, comunicativo y difícil de aburrir. Tienes el don de conectar con todos.',
  },
  'Cáncer': {
    'sol': 'Eres profundamente intuitivo y empático. Tu hogar y familia son tu mundo. Tienes una memoria emocional extraordinaria.',
    'luna': 'La luna está en casa aquí. Tus emociones son ricas, cambiantes y muy profundas. Necesitas sentirte seguro para abrirte.',
    'ascendente': 'Proyectas calidez y cuidado. La gente instintivamente quiere contarte sus problemas. Tu sensibilidad es visible.',
  },
  'Leo': {
    'sol': 'Eres magnético, creativo y naciste para brillar. Tu generosidad y calidez iluminan todo a tu alrededor.',
    'luna': 'Necesitas reconocimiento y amor para florecer emocionalmente. Eres leal y expresivo con quienes amas.',
    'ascendente': 'Entras a un cuarto y la gente lo nota. Proyectas confianza, elegancia y una presencia que no pasa desapercibida.',
  },
  'Virgo': {
    'sol': 'Eres analítico, detallista y profundamente dedicado. Tu mente ve lo que otros ignoran y tu trabajo siempre está bien hecho.',
    'luna': 'Procesas las emociones analizándolas. Tiendes a preocuparte, pero también eres increíblemente atento con las personas que amas.',
    'ascendente': 'Te perciben como alguien cuidadoso, inteligente y confiable. Das una primera impresión de persona que tiene todo bajo control.',
  },
  'Libra': {
    'sol': 'Buscas el equilibrio y la armonía en todo. Eres diplomático, estético y tienes un sentido innato de la justicia.',
    'luna': 'Necesitas paz y armonía para sentirte bien. Las relaciones son esenciales para tu bienestar emocional.',
    'ascendente': 'Proyectas encanto, elegancia y amabilidad. La gente te percibe como alguien fácil de tratar y con buen gusto.',
  },
  'Escorpio': {
    'sol': 'Eres intenso, perceptivo y transformador. Vas a las profundidades donde otros no se atreven. Tu poder es silencioso y real.',
    'luna': 'Tus emociones son poderosas y reservadas. Sientes todo profundamente pero muestras poco. La lealtad lo es todo para ti.',
    'ascendente': 'Proyectas misterio e intensidad. La gente siente que hay mucho más detrás de tus ojos. Tu presencia magnética.',
  },
  'Sagitario': {
    'sol': 'Eres libre, filosófico y eternamente optimista. El mundo es tu aula y la aventura tu estado natural.',
    'luna': 'Necesitas libertad emocional y espacio para explorar. Las restricciones te ahogan. Tu alegría es contagiosa.',
    'ascendente': 'Te perciben como alguien abierto, aventurero y honesto. Proyectas entusiasmo y una visión amplia de la vida.',
  },
  'Capricornio': {
    'sol': 'Eres ambicioso, disciplinado y construyes para el largo plazo. Tu paciencia y determinación no tienen igual.',
    'luna': 'Gestionas las emociones con estructura. No siempre las muestras, pero las sientes hondo. La responsabilidad te da seguridad.',
    'ascendente': 'Proyectas madurez, seriedad y competencia. La gente te respeta desde el primer momento.',
  },
  'Acuario': {
    'sol': 'Eres visionario, original e independiente. Piensas en el futuro cuando otros aún viven el pasado.',
    'luna': 'Procesas las emociones desde la distancia. Necesitas libertad para sentirte bien. Tu empatía es colectiva más que individual.',
    'ascendente': 'Te perciben como alguien diferente, intelectual y difícil de encasillar. Destacas sin proponértelo.',
  },
  'Piscis': {
    'sol': 'Eres intuitivo, compasivo y profundamente creativo. Vives entre dos mundos: el visible y el que solo tú puedes sentir.',
    'luna': 'Eres extraordinariamente sensible y empático. Absorbes las emociones de tu entorno. Necesitas soledad para recargarte.',
    'ascendente': 'Proyectas suavidad, misterio y una sensibilidad especial. La gente siente que eres difícil de definir, y eso te hace fascinante.',
  },
};
