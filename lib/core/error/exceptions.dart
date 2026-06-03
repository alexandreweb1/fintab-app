class ServerException implements Exception {
  final String message;
  const ServerException([this.message = 'Ocorreu um erro no servidor.']);
}

class NetworkException implements Exception {
  final String message;
  const NetworkException([this.message = 'Sem conexão com a internet.']);
}

class AuthException implements Exception {
  final String message;
  const AuthException([this.message = 'Erro de autenticação.']);
}

class CacheException implements Exception {
  final String message;
  const CacheException([this.message = 'Erro ao acessar dados locais.']);
}
