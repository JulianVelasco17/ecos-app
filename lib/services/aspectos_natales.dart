import 'calculos_planetarios.dart';

class AspectoNatal {
  final String planeta1;
  final String planeta2;
  final String tipo;
  final double orbe;

  const AspectoNatal({
    required this.planeta1,
    required this.planeta2,
    required this.tipo,
    required this.orbe,
  });

  String get etiqueta => '$planeta1 $tipo $planeta2';
}

class AspectosNatales {
  static const _tipos = [
    (0.0,   'en conjunción con', 8.0),
    (60.0,  'en sextil con',     6.0),
    (90.0,  'en cuadratura con', 7.0),
    (120.0, 'en trígono con',    8.0),
    (180.0, 'en oposición con',  8.0),
  ];

  static const _nombreCorto = {
    'en conjunción con': 'Conjunción',
    'en sextil con':     'Sextil',
    'en cuadratura con': 'Cuadratura',
    'en trígono con':    'Trígono',
    'en oposición con':  'Oposición',
  };

  static const significados = {
    'Conjunción': 'fusión e intensidad — ambas energías amplifican',
    'Sextil':     'fluidez natural — oportunidades sin esfuerzo',
    'Cuadratura': 'tensión creativa — el conflicto que hace crecer',
    'Trígono':    'armonía — talento que fluye fácil',
    'Oposición':  'polaridad — aprendes a través del otro extremo',
  };

  static List<AspectoNatal> calcular(DateTime fecha, int hora, int min) {
    final dt = DateTime(fecha.year, fecha.month, fecha.day, hora, min);
    final planetas = CalculosPlanetarios.calcularPosiciones(dt);
    final resultados = <AspectoNatal>[];

    for (int i = 0; i < planetas.length; i++) {
      for (int j = i + 1; j < planetas.length; j++) {
        var diff = (planetas[i].longitud - planetas[j].longitud).abs();
        if (diff > 180) diff = 360 - diff;

        for (final (angulo, nombre, orbeMax) in _tipos) {
          final orbe = (diff - angulo).abs();
          if (orbe <= orbeMax) {
            resultados.add(AspectoNatal(
              planeta1: planetas[i].nombre,
              planeta2: planetas[j].nombre,
              tipo: nombre,
              orbe: orbe,
            ));
            break;
          }
        }
      }
    }

    resultados.sort((a, b) => a.orbe.compareTo(b.orbe));
    return resultados.take(5).toList();
  }

  // Compara las cartas de dos personas (sinastría)
  static List<AspectoNatal> calcularSinastria(
    DateTime fecha1, int hora1, int min1,
    DateTime fecha2, int hora2, int min2,
  ) {
    final p1 = CalculosPlanetarios.calcularPosiciones(
        DateTime(fecha1.year, fecha1.month, fecha1.day, hora1, min1));
    final p2 = CalculosPlanetarios.calcularPosiciones(
        DateTime(fecha2.year, fecha2.month, fecha2.day, hora2, min2));

    // Solo los primeros 5 (Sol, Luna, Mercurio, Venus, Marte)
    final key1 = p1.take(5).toList();
    final key2 = p2.take(5).toList();
    final resultados = <AspectoNatal>[];

    for (final a in key1) {
      for (final b in key2) {
        var diff = (a.longitud - b.longitud).abs();
        if (diff > 180) diff = 360 - diff;

        for (final (angulo, nombre, orbeMax) in _tipos) {
          final orbe = (diff - angulo).abs();
          if (orbe <= orbeMax) {
            resultados.add(AspectoNatal(
              planeta1: a.nombre,
              planeta2: b.nombre,
              tipo: nombre,
              orbe: orbe,
            ));
            break;
          }
        }
      }
    }

    resultados.sort((a, b) => a.orbe.compareTo(b.orbe));
    return resultados.take(4).toList();
  }

  static String nombreCorto(String tipo) => _nombreCorto[tipo] ?? tipo;
}
