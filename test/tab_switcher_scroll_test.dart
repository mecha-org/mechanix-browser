import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mechanix_browser/core/utils/app_theme.dart';
import 'package:mechanix_browser/features/browser/bloc/browser_bloc.dart';
import 'package:mechanix_browser/features/browser/data/models/browser_tab.dart';
import 'package:mechanix_browser/features/browser/presentation/widgets/tab_switcher_sheet.dart';
import 'package:mechanix_browser/l10n/app_localizations.dart';
import 'package:webview_cef/webview_cef.dart';

BrowserTab _tab(String title, {bool isPrivate = false}) => BrowserTab(
  id: title,
  controller: WebviewManager().createWebView(),
  currentUrl: 'https://$title.example/',
  title: title,
  isHomePage: false,
  isLoading: false,
  isPrivate: isPrivate,
);

/// Holds the given tabs and records events instead of running them.
class _TabsBloc extends BrowserBloc {
  _TabsBloc() {
    // ignore: invalid_use_of_visible_for_testing_member
    emit(
      state.copyWith(
        isInitialized: true,
        normalTabs: [for (var i = 0; i < 12; i++) _tab('normal$i')],
        activeNormalTabIndex: 10,
        privateTabs: [
          for (var i = 0; i < 12; i++) _tab('private$i', isPrivate: true),
        ],
        activePrivateTabIndex: 1,
        tabSwitcherMode: BrowserMode.normal,
      ),
    );
  }

  void showPrivateTabs() {
    // ignore: invalid_use_of_visible_for_testing_member
    emit(state.copyWith(tabSwitcherMode: BrowserMode.private));
  }

  @override
  void add(BrowserEvent event) {}
}

void main() {
  late _TabsBloc bloc;

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    bloc = _TabsBloc();
    // Not closed: close() shuts down CEF, which isn't running.
    await tester.pumpWidget(
      BlocProvider<BrowserBloc>.value(
        value: bloc,
        child: MaterialApp(
          theme: AppTheme.dark,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: TabSwitcherSheet(bloc: bloc)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Whether the card titled [title] is fully on screen.
  bool onScreen(WidgetTester tester, String title) {
    final finder = find.text(title);
    if (finder.evaluate().isEmpty) return false;
    final rect = tester.getRect(finder);
    return rect.top >= 0 && rect.bottom <= 800;
  }

  testWidgets('opens on the active tab', (tester) async {
    await pump(tester);
    expect(onScreen(tester, 'normal10'), isTrue);
    expect(onScreen(tester, 'normal0'), isFalse, reason: 'scrolled down');
  });

  testWidgets('switching to private tabs lands on their active tab', (
    tester,
  ) async {
    await pump(tester);
    bloc.showPrivateTabs();
    await tester.pumpAndSettle();
    expect(onScreen(tester, 'private1'), isTrue);
  });
}
