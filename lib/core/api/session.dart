class AuthUser {
  final String id;
  final String email;
  const AuthUser({required this.id, required this.email});
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
