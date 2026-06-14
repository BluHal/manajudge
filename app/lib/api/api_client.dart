import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'device_identity.dart';
import 'models.dart';

/// Client HTTP verso le superfici AI del Backend (Judge, Card Search). Porta l'identità
/// User anonima su ogni chiamata; ogni chiamata andata a buon fine conta come 1 AI Request
/// (il conteggio è lato Backend). `http.Client` iniettabile per i test.
class ApiClient {
  ApiClient({required this.baseUrl, required this.identity, http.Client? client})
      : _client = client ?? http.Client();

  final String baseUrl;
  final DeviceIdentity identity;
  final http.Client _client;

  Map<String, String> get _headers => {
        'content-type': 'application/json',
        'authorization': 'Bearer ${identity.token()}',
      };

  /// Card Search: query in linguaggio naturale -> lista di carte reali rankate (#11).
  Future<List<CardHit>> searchCards(String query) async {
    final http.Response resp;
    try {
      resp = await _client.post(
        Uri.parse('$baseUrl/api/search'),
        headers: _headers,
        body: jsonEncode({'query': query}),
      );
    } on http.ClientException catch (e) {
      throw ApiException('Backend non raggiungibile: ${e.message}');
    }
    if (resp.statusCode != 200) throw _error(resp.statusCode, resp.body);
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return ((data['cards'] as List<dynamic>?) ?? [])
        .map((c) => CardHit.fromJson(c as Map<String, dynamic>))
        .toList();
  }

  /// Judge: un turno di chat. Emette prima i metadati (fonti citate), poi il testo della
  /// risposta in streaming (#10). `history` = lista di { role: 'user'|'model', text }.
  Stream<ChatChunk> streamJudge(String message, List<Map<String, String>> history) async* {
    final request = http.Request('POST', Uri.parse('$baseUrl/api/chat'))
      ..headers.addAll(_headers)
      ..body = jsonEncode({'message': message, 'history': history});

    final http.StreamedResponse resp;
    try {
      resp = await _client.send(request);
    } on http.ClientException catch (e) {
      throw ApiException('Backend non raggiungibile: ${e.message}');
    }

    if (resp.statusCode != 200) {
      throw _error(resp.statusCode, await resp.stream.bytesToString());
    }

    var metaParsed = false;
    var buffer = '';
    await for (final chunk in resp.stream.transform(utf8.decoder)) {
      buffer += chunk;
      if (!metaParsed) {
        final nl = buffer.indexOf('\n');
        if (nl == -1) continue; // la prima riga (meta JSON) non è ancora completa
        yield MetaChunk(JudgeMeta.fromJson(jsonDecode(buffer.substring(0, nl)) as Map<String, dynamic>));
        buffer = buffer.substring(nl + 1);
        metaParsed = true;
      }
      if (buffer.isNotEmpty) {
        yield TextChunk(buffer);
        buffer = '';
      }
    }
  }

  ApiException _error(int status, String body) {
    String message;
    try {
      message = (jsonDecode(body) as Map<String, dynamic>)['error'] as String? ?? 'HTTP $status';
    } catch (_) {
      message = 'HTTP $status';
    }
    if (status == 401) message = 'Identità non riconosciuta dal Backend.';
    if (status == 402) message = 'Quota AI esaurita.';
    return ApiException(message, statusCode: status);
  }

  void close() => _client.close();
}
