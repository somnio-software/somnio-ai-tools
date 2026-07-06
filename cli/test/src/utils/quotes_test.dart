import 'package:somnio/src/utils/quotes.dart';
import 'package:test/test.dart';

void main() {
  group('SomnioQuote', () {
    test('stores text and author', () {
      const q = SomnioQuote('hello', 'someone');
      expect(q.text, 'hello');
      expect(q.author, 'someone');
    });
  });

  group('getRandomQuote', () {
    test('returns a quote with non-empty text and author', () {
      final q = getRandomQuote();
      expect(q.text, isNotEmpty);
      expect(q.author, isNotEmpty);
    });

    test('returns valid quotes across many calls', () {
      for (var i = 0; i < 50; i++) {
        final q = getRandomQuote();
        expect(q, isA<SomnioQuote>());
        expect(q.text, isNotEmpty);
      }
    });
  });
}
