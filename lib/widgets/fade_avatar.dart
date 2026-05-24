import 'package:flutter/material.dart';

class FadeAvatar extends StatefulWidget {
  final String? fotoUrl;
  final double radius;
  final Color? backgroundColor;
  final Widget? fallbackChild;

  const FadeAvatar({
    super.key,
    required this.radius,
    this.fotoUrl,
    this.backgroundColor,
    this.fallbackChild,
  });

  @override
  State<FadeAvatar> createState() => _FadeAvatarState();
}

class _FadeAvatarState extends State<FadeAvatar> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    final bg = widget.backgroundColor ?? const Color(0xFFE0D8C8);
    final diameter = widget.radius * 2;

    if (widget.fotoUrl == null || widget.fotoUrl!.isEmpty) {
      return CircleAvatar(
        radius: widget.radius,
        backgroundColor: bg,
        child: widget.fallbackChild,
      );
    }

    return ClipOval(
      child: SizedBox(
        width: diameter,
        height: diameter,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CircleAvatar(
              radius: widget.radius,
              backgroundColor: bg,
              child: widget.fallbackChild,
            ),
            AnimatedOpacity(
              opacity: _visible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeIn,
              child: Image.network(
                widget.fotoUrl!,
                fit: BoxFit.cover,
                frameBuilder: (ctx, child, frame, sync) {
                  if (frame != null && !_visible) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) setState(() => _visible = true);
                    });
                  }
                  return child;
                },
                errorBuilder: (ctx, err, stack) => const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
