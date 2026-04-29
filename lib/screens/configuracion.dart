import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../main.dart';
import 'ajustes_notificaciones.dart';

class PantallaConfiguracion extends StatelessWidget {
  const PantallaConfiguracion({super.key});

  Future<void> _cerrarSesion(BuildContext context) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFFF3EBD6),
        title: const Text('cerrar sesión', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w300, letterSpacing: 1)),
        content: const Text('¿seguro que quieres salir?', style: TextStyle(color: Colors.black54)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('cancelar', style: TextStyle(color: Colors.black45)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('salir', style: TextStyle(color: Colors.black87)),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    await AuthService.cerrarSesion();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const PantallaBienvenida()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? user?.displayName ?? 'invitado';

    return Scaffold(
      backgroundColor: const Color(0xFFF3EBD6),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'ajustes',
                    style: TextStyle(color: Colors.black, fontSize: 28, fontWeight: FontWeight.w300, letterSpacing: 3),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close, color: Colors.black45, size: 20),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              Text(
                email,
                style: const TextStyle(color: Colors.black26, fontSize: 12, letterSpacing: 1),
              ),

              const SizedBox(height: 48),

              const Divider(color: Colors.black12),

              // Opciones futuras (placeholders)
              _Opcion(
                icono: Icons.notifications_none,
                titulo: 'notificaciones',
                subtitulo: 'gestiona tus alertas diarias',
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const PantallaAjustesNotificaciones())),
              ),

              const Divider(color: Colors.black12),

              _Opcion(
                icono: Icons.lock_outline,
                titulo: 'privacidad',
                subtitulo: 'próximamente',
                onTap: () {},
              ),

              const Divider(color: Colors.black12),

              _Opcion(
                icono: Icons.info_outline,
                titulo: 'acerca de astro',
                subtitulo: 'versión 1.0.0',
                onTap: () {},
              ),

              const Divider(color: Colors.black12),

              const Spacer(),

              // Cerrar sesión
              GestureDetector(
                onTap: () => _cerrarSesion(context),
                child: const Row(
                  children: [
                    Icon(Icons.logout, color: Colors.black45, size: 16),
                    SizedBox(width: 12),
                    Text(
                      'cerrar sesión',
                      style: TextStyle(color: Colors.black45, fontSize: 13, letterSpacing: 2),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _Opcion extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String subtitulo;
  final VoidCallback onTap;

  const _Opcion({required this.icono, required this.titulo, required this.subtitulo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Row(
          children: [
            Icon(icono, color: Colors.black45, size: 18),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: const TextStyle(color: Colors.black87, fontSize: 13, letterSpacing: 1, fontWeight: FontWeight.w300)),
                  const SizedBox(height: 2),
                  Text(subtitulo, style: const TextStyle(color: Colors.black26, fontSize: 11, letterSpacing: 0.5)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.black12, size: 16),
          ],
        ),
      ),
    );
  }
}
