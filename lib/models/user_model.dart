// lib/models/user_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String? displayName;
  final String? department;
  final String? photoURL;
  final bool isProfileComplete;
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.email,
    this.displayName,
    this.department,
    this.photoURL,
    required this.isProfileComplete,
    required this.createdAt,
  });

  // Create UserModel from Firestore document
  factory UserModel.fromFirestore(Map<String, dynamic> data, String uid) {
    return UserModel(
      uid: uid,
      email: data['email'] ?? '',
      displayName: data['displayName'],
      department: data['department'],
      photoURL: data['photoURL'],
      isProfileComplete: data['isProfileComplete'] ?? false,
      createdAt: data['createdAt'] != null 
          ? (data['createdAt'] as Timestamp).toDate() 
          : DateTime.now(),
    );
  }

  // Convert UserModel to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'displayName': displayName,
      'department': department,
      'photoURL': photoURL,
      'isProfileComplete': isProfileComplete,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  // Create a copy with updated fields
  UserModel copyWith({
    String? displayName,
    String? department,
    String? photoURL,
    bool? isProfileComplete,
  }) {
    return UserModel(
      uid: uid,
      email: email,
      displayName: displayName ?? this.displayName,
      department: department ?? this.department,
      photoURL: photoURL ?? this.photoURL,
      isProfileComplete: isProfileComplete ?? this.isProfileComplete,
      createdAt: createdAt,
    );
  }
}