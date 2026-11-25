import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mechanix_browser/features/browser/presentation/widgets/app_text_context_menu.dart';

void main() {
  String? clipboard;

  setUp(() {
    clipboard = null;
    // Like the elinux embedder: getData works, hasStrings isn't implemented.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          switch (call.method) {
            case 'Clipboard.getData':
              return clipboard == null ? null : {'text': clipboard};
            case 'Clipboard.hasStrings':
              throw MissingPluginException();
          }
          return null;
        });
  });

  Future<TextEditingController> pump(
    WidgetTester tester, {
    bool withAppMenu = true,
  }) async {
    final controller = TextEditingController(text: 'hello');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TextField(
            controller: controller,
            contextMenuBuilder: withAppMenu ? appTextContextMenu : null,
          ),
        ),
      ),
    );
    await tester.longPress(find.byType(TextField));
    await tester.pumpAndSettle();
    return controller;
  }

  testWidgets('without it, Flutter leaves Paste out (the device bug)', (
    tester,
  ) async {
    clipboard = 'copied in the page';
    await pump(tester, withAppMenu: false);
    expect(find.text('Paste'), findsNothing);
  });

  testWidgets('offers Paste when the clipboard has text', (tester) async {
    clipboard = 'copied in the page';
    final controller = await pump(tester);
    expect(find.text('Paste'), findsOneWidget);

    await tester.tap(find.text('Paste'));
    await tester.pumpAndSettle();
    expect(controller.text, contains('copied in the page'));
  });

  testWidgets('no Paste when the clipboard is empty', (tester) async {
    await pump(tester);
    expect(find.text('Paste'), findsNothing);
    expect(find.text('Select all'), findsOneWidget);
  });
}
