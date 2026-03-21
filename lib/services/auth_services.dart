// lib/services/auth_services.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService extends ChangeNotifier {
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

  /// Sign in with Google.
  /// Always shows the account picker by signing out of Google first.
  /// Returns the [UserCredential] on success, null if the user cancelled,
  /// or throws a [FirebaseAuthException] on failure.
  Future<UserCredential?> signInWithGoogle() async {
    // ✅ Force the account picker to always appear by clearing any
    // cached Google session before starting a new sign-in flow.
    await _googleSignIn.signOut();

    // Trigger the Google sign-in flow — picker will always show now
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

    // User cancelled the picker
    if (googleUser == null) return null;

    // Obtain the auth details
    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

    // Create a Firebase credential
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    // Sign in to Firebase
    final userCredential = await _auth.signInWithCredential(credential);

    // ── Create Firestore user doc if this is a new Google user ────
    if (userCredential.additionalUserInfo?.isNewUser == true) {
      final user = userCredential.user!;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'uid': user.uid,
        'email': user.email ?? '',
        'displayName': user.displayName ?? '',
        'department': 'Science', // default — user can change in settings
        'createdAt': FieldValue.serverTimestamp(),
        'fcmToken': null,
      });
    }

    return userCredential;
  }

  /// Sign out from both Firebase and Google
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}