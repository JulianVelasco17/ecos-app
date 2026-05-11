import 'package:flutter/material.dart';
import '../services/notification_service.dart';

class PantallaAjustesNotificaciones extends StatefulWidget {
  const PantallaAjustesNotificaciones({super.key});

  @override
  State<PantallaAjustesNotificaciones> createState() =>
      _PantallaAjustesNotificacionesState();
}

class _PantallaAjustesNotificacionesState
    extends State<PantallaAjustesNotificaciones> {
  NotifPrefs _prefs = const NotifPrefs();
  bool _cargando = true;
  bool _guardando = false;

  static const _beige = Color(0xFFF3EBD6);

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final p = await NotificationService.cargarPreferencias();
    if (mounted) setState(() { _prefs = p; _cargando = false; });
  }

  Future<void> _guardar(NotifPrefs nuevas) async {
    setState(() { _prefs = nuevas; _guardando = true; });
    await NotificationService.guardarPreferencias(nuevas);
    await NotificationService.aplicarPreferencias(nuevas);
    if (mounted) setState(() => _guardando = false);
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _beige,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 40, 32, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('notificaciones',
                      style: TextStyle(color: Colors.black, fontSize: 22,
                          fontWeight: FontWeight.w300, letterSpacing: 2)),
                  Row(
                    children: [
                      if (_guardando)
                        const SizedBox(width: 16, height: 16,
                            child: CircularProgressIndicator(
                                color: Colors.black26, strokeWidth: 1.5)),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(Icons.close, color: Colors.black45, size: 20),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text('elige qué quieres recibir y cuándo',
                  style: TextStyle(color: Colors.black38, fontSize: 12, letterSpacing: 0.5)),
            ),

            const SizedBox(height: 32),

            if (_cargando)
              const Expanded(child: Center(
                  child: CircularProgressIndicator(color: Colors.black12)))
            else
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  children: [

                    // ── Lectura diaria ──────────────────────────────────────
                    _SeccionNotif(
                      activa: _prefs.diariaActiva,
                      onToggle: (v) => _guardar(_prefs.copyWith(diariaActiva: v)),
                      titulo: 'lectura diaria',
                      descripcion: 'tu mensaje personal en algún momento del día',
                      icono: '✦',
                    ),

                    const SizedBox(height: 12),
                    const Divider(color: Colors.black12),
                    const SizedBox(height: 12),

                    // ── Martes de Venus ─────────────────────────────────────
                    _SeccionNotif(
                      activa: _prefs.venusActiva,
                      onToggle: (v) => _guardar(_prefs.copyWith(venusActiva: v)),
                      titulo: 'martes de venus',
                      descripcion: 'recordatorio semanal de amor y vínculos',
                      icono: '♀',
                    ),

                    const SizedBox(height: 12),
                    const Divider(color: Colors.black12),
                    const SizedBox(height: 12),

                    // ── Fases lunares ───────────────────────────────────────
                    _SeccionNotif(
                      activa: _prefs.lunaActiva,
                      onToggle: (v) => _guardar(_prefs.copyWith(lunaActiva: v)),
                      titulo: 'fases lunares',
                      descripcion: 'aviso en luna nueva y luna llena',
                      icono: '○',
                    ),

                    const SizedBox(height: 40),

                    // Nota de pie
                    const Center(
                      child: Text(
                        'los cambios se aplican de inmediato',
                        style: TextStyle(color: Colors.black26,
                            fontSize: 11, letterSpacing: 0.5),
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SeccionNotif extends StatelessWidget {
  final bool activa;
  final ValueChanged<bool> onToggle;
  final String titulo;
  final String descripcion;
  final String icono;

  const _SeccionNotif({
    required this.activa,
    required this.onToggle,
    required this.titulo,
    required this.descripcion,
    required this.icono,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(icono,
                  style: const TextStyle(color: Colors.black38, fontSize: 16)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo,
                        style: const TextStyle(color: Colors.black87,
                            fontSize: 14, fontWeight: FontWeight.w300,
                            letterSpacing: 0.5)),
                    const SizedBox(height: 2),
                    Text(descripcion,
                        style: const TextStyle(color: Colors.black38,
                            fontSize: 11, letterSpacing: 0.3)),
                  ],
                ),
              ),
              Switch(
                value: activa,
                onChanged: onToggle,
                activeThumbColor: Colors.black,
                activeTrackColor: Colors.black26,
                inactiveThumbColor: Colors.black26,
                inactiveTrackColor: Colors.black12,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
