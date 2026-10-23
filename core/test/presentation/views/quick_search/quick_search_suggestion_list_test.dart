import 'dart:async';

import 'package:core/presentation/views/quick_search/quick_search_suggestion_box.dart';
import 'package:core/presentation/views/quick_search/quick_search_suggestion_box_decoration.dart';
import 'package:core/presentation/views/quick_search/quick_search_suggestion_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  _currentResultTests();
  group('QuickSearchSuggestionList dispose lifecycle', () {
    // Regression tests for Sentry-373586:
    // AnimationController.stop crash when widget is disposed while an async
    // suggestion callback is still in flight.

    late TextEditingController controller;

    setUp(() {
      controller = TextEditingController();
    });

    tearDown(() {
      controller.dispose();
    });

    Future<QuickSearchSuggestionsBox> buildSuggestionsBox(
      WidgetTester tester,
    ) async {
      late QuickSearchSuggestionsBox box;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(builder: (context) {
            box = QuickSearchSuggestionsBox(
              context,
              AxisDirection.down,
              false,
              false,
            );
            return const SizedBox.shrink();
          }),
        ),
      ));
      return box;
    }

    testWidgets(
      'no crash when disposed while non-empty query Future.wait is pending',
      (tester) async {
        // Sentry-373586: _getSuggestions awaits Future.wait, widget is disposed,
        // then the future resolves — previously threw AnimationController.stop crash.
        final completer = Completer<List<String>>();
        controller.text = 'query';

        final suggestionsBox = await buildSuggestionsBox(tester);

        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: QuickSearchSuggestionList<String, String, String>(
              suggestionsBox: suggestionsBox,
              controller: controller,
              suggestionsCallback: (_) => completer.future,
              animationDuration: const Duration(milliseconds: 300),
              animationStart: 0.0,
              decoration: const QuickSearchSuggestionsBoxDecoration(),
              getImmediateSuggestions: true,
              minCharsForSuggestions: 0,
            ),
          ),
        ));

        // Let initState fire _getSuggestions; suspends at Future.wait.
        await tester.pump();

        // Simulate navigating away — disposes the widget mid-flight.
        await tester.pumpWidget(const SizedBox());

        // Resolving future must not crash (mounted check guards the setState).
        completer.complete([]);
        await tester.pump();

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'no crash when disposed while empty query _getListRecent is pending',
      (tester) async {
        // Empty query takes the queryString.isEmpty branch in _getSuggestions
        // and awaits _getListRecent before its setState.
        final completer = Completer<List<String>>();
        controller.text = '';

        final suggestionsBox = await buildSuggestionsBox(tester);

        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: QuickSearchSuggestionList<String, String, String>(
              suggestionsBox: suggestionsBox,
              controller: controller,
              fetchRecentActionCallback: (_) => completer.future,
              animationDuration: const Duration(milliseconds: 300),
              animationStart: 0.0,
              decoration: const QuickSearchSuggestionsBoxDecoration(),
              getImmediateSuggestions: true,
              minCharsForSuggestions: 0,
            ),
          ),
        ));

        await tester.pump();

        await tester.pumpWidget(const SizedBox());

        completer.complete([]);
        await tester.pump();

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'no crash when disposed while _handleDebounceTimeListener _getListRecent is pending',
      (tester) async {
        // Debounce listener path: short query (length <= minCharsForSuggestions)
        // awaits _getListRecent before its setState.
        const debounceDuration = Duration(milliseconds: 100);
        final completer = Completer<List<String>>();
        controller.text = '';

        final suggestionsBox = await buildSuggestionsBox(tester);

        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: QuickSearchSuggestionList<String, String, String>(
              suggestionsBox: suggestionsBox,
              controller: controller,
              fetchRecentActionCallback: (_) => completer.future,
              animationDuration: const Duration(milliseconds: 300),
              animationStart: 0.0,
              decoration: const QuickSearchSuggestionsBoxDecoration(),
              getImmediateSuggestions: false,
              minCharsForSuggestions: 5,
              debounceDuration: debounceDuration,
            ),
          ),
        ));

        await tester.pump();

        // Trigger the debounce listener: text length 1 <= minCharsForSuggestions 5.
        controller.text = 'a';
        // Advance clock past debounce duration to fire the timer.
        await tester.pump(debounceDuration);

        // Dispose before the completer resolves.
        await tester.pumpWidget(const SizedBox());

        // Resolving must not crash (mounted check guards the setState).
        completer.complete([]);
        await tester.pump();

        expect(tester.takeException(), isNull);
      },
    );
  });
}

