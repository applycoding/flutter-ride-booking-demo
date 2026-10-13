/// API origin for the Quay ride service.
///
/// Empty [base] means "same origin as this web page", which is what the
/// single-port preview server uses. `flutter run` defaults to the local Worker.
class ApiConfig {
  const ApiConfig({required this.base});

  final String base;

  static const fromEnvironment = ApiConfig(
    base: String.fromEnvironment(
      'API_BASE',
      defaultValue: 'http://127.0.0.1:8787',
    ),
  );

  Uri resolve(String path, [Map<String, String> query = const {}]) {
    final resolved = base.isEmpty
        ? Uri.base.resolve(path)
        : Uri.parse(base).resolve(path);
    if (query.isEmpty) return resolved;
    return resolved.replace(
      queryParameters: {...resolved.queryParameters, ...query},
    );
  }

  Uri watchUri(String rideId) {
    final httpUri = resolve('/v1/rides/$rideId/watch');
    final scheme = httpUri.scheme == 'https' ? 'wss' : 'ws';
    return httpUri.replace(scheme: scheme);
  }
}
