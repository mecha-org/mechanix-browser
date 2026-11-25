import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mechanix_browser/core/utils/app_theme.dart';
import 'package:mechanix_browser/features/browser/bloc/browser_bloc.dart';
import 'package:mechanix_browser/features/browser/data/models/browser_history.dart';
import 'package:mechanix_browser/features/browser/presentation/widgets/browser_bottom_bar.dart';
import 'package:mechanix_browser/l10n/app_localizations.dart';

/// Starts with two suggestions and records events instead of running them.
class _SuggestionsBloc extends BrowserBloc {
  _SuggestionsBloc() {
    // ignore: invalid_use_of_visible_for_testing_member
    emit(
      state.copyWith(
        isInitialized: true,
        searchResults: [
          BrowserHistory(url: 'https://a.example/', title: 'A', timestamp: 0),
          BrowserHistory(url: 'https://b.example/', title: 'B', timestamp: 0),
        ],
      ),
    );
  }

  final events = <BrowserEvent>[];

  @override
  void add(BrowserEvent event) => events.add(event);
}

void main() {
  late _SuggestionsBloc bloc;
  late FocusNode addressBar;

  Future<void> pump(WidgetTester tester) async {
    bloc = _SuggestionsBloc();
    // Not closed: close() shuts down CEF, which isn't running.
    addressBar = FocusNode();
    addTearDown(addressBar.dispose);
    await tester.pumpWidget(
      BlocProvider<BrowserBloc>.value(
        value: bloc,
        child: MaterialApp(
          theme: AppTheme.dark,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                height: 72,
                child: BrowserBottomBar(addressBarFocusNode: addressBar),
              ),
            ),
          ),
        ),
      ),
    );
    addressBar.requestFocus();
    await tester.pumpAndSettle();
  }

  List<String> loaded() => [
    for (final e in bloc.events)
      if (e is BrowserUrlLoadRequested) e.url,
  ];

  // Linux is where a text field drops focus on any touch outside it.
  testWidgets(
    'tapping a suggestion opens it',
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
    (tester) async {
      await pump(tester);
      expect(find.text('B'), findsOneWidget);

      // Press, let frames run (as on a real screen), then lift.
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('B')),
      );
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(loaded(), ['https://b.example/']);
      expect(addressBar.hasFocus, isFalse);
      expect(find.text('B'), findsNothing);
    },
  );

  testWidgets(
    'Down then Enter opens the highlighted suggestion',
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
    (tester) async {
      await pump(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(loaded(), ['https://b.example/']);
    },
  );

  testWidgets(
    'a tap outside the bar and suggestions closes them',
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
    (tester) async {
      await pump(tester);

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(addressBar.hasFocus, isFalse);
      expect(find.text('B'), findsNothing);
      expect(loaded(), isEmpty);
    },
  );

  testWidgets(
    "the long-press menu's Paste pastes into the address bar",
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
    (tester) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async => call.method == 'Clipboard.getData'
            ? {'text': 'copied in the page'}
            : null,
      );
      await pump(tester);

      await tester.longPress(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(find.text('Paste'), findsOneWidget);

      // Press, let frames run (as on a real screen), then lift.
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Paste')),
      );
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.up();
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, contains('copied in the page'));
      expect(addressBar.hasFocus, isTrue);
      expect(loaded(), isEmpty);
    },
  );
}