Future<void> _mountSearch(
  WidgetTester tester,
  TextEditingController controller,
  Future<List<String>> Function(String) search, {
  Future<List<String>> Function(String)? recent,
  FocusNode? focusNode,
  int minChars = 0,
}) async {
  late QuickSearchSuggestionsBox box;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          box = QuickSearchSuggestionsBox(
            context,
            AxisDirection.down,
            false,
            false,
          );
          return const SizedBox();
        },
      ),
    ),
  );
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Focus(
          focusNode: focusNode,
          autofocus: focusNode != null,
          child: QuickSearchSuggestionList<String, String, String>(
            controller: controller,
            focusNode: focusNode,
            suggestionsBox: box,
            suggestionsCallback: search,
            fetchRecentActionCallback: recent,
            itemBuilder: (_, value) => Text(value),
            itemRecentBuilder: (_, value) => Text(value),
            getImmediateSuggestions: true,
            minCharsForSuggestions: minChars,
            debounceDuration: const Duration(milliseconds: 30),
            animationDuration: Duration.zero,
            animationStart: 1,
            decoration: const QuickSearchSuggestionsBoxDecoration(),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void _currentResultTests() {
  testWidgets(
    'new query runs while old request is pending; late old result is ignored',
    (tester) async {
      final controller = TextEditingController(text: 'old');
      final old = Completer<List<String>>();
      final latest = Completer<List<String>>();
      final calls = <String>[];
      await _mountSearch(tester, controller, (query) {
        calls.add(query);
        return query == 'old' ? old.future : latest.future;
      });
      controller.text = 'latest';
      await tester.pump(const Duration(milliseconds: 40));
      expect(calls, ['old', 'latest']);
      latest.complete(['latest result']);
      await tester.pump();
      await tester.pump();
      expect(find.text('latest result'), findsOneWidget);
      old.complete(['old result']);
      await tester.pump();
      expect(find.text('old result'), findsNothing);
      expect(find.text('latest result'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );

  testWidgets(
    'edit invalidates old response before debounce and starts latest query',
    (tester) async {
      final controller = TextEditingController(text: 'old');
      final old = Completer<List<String>>();
      final calls = <String>[];
      await _mountSearch(tester, controller, (query) {
        calls.add(query);
        return query == 'old' ? old.future : Future.value(['new result']);
      });
      controller.text = 'new';
      old.complete(['stale result']);
      await tester.pump();
      expect(find.text('stale result'), findsNothing);
      await tester.pump(const Duration(milliseconds: 40));
      await tester.pump();
      expect(calls, ['old', 'new']);
      expect(find.text('new result'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );

  testWidgets(
    'returning to the same text does not revive an earlier generation',
    (tester) async {
      final controller = TextEditingController(text: 'a');
      final old = Completer<List<String>>();
      final latest = Completer<List<String>>();
      var count = 0;
      await _mountSearch(
        tester,
        controller,
        (_) => ++count == 1 ? old.future : latest.future,
      );
      controller.text = 'b';
      controller.text = 'a';
      await tester.pump(const Duration(milliseconds: 40));
      expect(count, 2);
      latest.complete(['current a']);
      await tester.pump();
      old.complete(['old a']);
      await tester.pump();
      expect(find.text('current a'), findsOneWidget);
      expect(find.text('old a'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );

  testWidgets('late recent fallback cannot replace current email suggestions', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'old');
    final recent = Completer<List<String>>();
    await _mountSearch(
      tester,
      controller,
      (query) async => query == 'old' ? [] : ['new result'],
      recent: (_) => recent.future,
    );
    controller.text = 'new';
    await tester.pump(const Duration(milliseconds: 40));
    await tester.pump();
    recent.complete(['old recent']);
    await tester.pump();
    expect(find.text('new result'), findsOneWidget);
    expect(find.text('old recent'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets('blur cancels in-flight callbacks before recent fallback', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'first');
    final focus = FocusNode();
    final pending = Completer<List<String>>();
    var searches = 0;
    var recentCalls = 0;
    await _mountSearch(
      tester,
      controller,
      (_) {
        searches++;
        return pending.future;
      },
      recent: (_) async {
        recentCalls++;
        return ['stale recent'];
      },
      focusNode: focus,
    );
    expect(searches, 1);
    focus.unfocus();
    await tester.pump();
    pending.complete([]);
    await tester.pump();
    expect(recentCalls, 0);
    expect(find.text('stale recent'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    focus.dispose();
  });

  testWidgets('submit blur cancels pending debounce without another search', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'first');
    final focus = FocusNode();
    final calls = <String>[];
    await _mountSearch(tester, controller, (query) async {
      calls.add(query);
      return ['result'];
    }, focusNode: focus);
    expect(focus.hasFocus, isTrue);
    expect(calls, ['first']);
    controller.text = 'submit';
    focus.unfocus();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    expect(calls, ['first']);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    focus.dispose();
  });
}
