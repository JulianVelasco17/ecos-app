const { setGlobalOptions } = require("firebase-functions");
const { defineSecret } = require("firebase-functions/params");
const { onDocumentCreated, onDocumentWritten } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { initializeApp } = require("firebase-admin/app");
const { getMessaging } = require("firebase-admin/messaging");
const { getFirestore } = require("firebase-admin/firestore");
const { getStorage } = require("firebase-admin/storage");
const axios = require("axios");

initializeApp();
setGlobalOptions({ maxInstances: 10 });

const ANTHROPIC_API_KEY = defineSecret("ANTHROPIC_API_KEY");

// ── Banco de frases (mismo que la app) ───────────────────────────────────────
const FRASES = [
  {id:1,   frase:'Mereces sentirte bien.',                                                              area:'identidad'},
  {id:2,   frase:'Eres un museo de todo lo que has amado.',                                            area:'identidad'},
  {id:3,   frase:'La única forma es atravesarlo.',                                                     area:'cambio'},
  {id:4,   frase:'Del caos nacen estrellas.',                                                          area:'cambio'},
  {id:5,   frase:'La vulnerabilidad es el acto más valiente.',                                         area:'identidad'},
  {id:6,   frase:'Cada momento con tus amigos, desde hoy, es sagrado.',                                area:'vínculos'},
  {id:7,   frase:'Memento mori.',                                                                      area:'tiempo'},
  {id:8,   frase:'Carpe diem.',                                                                        area:'tiempo'},
  {id:9,   frase:'Suéltalo.',                                                                          area:'cambio'},
  {id:10,  frase:'No te ahogues nadando en tu propio amor.',                                           area:'amor'},
  {id:11,  frase:'Tu corazón sabe cómo encontrar el amor otra vez.',                                   area:'amor'},
  {id:12,  frase:'Ningún mañana está garantizado.',                                                    area:'tiempo'},
  {id:13,  frase:'Hay alguien que piensa en ti más seguido de lo que imaginas.',                       area:'vínculos'},
  {id:14,  frase:'La belleza en tu corazón atrae cosas bellas.',                                       area:'identidad'},
  {id:15,  frase:'No estás obligado a estar de acuerdo con todo esto.',                                area:'identidad'},
  {id:16,  frase:'La fuerza y la amabilidad pueden coexistir en ti.',                                  area:'identidad'},
  {id:17,  frase:'Descansar también es una forma de avanzar.',                                         area:'cuerpo'},
  {id:18,  frase:'No todos los silencios necesitan palabras.',                                         area:'soledad'},
  {id:19,  frase:'Extrañar es otra manera de seguir amando.',                                          area:'duelo'},
  {id:20,  frase:'Tu ritmo es perfecto tal como es.',                                                  area:'identidad'},
  {id:21,  frase:'El tiempo revela lo que las prisas esconden.',                                       area:'tiempo'},
  {id:22,  frase:'Este espacio que ocupas ya es tuyo por derecho.',                                    area:'identidad'},
  {id:23,  frase:'El miedo y el deseo a menudo son gemelos.',                                          area:'miedo'},
  {id:24,  frase:'Alguien conserva una foto tuya como quien guarda un talismán.',                      area:'vínculos'},
  {id:25,  frase:'No toda cicatriz necesita convertirse en historia.',                                 area:'duelo'},
  {id:26,  frase:'Puedes renacer sin borrar quien fuiste.',                                            area:'cambio'},
  {id:27,  frase:'Aquello que evitas también te construye.',                                           area:'identidad'},
  {id:28,  frase:'Existe amor que aún no conoces.',                                                    area:'amor'},
  {id:29,  frase:'No todo lo que se fue te pertenecía realmente.',                                     area:'duelo'},
  {id:30,  frase:'Tus contradicciones también son parte de tu verdad.',                                area:'identidad'},
  {id:31,  frase:'El cuerpo intuye antes que la mente razone.',                                        area:'cuerpo'},
  {id:32,  frase:'Mereces cosas que todavía no sabes nombrar.',                                        area:'identidad'},
  {id:33,  frase:'Algunos capítulos quedan abiertos y eso también está bien.',                         area:'duelo'},
  {id:34,  frase:'No necesitas comprenderlo todo para continuar.',                                     area:'cambio'},
  {id:35,  frase:'La soledad a veces llega como un regalo incómodo.',                                  area:'soledad'},
  {id:36,  frase:'Estás más cerca de lograrlo de lo que percibes.',                                    area:'propósito'},
  {id:37,  frase:'No todo amor doloroso está equivocado.',                                             area:'amor'},
  {id:38,  frase:'Amar sin perderte en el otro: ese es el verdadero desafío.',                         area:'amor'},
  {id:39,  frase:'El amor que buscas también te está buscando.',                                       area:'amor'},
  {id:40,  frase:'Intensidad y profundidad no son lo mismo.',                                          area:'amor'},
  {id:41,  frase:'Algunas personas llegan exactamente cuando debían.',                                 area:'vínculos'},
  {id:42,  frase:'El esfuerzo silencioso cuenta doble.',                                               area:'trabajo'},
  {id:43,  frase:'Descansar no equivale a rendirse.',                                                  area:'cuerpo'},
  {id:44,  frase:'Este cuerpo tuyo te ha traído hasta aquí.',                                          area:'cuerpo'},
  {id:45,  frase:'La abundancia comienza cuando aceptas que la mereces.',                              area:'dinero'},
  {id:46,  frase:'No tienes que ser consistente para ser auténtico.',                                  area:'identidad'},
  {id:47,  frase:'No todo final es sinónimo de pérdida.',                                              area:'cambio'},
  {id:48,  frase:'El cambio que temes ya viene en camino.',                                            area:'cambio'},
  {id:49,  frase:'Soltar es, a veces, lo más valiente que puedes hacer.',                              area:'cambio'},
  {id:50,  frase:'En un mundo de superficies, encuentra tu profundidad.',                              area:'identidad'},
  {id:51,  frase:'Sanar puede parecerse a desaparecer un rato.',                                       area:'duelo'},
  {id:52,  frase:'Existen personas que se sienten como hogar desde el primer encuentro.',              area:'vínculos'},
  {id:53,  frase:'No todas las flores anuncian su llegada con ruido.',                                 area:'identidad'},
  {id:54,  frase:'La nostalgia también es una fabuladora.',                                            area:'duelo'},
  {id:55,  frase:'Muchas despedidas ocurren mucho antes del último adiós.',                            area:'duelo'},
  {id:56,  frase:'Lo más difícil no siempre es lo incorrecto.',                                        area:'cambio'},
  {id:57,  frase:'Tu ternura conserva todo su valor.',                                                 area:'identidad'},
  {id:58,  frase:'No necesitas probar tu sufrimiento para merecer paz.',                               area:'identidad'},
  {id:59,  frase:'Hay miradas capaces de cambiar vidas completas.',                                    area:'vínculos'},
  {id:60,  frase:'Lo que amas te transforma inevitablemente.',                                         area:'amor'},
  {id:61,  frase:'Crecer se siente, a veces, como ir perdiendo partes de ti.',                         area:'cambio'},
  {id:62,  frase:'Hasta la calma puede dar vértigo.',                                                  area:'cambio'},
  {id:63,  frase:'No toda conexión nació para quedarse.',                                              area:'vínculos'},
  {id:64,  frase:'Tu sensibilidad no es un error de diseño.',                                          area:'identidad'},
  {id:65,  frase:'Algunas personas llegan solo para enseñarte a irte.',                                area:'vínculos'},
  {id:66,  frase:'No todo vacío reclama ser llenado de inmediato.',                                    area:'soledad'},
  {id:67,  frase:'El amor también existe en voz baja.',                                                area:'amor'},
  {id:68,  frase:'Cambiar de opinión también es una forma de belleza.',                                area:'cambio'},
  {id:69,  frase:'La esperanza regresa sin que la llames.',                                            area:'cambio'},
  {id:70,  frase:'Algunos días, existir ya es hazaña suficiente.',                                     area:'identidad'},
  {id:71,  frase:'No todo lo importante cabe en palabras.',                                            area:'identidad'},
  {id:72,  frase:'Tus límites también son un acto de amor.',                                           area:'identidad'},
  {id:73,  frase:'Hay recuerdos que continúan respirando dentro de ti.',                               area:'duelo'},
  {id:74,  frase:'Lo que callas también tiene peso.',                                                  area:'identidad'},
  {id:75,  frase:'La vida cambia sin avisar casi nunca.',                                              area:'cambio'},
  {id:76,  frase:'Nadie ve todas las batallas que has ganado en silencio.',                            area:'identidad'},
  {id:77,  frase:'Perderse es parte del camino correcto a veces.',                                     area:'cambio'},
  {id:78,  frase:'No todo lo roto requiere reparación.',                                               area:'duelo'},
  {id:79,  frase:'Hay personas que nunca sabrán lo mucho que significaron.',                           area:'vínculos'},
  {id:80,  frase:'Tu corazón merece la misma paciencia que das a otros.',                              area:'amor'},
  {id:81,  frase:'Algunas cosas terminan para protegerte del daño.',                                   area:'cambio'},
  {id:82,  frase:'El cariño trasciende las distancias.',                                               area:'vínculos'},
  {id:83,  frase:'No llegas tarde a tu propia vida.',                                                  area:'tiempo'},
  {id:84,  frase:'Ciertos silencios abrazan mejor que mil palabras.',                                  area:'soledad'},
  {id:85,  frase:'Hasta la tristeza se cansa y descansa.',                                             area:'duelo'},
  {id:86,  frase:'Amar es aceptar la incertidumbre.',                                                  area:'amor'},
  {id:87,  frase:'No tienes que convertir cada dolor en lección.',                                     area:'duelo'},
  {id:88,  frase:'Tu historia no pierde valor por cambiar de dirección.',                              area:'identidad'},
  {id:89,  frase:'Algunas conexiones sobreviven intactas al paso del tiempo.',                         area:'vínculos'},
  {id:90,  frase:'La intuición habla en susurros, casi nunca grita.',                                  area:'identidad'},
  {id:91,  frase:'Las pequeñas rutinas también contienen amor.',                                       area:'amor'},
  {id:92,  frase:'Lo que sientes merece todo el espacio del mundo.',                                   area:'identidad'},
  {id:93,  frase:'No toda nostalgia es una invitación a regresar.',                                    area:'duelo'},
  {id:94,  frase:'Tu cuerpo guarda memoria de lo que olvidaste conscientemente.',                      area:'cuerpo'},
  {id:95,  frase:'A veces el cierre consiste en dejar de insistir.',                                   area:'cambio'},
  {id:96,  frase:'La paz puede sentirse extraña después de tanto caos.',                               area:'cambio'},
  {id:97,  frase:'Hay personas que llegan para suavizar tus bordes.',                                  area:'vínculos'},
  {id:98,  frase:'No todo pensamiento merece quedarse contigo.',                                       area:'identidad'},
  {id:99,  frase:'La vida ocurre incluso mientras dudas.',                                             area:'tiempo'},
  {id:100, frase:'El amor sano no necesita perseguirte para alcanzarte.',                              area:'amor'},
  {id:101, frase:'Algunas heridas solo piden ser reconocidas.',                                        area:'duelo'},
  {id:102, frase:'Tu versión más tierna también es fuerte.',                                           area:'identidad'},
  {id:103, frase:'No necesitas convertirte en otra persona para ser amado.',                           area:'identidad'},
  {id:104, frase:'Ciertas pérdidas te hacen más humano.',                                              area:'duelo'},
  {id:105, frase:'Lo que buscas afuera quizá habita dentro de ti.',                                    area:'identidad'},
  {id:106, frase:'La honestidad también parte corazones.',                                             area:'vínculos'},
  {id:107, frase:'Algunas personas solo saben amar desde la distancia.',                               area:'amor'},
  {id:108, frase:'No todo cansancio se cura con dormir.',                                              area:'cuerpo'},
  {id:109, frase:'Tu existencia afecta más vidas de las que alcanzas a imaginar.',                     area:'identidad'},
  {id:110, frase:'Incluso las etapas confusas tienen su belleza.',                                     area:'cambio'},
  {id:111, frase:'A veces el alma solo pide un poco de silencio.',                                     area:'soledad'},
  {id:112, frase:'No toda espera merece tu tiempo.',                                                   area:'tiempo'},
  {id:113, frase:'Hay personas que jamás olvidarán tu bondad.',                                        area:'vínculos'},
  {id:114, frase:'Tu forma de amar dice quién eres.',                                                  area:'amor'},
  {id:115, frase:'El miedo también puede señalar hacia dónde ir.',                                     area:'miedo'},
  {id:116, frase:'Algunas conexiones no necesitan explicaciones lógicas.',                             area:'vínculos'},
  {id:117, frase:'Lo intenso no siempre es lo más real.',                                              area:'amor'},
  {id:118, frase:'Existen momentos que cambian tu vida sin anunciarse.',                               area:'tiempo'},
  {id:119, frase:'Tu corazón no se equivoca por sentir demasiado.',                                    area:'identidad'},
  {id:120, frase:'La distancia revela verdades que la cercanía oculta.',                               area:'vínculos'},
  {id:121, frase:'Crecer implica, a veces, decepcionar expectativas ajenas.',                          area:'cambio'},
  {id:122, frase:'Hay amores que solo ocurren una vez en la vida.',                                    area:'amor'},
  {id:123, frase:'No necesitas correr para llegar a tiempo.',                                          area:'tiempo'},
  {id:124, frase:'Tu paz vale más que cualquier compañía tóxica.',                                     area:'identidad'},
  {id:125, frase:'Algunas personas coinciden contigo solo para despertarte.',                          area:'vínculos'},
  {id:126, frase:'El tiempo también sabe cuidar heridas.',                                             area:'duelo'},
  {id:127, frase:'No todo pensamiento oscuro dice la verdad.',                                         area:'miedo'},
  {id:128, frase:'Hay abrazos que llegan tarde pero igual sanan.',                                     area:'vínculos'},
  {id:129, frase:'Tu presencia importa incluso cuando dudas de ello.',                                 area:'identidad'},
  {id:130, frase:'La ternura sigue siendo un acto revolucionario.',                                    area:'identidad'},
  {id:131, frase:'Algunas despedidas son puro amor propio.',                                           area:'duelo'},
  {id:132, frase:'No tienes que responder todo de inmediato.',                                         area:'identidad'},
  {id:133, frase:'Hay personas que extrañan tu voz en secreto.',                                       area:'vínculos'},
  {id:134, frase:'Tu energía también necesita protección.',                                            area:'cuerpo'},
  {id:135, frase:'Insistir puede ser otra cara del miedo.',                                            area:'miedo'},
  {id:136, frase:'No todo lo que termina ha fracasado.',                                               area:'cambio'},
  {id:137, frase:'Tus sueños cambian contigo y eso está bien.',                                        area:'propósito'},
  {id:138, frase:'Tu historia no necesita compararse con ninguna otra.',                               area:'identidad'},
  {id:139, frase:'Algunas heridas regresan solo para comprobar si ya sanaste.',                        area:'duelo'},
  {id:140, frase:'El amor propio también se aprende despacio.',                                        area:'amor'},
  {id:141, frase:'Hay personas que llegan para recordarte quién solías ser.',                          area:'vínculos'},
  {id:142, frase:'No toda conexión necesita un nombre específico.',                                    area:'vínculos'},
  {id:143, frase:'Tu sensibilidad puede ser tu mejor brújula.',                                        area:'identidad'},
  {id:144, frase:'A veces la vida te aleja para después acercarte mejor.',                             area:'cambio'},
  {id:145, frase:'No todo lo callado desaparece.',                                                     area:'identidad'},
  {id:146, frase:'Algunas emociones solo quieren ser sentidas, no resueltas.',                         area:'identidad'},
  {id:147, frase:'Tu ritmo lento también tiene validez.',                                              area:'identidad'},
  {id:148, frase:'Algunas personas aman mejor de lo que saben decirlo.',                               area:'amor'},
  {id:149, frase:'La calma no siempre se parece a la felicidad.',                                      area:'identidad'},
  {id:150, frase:'Hay belleza en dejar de perseguir lo que huye.',                                     area:'cambio'},
  {id:151, frase:'No tienes que justificar tu agotamiento.',                                           area:'cuerpo'},
  {id:152, frase:'Tu presencia es refugio para alguien.',                                              area:'vínculos'},
  {id:153, frase:'Algunas respuestas llegan tarde pero aún sirven.',                                   area:'tiempo'},
  {id:154, frase:'El amor cambia de forma con el tiempo.',                                             area:'amor'},
  {id:155, frase:'Hay personas que aparecen cuando finalmente estás listo.',                           area:'vínculos'},
  {id:156, frase:'Tu corazón sobrevivió a lo que creíste imposible.',                                  area:'identidad'},
  {id:157, frase:'No toda duda significa que vas por mal camino.',                                     area:'miedo'},
  {id:158, frase:'Hay versiones tuyas que merecen compasión.',                                         area:'identidad'},
  {id:159, frase:'A veces la vida solo te pide que esperes.',                                          area:'tiempo'},
  {id:160, frase:'El deseo también puede confundirte completamente.',                                  area:'amor'},
  {id:161, frase:'Algunas conexiones se sienten como destino por algo.',                               area:'vínculos'},
  {id:162, frase:'No todo lo perdido necesita ser recuperado.',                                        area:'duelo'},
  {id:163, frase:'Tu tranquilidad no tiene precio.',                                                   area:'identidad'},
  {id:164, frase:'Hay silencios que son despedidas no pronunciadas.',                                  area:'duelo'},
  {id:165, frase:'La nostalgia tiende a editar los recuerdos.',                                        area:'duelo'},
  {id:166, frase:'Algunas personas nunca sabrán cómo te salvaron.',                                    area:'vínculos'},
  {id:167, frase:'No tienes que quedarte donde ya no creces.',                                         area:'cambio'},
  {id:168, frase:'Tu intuición merece toda tu confianza.',                                             area:'identidad'},
  {id:169, frase:'Hay heridas que sanan solo con ser vistas.',                                         area:'duelo'},
  {id:170, frase:'El amor verdadero también necesita espacio para respirar.',                          area:'amor'},
  {id:171, frase:'Algunas personas llegan para enseñarte sobre límites.',                              area:'vínculos'},
  {id:172, frase:'No todo cambio tiene que lastimar.',                                                 area:'cambio'},
  {id:173, frase:'Seguir intentándolo tiene su propia belleza.',                                       area:'propósito'},
  {id:174, frase:'Tu existencia no necesita justificación.',                                           area:'identidad'},
  {id:175, frase:'A veces el alma se adelanta varios pasos al cuerpo.',                                area:'cuerpo'},
  {id:176, frase:'No toda tristeza viene a destruirte.',                                               area:'duelo'},
  {id:177, frase:'Hay conexiones que sobreviven incluso al orgullo más terco.',                        area:'vínculos'},
  {id:178, frase:'Tu manera de sentir también merece respeto.',                                        area:'identidad'},
  {id:179, frase:'Algunas cosas buenas tardan en reconocerse.',                                        area:'tiempo'},
  {id:180, frase:'El miedo habla de lo que te importa de verdad.',                                     area:'miedo'},
  {id:181, frase:'Hay personas que te recuerdan con mucho más cariño del que imaginas.',               area:'vínculos'},
  {id:182, frase:'No necesitas responder con dureza para protegerte.',                                 area:'identidad'},
  {id:183, frase:'Tu sensibilidad no es sinónimo de debilidad.',                                       area:'identidad'},
  {id:184, frase:'Algunas despedidas liberan más de lo que duelen.',                                   area:'duelo'},
  {id:185, frase:'La vida también avanza mientras descansas.',                                         area:'cuerpo'},
  {id:186, frase:'Las personas sinceras tienen su propia belleza.',                                    area:'vínculos'},
  {id:187, frase:'No todo lo doloroso tiene que quedarse para siempre.',                               area:'duelo'},
  {id:188, frase:'Tu energía transforma los espacios que habitas.',                                    area:'identidad'},
  {id:189, frase:'Algunas conexiones llegan para enseñarte calma.',                                    area:'vínculos'},
  {id:190, frase:'El tiempo revela lo que la emoción ocultaba.',                                       area:'tiempo'},
  {id:191, frase:'Hay cosas que solo comprendes después de perderlas.',                                area:'duelo'},
  {id:192, frase:'No tienes que saberlo todo hoy mismo.',                                              area:'tiempo'},
  {id:193, frase:'Tu corazón merece lugares seguros donde latir.',                                     area:'amor'},
  {id:194, frase:'Algunas personas son lecciones vestidas de destino.',                                area:'vínculos'},
  {id:195, frase:'La ternura también puede ser tu armadura.',                                          area:'identidad'},
  {id:196, frase:'Hay amores que crecen despacio como plantas.',                                       area:'amor'},
  {id:197, frase:'No todo vacío es algo malo.',                                                        area:'soledad'},
  {id:198, frase:'Tu voz merece ser escuchada.',                                                       area:'identidad'},
  {id:199, frase:'Algunas heridas necesitan descanso, no respuestas.',                                 area:'duelo'},
  {id:200, frase:'El caos puede ser el anuncio de algo bueno.',                                        area:'cambio'},
  {id:201, frase:'Hay personas que llegan para quedarse en tu memoria eternamente.',                   area:'vínculos'},
  {id:202, frase:'No tienes que cargarlo todo en soledad.',                                            area:'soledad'},
  {id:203, frase:'Tu cuerpo también merece gratitud.',                                                 area:'cuerpo'},
  {id:204, frase:'Algunas emociones llegan para enseñarte algo específico.',                           area:'identidad'},
  {id:205, frase:'El amor no siempre sabe cómo quedarse.',                                             area:'amor'},
  {id:206, frase:'Los momentos pequeños a veces se vuelven eternos.',                                  area:'tiempo'},
  {id:207, frase:'No toda distancia significa olvido.',                                                area:'vínculos'},
  {id:208, frase:'Tu manera de amar también cuenta.',                                                  area:'amor'},
  {id:209, frase:'Algunas personas te extrañan sin decírtelo.',                                        area:'vínculos'},
  {id:210, frase:'La calma se construye ladrillo a ladrillo.',                                         area:'cambio'},
  {id:211, frase:'Empezar de nuevo tiene su propia belleza.',                                          area:'cambio'},
  {id:212, frase:'No tienes que endurecerte para sanar.',                                              area:'duelo'},
  {id:213, frase:'Tu existencia ya ha cambiado historias ajenas.',                                     area:'identidad'},
  {id:214, frase:'Algunas conexiones se sienten antiguas desde el inicio.',                            area:'vínculos'},
  {id:215, frase:'El tiempo también acomoda los corazones rotos.',                                     area:'duelo'},
  {id:216, frase:'Hay personas a las que nunca olvidarás del todo.',                                   area:'vínculos'},
  {id:217, frase:'No todo amor necesita durar para ser válido.',                                       area:'amor'},
  {id:218, frase:'Tu tristeza también merece ternura.',                                                area:'duelo'},
  {id:219, frase:'Algunas respuestas llegan cuando dejas de buscarlas.',                               area:'tiempo'},
  {id:220, frase:'El miedo no siempre anuncia peligro real.',                                          area:'miedo'},
  {id:221, frase:'Hay abrazos capaces de curar años completos.',                                       area:'vínculos'},
  {id:222, frase:'No tienes que apresurarte en sanar.',                                                area:'duelo'},
  {id:223, frase:'Tu corazón aún sabe cómo confiar.',                                                  area:'amor'},
  {id:224, frase:'Algunas personas llegan para devolverte la esperanza perdida.',                      area:'vínculos'},
  {id:225, frase:'La vida cambia más rápido de lo que aparenta.',                                      area:'tiempo'},
  {id:226, frase:'Hay silencios que significan paz pura.',                                             area:'soledad'},
  {id:227, frase:'No todo pensamiento merece tu atención.',                                            area:'identidad'},
  {id:228, frase:'Tu sensibilidad también es una forma de fortaleza.',                                 area:'identidad'},
  {id:229, frase:'Algunas despedidas son inevitables y hermosas a la vez.',                            area:'duelo'},
  {id:230, frase:'El amor habita en los detalles más mínimos.',                                        area:'amor'},
  {id:231, frase:'Hay personas que te quisieron mejor de lo que supieron demostrarlo.',                area:'amor'},
  {id:232, frase:'No necesitas cargar culpas para siempre.',                                           area:'duelo'},
  {id:233, frase:'Tu intuición probablemente ya conoce la respuesta.',                                 area:'identidad'},
  {id:234, frase:'Algunas conexiones solo existen para un instante específico.',                       area:'vínculos'},
  {id:235, frase:'La nostalgia también inventa perfecciones que nunca fueron.',                        area:'duelo'},
  {id:236, frase:'Ser comprendido es algo casi sagrado.',                                              area:'vínculos'},
  {id:237, frase:'No tienes que quedarte donde no puedes respirar.',                                   area:'cambio'},
  {id:238, frase:'Tu corazón también necesita descansar.',                                             area:'amor'},
  {id:239, frase:'Algunas personas llegan justo antes de que te rindas.',                              area:'vínculos'},
  {id:240, frase:'El tiempo también sabe despedirse con elegancia.',                                   area:'tiempo'},
  {id:241, frase:'Hay heridas que se transforman en sabiduría.',                                       area:'duelo'},
  {id:242, frase:'No toda compañía evita la soledad.',                                                 area:'soledad'},
  {id:243, frase:'Tu existencia merece suavidad.',                                                     area:'identidad'},
  {id:244, frase:'Algunas emociones regresan solo para despedirse bien.',                              area:'duelo'},
  {id:245, frase:'El amor sano también sabe poner límites.',                                           area:'amor'},
  {id:246, frase:'Hay personas que siempre serán un "qué hubiera pasado si".',                         area:'vínculos'},
  {id:247, frase:'No tienes que estar resuelto completamente para ser amado.',                         area:'amor'},
  {id:248, frase:'Tu forma de ver el mundo tiene un valor único.',                                     area:'identidad'},
  {id:249, frase:'Algunas historias terminan sin villanos claros.',                                    area:'duelo'},
  {id:250, frase:'La vida también transcurre en los días simples.',                                    area:'tiempo'},
  {id:251, frase:'Hay silencios que funcionan como protección.',                                       area:'soledad'},
  {id:252, frase:'No todo lo roto necesita volver a unirse.',                                          area:'duelo'},
  {id:253, frase:'Tu corazón aún puede sorprenderte.',                                                 area:'amor'},
  {id:254, frase:'Algunas personas dejan huellas imposibles de traducir en palabras.',                 area:'vínculos'},
  {id:255, frase:'Descansar también es una decisión valiente.',                                        area:'cuerpo'},
  {id:256, frase:'Aceptar el cambio tiene su propia belleza.',                                         area:'cambio'},
  {id:257, frase:'No tienes que entender cada emoción para permitirte sentirla.',                      area:'identidad'},
  {id:258, frase:'Tu presencia puede salvar el día de alguien más.',                                   area:'vínculos'},
  {id:259, frase:'Algunas conexiones parecen venir de otra vida.',                                     area:'vínculos'},
  {id:260, frase:'El tiempo también suaviza los recuerdos afilados.',                                  area:'tiempo'},
  {id:261, frase:'Hay personas que llegan específicamente para enseñarte calma.',                      area:'vínculos'},
  {id:262, frase:'No todo amor tiene que quedarse para importar.',                                     area:'amor'},
  {id:263, frase:'Tu sensibilidad podría ser tu mayor don.',                                           area:'identidad'},
  {id:264, frase:'Algunas despedidas son necesarias para poder crecer.',                               area:'cambio'},
  {id:265, frase:'La vida también recompensa a quienes esperan.',                                      area:'tiempo'},
  {id:266, frase:'Hay cosas que solo florecen con paciencia.',                                         area:'tiempo'},
  {id:267, frase:'No tienes que seguir cargando versiones viejas de ti mismo.',                        area:'identidad'},
  {id:268, frase:'Tu corazón sabe más de lo que tu mente acepta.',                                     area:'identidad'},
  {id:269, frase:'Algunas personas son hogar aunque no perduren.',                                     area:'vínculos'},
  {id:270, frase:'El amor también puede manifestarse como tranquilidad.',                              area:'amor'},
  {id:271, frase:'Hay recuerdos que continúan acompañándote siempre.',                                 area:'duelo'},
  {id:272, frase:'No toda tristeza necesita una solución inmediata.',                                  area:'duelo'},
  {id:273, frase:'Tu historia sigue escribiéndose página a página.',                                   area:'identidad'},
  {id:274, frase:'Algunas emociones solo quieren ser escuchadas.',                                     area:'identidad'},
  {id:275, frase:'El tiempo también acomoda las distancias.',                                          area:'tiempo'},
  {id:276, frase:'Hay personas que aparecen para devolverte la fe.',                                   area:'vínculos'},
  {id:277, frase:'No tienes que apagarte para encajar en ningún lugar.',                               area:'identidad'},
  {id:278, frase:'Tu existencia ya merece amor incondicionalmente.',                                   area:'identidad'},
  {id:279, frase:'Algunas conexiones llegan para transformarte por completo.',                         area:'vínculos'},
  {id:280, frase:'La calma también puede ser emocionante.',                                            area:'cambio'},
  {id:281, frase:'Algunos días, resistir ya es suficiente logro.',                                     area:'identidad'},
  {id:282, frase:'No todo final viene acompañado de respuestas.',                                      area:'cambio'},
  {id:283, frase:'Tu ternura continúa siendo necesaria en este mundo.',                                area:'identidad'},
  {id:284, frase:'Algunas personas vivirán para siempre en ciertas canciones.',                        area:'vínculos'},
  {id:285, frase:'El amor también consiste en elegirte a ti mismo.',                                   area:'amor'},
  {id:286, frase:'Hay silencios que gritan "te extraño".',                                             area:'duelo'},
  {id:287, frase:'No tienes que demostrar tu dolor para que sea válido.',                              area:'duelo'},
  {id:288, frase:'Tu ritmo tiene su propia belleza particular.',                                       area:'identidad'},
  {id:289, frase:'Algunas heridas te enseñan a amar diferente.',                                       area:'duelo'},
  {id:290, frase:'El tiempo transforma incluso lo que parecía inmutable.',                             area:'tiempo'},
  {id:291, frase:'Hay personas que aún te llevan consigo.',                                            area:'vínculos'},
  {id:292, frase:'No toda conexión necesita continuidad para ser valiosa.',                            area:'vínculos'},
  {id:293, frase:'Tu corazón merece espacios donde ser honesto.',                                      area:'amor'},
  {id:294, frase:'Algunas emociones llegan específicamente para abrirte los ojos.',                    area:'identidad'},
  {id:295, frase:'La vida también comienza después de grandes pérdidas.',                              area:'cambio'},
  {id:296, frase:'Las personas que sienten mucho tienen su propia belleza.',                           area:'identidad'},
  {id:297, frase:'No tienes que ser perfecto para merecer amor.',                                      area:'amor'},
  {id:298, frase:'Tu existencia también merece ser celebrada.',                                        area:'identidad'},
  {id:299, frase:'Algunas cosas buenas llegan cuando finalmente dejas de perseguirlas.',               area:'tiempo'},
  {id:300, frase:'El amor más difícil de dar suele ser el amor propio.',                               area:'amor'},
];

