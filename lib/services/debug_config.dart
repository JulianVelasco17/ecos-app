import 'package:firebase_auth/firebase_auth.dart';

class DebugConfig {
  DebugConfig._();
  static final DebugConfig instance = DebugConfig._();

  static const _uidsAutorizados = {'RNd1s8hhnlVgmYj4Gzhgknx5h3T2'};

  bool get activo {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return uid != null && _uidsAutorizados.contains(uid);
  }

  Future<void> cargar() async {}
}
