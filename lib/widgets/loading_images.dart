import 'package:flutter/material.dart';

class LoadingImages extends StatefulWidget {
  final bool pegadoDerecha;
  const LoadingImages({super.key, this.pegadoDerecha = false});

  @override
  State<LoadingImages> createState() => _LoadingImagesState();
}

class _LoadingImagesState extends State<LoadingImages> {
  static const _imagenes = [
    'assets/Load_1.png',
    'assets/Load_2.png',
    'assets/Load_3.png',
  ];

  int _indice = 0;

  @override
  void initState() {
    super.initState();
    _animar();
  }

  Future<void> _animar() async {
    while (mounted) {
      await Future.delayed(const Duration(milliseconds: 250));
      if (!mounted) return;
      setState(() => _indice = (_indice + 1) % _imagenes.length);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.of(context).size.width;
    final alto = ancho * 1.3;

    final imagen = Transform.scale(
      scaleX: widget.pegadoDerecha ? 1 : -1,
      child: Image.asset(
        _imagenes[_indice],
        width: ancho * 1.15,
        fit: BoxFit.contain,
        alignment: widget.pegadoDerecha ? Alignment.bottomRight : Alignment.bottomLeft,
      ),
    );

    return SizedBox(
      width: ancho,
      height: alto,
      child: OverflowBox(
        maxWidth: ancho * 1.15,
        maxHeight: alto + 40,
        alignment: widget.pegadoDerecha ? Alignment.bottomRight : Alignment.bottomLeft,
        child: Transform.translate(
          offset: widget.pegadoDerecha ? const Offset(30, 40) : const Offset(-30, 40),
          child: imagen,
        ),
      ),
    );
  }
}
