import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ClaudeService {
  static const _url = 'https://api.anthropic.com/v1/messages';
  static const _modelo = 'claude-haiku-4-5-20251001'; // el más rápido y barato

  static String get _apiKey => (dotenv.env['ANTHROPIC_API_KEY'] ?? '').trim();

  // Esencia por signo solar — tono e intención dominante
  // Planeta que rige cada área temática
  static const _planetaPorArea = {
    'identidad':  'Sol',
    'propósito':  'Sol',
    'amor':       'Venus',
    'vínculos':   'Venus',
    'duelo':      'Luna',
    'soledad':    'Luna',
    'miedo':      'Luna',
    'cambio':     'Marte',
    'trabajo':    'Marte',
    'tiempo':     'Saturno',
    'cuerpo':     'Saturno',
  };

  // Signo del planeta regente según la carta del usuario
  static String _signoRector(
    String area,
    String signoSolar,
    String signoLunar,
    String ascendente,
    Map<String, String> planetas,
  ) {
    final planeta = _planetaPorArea[area];
    switch (planeta) {
      case 'Sol':     return signoSolar;
      case 'Luna':    return signoLunar;
      case 'Venus':   return planetas['Venus']  ?? signoSolar;
      case 'Marte':   return planetas['Marte']  ?? signoSolar;
      case 'Saturno': return planetas['Saturno'] ?? signoSolar;
      default:        return signoSolar;
    }
  }

  static const _esenciaSolar = {
    'Aries':       'Frases cortas y directas. Verbos en presente. Sin rodeos. Ritmo rápido, como quien ya sabe qué hacer.',
    'Tauro':       'Ritmo pausado y concreto. Frases que se posan. Sensaciones físicas o cotidianas. Sin prisa.',
    'Géminis':     'Tono ágil, con cambios de perspectiva. Puede haber dos ideas en tensión suave. Ligero y despierto.',
    'Cáncer':      'Tono suave e interior. Frases que miran hacia adentro. Proximidad emocional sin dramatismo.',
    'Leo':         'Frases con peso y presencia. Afirmativas. Como si quien las dice ocupara bien el espacio.',
    'Virgo':       'Tono preciso y observador. Frases bien construidas. Una sola idea clara por oración.',
    'Libra':       'Tono equilibrado, sin extremos. Frases que consideran dos lados. Elegante pero accesible.',
    'Escorpio':    'Tono denso y directo. Pocas palabras, mucho peso. Frases que van al fondo sin adornos.',
    'Sagitario':   'Tono abierto y con perspectiva amplia. Frases que miran lejos. Resuelto pero sin cerrar.',
    'Capricornio': 'Tono sobrio y con peso. Frases que hablan de consecuencias o de tiempo. Sin excesos.',
    'Acuario':     'Tono distinto, ligeramente despegado. Puede haber una observación inesperada. No convencional.',
    'Piscis':      'Tono fluido y con capas. Frases que sugieren más de lo que dicen. Abierto, sin bordes duros.',
  };


  // Genera el mensaje de "tus astros de hoy" para un usuario
  static Future<String> generarAstrosDelDia({
    required String nombre,
    required String signoSolar,
    required String signoLunar,
    required String ascendente,
    required String fraseBase,
    required String areaFrase,
    Map<String, String> planetas = const {},
  }) async {
    final signoTono = _signoRector(areaFrase, signoSolar, signoLunar, ascendente, planetas);
    final esencia = _esenciaSolar[signoTono] ?? '';
    const aperturas = [
      'Estás', 'Tiendes a', 'Hoy', 'Esa', 'Ese', 'Lo que sientes',
      'Lo que buscas', 'Tu cuerpo', 'La decisión', 'Hay una parte de ti que',
      'Te pesa', 'Te cuesta', 'Te va mejor', 'Ya lo sabes',
      'El problema', 'Eso que', 'Hay algo que', 'Llevas',
      'Algo en ti', 'Sigues', 'Todavía',
    ];
    final apertura = aperturas[Random().nextInt(aperturas.length)];

    final prompt = '''
Eres la voz de una app de astrología.

Frase base: "$fraseBase"

Escribe 1-2 oraciones que expandan esa frase. Habla en imperativo directo ("acepta", "mira", "suelta"), no en segunda persona descriptiva ("aceptas", "miras").

Tono: $esencia

Reglas:
- No menciones signos zodiacales ni planetas
- Usa lenguaje general, nunca asumas el contexto específico del usuario (no digas "oficina", "jefe", "pareja", "hijos", etc.)
- Sin "no es X, es Y" ni ninguna estructura de contraste
- Sin metáforas abstractas ni palabras como "energía", "vibra", "universo"
- PROHIBIDO usar listas o enumeraciones de ningún tipo. Nada de "X, Y, Z" aunque sean sustantivos, verbos o frases distintas. Una idea por oración, sin excepciones. Ejemplos prohibidos: "ese respiro, esa pausa, eso que...", "lo que sientes, lo que piensas, lo que..."
- PROHIBIDO usar guiones (— o -) en el texto
- No repitas palabras clave de la frase base en el desarrollo
- Empieza con: "$apertura"

Responde SOLO con JSON:
{
  "frase": "...",
  "parrafo": "..."
}
''';

    return await _llamarClaude(prompt, maxTokens: 200);
  }

  static const _tonosAmigos = [
    'observador: describe lo que pasa sin opinar, como alguien que mira desde afuera con cara de "ya sé cómo termina esto".',
    'irónico: usa la ironía afectuosa. Que se note que sabes exactamente qué está pasando y te parece un poco ridículo, pero con cariño.',
    'tierno: cálido y directo, sin ser cursi. Como cuando alguien dice algo lindo sin querer.',
    'directo: sin rodeos ni adornos. Solo la verdad, enunciada con la frialdad de quien ya lo vio venir.',
    'nostálgico: como recordando algo que ya ocurrió entre ellos, con cierta ternura resignada.',
    'chusco: con humor real, como alguien que cuenta un chisme gracioso. Puede ser un poco exagerado. Que dé risa.',
    'reflexivo: pausado, como alguien que acaba de darse cuenta de algo incómodo pero cierto.',
  ];

  static String tonoAmigosDelDia(DateTime fecha) {
    final idx = (fecha.year * 10000 + fecha.month * 100 + fecha.day) % _tonosAmigos.length;
    return _tonosAmigos[idx];
  }

  // Genera 1 oración de desarrollo para una frase del banco de amigos
  static Future<String> generarDesarrolloAmigos({
    required String frase,
    required String signoSolar1,
    required String signoLunar1,
    required String signoSolar2,
    required String signoLunar2,
    required String tono,
  }) async {
    final prompt = '''
Eres la voz de una app de astrología. Esta frase describe a dos personas:

"$frase"

[USUARIO] tiene Sol en $signoSolar1, Luna en $signoLunar1.
[AMIGO] tiene Sol en $signoSolar2, Luna en $signoLunar2.

Escribe exactamente 1 oración en español que desarrolle o complemente esa frase, usando los nombres [USUARIO] y [AMIGO]. Traduce los signos a comportamientos concretos sin mencionar signos ni planetas.

Tono: $tono

ESTRICTAMENTE PROHIBIDO: guiones de cualquier tipo (— – -), paréntesis, punto y coma, metáforas, palabras como "energía", "vibra", "universo", "brillar", "intensidad", más de una oración, repetir palabras clave de la frase.

Responde SOLO con el texto, sin JSON, sin comillas.
''';
    return await _llamarClaude(prompt, maxTokens: 80);
  }

  // Genera un caption astrológico sobre la dinámica de pareja (martes Venus)
  static Future<String> generarCaptionAstralPareja({
    required String nombre1,
    required String signoSolar1,
    required String signoLunar1,
    required String ascendente1,
    required String nombre2,
    required String signoSolar2,
    required String signoLunar2,
    required String ascendente2,
  }) async {
    final n1 = nombre1.split(' ').first;
    final n2 = nombre2.split(' ').first;
    final prompt = '''
Eres la voz de una app de astrología para parejas.

Carta de $n1: Sol en $signoSolar1, Luna en $signoLunar1, Ascendente en $ascendente1.
Carta de $n2: Sol en $signoSolar2, Luna en $signoLunar2, Ascendente en $ascendente2.

Escribe 1 oración en español sobre cómo funciona esta pareja según sus cartas. Directo, sin rodeos. Habla de lo que hacen o sienten juntos, no de lo que "podrían" hacer. Sin mencionar signos ni planetas. Sin "energía", "vibra", "universo", "cósmico", "alma". Sin metáforas. Sin guiones.
''';
    return await _llamarClaude(prompt);
  }

  // Genera la lectura "Wrapped" de carta natal — 5 slides estilo Spotify Wrapped
  static Future<String> generarLecturaWrapped({
    required String nombre,
    required String signoSolar,
    required String signoLunar,
    required String ascendente,
    required String venus,
    required String marte,
  }) async {
    final n = nombre.split(' ').first;
    final prompt = '''
You are writing a birth chart reading for $n. Their chart: Sun in $signoSolar, Moon in $signoLunar, Ascendant in $ascendente, Venus in $venus, Mars in $marte.

Write 5 slides for a "chart reading" experience. Each slide is a short, punchy text in Spanish. Rules:
- DO NOT mention sign names, planet names, or any astrology terms — translate everything into human experiences
- DO NOT sound like a horoscope
- Every sentence must feel personal and specific to this combination
- Direct, slightly poetic but clear — never vague or mystical
- No "energía", "vibra", "universo", "manifesta", "cósmico"
- No long dashes (—)
- No markdown
- Do NOT repeat ideas across slides

Slide guidelines:
1. apertura: 1 powerful sentence combining all three main placements (Sun + Moon + Ascendant). Personal and slightly surprising. No "eres" as first word.
2. identidad: Start with "En el fondo, eres alguien que..." then 1-2 sentences. Based on Sun + Ascendant. What drives them at the core.
3. emociones: 2 sentences. How they feel and behave in close relationships, derived from Moon + Venus (or Moon + Mars if more relevant).
4. tension: 2 sentences. A real internal conflict from the chart. Avoid generic positivity. Name the actual tension clearly.
5. insight: 1-2 sentences. A practical, grounded suggestion based on the tension. Must feel usable in real life.

Respond ONLY with this JSON, nothing else:
{
  "apertura": "...",
  "identidad": "...",
  "emociones": "...",
  "tension": "...",
  "insight": "..."
}
''';
    return await _llamarClaude(prompt, maxTokens: 700);
  }

  // Genera la descripción editorial para una posición astrológica (planeta + signo)
  static Future<String> generarDescripcionPosicion({
    required String planeta,
    required String signo,
    int? casa,
  }) async {
    final casaLinea = casa != null ? '\nCasa: $casa' : '';
    final prompt = '''
Actúa como un redactor de producto especializado en astrología para apps móviles.

Tu tarea es escribir un texto en español claro, natural y directo, similar al estilo de apps reales (tipo Co–Star o The Pattern), evitando cualquier tono poético excesivo o estructuras típicas de IA.

---

ESTRUCTURA:

1. Título:
   Ej: "$planeta en $signo"

2. Primer párrafo:
   Explica qué representa el $planeta (ej: el Sol como identidad, ego, dirección en la vida).
   Después, describe cómo se expresa en $signo de forma clara y comprensible.
${casa != null ? '''
3. Segundo párrafo:
   Explica qué significa esa posición en la casa $casa, conectándolo con áreas de vida concretas.
''' : ''}
---

TONO:
* Claro, directo y humano
* Explicativo pero cercano
* Sin dramatismo ni lenguaje místico excesivo
* Debe sentirse como texto de producto, no como ensayo ni poesía

---

REGLAS IMPORTANTES:

❌ Evitar completamente:
* "no es…, es…"
* "no eres…, eres…"
* "no se trata de…, sino de…"
* frases correctivas o comparativas
* lenguaje rebuscado o filosófico
* metáforas exageradas

❌ No usar:
* comillas internas ("yo soy…")
* frases ambiguas o demasiado abstractas
* guiones de ningún tipo (ni — ni - ni –)

✅ Usar:
* lenguaje sencillo y natural
* ejemplos implícitos de comportamiento (cómo actúa la persona)
* frases claras y bien construidas
* vocabulario cotidiano

---

ESTILO DE REFERENCIA:
✔ "El Sol determina tu identidad y tu forma de moverte en la vida."
✔ "Con el Sol en Aries, tiendes a actuar con iniciativa y a tomar la delantera."
✔ "En la casa 11, esta energía se expresa en tus amistades, grupos y metas a futuro."

---

EXTENSIÓN: 40–55 palabras. Máximo 2 oraciones por párrafo. Sin título.

Planeta: $planeta
Signo: $signo$casaLinea

Genera el texto siguiendo estrictamente este estilo. No incluyas nada más, solo el texto.
''';
    return await _llamarClaude(prompt, maxTokens: 180);
  }

  // Genera descripciones para Sol, Luna y Ascendente en paralelo
  static Future<Map<String, String>> generarDescripcionesSignos({
    required String signoSolar,
    required String signoLunar,
    required String ascendente,
    Map<String, int> casas = const {},
  }) async {
    final resultados = await Future.wait([
      generarDescripcionPosicion(planeta: 'Sol',        signo: signoSolar,  casa: casas['Sol']),
      generarDescripcionPosicion(planeta: 'Luna',       signo: signoLunar,  casa: casas['Luna']),
      generarDescripcionPosicion(planeta: 'Ascendente', signo: ascendente,  casa: casas['Ascendente']),
    ]);
    return {
      'sol':        resultados[0],
      'luna':       resultados[1],
      'ascendente': resultados[2],
    };
  }

  // Genera una lectura natal profunda por áreas de vida (JSON)
  static Future<String> generarLecturaProfunda({
    required String nombre,
    required String signoSolar,
    required String signoLunar,
    required String ascendente,
    required List<String> aspectos,
  }) async {
    final n = nombre.split(' ').first;
    final prompt = '''
Eres la voz de una app de astrología. Carta natal de $n: Sol en $signoSolar, Luna en $signoLunar, Ascendente en $ascendente. Aspectos dominantes: ${aspectos.join('; ')}.

Escribe una lectura organizada por áreas de vida. Para cada área: 1 oración corta y concreta en español. No menciones signos ni términos técnicos — tradúcelos a experiencias humanas. Tono: íntimo, directo, ligeramente oracular. Sin "energía", "vibra", "universo". Sin guiones largos. Sin markdown.

Responde SOLO con este JSON sin nada más:
{
  "amor": "...",
  "amistad": "...",
  "suerte": "...",
  "familia": "...",
  "dinero": "..."
}
''';
    return await _llamarClaude(prompt, maxTokens: 600);
  }

  // Genera una lectura profunda de carta astral (3 secciones + 5 ámbitos)
  static Future<String> generarLecturaCartaProfunda({
    required String nombre,
    required String signoSolar,
    required String signoLunar,
    required String ascendente,
    required List<String> aspectos,
    required Map<String, String> planetas,
  }) async {
    final n = nombre.split(' ').first;
    final planetasStr = planetas.entries.map((e) => '${e.key} en ${e.value}').join(', ');
    final prompt = '''
Eres un astrólogo que escribe lecturas de carta natal para una app. Carta de $n: Sol en $signoSolar, Luna en $signoLunar, Ascendente en $ascendente. Planetas: $planetasStr. Aspectos: ${aspectos.take(8).join('; ')}.

Escribe una lectura personal. Reglas absolutas:
- Habla directamente a $n en segunda persona ("eres", "tienes", "buscas")
- NUNCA menciones signos, planetas, aspectos ni ningún término técnico de astrología — traduce todo a comportamiento, emociones y situaciones humanas concretas
- Tono: íntimo, directo, revelador — como alguien que te ha observado años
- Sin "energía", "vibra", "universo", "flujo", "cósmico"
- PROHIBIDO usar guiones de cualquier tipo (-, –, —). Usa punto o dos puntos en su lugar.
- PROHIBIDO usar oraciones adversativas: nada de "pero", "sino", "aunque", "sin embargo", "no obstante", "a pesar de". Si hay contraste, exprésalo en dos oraciones separadas.
- Sin markdown. Sin listas.

Secciones:

frase — Una sola oración de máximo 10 palabras que capture la esencia de $n. Debe ser impactante, específica, casi incómoda de lo precisa que es. Sin clichés astrológicos. Sin signos de puntuación al final.

big3 — Cómo interactúan tu identidad, tu mundo emocional y la imagen que proyectas como UN sistema. No describas cada uno por separado. Describe la dinámica entre ellos: la tensión interna, cómo se contradicen o se refuerzan, qué produce esa combinación específica en la vida diaria de $n. 3-4 oraciones.

aspectos — Los patrones más marcados de su carta: qué repite sin darse cuenta, qué le cuesta aunque tenga capacidad, qué le sale con una facilidad que no entiende. Concreta y específica, sin nombrar los aspectos técnicamente. 3-4 oraciones.

amor — Cómo se comporta $n en relaciones románticas: qué busca, qué evita, qué patrón repite, qué necesita aunque no lo pida. 2-3 oraciones.

amistad — Cómo se relaciona con amigos y grupos: qué tipo de vínculo construye, qué le cuesta en lo social, cómo es como amigo/a. 2-3 oraciones.

suerte — Dónde y cómo tiende a aparecer la oportunidad para $n, qué tipo de timing o contexto le favorece. 2-3 oraciones.

familia — Su dinámica con la familia de origen y la que construye: qué hereda, qué repite, qué intenta cambiar. 2-3 oraciones.

dinero — Su relación con el dinero, el trabajo y la seguridad material: cómo lo gana, cómo lo gestiona, qué creencia lleva sin cuestionarla. 2-3 oraciones.

Responde SOLO con este JSON:
{
  "frase": "...",
  "big3": "...",
  "aspectos": "...",
  "amor": "...",
  "amistad": "...",
  "suerte": "...",
  "familia": "...",
  "dinero": "..."
}
''';
    return await _llamarClaude(prompt, maxTokens: 1150);
  }

  // Genera una lectura de sinastría entre dos personas

  static const _frasesVenus = [
    'Di lo que quieres, no lo insinúes',
    'Hoy es mejor hablar que asumir',
    'No esperes a que tu pareja lo entienda solo',
    'Si algo te molesta, dilo hoy',
    'No ignores lo evidente',
    'Hoy es buen momento para aclarar cosas',
    'No le des tantas vueltas',
    'No te quedes callado por comodidad',
    'No evites lo incómodo',
    'Hoy es mejor ser directo',
    'No te adelantes a conclusiones',
    'No ignores lo que ya sabes',
    'Di lo que necesitas hoy, sin adornos',
    'No esperes a que tu pareja adivine lo importante',
    'Si algo te incomoda, nómbralo y listo',
    'Aclara con tu pareja lo que está quedando ambiguo',
    'Corta el rodeo: ve al punto',
    'Pregunta directo a tu pareja lo que quieres saber',
    'Lo implícito hoy confunde; hazlo explícito',
    'Dile a tu pareja exactamente qué sí te funciona',
    'Evita suavizar lo que sí importa',
    'Si dudas, verifica con tu pareja',
    'Observa cómo responde tu pareja hoy',
    'Hoy puedes notar detalles que antes no',
    'No todo depende de ti',
    'Hoy es más claro de lo que parece',
    'No todo tiene doble intención',
    'Escucha antes de reaccionar',
    'Hoy hay más sensibilidad de lo normal',
    'Hoy la intención importa más que la forma',
    'Observa cómo cambia el tono hoy',
    'Nota qué cambia cuando bajan el ritmo',
    'Observa cómo responde tu pareja cuando no presionas',
    'Hoy los detalles pesan más que los planes',
    'Fíjate en el tono de tu pareja, no solo en las palabras',
    'Hay matices que se pierden si vas rápido',
    'Mira qué evita tu pareja y por qué',
    'Lo pequeño está diciendo bastante',
    'Detecta cuándo tu pareja se abre y cuándo no',
    'Hoy ninguno está para juegos ambiguos',
    'Hoy hay ganas, pero también confusión',
    'Hoy hay química, pero también diferencias',
    'No asumas lo peor',
    'No fuerces una conversación que no fluye',
    'No corrijas, entiende primero',
    'No te cierres antes de tiempo',
    'Hoy pueden llevarse muy bien, si cooperan',
    'Hoy hay cierta incomodidad',
    'Algo no está del todo alineado',
    'Hay un pequeño roce',
    'Hoy no todo fluye igual',
    'Algo se siente fuera de lugar',
    'Hay una diferencia que pesa un poco',
    'Hoy hay más sensibilidad',
    'Algo se puede malinterpretar fácil',
    'Propón algo en lugar de esperar',
    'Hoy vale la pena hacer el esfuerzo',
    'Hoy hay oportunidad de hacerlo mejor',
    'Hoy puedes cambiar el tono de la dinámica',
    'Hoy se vale intentar diferente',
    'Hoy lo simple funciona mejor',
    'Hoy puedes hacerlo más fácil',
    'Dile a tu pareja lo que sí te gusta',
    'Haz el primer movimiento',
    'Hoy vale tomar iniciativa',
    'No esperes a que pase solo',
    'Hoy puedes cambiar la dinámica',
    'Haz algo diferente',
    'Toma la iniciativa sin pensarlo tanto',
    'Hoy puedes acercarte más',
    'Da un paso, aunque sea pequeño',
    'Dale espacio a tu pareja sin desaparecer',
    'No todo tiene que resolverse ahora',
    'Hoy es buen día para bajar la guardia',
    'No todo es tan serio como parece',
    'No te compliques de más',
    'No midas todo',
    'No todo requiere respuesta inmediata',
    'Hoy es mejor ir con calma',
    'Dale tiempo a lo que está pasando',
    'No todo necesita resolverse hoy',
    'Baja el ritmo un poco',
    'Hoy menos es más',
    'Hoy vale la pena acercarse un poco más',
    'Hoy se siente bien estar juntos',
    'Haz algo simple con tu pareja hoy',
    'Hoy es buen momento para conectar',
    'Acércate sin pensarlo tanto',
    'Hoy lo importante es compartir',
    'Disfruta lo que sí está pasando',
    'Hoy hay ganas de estar cerca',
    'Hazle saber a tu pareja que te importa',
    'Hoy lo pequeño cuenta más',
    'Quédate un poco más de lo normal',
    'Hoy es buen día para un plan juntos',
    'No hace falta hacerlo perfecto',
    'Hoy se trata de disfrutar',
    'Mira a tu pareja con más atención',
    'Hoy pueden sentirse más cerca',
    'Aprovecha el momento con tu pareja',
    'Hoy es buen día para bajar la guardia juntos',
    'Haz algo que se sienta bien para ambos',
    'Hoy hay espacio para conectar mejor',
    'Hoy es buen día para estar juntos sin plan',
    'Disfruta lo simple con tu pareja',
    'Hoy hay espacio para algo bonito',
    'Acércate sin razón específica',
    'Hoy se trata de compartir',
    'Haz algo que los acerque',
    'Hoy vale la pena estar presentes',
    'Disfruta el tiempo juntos',
    'Hoy hay más conexión de la que parece',
    'Haz algo pequeño por tu pareja',
    'Hoy es buen día para una conversación tranquila',
    'Quédate un rato más',
    'Hoy se siente bien coincidir',
    'Disfruta lo que sí funciona',
    'Hoy hay oportunidad de conectar mejor',
  ];

  static Future<Map<String, String>> generarFraseCompatibilidad({
    required String parejaName,
  }) async {
    final frase = _frasesVenus[Random().nextInt(_frasesVenus.length)];
    final pareja = parejaName.split(' ').first;
    final prompt = '''
Eres la voz de una app de relaciones. Escribes como una voz externa que describe situaciones de pareja de forma objetiva, sin involucrarse, no como una persona ni como un horóscopo.

La frase de hoy es: "$frase"

Desarrolla esa idea aplicada a la dinámica entre el usuario y $pareja.

ANTES DE ESCRIBIR:
elige aleatoriamente el tono con esta probabilidad:
- 20% tensión
- 40% neutral
- 40% calma / conexión

elige también un tipo de situación y úsalo:
- interacción directa (estar juntos físicamente)
- ausencia o distancia (no verse, planes separados)
- decisión práctica (planes, tiempos, prioridades)
- rutina compartida (comida, descanso, tareas)
- percepción interna (lo que notas sin que se diga)
- momento neutro (sin conflicto ni tensión clara)

evita repetir escenarios de conversación o teléfono

ESTILO:
directo, observador, preciso
sin tono emocional exagerado
sin intentar sonar profundo o "bonito"
escribe como si describieras algo que ya ocurrió

REGLAS:
español mexicano natural
usar siempre "tú"
usar conjugaciones correctas de "tú" (ej: dices, sientes, hablas)
prohibido voseo en cualquier forma (ej: soltás, decís, querés, tenés)
mantener consistencia total en el registro

máximo 90 palabras
frases cortas
sin metáforas
sin lenguaje motivacional
no explicar la frase, integrarla de forma natural
prohibido usar guiones de cualquier tipo (-, –, —)

evitar expresiones coloquiales (ej: "no te late", "pues", "ah", "la neta")
evitar muletillas o palabras vagas como "rollo", "épico", "intenso", "conexión", "energía"
evitar lenguaje abstracto o conceptual como "la pausa", "el proceso", "el respiro", "la cercanía", "lo que se siente"
evitar lenguaje técnico como "patrones" o "dinámicas"
evitar lenguaje formal o rígido (ej: "notará el cambio", "procederá a", "percibirá")

usar lenguaje concreto y literal
usar acciones observables (responder, hablar, ignorar, proponer, cancelar)

no usar estructuras del tipo "no es X, sino Y"
no reformular ideas para hacerlas más profundas o elegantes

no centrar la escena en mensajes, chats o llamadas a menos que sea necesario

cada frase debe leerse como una observación externa, clara y natural

no asumir que los eventos ya ocurrieron hoy
evitar referencias temporales específicas como "hoy", "ayer", "esta mañana", "más tarde"
el texto debe poder leerse en cualquier momento del día
usar formulaciones generales o continuas (ej: "a veces", "cuando pasa", "en estos casos")
no describir eventos cerrados en el tiempo

ESTRUCTURA (flexible):
abrir con una observación o situación
puede mostrar diferencia o coincidencia entre usuario y $pareja
añadir una interpretación simple
cerrar de forma natural (abierta, neutra o ligeramente incómoda según el tono)

IMPORTANTE:
la voz es externa y objetiva
usar español natural de México, como alguien hablaría en voz baja y claro
preferir frases simples (ej: "se da cuenta", "lo nota", "lo siente")
el texto debe sentirse específico, real y contenido
puede ser incómodo, neutro o tranquilo según el tono elegido
si suena genérico o decorado, está mal
no asumir rasgos específicos: no inventar historias ni detalles particulares
hablar desde situaciones comunes que podrían aplicar a cualquier pareja

Responde SOLO con este JSON. "cierre" debe ser exactamente una sola frase:
{"cuerpo": "...", "cierre": "..."}
''';
    final raw = await _llamarClaude(prompt, maxTokens: 220);
    try {
      final json = jsonDecode(raw.replaceAll(RegExp(r'^```json|```$', multiLine: true), '').trim());
      return {
        'frase':  frase,
        'cuerpo': json['cuerpo'] as String,
        'cierre': json['cierre'] as String,
      };
    } catch (_) {
      return {'frase': frase, 'cuerpo': raw, 'cierre': ''};
    }
  }

  static Future<String> generarSinastria({
    required String nombre1,
    required String nombre2,
    required List<String> aspectos,
  }) async {
    final n1 = nombre1.split(' ').first;
    final n2 = nombre2.split(' ').first;
    final prompt = '''
Eres la voz de una app de astrología. Escribe una lectura de sinastría entre $n1 y $n2.

Aspectos entre sus cartas natales: ${aspectos.join('; ')}.

Escribe exactamente 2 oraciones en español. La primera habla de lo que los une o complementa. La segunda habla de un punto de fricción o aprendizaje mutuo. No menciones signos, planetas ni términos de astrología. Tono: íntimo, cálido, directo. Sin "energía", "vibra", "cósmico". Nunca uses guiones de ningún tipo (ni —, ni -, ni –); si necesitas separar ideas usa dos puntos (:).
''';
    return await _llamarClaude(prompt);
  }

  // Genera un caption para valorar a la pareja (martes Venus)
  static Future<String> generarCaptionValoracion({
    required String miNombre,
    required String parejaName,
  }) async {
    final n1 = miNombre.split(' ').first;
    final n2 = parejaName.split(' ').first;
    final prompt = '''
Escribe exactamente 1 oración en español que $n1 podría decirle a $n2 hoy para hacerle sentir valorado. No hagas preguntas ni pidas más información — inventa algo concreto y cálido ahora. Sin "energía", "vibra", "universo". Sin guiones largos. Sin comillas. Sin saludos.
''';
    return await _llamarClaude(prompt);
  }

  // Genera un plan combinado para el fin de semana (viernes Venus)
  static Future<String> generarPlanFinde({
    required String nombre1,
    required String plan1,
    required String nombre2,
    required String plan2,
  }) async {
    final n1 = nombre1.split(' ').first;
    final n2 = nombre2.split(' ').first;
    final prompt = '''
$n1 quiere: "$plan1". $n2 quiere: "$plan2".
Escribe exactamente 2 oraciones en español sugiriendo un plan de fin de semana que combine ambas ideas de forma creativa. Tono: concreto, cálido, divertido. Sin "energía", "vibra". Sin guiones largos.
''';
    return await _llamarClaude(prompt);
  }

  // Genera 2 párrafos de expansión íntima para "más allá"
  static Future<String> generarExpansionDiaria({
    required String signoSolar,
    required String signoLunar,
    required String ascendente,
    required String fraseBase,
    required String desarrolloBase,
  }) async {
    // Determina el estilo estructural: solo 1 de cada 3 puede usar enumeraciones "tu X, tu Y"
    final rnd  = Random();
    final slot = rnd.nextInt(3);

    const ritmos = [
      'Cada párrafo: 1 oración larga y bien construida.',
      'Cada párrafo: 2 oraciones cortas.',
      'Cada párrafo: 3 oraciones medianas.',
      'Cada párrafo: 2 oraciones cortas y 1 mediana.',
      'Primer párrafo: 1 oración larga. Segundo párrafo: 2 oraciones cortas.',
      'Primer párrafo: 2 oraciones cortas. Segundo párrafo: 3 oraciones medianas.',
      'Primer párrafo: 3 oraciones cortas. Segundo párrafo: 1 oración larga.',
      'Cada párrafo: 2 oraciones, una corta y una larga.',
    ];
    final instruccionRitmo = ritmos[rnd.nextInt(ritmos.length)];
    final instruccionEstructura = slot == 0
        ? 'Puedes usar una lista corta separada por puntos si encaja bien.'
        : 'PROHIBIDO usar listas o enumeraciones. Construye frases completas con verbo y sujeto.';

    final prompt = '''
Eres la voz de una app de astrología. Escribes como un producto real: directo, claro y ligeramente íntimo. Suena humano, sin adornos innecesarios.

Aquí está la lectura base:

Frase: "$fraseBase"
Párrafo: "$desarrolloBase"

Carta natal: Sol en $signoSolar, Luna en $signoLunar, Ascendente en $ascendente.

---

TAREA:

Escribe exactamente 2 párrafos en español que expandan esta lectura.

Cada párrafo:
* 2–3 oraciones
* Frases cortas o medianas
* Ritmo natural (puede incluir una frase muy corta tipo golpe final)

---

OBJETIVO DE ESTILO:

* Debe parecer texto de app real (tipo Co–Star)
* Claro, directo, sin metáforas complejas
* Ligero tono íntimo, pero sin dramatizar
* Puede incluir una línea tipo instrucción o recomendación directa

---

REGLAS ESTRICTAS:

❌ PROHIBIDO:
* Repetir la frase o el párrafo base
* Mencionar signos, planetas o astrología
* Usar palabras: "energía", "vibra", "universo", "manifiesta"
* Usar estructuras: "no es…, es…" / "no se trata de…, sino de…" / "más que…, es…"
* Metáforas abstractas o de autoayuda
* Tono filosófico o poético excesivo
* Guiones largos (—)
* Comillas

❌ EVITAR:
* Explicar demasiado
* Frases largas con muchas ideas
* Lenguaje ambiguo o genérico

✅ USAR (OBLIGATORIO):
* Observaciones concretas: qué hace la persona, qué evita, qué repite
* Lenguaje cotidiano
* Frases como: "Deja de…" / "No sigas…" / "Hazlo simple" / "Ya lo sabes"
* Cerrar con una frase corta contundente (opcional)

---

ESTILO DE REFERENCIA (CLAVE):
"Alguien ha estado pensando en ti más de lo que crees."
"Deja de cuestionar si importas."
"Te cambió, aunque no lo veas."
"Tiendes a buscar razones para alejarte."
"Deja el análisis. Deja que pase."

---

INSTRUCCIÓN DE RITMO: $instruccionRitmo

---

INSTRUCCIÓN DE ESTRUCTURA: $instruccionEstructura

---

TONO INTERNO (influye, pero no se menciona):
* Sol ($signoSolar) → cómo actúa
* Luna ($signoLunar) → cómo siente
* Ascendente ($ascendente) → cómo responde

---

TEST FINAL (OBLIGATORIO):
Antes de responder, revisa:
* ¿Suena como algo que leerías en una app real?
* ¿Es claro en la primera lectura?
* ¿Hay alguna estructura prohibida? → Si falla, reescribe completamente

---

Salida: SOLO los dos párrafos, separados por una línea en blanco. Sin explicaciones adicionales.
''';
    return await _llamarClaude(prompt, maxTokens: 500);
  }

  // Genera lectura profunda de cómo el clima astral afecta la carta natal del usuario
  static Future<String> generarLecturaClimaPersonal({
    required String signoSolar,
    required String signoLunar,
    required String ascendente,
    required String planetasHoy,
  }) async {
    final prompt = '''
Eres la voz de una app de astrología. Esta persona tiene Sol en $signoSolar, Luna en $signoLunar, Ascendente en $ascendente.

Hoy los planetas están así: $planetasHoy.

Escribe una lectura que explique cómo el clima astral de hoy afecta personalmente a esta persona. No menciones nombres de signos ni planetas directamente — tradúcelo a experiencias concretas. Tono: íntimo, directo, útil. Sin "energía", "vibra", "universo". Sin markdown. No hagas preguntas.

Además, selecciona exactamente 4 aspectos de esta lista que sean más relevantes para esta persona hoy, según la interacción entre su carta natal y los planetas actuales. Asigna a cada uno un valor del 1 al 100 que represente la intensidad con la que esa persona siente ese aspecto hoy.

Lista de aspectos: claridad mental, ruido mental, enfoque, dispersión, intuición, sensibilidad, paciencia, impulsividad, necesidad de espacio, apertura emocional, energía social, deseo de compañía, conexión emocional, cansancio emocional, motivación, estabilidad, inquietud, calma interna, tensión interna, confianza, vulnerabilidad, sobreanálisis, espontaneidad, descanso, productividad, creatividad, deseo de movimiento, presencia, nostalgia, deseo de control, flexibilidad, claridad emocional, deseo de aislamiento, receptividad, tolerancia emocional, necesidad de descanso, iniciativa, deseo de cercanía, energía física, conexión contigo mismo.

Responde SOLO con este JSON:
{
  "activado": "2-3 oraciones sobre qué área de su vida está más activada hoy.",
  "navegar": "2-3 oraciones sobre cómo aprovechar o navegar este clima específicamente.",
  "cuidar": "1-2 oraciones sobre qué cuidar o evitar hoy.",
  "frase": "Una frase corta (máx 8 palabras) que capture la esencia del día. Directa, sin explicación.",
  "aspectos": [
    {"nombre": "nombre del aspecto", "valor": 0},
    {"nombre": "nombre del aspecto", "valor": 0},
    {"nombre": "nombre del aspecto", "valor": 0},
    {"nombre": "nombre del aspecto", "valor": 0}
  ]
}
''';
    return await _llamarClaude(prompt, maxTokens: 700);
  }

  // Descripciones internas de cada arquetipo para guiar a Claude
  static const _descripcionesArquetipo = {
    'Jardín Sereno':
        'No hay armonía fuerte en ninguna dimensión. El vínculo es tranquilo y sin drama, pero también sin chispa real. Se llevan bien, coexisten con calma, pero no se transforman mutuamente. El reporte debe ser honesto sobre la neutralidad: hay paz pero poca pasión, y eso puede ser suficiente o puede quedarse corto según lo que busquen.',
    'Cruz de Caminos':
        'Solo comparten armonía en la primera impresión (ascendentes). Se atraen superficialmente y conectan bien al principio, pero sus caminos de fondo divergen. El reporte debe hablar de una conexión que brilla al inicio y requiere trabajo consciente para profundizar.',
    'Sen':
        'Solo hay armonía emocional (lunas). Se entienden en silencio, se cuidan sin pedírselo, pero les falta chispa y alineación de identidad. El reporte debe hablar de una amistad amorosa profunda que puede confundirse con romance — o convertirse en uno con paciencia.',
    'Delusional':
        'Armonía emocional y de primera impresión, pero no en lo fundamental ni en la atracción física. Se sienten bien juntos y se proyectan bien como pareja ante otros, pero puede haber una ilusión de compatibilidad que la realidad cotidiana desafía. El reporte debe ser honesto sobre el riesgo de confundir comodidad con profundidad.',
    'Vértigo':
        'Solo hay armonía Venus-Marte: pura atracción física y química. El deseo es real, la tensión también. Pero no comparten mucho más — ni emocionalmente ni en identidad. El reporte debe ser honesto: esto es intenso y difícil de ignorar, pero construir algo duradero requiere trabajo.',
    'Nudo Kármico':
        'Armonía Venus-Marte y de ascendentes. Se atraen y se presentan bien juntos al mundo, pero hay algo más oscuro: una sensación de deuda o repetición, como si ya se hubieran encontrado antes. El reporte debe hablar de atracción inevitable y patrones difíciles de romper.',
    'El Hechizo':
        'Armonía Venus-Marte y lunar. Se atraen y se entienden emocionalmente. Hay magia genuina entre ellos. Pero sin alineación de identidades, pueden perderse en el encanto sin construir algo sólido. El reporte debe capturar esa sensación de estar hechizados el uno por el otro.',
    'Umbral':
        'Todo armonioso excepto Sol-Sol: atracción, emoción y apariencia pública se alinean, pero en el fondo son personas distintas. Están en el umbral de algo grande — pueden cruzarlo o quedarse en lo superficial. El reporte debe hablar de una conexión casi completa con una grieta central que exige honestidad.',
    'Flor de Loto':
        'Solo hay armonía solar: comparten valores, visión de vida e identidad profunda. Pero les falta chispa, química y resonancia emocional visible. El reporte debe hablar de un respeto y admiración mutua profundos — se reconocen el uno en el otro — pero con poca llama romántica natural.',
    'El Espiral y el Ciclo':
        'Armonía solar y de ascendentes. Se reconocen y se proyectan bien juntos, con una sensación de que esto ya ha pasado antes, cíclico y familiar. El reporte debe hablar de un vínculo que se repite y se transforma, como algo que siempre vuelve.',
    'Animo Flore':
        'Armonía solar y lunar: comparten identidad y mundo emocional. Es una conexión de alma — se entienden sin explicarse, se sostienen mutuamente. Pero puede faltarles tensión romántica. El reporte debe hablar de una intimidad rara y valiosa, la clase de vínculo que florece lentamente.',
    'Los Alquimistas':
        'Armonía en Sol, Luna y Ascendente — todo menos Venus-Marte. Se conocen profundo, se ven con claridad, se apoyan con fuerza. Pero la pasión física puede ser tibia. El reporte debe hablar de una pareja que puede transformarse mutuamente en algo mejor, aunque deban cultivar el deseo conscientemente.',
    'Amor Fati':
        'Armonía solar y Venus-Marte: identidad y atracción alineadas. Se sienten destinados, la atracción y el reconocimiento se funden. El reporte debe hablar de una conexión que se siente inevitable — como si el amor fuera parte de su destino compartido, con toda la intensidad que eso implica.',
    'Sublime':
        'Armonía en Sol, Venus-Marte y Ascendente. Casi todo coincide — identidad, atracción, presencia pública. Solo falta la sintonía emocional más profunda. El reporte debe hablar de una pareja que parece perfecta desde afuera y tiene sustancia real, pero debe aprender a vulnerabilizarse emocionalmente.',
    'La Maravilla':
        'Armonía en Sol, Venus-Marte y Luna. Identidad, atracción y emoción alineadas. Solo falta la sintonía de superficie (cómo se ven juntos al mundo). El reporte debe hablar de algo raro y genuino: se aman desde adentro hacia afuera, con una profundidad que no necesita aprobación externa.',
    'Sahacara':
        'Las cuatro dimensiones en armonía: Sol, Venus-Marte, Luna y Ascendente. Una alineación completa y poco común. El reporte debe hablar de una conexión excepcional — no perfecta, pero sí profundamente compatible en múltiples capas. Esto no significa ausencia de conflicto, sino que tienen las herramientas para atravesarlo juntos.',
  };

  // Genera un reporte de compatibilidad romántica entre dos personas
  static Future<String> generarCompatibilidadRomantica({
    required String nombre1,
    required String signoSolar1,
    required String signoLunar1,
    required String asc1,
    required String nombre2,
    required String signoSolar2,
    required String signoLunar2,
    required String asc2,
    required String arquetipo,
  }) async {
    final n1 = nombre1.split(' ').first;
    final n2 = nombre2.split(' ').first;
    final descripcion = _descripcionesArquetipo[arquetipo] ?? 'Una conexión única entre dos personas.';
    final prompt = '''
Eres la voz de una app de astrología. Escribe un reporte de compatibilidad romántica entre $n1 y $n2.

Carta de $n1: Sol en $signoSolar1, Luna en $signoLunar1, Ascendente en $asc1.
Carta de $n2: Sol en $signoSolar2, Luna en $signoLunar2, Ascendente en $asc2.

Su arquetipo romántico es "$arquetipo". Este es el núcleo del reporte — todo debe estar escrito desde esta verdad:
$descripcion

Escribe exactamente 4 secciones coherentes con el arquetipo. Cada sección (excepto intro): 2-3 oraciones concretas e íntimas. No menciones nombres de signos ni planetas directamente — tradúcelos a experiencias humanas. No menciones el nombre del arquetipo en el texto. Tono: honesto, cálido, ligeramente poético. Sin "energía", "vibra", "universo". Sin guiones largos. Sin markdown. No hagas preguntas.

Responde SOLO con este JSON:
{
  "intro": "1-2 oraciones sobre este vínculo. Reglas: (1) No parafrasees la descripción del arquetipo ni uses sus metáforas literales. (2) Habla de tensión, deseo, crecimiento, obsesión, calma, caos, conexión o contraste — elige el ángulo más inesperado. (3) Usa 'ustedes', 'entre ustedes' o los nombres — directo y personal. (4) Sin clichés románticos, sin cursilería, sin metáforas de espejos ni luz. (5) Que suene como una verdad emocional descubierta, estilo Co-Star o The Pattern. Ejemplos: 'A $n1 y $n2 les cuesta estar juntos tanto como les cuesta no estarlo.', 'Entre ustedes, el silencio rara vez significa distancia.', 'Se provocan incluso cuando intentan protegerse.' Genera algo completamente original con esa carga.",
  "atraccion": "2-3 oraciones sobre la atracción física y el deseo tal como los define su arquetipo.",
  "comunicacion": "2-3 oraciones sobre cómo se entienden y se hablan.",
  "conexion_emocional": "2-3 oraciones sobre la profundidad emocional y el mundo interior que comparten.",
  "potencial": "2-3 oraciones sobre lo que pueden construir juntos desde este arquetipo específico."
}
''';
    return await _llamarClaude(prompt, maxTokens: 1000);
  }

  // Genera comparaciones de 6 planetas entre dos personas
  static Future<Map<String, String>> generarComparacionPlanetas({
    required String nombre1,
    required String nombre2,
    required String solar1,    required String solar2,
    required String lunar1,    required String lunar2,
    required Map<String, String> planetas1,
    required Map<String, String> planetas2,
  }) async {
    final n1 = nombre1.split(' ').first;
    final n2 = nombre2.split(' ').first;
    final prompt = '''
Eres la voz de una app de astrología. Compara estos 6 planetas entre $n1 y $n2. Para cada uno escribe UNA sola oración directa, concreta y sin clichés que describa cómo se complementan o contrastan en esa dimensión. Sin mencionar signos explícitamente. Tono honesto, moderno, tipo Co-Star.

Sol: $n1=$solar1, $n2=$solar2
Luna: $n1=$lunar1, $n2=$lunar2
Mercurio: $n1=${planetas1['Mercurio'] ?? '?'}, $n2=${planetas2['Mercurio'] ?? '?'}
Venus: $n1=${planetas1['Venus'] ?? '?'}, $n2=${planetas2['Venus'] ?? '?'}
Marte: $n1=${planetas1['Marte'] ?? '?'}, $n2=${planetas2['Marte'] ?? '?'}
Júpiter: $n1=${planetas1['Júpiter'] ?? '?'}, $n2=${planetas2['Júpiter'] ?? '?'}

Responde SOLO con este JSON:
{"sol":"...","luna":"...","mercurio":"...","venus":"...","marte":"...","jupiter":"..."}
''';
    final raw = await _llamarClaude(prompt, maxTokens: 500);
    try {
      final start = raw.indexOf('{');
      final end = raw.lastIndexOf('}');
      final json = jsonDecode(raw.substring(start, end + 1)) as Map<String, dynamic>;
      return json.map((k, v) => MapEntry(k, v as String));
    } catch (_) {
      return {};
    }
  }

  // Genera escenarios de vida futura basados en sinastría
  static Future<Map<String, String>> generarEscenariosVida({
    required String nombre1,
    required String nombre2,
    required String solar1,    required String solar2,
    required String lunar1,    required String lunar2,
    required String asc1,      required String asc2,
    required Map<String, String> planetas1,
    required Map<String, String> planetas2,
    required String arquetipo,
  }) async {
    final n1 = nombre1.split(' ').first;
    final n2 = nombre2.split(' ').first;
    final prompt = '''
Eres la voz de una app de astrología estilo Co-Star. Basándote en la sinastría entre $n1 y $n2, escribe 6 escenarios de vida futura concretos, visuales y originales. Cada uno: 2-3 oraciones que pinten una imagen específica de cómo serían juntos en esa situación. Tono: honesto, directo, cinematográfico. Sin clichés, sin "energía", sin "universo". Pueden ser tiernos, tensos o graciosos según lo que diga la sinastría. Usa los nombres $n1 y $n2.

Sinastría:
- Sol: $n1=$solar1, $n2=$solar2
- Luna: $n1=$lunar1, $n2=$lunar2
- Ascendente: $n1=$asc1, $n2=$asc2
- Venus: $n1=${planetas1['Venus'] ?? '?'}, $n2=${planetas2['Venus'] ?? '?'}
- Marte: $n1=${planetas1['Marte'] ?? '?'}, $n2=${planetas2['Marte'] ?? '?'}
- Arquetipo romántico: $arquetipo

Responde SOLO con este JSON:
{
  "en_casa": "...",
  "en_publico": "...",
  "en_una_pelea": "...",
  "de_viaje": "...",
  "con_dinero": "...",
  "en_la_vejez": "..."
}
''';
    final raw = await _llamarClaude(prompt, maxTokens: 700);
    try {
      final start = raw.indexOf('{');
      final end = raw.lastIndexOf('}');
      final json = jsonDecode(raw.substring(start, end + 1)) as Map<String, dynamic>;
      return json.map((k, v) => MapEntry(k, v as String));
    } catch (_) {
      return {};
    }
  }

  // Genera el caption universal del clima astral
  static Future<String> generarClimaAstral(String resumenPlanetas, {String? cartaNatal}) async {
    final partePersonal = cartaNatal != null && cartaNatal.isNotEmpty
        ? '\n\nCarta natal del usuario: $cartaNatal. Menciona brevemente cómo uno de los tránsitos de hoy toca su carta personal (conjunción, tensión o apoyo al signo natal).'
        : '';
    final prompt = '''
Eres la voz de una app de astrología. Escribe 2-3 oraciones cortas en español describiendo el clima astral del día basándote en estas posiciones planetarias actuales: $resumenPlanetas.$partePersonal

Menciona 2-3 planetas con sus signos (sin grados) explicando qué tono o tensión le dan al día. Tono: técnico pero accesible, directo. Sin "vibra", "universo", "manifiesta". Sin guiones largos (—). Sin saludos. Sin números de grado.
''';
    return await _llamarClaude(prompt, maxTokens: 400);
  }

  // Método base que llama a la API de Claude
  static Future<String> _llamarClaude(String prompt, {int maxTokens = 300}) async {
    try {
      final response = await http.post(
        Uri.parse(_url),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': _apiKey,
          'anthropic-version': '2023-06-01',
        },
        body: jsonEncode({
          'model': _modelo,
          'max_tokens': maxTokens,
          'messages': [
            {'role': 'user', 'content': prompt}
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['content'][0]['text'] as String;
      }
      return 'El cielo guarda silencio hoy.';
    } catch (e) {
      return 'El cielo guarda silencio hoy.';
    }
  }
}
