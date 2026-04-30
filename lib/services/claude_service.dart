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

  // Genera el mensaje de compatibilidad entre dos amigos.
  // tipo: 'solo' = frase sobre el amigo, 'interaccion' = dinámica entre los dos.
  static Future<String> generarCompatibilidad({
    required String nombre1,
    required String signoSolar1,
    required String signoLunar1,
    required String nombre2,
    required String signoSolar2,
    required String signoLunar2,
    required String tipo, // 'solo' | 'interaccion'
  }) async {
    final n1 = nombre1.split(' ').first;
    final n2 = nombre2.split(' ').first;

    final prompt = tipo == 'solo'
        ? '''
Eres la voz de una app de astrología. Solo conoces los signos de $n2: Sol en $signoSolar2, Luna en $signoLunar2. No sabes nada más de su vida.

Escribe exactamente 2 oraciones en español dirigidas a $n1, describiendo cómo puede estar $n2 hoy según su carta astral — su estado de ánimo, su manera de ser en este momento. Traduce los signos a experiencias humanas concretas, sin mencionar nombres de signos ni planetas. Tono: íntimo, observador. Sin "energía", "vibra", "universo". Sin guiones largos. Sin saludos.
'''
        : '''
Eres la voz de una app de astrología. Solo conoces los signos de estas dos personas: $n1 tiene Sol en $signoSolar1 y Luna en $signoLunar1. $n2 tiene Sol en $signoSolar2 y Luna en $signoLunar2. No sabes nada de su relación real.

Escribe exactamente 2 oraciones en español sobre cómo podrían relacionarse $n1 y $n2 según sus cartas — qué tensión o complicidad natural existe entre sus formas de ser. Traduce los signos a experiencias humanas concretas, sin mencionar nombres de signos ni planetas. Tono: íntimo, directo. Sin "energía", "vibra", "universo". Sin guiones largos. Solo los primeros nombres. Sin saludos.
''';

    return await _llamarClaude(prompt);
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
    final prompt = '''
Eres el redactor de una app de astrología estilo Co-Star. Escribe en español, tono directo y humano, sin misticismo ni metáforas.

Escribe exactamente 1 título y 1 párrafo sobre $planeta en $signo${casa != null ? ' en casa $casa' : ''}. El párrafo explica qué representa $planeta, cómo se expresa en $signo${casa != null ? ', y qué área de vida activa la casa $casa' : ''}. Sin listas, sin subtítulos extra, sin frases correctivas ("no es… sino…").

LÍMITE ESTRICTO: 40–55 palabras en total (título incluido). Cuenta las palabras antes de responder.

Formato:
# $planeta en $signo
[párrafo]

Solo el texto, nada más.
''';
    return await _llamarClaude(prompt, maxTokens: 350);
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

  // Genera una lectura profunda expandida de carta astral (7 secciones)
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
Eres la voz de una app de astrología profunda. Carta natal de $n: Sol en $signoSolar, Luna en $signoLunar, Ascendente en $ascendente. Planetas: $planetasStr. Aspectos dominantes: ${aspectos.take(8).join('; ')}.

Escribe una lectura completa de carta natal organizada en 7 secciones. Cada sección: 2-3 oraciones directas, concretas, íntimas. No menciones signos ni planetas — tradúcelos a experiencias humanas reales. Tono: revelador, sin florituras, como alguien que te conoce de verdad. Sin "energía", "vibra", "universo", "flujo". Sin guiones largos. Sin markdown.

Responde SOLO con este JSON sin nada más:
{
  "esencia": "Quién eres en el núcleo — tu naturaleza más verdadera.",
  "proposito": "Para qué viniste — tu dirección de vida.",
  "amor": "Cómo amas, qué buscas, qué te desafía en relaciones.",
  "sombra": "Tu mayor patrón inconsciente — lo que sabotea sin que lo veas.",
  "dones": "Tus talentos naturales más distinctivos.",
  "carrera": "Dónde florecen tus capacidades en el trabajo.",
  "crecimiento": "Tu frontera de evolución — lo que este ciclo pide de ti."
}
''';
    return await _llamarClaude(prompt, maxTokens: 900);
  }

  // Genera una lectura de sinastría entre dos personas
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

Escribe exactamente 2 oraciones en español. La primera habla de lo que los une o complementa. La segunda habla de un punto de fricción o aprendizaje mutuo. No menciones signos, planetas ni términos de astrología. Tono: íntimo, cálido, directo. Sin "energía", "vibra", "cósmico". Sin guiones largos.
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

Escribe una lectura que explique cómo el clima astral de hoy afecta personalmente a esta persona. Organízala en 3 secciones. No menciones nombres de signos ni planetas directamente — tradúcelo a experiencias concretas. Tono: íntimo, directo, útil. Sin "energía", "vibra", "universo". Sin markdown. No hagas preguntas.

Responde SOLO con este JSON:
{
  "activado": "1-2 oraciones sobre qué área de su vida está más activada hoy.",
  "navegar": "1-2 oraciones sobre cómo aprovechar o navegar este clima específicamente.",
  "cuidar": "1 oración sobre qué cuidar o evitar hoy."
}
''';
    return await _llamarClaude(prompt, maxTokens: 500);
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

Escribe exactamente 4 secciones coherentes con el arquetipo. Cada sección: 2-3 oraciones concretas e íntimas. No menciones nombres de signos ni planetas directamente — tradúcelos a experiencias humanas. No menciones el nombre del arquetipo en el texto. Tono: honesto, cálido, ligeramente poético. Sin "energía", "vibra", "universo". Sin guiones largos. Sin markdown. No hagas preguntas.

Responde SOLO con este JSON:
{
  "intro": "2-3 oraciones sobre el vínculo general según su arquetipo.",
  "atraccion": "2-3 oraciones sobre la atracción física y química tal como la define su arquetipo.",
  "comunicacion": "2-3 oraciones sobre cómo se entienden y se hablan.",
  "desafios": "2-3 oraciones sobre los puntos de fricción reales de este arquetipo y cómo atravesarlos.",
  "potencial": "2-3 oraciones sobre lo que pueden construir juntos desde este arquetipo específico."
}
''';
    return await _llamarClaude(prompt, maxTokens: 1000);
  }

  // Genera el caption universal del clima astral
  static Future<String> generarClimaAstral(String resumenPlanetas) async {
    final prompt = '''
Eres la voz de una app de astrología. Escribe exactamente 2 oraciones en español describiendo el clima astral del día basándote en estas posiciones planetarias: $resumenPlanetas.

Menciona 1 o 2 planetas y sus signos actuales de forma natural, explicando qué tono o tensión le dan al día. El mensaje es universal — válido para cualquier persona. Tono: técnico pero accesible, directo. Sin "vibra", "universo", "manifiesta". Sin guiones largos (—). Sin saludos.
''';
    return await _llamarClaude(prompt);
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
