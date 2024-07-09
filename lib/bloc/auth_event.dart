import 'package:equatable/equatable.dart';
import 'dart:io';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class SignUpRequested extends AuthEvent {
  final String email;
  final String password;
  final String name;
  final String gender;
  final DateTime dob;
  final File profilePicFile;
  final String phone;

  const SignUpRequested({
    required this.email,
    required this.password,
    required this.name,
    required this.gender,
    required this.dob,
    required this.profilePicFile,
    required this.phone,
  });

  @override
  List<Object?> get props => [email, password, name, gender, dob, profilePicFile, phone];
}

class LogInRequested extends AuthEvent {
  final String email;
  final String password;

  const LogInRequested({required this.email, required this.password});

  @override
  List<Object?> get props => [email, password];
}

class LogOutRequested extends AuthEvent {}

class CheckAuthStatusRequested extends AuthEvent {}
