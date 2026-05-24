import 'package:flutter/material.dart';
import '../services/debug_config.dart';

class DebugBotonCarga extends StatelessWidget {
  final VoidCallback onTap;
  final Color color;

  const DebugBotonCarga({
    super.key,
    required this.onTap,
    this.color = Colors.black26,
  });

  @override
  Widget build(BuildContext context) {
    if (!DebugConfig.instance.activo) return const SizedBox.shrink();
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          'debug: ver carga ↺',
          style: TextStyle(color: color, fontSize: 11, letterSpacing: 1.5),
        ),
      ),
    );
  }
}
