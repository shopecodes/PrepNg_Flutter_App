import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

class AuthService extends ChangeNotifier {
  static const String _deleteAccountFunctionName = 'deleteAccount';
  static const String _functionsRegion = 'us-central1';

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  User? _user;

  User? get user => _user;

  AuthService() {
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      notifyListeners();
    });
  }

  Future<UserCredential?> signInWithGoogle() async {
    await _googleSignIn.signOut();

    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null;

    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await _auth.signInWithCredential(credential);

    if (userCredential.additionalUserInfo?.isNewUser == true) {
      final user = userCredential.user!;
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': user.email ?? '',
        'displayName': user.displayName ?? '',
        'department': 'Science',
        'createdAt': FieldValue.serverTimestamp(),
        'fcmToken': null,
      });
    }

    return userCredential;
  }

  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No signed-in user was found.',
      );
    }

    // ── Step 1: Re-authenticate with Google before deletion ──────────────
    // Firebase requires recent authentication for sensitive operations.
    // We silently re-auth the user with Google to get a fresh credential.
    try {
      await _googleSignIn.signOut(); // clear cached account first
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // User cancelled the re-auth prompt
        throw FirebaseAuthException(
          code: 'cancelled',
          message: 'Account deletion was cancelled.',
        );
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Re-authenticate the Firebase user with fresh Google credential
      await user.reauthenticateWithCredential(credential);
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      throw FirebaseAuthException(
        code: 'reauth-failed',
        message: 'Could not verify your identity. Please try again.',
      );
    }

    // ── Step 2: Get fresh ID token AFTER re-authentication ───────────────
    final projectId = Firebase.app().options.projectId;
    if (projectId.isEmpty) {
      throw Exception('Unable to determine Firebase project configuration.');
    }

    // Force refresh = true so we get a token valid for the Cloud Function
    final idToken = await user.getIdToken(true);

    final uri = Uri.parse(
      'https://$_functionsRegion-$projectId.cloudfunctions.net/'
      '$_deleteAccountFunctionName',
    );

    // ── Step 3: Call the Cloud Function to delete everything ─────────────
    final response = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message = 'Failed to delete account. Please try again.';
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final serverMessage = body['message'];
        if (serverMessage is String && serverMessage.trim().isNotEmpty) {
          message = serverMessage;
        }
      } catch (_) {
        if (response.body.trim().isNotEmpty) {
          message = response.body.trim();
        }
      }
      throw Exception(message);
    }

    // ── Step 4: Sign out locally after successful deletion ───────────────
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
