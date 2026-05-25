import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class PurchasesService {
  PurchasesService._();

  static Future<void> ensureConfigured() async {
    if (await Purchases.isConfigured) return;

    if (!Platform.isIOS) throw Exception('pagos solo disponibles en iOS');

    const rcKey = 'appl_YkGBBmtgmIWgCvFOdHyKDhMDRTx';

    try {
      await Purchases.setLogLevel(LogLevel.debug);
      await Purchases.configure(PurchasesConfiguration(rcKey));
      debugPrint('[RC] configurado OK');
    } catch (e) {
      throw Exception('error al iniciar pagos: $e');
    }
  }
}
