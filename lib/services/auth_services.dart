// lib/services/auth_service.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _user;

  User? get user => _user;

  AuthService() {
    // Listen to Auth changes and notify the app
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      notifyListeners(); // This tells the app to rebuild when login status changes
    });
  }
}