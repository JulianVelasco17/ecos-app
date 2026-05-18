import 'dart:math';
import 'calculos_astrales.dart';

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

  static const _significadosLista = {
    'Conjunción': ['fusión e intensidad: ambas energías amplifican'],
    'Sextil': [
      'fluidez natural: oportunidades sin esfuerzo',
      'afinidad espontánea: se apoyan sin pensarlo',
      'comunicación fácil: se entienden casi sin palabras',
      'complemento suave: cada uno potencia al otro',
    ],
    'Cuadratura': [
      'tensión creativa: el conflicto que hace crecer',
      'fricción productiva: se retan a ser mejores',
      'choque de voluntades: difícil, pero transforma',
      'desafío constante: la incomodidad que despierta',
    ],
    'Trígono': [
      'armonía: talento que fluye fácil',
      'sintonía profunda: se reconocen sin explicarse',
      'gracia compartida: lo que uno siente, el otro lo entiende',
      'flujo natural: juntos las cosas se dan solas',
    ],
    'Oposición': [
      'polaridad: aprendes a través del otro extremo',
      'espejo y atracción: lo que te falta, el otro lo tiene',
      'tensión magnética: opuestos que se necesitan',
      'equilibrio en construcción: cada uno completa al otro',
    ],
  };

  static final _rng = Random();

  static String significadoAleatorio(String tipo) {
    final lista = _significadosLista[tipo];
    if (lista == null || lista.isEmpty) return '';
    return lista[_rng.nextInt(lista.length)];
  }

  static Map<String, String> get significados => {
    for (final e in _significadosLista.entries)
      e.key: e.value.first,
  };

  static List<AspectoNatal> calcular(DateTime fecha, int hora, int min) {
    final lons = CalculosAstrales.calcularLongitudes(fecha, hora, min);
    final nombres = lons.keys.toList();
    final resultados = <AspectoNatal>[];

    for (int i = 0; i < nombres.length; i++) {
      for (int j = i + 1; j < nombres.length; j++) {
        var diff = (lons[nombres[i]]! - lons[nombres[j]]!).abs();
        if (diff > 180) diff = 360 - diff;

        for (final (angulo, nombre, orbeMax) in _tipos) {
          final orbe = (diff - angulo).abs();
          if (orbe <= orbeMax) {
            resultados.add(AspectoNatal(
              planeta1: nombres[i],
              planeta2: nombres[j],
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
    final lons1 = CalculosAstrales.calcularLongitudes(fecha1, hora1, min1);
    final lons2 = CalculosAstrales.calcularLongitudes(fecha2, hora2, min2);

    // Solo los planetas personales: Sol, Luna, Mercurio, Venus, Marte
    const personales = ['Sol', 'Luna', 'Mercurio', 'Venus', 'Marte'];
    final resultados = <AspectoNatal>[];

    for (final a in personales) {
      for (final b in personales) {
        if (!lons1.containsKey(a) || !lons2.containsKey(b)) continue;
        var diff = (lons1[a]! - lons2[b]!).abs();
        if (diff > 180) diff = 360 - diff;

        for (final (angulo, nombre, orbeMax) in _tipos) {
          final orbe = (diff - angulo).abs();
          if (orbe <= orbeMax) {
            resultados.add(AspectoNatal(
              planeta1: a,
              planeta2: b,
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