function seleccionarFrase(cola) {
  if (!cola || cola.length === 0) {
    // Cola vacía: selección aleatoria
    return FRASES[Math.floor(Math.random() * FRASES.length)];
  }
  const id = cola[0];
  return FRASES.find((f) => f.id === id) ?? FRASES[Math.floor(Math.random() * FRASES.length)];
}

// ── Regenerar colas de frases ────────────────────────────────────────────────
// Para disparar: en Firestore, escribe cualquier campo en
// admin/regenerarColas  (ej. { ejecutar: true })
function mezclarSinRepetirArea(frases) {
  // Fisher-Yates shuffle inicial
  const arr = [...frases].sort(() => Math.random() - 0.5);

  // Reordenar para que ningún área consecutiva se repita
  for (let i = 1; i < arr.length; i++) {
    if (arr[i].area === arr[i - 1].area) {
      // Buscar el siguiente elemento con área diferente para hacer swap
      const j = arr.findIndex((f, idx) => idx > i && f.area !== arr[i - 1].area);
      if (j !== -1) {
        [arr[i], arr[j]] = [arr[j], arr[i]];
      }
    }
  }
  return arr.map((f) => f.id);
}

exports.regenerarColasFrases = onDocumentWritten(
  "admin/regenerarColas",
  async (event) => {
    // Solo ejecutar cuando ejecutar === true, para no crear un bucle
    if (event.data?.after?.data()?.ejecutar !== true) return;
    const db = getFirestore();

    const usuarios = await db.collection("usuarios").get();
    const batch = db.batch();

    usuarios.forEach((doc) => {
      const mezclados = mezclarSinRepetirArea(FRASES);
      batch.update(doc.ref, { frasesQueue: mezclados });
    });

    await batch.commit();
    // ejecutar: false para no volver a dispararse
    await db.collection("admin").doc("regenerarColas")
      .set({ ejecutar: false, ultimaEjecucion: new Date().toISOString(), total: usuarios.size });
  }
);

