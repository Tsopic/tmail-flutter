import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jmap_dart_client/jmap/core/utc_date.dart';
import 'package:jmap_dart_client/jmap/mail/email/email_filter_condition.dart';
import 'package:tmail_ui_user/features/mailbox_dashboard/presentation/model/search/email_sort_order_type.dart';
import 'package:tmail_ui_user/features/mailbox_dashboard/presentation/model/search/search_email_filter.dart';
import 'package:tmail_ui_user/features/search/email/domain/execution/search_execution_context.dart';
import 'package:tmail_ui_user/features/search/email/domain/execution/search_execution_intent.dart';
import 'package:tmail_ui_user/features/search/email/domain/execution/search_pagination_strategies.dart';
import 'package:tmail_ui_user/features/search/email/domain/execution/search_request_spec.dart';
import 'package:tmail_ui_user/features/thread/domain/model/search_query.dart';
import 'package:tmail_ui_user/main/utils/app_config.dart';

void main() {
  final lastDate = UTCDate(DateTime.parse('2026-03-15T10:00:00.000Z'));

  void useServerSearch(String? value) {
    dotenv.loadFromString(
      isOptional: true,
      envString: value == null ? '' : 'SERVER_SEARCH=$value',
    );
  }

  List<Map<String, dynamic>>? relevanceSort() => EmailSortOrderType.relevance
      .getSortOrder()
      .toNullable()
      ?.map((comparator) => comparator.toJson())
      .toList();

  SearchRequestSpec resolveRelevance(SearchExecutionIntent intent) {
    final ctx = SearchExecutionContext(
      intent: intent,
      committed: SearchEmailFilter(sortOrderType: EmailSortOrderType.relevance),
      collapseThreads: false,
    );
    return resolveSearchRequestSpec(SearchRequestSpec.base(ctx), ctx);
  }

  tearDown(dotenv.clean);

  group('SERVER_SEARCH parsing', () {
    for (final (value, ranked) in [
      (null, true),
      ('', true),
      ('ranked', true),
      ('unknown', true),
      ('basic', false),
      (' Basic ', false),
    ]) {
      test('${value == null ? 'missing' : '"$value"'} → ranked: $ranked', () {
        useServerSearch(value);
        expect(AppConfig.isServerSearchRanked, ranked);
      });
    }
  });

  group('ranked server search (default)', () {
    setUp(() => useServerSearch(null));

    test('relevance omits sort and pages by offset', () {
      expect(relevanceSort(), isNull);
      expect(EmailSortOrderType.relevance.isScrollByPosition(), isTrue);

      final more = resolveRelevance(
        LoadMoreIntent(
          currentCount: 20,
          lastEmailDate: lastDate,
          lastEmailId: null,
        ),
      );
      expect(more.position, 20);
      expect(more.filter.before, isNull);
    });

    test('free text stays on the server text matcher', () {
      expect(
        SearchEmailFilter(
          text: SearchQuery('tsopic'),
        ).mappingToEmailFilterCondition(),
        EmailFilterCondition(text: 'tsopic'),
      );
    });
  });

  group('basic server search', () {
    setUp(() => useServerSearch('basic'));

    test('relevance sorts newest first and pages by date', () {
      expect(relevanceSort(), [
        {'property': 'receivedAt', 'isAscending': false},
      ]);
      expect(EmailSortOrderType.relevance.isScrollByPosition(), isFalse);

      final fresh = resolveRelevance(const NewSearchIntent());
      expect(fresh.position, isNull);

      final more = resolveRelevance(
        LoadMoreIntent(
          currentCount: 20,
          lastEmailDate: lastDate,
          lastEmailId: null,
        ),
      );
      expect(more.position, isNull);
      expect(more.filter.before, lastDate);
    });

    test('other sort orders are unchanged', () {
      expect(
        EmailSortOrderType.mostRecent
            .getSortOrder()
            .toNullable()!
            .single
            .toJson(),
        {'property': 'receivedAt', 'isAscending': false},
      );
      expect(EmailSortOrderType.subjectAscending.isScrollByPosition(), isTrue);
      expect(EmailSortOrderType.mostRecent.isScrollByPosition(), isFalse);
    });

    test('free text stays on the server text matcher', () {
      for (final query in ['tsopic', 'a+b@example.ee', '"research trial"']) {
        expect(
          SearchEmailFilter(
            text: SearchQuery(query),
          ).mappingToEmailFilterCondition(),
          EmailFilterCondition(text: query),
        );
      }
    });
  });
}
