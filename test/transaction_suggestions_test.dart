import 'package:flutter_test/flutter_test.dart';
import 'package:my_finance_app/features/transactions/domain/transaction_suggestions.dart';

/// Builds a pre-normalized index entry the way the dialog does.
SuggestionEntry entry(String title, String category, int rank, {String note = ''}) {
  final norm = normalizeForSearch('$title $note');
  return SuggestionEntry(
    category: category,
    normText: norm,
    tokens: suggestionTokens(norm),
    recencyRank: rank,
    exampleTitle: title,
  );
}

List<SuggestionEntry> reindex(List<SuggestionEntry> entries) {
  // recencyRank is supplied per entry already; helper kept for readability.
  return entries;
}

void main() {
  group('normalizeForSearch', () {
    test('lowercases and strips pt/es diacritics', () {
      expect(normalizeForSearch('Alimentação'), 'alimentacao');
      expect(normalizeForSearch('Pão de Açúcar'), 'pao de acucar');
      expect(normalizeForSearch('SAÚDE'), 'saude');
      expect(normalizeForSearch('Niño'), 'nino');
    });

    test('collapses punctuation/symbols to single spaces and trims', () {
      expect(normalizeForSearch('Uber - Eats!!'), 'uber eats');
      expect(normalizeForSearch('  Mercado   Livre  '), 'mercado livre');
      expect(normalizeForSearch('iFood (almoço)'), 'ifood almoco');
    });
  });

  group('suggestionTokens', () {
    test('keeps only tokens of length >= 2', () {
      expect(suggestionTokens('a uber x eats'), {'uber', 'eats'});
    });
  });

  group('rankCategorySuggestions', () {
    final valid = {'Alimentação', 'Outros', 'Transporte', 'Compras', 'Lazer'};

    test('frequency beats a single recent entry (the core fix)', () {
      // Newest entry (rank 0) used "Outros"; the user historically tags
      // "Mercado" as "Alimentação" many times.
      final index = reindex([
        entry('Mercado', 'Outros', 0),
        for (var i = 1; i <= 8; i++) entry('Mercado', 'Alimentação', i),
      ]);

      final result = rankCategorySuggestions(
        query: 'mercado',
        index: index,
        validCategories: valid,
      );

      expect(result, isNotEmpty);
      expect(result.first.category, 'Alimentação',
          reason: 'should NOT suggest the last entry\'s category');
      expect(result.first.hits, 8);
      // "Outros" still appears, but ranked below.
      expect(result.map((s) => s.category), contains('Outros'));
      expect(result.first.score, greaterThan(result[1].score));
    });

    test('dedupes by category and counts hits', () {
      final index = reindex([
        for (var i = 0; i < 50; i++) entry('iFood', 'Alimentação', i),
      ]);
      final result = rankCategorySuggestions(
        query: 'ifood',
        index: index,
        validCategories: valid,
      );
      expect(result.length, 1);
      expect(result.first.category, 'Alimentação');
      expect(result.first.hits, 50);
      expect(result.first.example, 'iFood');
    });

    test('matches a partial prefix of a word ("merc" -> "Mercado Livre")', () {
      final index = reindex([entry('Mercado Livre', 'Compras', 0)]);
      final result = rankCategorySuggestions(
        query: 'merc',
        index: index,
        validCategories: valid,
      );
      expect(result.single.category, 'Compras');
    });

    test('accent-insensitive query matches accented history', () {
      final index = reindex([
        for (var i = 0; i < 3; i++) entry('Açaí da esquina', 'Lazer', i),
      ]);
      final result = rankCategorySuggestions(
        query: 'acai',
        index: index,
        validCategories: valid,
      );
      expect(result.single.category, 'Lazer');
    });

    test('lone fuzzy 3-char-prefix noise stays below threshold', () {
      // "mercurio" only shares the first 3 chars with "mercado" -> excluded.
      final index = reindex([entry('Mercurio', 'Outros', 0)]);
      final result = rankCategorySuggestions(
        query: 'mercado',
        index: index,
        validCategories: valid,
      );
      expect(result, isEmpty);
    });

    test('excludes categories that are not currently selectable', () {
      final index = reindex([
        for (var i = 0; i < 5; i++) entry('Uber', 'CategoriaApagada', i),
      ]);
      final result = rankCategorySuggestions(
        query: 'uber',
        index: index,
        validCategories: valid, // does not contain 'CategoriaApagada'
      );
      expect(result, isEmpty);
    });

    test('drops the already-selected category when alternatives exist', () {
      final index = reindex([
        for (var i = 0; i < 5; i++) entry('Uber', 'Transporte', i),
        for (var i = 5; i < 7; i++) entry('Uber viagem', 'Lazer', i),
      ]);
      final result = rankCategorySuggestions(
        query: 'uber',
        index: index,
        validCategories: valid,
        currentCategory: 'Transporte',
      );
      expect(result.map((s) => s.category), isNot(contains('Transporte')));
      expect(result.map((s) => s.category), contains('Lazer'));
    });

    test('keeps the selected category if it is the only match', () {
      final index = reindex([
        for (var i = 0; i < 5; i++) entry('Uber', 'Transporte', i),
      ]);
      final result = rankCategorySuggestions(
        query: 'uber',
        index: index,
        validCategories: valid,
        currentCategory: 'Transporte',
      );
      expect(result.single.category, 'Transporte');
    });

    test('returns empty for too-short queries', () {
      final index = reindex([entry('Uber', 'Transporte', 0)]);
      expect(
        rankCategorySuggestions(query: 'u', index: index, validCategories: valid),
        isEmpty,
      );
      expect(
        rankCategorySuggestions(query: '', index: index, validCategories: valid),
        isEmpty,
      );
    });

    test('history match fills the title with the matched past description', () {
      final index = reindex([
        for (var i = 0; i < 4; i++) entry('Combustível posto', 'Transporte', i),
      ]);
      final result = rankCategorySuggestions(
        query: 'comb',
        index: index,
        validCategories: valid,
      );
      expect(result.single.category, 'Transporte');
      expect(result.single.fillTitle, 'Combustível posto',
          reason: 'accepting should complete the title, not just the category');
    });

    test('matches a category by name even with no history', () {
      final cats = {'Combustível', 'Alimentação', 'Outros'};
      final result = rankCategorySuggestions(
        query: 'comb',
        index: const [], // nothing in history
        validCategories: cats,
      );
      expect(result.single.category, 'Combustível');
      expect(result.single.hits, 0);
      expect(result.single.example, '',
          reason: 'no past example to show for a name-only match');
      expect(result.single.fillTitle, 'Combustível',
          reason: 'a name match still fills the title with the category name');
    });

    test('caps the result at kSuggestionMaxRows', () {
      final cats = {'C1', 'C2', 'C3', 'C4', 'C5', 'C6'};
      final index = <SuggestionEntry>[];
      var rank = 0;
      for (final c in cats) {
        for (var i = 0; i < 3; i++) {
          index.add(entry('Padaria', c, rank++));
        }
      }
      final result = rankCategorySuggestions(
        query: 'padaria',
        index: index,
        validCategories: cats,
      );
      expect(result.length, lessThanOrEqualTo(kSuggestionMaxRows));
    });
  });
}