async function enviarATodos(tokens, notification, data) {
  if (!tokens || tokens.length === 0) return;
  const mensajes = tokens.map((token) => ({ token, notification, data }));
  const resultado = await getMessaging().sendEach(mensajes);
  return resultado;
}

async function llamarClaude(prompt, apiKey, maxTokens = 200) {
  const response = await axios.post(
    "https://api.anthropic.com/v1/messages",
    {
      model: "claude-haiku-4-5-20251001",
      max_tokens: maxTokens,
      messages: [{ role: "user", content: prompt }],
    },
    {
      headers: {
        "x-api-key": apiKey,
        "anthropic-version": "2023-06-01",
        "content-type": "application/json",
      },
    }
  );
  return response.data.content[0].text;
}

async function generarLecturaUsuario(nombre, signoSolar, signoLunar, ascendente, fraseBase, apiKey) {
  const aperturas = ["Estás","Tiendes a","Hoy","Ese","Lo que sientes","Lo que buscas",
    "Tu cuerpo","Hay una parte de ti que","Te pesa","Ya lo sabes","Llevas","Algo en ti","Sigues"];
  const apertura = aperturas[Math.floor(Math.random() * aperturas.length)];

  const prompt = `Eres la voz de una app de astrología.

Frase base: "${fraseBase}"

Escribe 1-2 oraciones que expandan esa frase. Habla en imperativo directo ("acepta", "mira", "suelta"), no en segunda persona descriptiva.

Reglas:
- No menciones signos zodiacales ni planetas
- Usa lenguaje general, nunca asumas el contexto específico del usuario
- Sin guiones (— o -)
- PROHIBIDO usar listas o enumeraciones
- No repitas palabras clave de la frase base
- Empieza con: "${apertura}"

Responde SOLO con JSON: {"frase": "...", "parrafo": "..."}`;

  const texto = await llamarClaude(prompt, apiKey);
  try {
    const json = JSON.parse(texto.match(/\{[\s\S]*\}/)?.[0] ?? "{}");
    return { frase: json.frase ?? fraseBase, parrafo: json.parrafo ?? "" };
  } catch {
    return { frase: fraseBase, parrafo: "" };
  }
}

