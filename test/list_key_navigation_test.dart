import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mechanix_browser/core/utils/app_theme.dart';
import 'package:mechanix_browser/features/browser/presentation/widgets/list_key_navigation.dart';
import 'package:mechanix_browser/features/browser/presentation/widgets/list_search_field.dart';

void main() {
  group('ListHighlightController', () {
    test('Down starts at the first row, Up at the last', () {
      final down = ListHighlightController()..itemCount = 3;
      down.next();
      expect(down.current, 0);

      final up = ListHighlightController()..itemCount = 3;
      up.previous();
      expect(up.current, 2);
    });

    test('moving past either end goes back to no highlight', () {
      final c = ListHighlightController()..itemCount = 2;
      c.next();
      c.next();
      expect(c.current, 1);
      c.next();
      expect(c.current, isNull);

      c.next();
      c.previous();
      expect(c.current, isNull);
    });

    test('a row that left the list is not current', () {
      final c = ListHighlightController()..itemCount = 3;
      c.previous(); // row 2
      c.itemCount = 2;
      expect(c.current, isNull);
    });

    test('does nothing on an empty list', () {
      final c = ListHighlightController();
      c.next();
      c.previous();
      expect(c.value, isNull);
    });
  });

  group('ListSearchField', () {
    late ListHighlightController highlight;
    late List<int?> submitted;

    Future<void> pump(WidgetTester tester, {int rows = 3}) async {
      highlight = ListHighlightController()..itemCount = rows;
      submitted = [];
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: [AppColorsExtension.dark]),
          home: Scaffold(
            body: Column(
              children: [
                ListSearchField(
                  hintText: 'Search',
                  highlight: highlight,
                  onSubmitted: () => submitted.add(highlight.current),
                  onChanged: (_) {},
                ),
                for (var i = 0; i < rows; i++)
                  HighlightedRow(
                    controller: highlight,
                    index: i,
                    child: SizedBox(height: 40, child: Text('row $i')),
                  ),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.byType(TextField));
      await tester.pump();
    }

    testWidgets('arrow keys move the highlight while the field keeps focus', (
      tester,
    ) async {
      await pump(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      expect(highlight.current, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      expect(highlight.current, 0);

      final field = tester.widget<EditableText>(find.byType(EditableText));
      expect(field.focusNode.hasFocus, isTrue);
    });

    testWidgets('Enter submits with the highlighted row', (tester) async {
      await pump(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.testTextInput.receiveAction(TextInputAction.search);
      expect(submitted, [2]);
    });

    testWidgets('typing clears the highlight', (tester) async {
      await pump(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      expect(highlight.current, 0);
      await tester.enterText(find.byType(TextField), 'abc');
      expect(highlight.current, isNull);
    });

    testWidgets('Escape clears the highlight', (tester) async {
      await pump(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      expect(highlight.current, isNull);
    });

    testWidgets('arrows are left alone when the list is empty', (tester) async {
      await pump(tester, rows: 0);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      expect(highlight.value, isNull);
    });
  });
}
