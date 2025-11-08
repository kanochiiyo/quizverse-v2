import 'package:quizverse/services/auth_service.dart';

class AuthController {
  final AuthService _authService = AuthService();

  Future<void> login({
    required String username,
    required String password,
  }) async {
    await _authService.login(username: username, password: password);
  }

  Future<void> register({
    required String username,
    required String password,
  }) async {
    await _authService.register(username: username, password: password);
  }

  Future<bool> checkInitialLoginStatus() async {
    return await _authService.isLoggedIn();
  }

  Future<void> logout() async {
    await _authService.logout();
  }

  Future<String?> getLoggedInUserId() async {
    return await _authService.getUserId();
  }

  Future<String?> getLoggedInUsername() async {
    return await _authService.getUsername();
  }
}