// ── Paso 1: Genera lecturas a las 5am y asigna hora aleatoria de envío ────────
exports.generarLecturasDiarias = onSchedule(
  {
    schedule: "0 5 * * *",
    timeZone: "America/Mexico_City",
    region: "us-central1",
    timeoutSeconds: 120,
  },
  async () => {
    const db = getFirestore();
    const hoy = new Date();
    const fechaKey = `${hoy.getFullYear()}-${String(hoy.getMonth() + 1).padStart(2, "0")}-${String(hoy.getDate()).padStart(2, "0")}`;

    const usuariosSnap = await db.collection("usuarios").get();

    for (const userDoc of usuariosSnap.docs) {
      try {
        const uid = userDoc.id;
        const datos = userDoc.data();
        if (!datos?.fcmTokens?.length && !datos?.fcmToken) continue;

        const lecturaRef = db.collection("usuarios").doc(uid).collection("lecturas").doc(fechaKey);
        const lecturaSnap = await lecturaRef.get();

        let fraseBase, areaFrase;

        if (lecturaSnap.exists && lecturaSnap.data()?.fraseBase) {
          fraseBase = lecturaSnap.data().fraseBase;
          areaFrase = lecturaSnap.data().areaFrase ?? "identidad";
        } else {
          const cola = Array.isArray(datos?.frasesQueue) ? [...datos.frasesQueue] : [];
          const fraseObj = seleccionarFrase(cola);
          fraseBase = fraseObj.frase;
          areaFrase = fraseObj.area ?? "identidad";
          await db.collection("usuarios").doc(uid).update({ frasesQueue: cola.slice(1) });
          // Solo guarda la frase — el desarrollo lo genera Claude cuando el usuario abre la app
          await lecturaRef.set({ fraseBase, areaFrase });
        }

        // Hora aleatoria entre 8am y 9pm CDMX = horas 8-21
        const horaEnvio = 8 + Math.floor(Math.random() * 14); // 8 a 21
        await db.collection("notificacionesPendientes").doc(uid).set({
          uid,
          fechaKey,
          fraseBase,
          horaEnvio,
          enviado: false,
        });
      } catch (e) {
        console.error(`Error generando lectura para ${userDoc.id}:`, e.message);
      }
    }
  }
);

