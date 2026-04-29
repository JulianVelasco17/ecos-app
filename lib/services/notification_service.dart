import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

// IDs fijos por tipo de notificación
const _idDiaria = 0;
const _idVenus  = 1;
const _idLuna   = 2;

class NotifPrefs {
  final bool diariaActiva;
  final int diariaHora;
  final int diariaMinutos;
  final bool venusActiva;
  final bool lunaActiva;

  const NotifPrefs({
    this.diariaActiva  = true,
    this.diariaHora    = 9,
    this.diariaMinutos = 0,
    this.venusActiva   = false,
    this.lunaActiva    = false,
  });

  NotifPrefs copyWith({
    bool? diariaActiva,
    int? diariaHora,
    int? diariaMinutos,
    bool? venusActiva,
    bool? lunaActiva,
  }) => NotifPrefs(
    diariaActiva:   diariaActiva   ?? this.diariaActiva,
    diariaHora:     diariaHora     ?? this.diariaHora,
    diariaMinutos:  diariaMinutos  ?? this.diariaMinutos,
    venusActiva:    venusActiva    ?? this.venusActiva,
    lunaActiva:     lunaActiva     ?? this.lunaActiva,
  );
}

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> inicializar() async {
    tz_data.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios     = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(android: android, iOS: ios);
    await _plugin.initialize(settings);

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  // ── Preferencias ──────────────────────────────────────────────────────────

  static Future<NotifPrefs> cargarPreferencias() async {
    final p = await SharedPreferences.getInstance();
    return NotifPrefs(
      diariaActiva:  p.getBool('notif_diaria_activa')  ?? true,
      diariaHora:    p.getInt('notif_diaria_hora')      ?? 9,
      diariaMinutos: p.getInt('notif_diaria_minutos')   ?? 0,
      venusActiva:   p.getBool('notif_venus_activa')    ?? false,
      lunaActiva:    p.getBool('notif_luna_activa')     ?? false,
    );
  }

  static Future<void> guardarPreferencias(NotifPrefs prefs) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('notif_diaria_activa',  prefs.diariaActiva);
    await p.setInt( 'notif_diaria_hora',    prefs.diariaHora);
    await p.setInt( 'notif_diaria_minutos', prefs.diariaMinutos);
    await p.setBool('notif_venus_activa',   prefs.venusActiva);
    await p.setBool('notif_luna_activa',    prefs.lunaActiva);
  }

  // ── Programar / cancelar ──────────────────────────────────────────────────

  static Future<void> aplicarPreferencias(NotifPrefs prefs, {String fraseDiaria = 'tus astros te esperan'}) async {
    await _plugin.cancelAll();

    if (prefs.diariaActiva) {
      await _programarDiaria(prefs.diariaHora, prefs.diariaMinutos, fraseDiaria);
    }
    if (prefs.venusActiva) {
      await _programarVenus();
    }
    if (prefs.lunaActiva) {
      await _programarLuna();
    }
  }

  // Notificación diaria a hora fija
  static Future<void> _programarDiaria(int hora, int minutos, String frase) async {
    final now   = tz.TZDateTime.now(tz.local);
    var horario = tz.TZDateTime(tz.local, now.year, now.month, now.day, hora, minutos);
    if (horario.isBefore(now)) horario = horario.add(const Duration(days: 1));

    await _plugin.zonedSchedule(
      _idDiaria,
      'tus astros de hoy ✦',
      frase,
      horario,
      _detalles('astros_diarios', 'Lectura diaria', 'Tu lectura astrológica personal'),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // se repite cada día
    );
  }

  // Notificación de Venus cada martes
  static Future<void> _programarVenus() async {
    final now = tz.TZDateTime.now(tz.local);
    // Próximo martes a las 10am
    var dias = (DateTime.tuesday - now.weekday + 7) % 7;
    if (dias == 0) dias = 7;
    final horario = tz.TZDateTime(tz.local, now.year, now.month, now.day + dias, 10, 0);

    await _plugin.zonedSchedule(
      _idVenus,
      'martes de venus ♀',
      'el amor y los vínculos están en el centro hoy',
      horario,
      _detalles('venus', 'Martes de Venus', 'Recordatorio semanal de Venus'),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  // Notificación de luna — cada 14 días (luna nueva / llena aprox.)
  static Future<void> _programarLuna() async {
    // Referencia de luna nueva: 29 dic 2024
    final referencia = DateTime(2024, 12, 29);
    final ahora = DateTime.now();
    final diasDesde = ahora.difference(referencia).inDays;
    final ciclo = 29.53;

    // Días hasta la próxima luna nueva o llena (la que venga antes)
    final faseActual = diasDesde % ciclo;
    double diasHastaProxima;
    String titulo;
    String cuerpo;

    if (faseActual < 14.77) {
      diasHastaProxima = 14.77 - faseActual;
      titulo = 'luna llena ○';
      cuerpo = 'la luna llena ilumina lo que estaba oculto';
    } else {
      diasHastaProxima = ciclo - faseActual;
      titulo = 'luna nueva ●';
      cuerpo = 'la luna nueva abre un nuevo ciclo para ti';
    }

    final horario = tz.TZDateTime.now(tz.local)
        .add(Duration(hours: (diasHastaProxima * 24).round()));

    await _plugin.zonedSchedule(
      _idLuna,
      titulo,
      cuerpo,
      horario,
      _detalles('luna', 'Fases lunares', 'Aviso de luna nueva y llena'),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // Solo para debug — dispara ahora mismo
  static Future<void> mostrarAhora(String frase) async {
    await _plugin.show(
      99,
      'tus astros de hoy ✦',
      frase,
      _detalles('astros_diarios', 'Lectura diaria', 'Tu lectura astrológica personal'),
    );
  }

  // Helper de detalles de notificación
  static NotificationDetails _detalles(String channelId, String channelName, String desc) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId, channelName,
        channelDescription: desc,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(),
    );
  }

  // Programar lectura diaria (compatibilidad con código anterior)
  static Future<void> programarNotificacionDelDia(String frase) async {
    final prefs = await cargarPreferencias();
    if (!prefs.diariaActiva) return;
    await _programarDiaria(prefs.diariaHora, prefs.diariaMinutos, frase);
  }
}
