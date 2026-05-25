import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class PurchasesService {
  PurchasesService._();

  /// Asegura que RC esté configurado. Lanza excepción con mensaje claro si no puede.
  static Future<void> ensureConfigured() async {
    if (await Purchases.isConfigured) return;

    if (!Platform.isIOS) throw Exception('pagos solo disponibles en iOS');

    final rcKey = dotenv.env['REVENUECAT_IOS_KEY'];
    if (rcKey == null || rcKey.isEmpty) {
      throw Exception('clave de pagos no encontrada (RC key vacía)');
    }

    try {
      await Purchases.setLogLevel(LogLevel.debug);
      await Purchases.configure(PurchasesConfiguration(rcKey));
      debugPrint('[RC] configurado en ensureConfigured');
    } catch (e) {
      throw Exception('error al iniciar pagos: $e');
    }
  }
}
