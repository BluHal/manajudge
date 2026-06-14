import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:manajudge/api/api_client.dart';
import 'package:manajudge/api/device_identity.dart';
import 'package:manajudge/api/models.dart';

ApiClient clientWith(http.Client mock) =>
    ApiClient(baseUrl: 'http://test', identity: FakeDeviceIdentity('dev-1'), client: mock);

void main() {
  group('searchCards', () {
    test('porta l’identità e mappa le carte reali', () async {
      final mock = MockClient((req) async {
        expect(req.headers['authorization'], 'Bearer dev-1');
        expect(jsonDecode(req.body), {'query': 'counter target spell'});
        return http.Response(
          jsonEncode({
            'cards': [
              {'oracle_id': 'A', 'name': 'Counterspell', 'type_line': 'Instant', 'oracle_text': 'Counter target spell.', 'similarity': 0.91},
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final cards = await clientWith(mock).searchCards('counter target spell');
      expect(cards, hasLength(1));
      expect(cards.single.name, 'Counterspell');
      expect(cards.single.similarity, closeTo(0.91, 1e-9));
    });

    test('401 -> ApiException', () async {
      final mock = MockClient((req) async => http.Response(jsonEncode({'error': 'no token'}), 401));
      expect(
        () => clientWith(mock).searchCards('x'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401)),
      );
    });
  });

  group('streamJudge', () {
    test('emette meta poi testo, anche con la riga meta spezzata tra chunk', () async {
      final meta = jsonEncode({
        'rewritten': 'q',
        'confidence': 'alta',
        'cards': [],
        'sources': [
          {'rule_id': '601.2a', 'header_path': 'Casting Spells', 'text': 'Bla bla.'},
        ],
      });
      // La prima riga (meta) arriva spezzata in due pezzi; poi il testo.
      final pieces = [meta.substring(0, 10), '${meta.substring(10)}\nCiao ', 'mondo'];
      final mock = MockClient.streaming((req, body) async {
        return http.StreamedResponse(
          Stream.fromIterable(pieces.map(utf8.encode)),
          200,
        );
      });

      final chunks = await clientWith(mock).streamJudge('q', const []).toList();
      expect(chunks.first, isA<MetaChunk>());
      final m = (chunks.first as MetaChunk).meta;
      expect(m.confidence, 'alta');
      expect(m.sources.single.reference, '601.2a');

      final text = chunks.whereType<TextChunk>().map((c) => c.text).join();
      expect(text, 'Ciao mondo');
    });

    test('402 quota -> ApiException riconosciuta', () async {
      final mock = MockClient.streaming((req, body) async {
        return http.StreamedResponse(Stream.value(utf8.encode('{"error":"quota"}')), 402);
      });
      await expectLater(
        clientWith(mock).streamJudge('q', const []).toList(),
        throwsA(isA<ApiException>().having((e) => e.isQuotaExhausted, 'isQuotaExhausted', true)),
      );
    });
  });
}
