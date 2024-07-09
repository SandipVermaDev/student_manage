import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_event.dart';
import 'auth_state.dart';
import '../repository/auth_repository.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;

  AuthBloc(this._authRepository) : super(AuthInitial()) {
    on<SignUpRequested>(_onSignUpRequested);
    on<LogInRequested>(_onLogInRequested);
    on<LogOutRequested>(_onLogOutRequested);
    on<CheckAuthStatusRequested>(_onCheckAuthStatusRequested);
  }

  Future<void> _onSignUpRequested(SignUpRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      User? user = await _authRepository.signUp(
        email: event.email,
        password: event.password,
        name: event.name,
        gender: event.gender,
        dob: event.dob,
        profilePicFile: event.profilePicFile,
        phone: event.phone,
      );
      if (user != null) {
        emit(AuthAuthenticated(user.email!));
      } else {
        emit(const AuthError('Sign up failed'));
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        emit(const AuthError('User already exists. Please login.'));
      } else {
        emit(AuthError(e.message!));
      }
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }


  Future<void> _onLogInRequested(LogInRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      User? user = await _authRepository.logIn(email: event.email, password: event.password);
      if (user != null) {
        emit(AuthAuthenticated(user.email!));
      } else {
        emit(const AuthError('Log in failed'));
      }
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onLogOutRequested(LogOutRequested event, Emitter<AuthState> emit) async {
    await _authRepository.logOut();
    emit(AuthUnauthenticated());
  }

  Future<void> _onCheckAuthStatusRequested(CheckAuthStatusRequested event, Emitter<AuthState> emit) async {
    final user = _authRepository.getCurrentUser();
    if (user != null && user.emailVerified) {
      emit(AuthAuthenticated(user.email!));
    } else {
      emit(AuthUnauthenticated());
    }
  }
}