// ── Paso 2: Cada hora revisa quién debe recibir su notificación ───────────────
exports.enviarNotificacionesPendientes = onSchedule(
  {
    schedule: "0 * * * *",
    timeZone: "America/Mexico_City",
    region: "us-central1",
    timeoutSeconds: 120,
  },
  async () => {
    const db = getFirestore();
    const ahoraHora = parseInt(
      new Date().toLocaleString("en-US", { timeZone: "America/Mexico_City", hour: "numeric", hour12: false })
    );

    const pendientesSnap = await db.collection("notificacionesPendientes")
      .where("enviado", "==", false)
      .where("horaEnvio", "==", ahoraHora)
      .get();

    for (const doc of pendientesSnap.docs) {
      try {
        const { uid, fraseBase, fechaKey } = doc.data();
        const userDoc = await db.collection("usuarios").doc(uid).get();
        const userData = userDoc.data();
        const tokens = userData?.fcmTokens ?? (userData?.fcmToken ? [userData.fcmToken] : []);
        if (!tokens.length) continue;

        await enviarATodos(
          tokens,
          { title: "resonancia del día", body: fraseBase },
          { tipo: "lectura_diaria", fecha: fechaKey }
        );

        await doc.ref.update({ enviado: true });
      } catch (e) {
        console.error(`Error enviando notificación a ${doc.data().uid}:`, e.message);
      }
    }
  }
);

