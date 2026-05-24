import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static const _serverClientId = '424940223395-9t9r7fcma2slfmstcbp314enmkkmj28l.apps.googleusercontent.com';
  static const _iosClientId    = '424940223395-tlh06k38h4mi8fdivhir7407i7ju43a9.apps.googleusercontent.com';

  // Usuario actualmente loggeado (null si no hay sesión)
  static User? get usuarioActual => _auth.currentUser;

  // Inicia sesión con Google
  static Future<User?> loginConGoogle() async {
    try {
      await GoogleSignIn.instance.initialize(
        clientId: _iosClientId,
        serverClientId: _serverClientId,
      );
      final cuenta = await GoogleSignIn.instance.authenticate();
      final auth = cuenta.authentication;
      final credencial = GoogleAuthProvider.credential(
        idToken: auth.idToken,
      );
      final resultado = await _auth.signInWithCredential(credencial);
      return resultado.user;
    } catch (e) {
      print('ERROR Google Sign-In: $e');
      return null;
    }
  }

  // Crea un usuario anónimo — Firebase le asigna un uid único sin necesidad de cuenta
  static Future<User?> loginAnonimo() async {
    try {
      final resultado = await _auth.signInAnonymously();
      return resultado.user;
    } catch (e) {
      return null;
    }
  }

  static String _generarNonce([int length = 32]) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._';
    final rng = Random.secure();
    return List.generate(length, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  static String _sha256Nonce(String nonce) =>
      sha256.convert(utf8.encode(nonce)).toString();

  static Future<User?> loginConApple() async {
    try {
      final rawNonce = _generarNonce();
      final credencial = await SignInWithApple.getAppleIDCredential(
        scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
        nonce: _sha256Nonce(rawNonce),
      );
      final oauthCred = OAuthProvider('apple.com').credential(
        idToken: credencial.identityToken,
        accessToken: credencial.authorizationCode,
        rawNonce: rawNonce,
      );
      final resultado = await _auth.signInWithCredential(oauthCred);
      return resultado.user;
    } catch (e) {
      print('ERROR loginConApple: $e');
      return null;
    }
  }

  static Future<bool> vincularConGoogle() async {
    try {
      await GoogleSignIn.instance.initialize(
        clientId: _iosClientId,
        serverClientId: _serverClientId,
      );
      final cuenta = await GoogleSignIn.instance.authenticate();
      final auth = cuenta.authentication;
      final credencial = GoogleAuthProvider.credential(idToken: auth.idToken);
      await _auth.currentUser!.linkWithCredential(credencial);
      return true;
    } catch (e) {
      print('ERROR vincular Google: $e');
      return false;
    }
  }

  static Future<bool> vincularConApple() async {
    try {
      final rawNonce = _generarNonce();
      final credencial = await SignInWithApple.getAppleIDCredential(
        scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
        nonce: _sha256Nonce(rawNonce),
      );
      final oauthCred = OAuthProvider('apple.com').credential(
        idToken: credencial.identityToken,
        accessToken: credencial.authorizationCode,
        rawNonce: rawNonce,
      );
      await _auth.currentUser!.linkWithCredential(oauthCred);
      return true;
    } catch (e) {
      print('ERROR vincular Apple: $e');
      return false;
    }
  }

  // Cierra sesión
  static Future<void> cerrarSesion() async {
    await GoogleSignIn.instance.signOut();
    await _auth.signOut();
  }
}
