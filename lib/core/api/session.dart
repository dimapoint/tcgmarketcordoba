class AuthUser {
  final String id;
  final String email;
  final bool isAdmin;
  const AuthUser({required this.id, required this.email, this.isAdmin = false});
}

class AuthSession {
  final String accessToken;
  final String refreshToken;
  final AuthUser user;
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });
}