// ── Notificación de carta Venus ───────────────────────────────────────────────
exports.notificarCarta = onDocumentCreated(
  "venus_cartas/{uid}/cartas/{cartaId}",
  async (event) => {
    const uid = event.params.uid;
    const carta = event.data.data();
    if (!carta) return;

    const db = getFirestore();
    const userDoc = await db.collection("usuarios").doc(uid).get();
    const userData = userDoc.data();
    const tokens = userData?.fcmTokens ?? (userData?.fcmToken ? [userData.fcmToken] : []);
    if (!tokens.length) return;

    const nombreRemitente = (carta.de ?? "Tu pareja").split(" ")[0];

    await enviarATodos(
      tokens,
      { title: "venus", body: `${nombreRemitente} te ha enviado una carta de amor 💌` },
      { tipo: "venus" }
    );
  }
);

// ── Notificación de solicitud de amistad ──────────────────────────────────────
exports.notificarSolicitudAmistad = onDocumentCreated(
  "solicitudes/{solicitudId}",
  async (event) => {
    const data = event.data.data();
    if (!data) return;

    const destinatarioUid = data.para;
    const remitenteUid    = data.de;
    if (!destinatarioUid || !remitenteUid) return;

    const db = getFirestore();
    const [destinatarioDoc, remitenteDoc] = await Promise.all([
      db.collection("usuarios").doc(destinatarioUid).get(),
      db.collection("usuarios").doc(remitenteUid).get(),
    ]);

    const destData = destinatarioDoc.data();
    const tokens = destData?.fcmTokens ?? (destData?.fcmToken ? [destData.fcmToken] : []);
    if (!tokens.length) return;

    const nombreRemitente = (remitenteDoc.data()?.nombre ?? "Alguien").split(" ")[0];

    await enviarATodos(
      tokens,
      { title: "nueva solicitud", body: `${nombreRemitente} quiere agregarte` },
      { tipo: "solicitud_amistad", uid: remitenteUid }
    );
  }
);

