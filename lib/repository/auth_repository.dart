import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class AuthRepository {
  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;
  final FirebaseStorage _firebaseStorage;

  AuthRepository({FirebaseAuth? firebaseAuth, FirebaseFirestore? firestore, FirebaseStorage? firebaseStorage})
      : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _firebaseStorage = firebaseStorage ?? FirebaseStorage.instance;

  Future<String> _uploadImage(File image, String email) async {
    try {
      final storageRef = _firebaseStorage.ref().child('profile_pics/$email.jpg');
      await storageRef.putFile(image);
      return await storageRef.getDownloadURL();
    } catch (e) {
      throw Exception('Error uploading image: $e');
    }
  }

  Future<User?> signUp({
    required String email,
    required String password,
    required String name,
    required String gender,
    required DateTime dob,
    required File profilePicFile,
    required String phone,
  }) async {
    try {
      UserCredential userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? user = userCredential.user;
      if (user != null) {
        String profilePicUrl = await _uploadImage(profilePicFile, email);
        await _firestore.collection('teachers').doc(email).set({
          'name': name,
          'gender': gender,
          'dob': dob,
          'profilePicUrl': profilePicUrl,
          'phone': phone,
          'email': email,
        });
        await user.sendEmailVerification();
      }
      return user;
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<User?> logIn({required String email, required String password}) async {
    try {
      UserCredential userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (userCredential.user != null && !userCredential.user!.emailVerified) {
        await userCredential.user?.sendEmailVerification();
        throw Exception('Email not verified');
      }
      return userCredential.user;
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<void> logOut() async {
    await _firebaseAuth.signOut();
  }

  User? getCurrentUser() {
    return _firebaseAuth.currentUser;
  }

  Stream<User?> get userChanges => _firebaseAuth.userChanges();
}
