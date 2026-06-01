import 'package:http/http.dart' as http;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;

Future<void> main() async {
  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addHandler((Request request) async {
    if (request.method == 'OPTIONS') {
      return _cors(Response.ok(''));
    }

    final target = Uri.https(
      'ruz.fa.ru',
      '/api/${request.url.path}',
      request.url.queryParametersAll,
    );

    try {
      final response = await http.get(target);
      return _cors(
        Response(
          response.statusCode,
          body: response.bodyBytes,
          headers: <String, String>{
            'content-type': response.headers['content-type'] ?? 'application/json; charset=utf-8',
          },
        ),
      );
    } catch (error) {
      return _cors(
        Response.internalServerError(
          body: '{"error":1,"message":"Proxy request failed: $error"}',
          headers: <String, String>{'content-type': 'application/json; charset=utf-8'},
        ),
      );
    }
  });

  final server = await io.serve(handler, 'localhost', 3000);
  server.autoCompress = true;
  // ignore: avoid_print
  print('Proxy server running on http://${server.address.host}:${server.port}');
}

Response _cors(Response response) {
  return response.change(
    headers: <String, String>{
      ...response.headers,
      'access-control-allow-origin': '*',
      'access-control-allow-methods': 'GET, OPTIONS',
      'access-control-allow-headers': '*',
    },
  );
}