// ── Notificación de solicitud Venus ──────────────────────────────────────────
exports.notificarSolicitudVenus = onDocumentWritten(
  "usuarios/{uid}",
  async (event) => {
    const antes  = event.data.before.data();
    const despues = event.data.after.data();
    if (!despues) return;

    const enlaceAntes  = antes?.venusEnlace;
    const enlaceDespues = despues.venusEnlace;

    // Solo nos interesa cuando el estado pasa a "pendiente_recibida" por primera vez
    const eraOtroEstado = !enlaceAntes || enlaceAntes.estado !== "pendiente_recibida";
    const ahoraEsPendiente = enlaceDespues?.estado === "pendiente_recibida";
    if (!eraOtroEstado || !ahoraEsPendiente) return;

    const tokens = despues.fcmTokens ?? (despues.fcmToken ? [despues.fcmToken] : []);
    if (!tokens.length) return;

    const remitenteUid = enlaceDespues.uid;
    const nombreRemitente = (enlaceDespues.nombre ?? "Alguien").split(" ")[0];

    await enviarATodos(
      tokens,
      { title: "venus", body: `${nombreRemitente} quiere conectar contigo en venus` },
      { tipo: "solicitud_venus", uid: remitenteUid }
    );
  }
);

// ── Wipe diario de imágenes de cartas leídas ──────────────────────────────────
exports.limpiarImagenesCartas = onSchedule(
  {
    schedule: "0 3 * * *",
    timeZone: "America/Mexico_City",
    region: "us-central1",
    timeoutSeconds: 120,
  },
  async () => {
    const db     = getFirestore();
    const bucket = getStorage().bucket();

    const usuariosSnap = await db.collection("venus_cartas").get();

    for (const usuarioDoc of usuariosSnap.docs) {
      const ayer = new Date(Date.now() - 24 * 60 * 60 * 1000);
      const cartasSnap = await usuarioDoc.ref
        .collection("cartas")
        .where("leida", "==", true)
        .where("timestamp", "<=", ayer)
        .get();

      for (const cartaDoc of cartasSnap.docs) {
        const { imagenUrl } = cartaDoc.data();

        if (imagenUrl) {
          try {
            const match = imagenUrl.match(/\/o\/(.+?)\?/);
            if (match) {
              const filePath = decodeURIComponent(match[1]);
              await bucket.file(filePath).delete();
            }
          } catch (e) {
            console.error(`Error borrando imagen ${imagenUrl}:`, e.message);
          }
        }

        await cartaDoc.ref.delete();
      }
    }
  }
);

// ── Debug: enviar notificación de prueba al usuario actual ────────────────────
exports.enviarNotifDebug = onCall(
  { region: "us-central1" },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Sin sesión");

    const tipo = request.data?.tipo ?? "diaria";
    const db = getFirestore();
    const userDoc = await db.collection("usuarios").doc(uid).get();
    const userData = userDoc.data();
    const tokens = userData?.fcmTokens ?? (userData?.fcmToken ? [userData.fcmToken] : []);

    if (!tokens.length) throw new HttpsError("not-found", "Sin token FCM registrado");

    const mensajes = {
      diaria:   { title: "resonancia del día ✦",  body: "esta es una notificación de prueba de lectura diaria" },
      venus:    { title: "venus ♀",               body: "alguien quiere conectar contigo en venus" },
      carta:    { title: "venus",                 body: "tu pareja te ha enviado una carta 💌" },
    };

    const notif = mensajes[tipo] ?? mensajes.diaria;
    const resultado = await enviarATodos(tokens, notif, { tipo, debug: "true" });

    const exitosos = resultado?.successCount ?? resultado?.responses?.filter(r => r.success)?.length ?? 0;
    const fallidos = resultado?.failureCount ?? resultado?.responses?.filter(r => !r.success)?.length ?? 0;

    return { tokens: tokens.length, exitosos, fallidos };
  }
);
