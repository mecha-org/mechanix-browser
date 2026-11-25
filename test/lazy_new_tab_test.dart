import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mechanix_browser/core/database/app_database.dart';
import 'package:mechanix_browser/features/browser/bloc/browser_bloc.dart';
import 'package:mechanix_browser/features/browser/data/bookmarks/bookmark_model.dart';
import 'package:mechanix_browser/features/browser/data/repositories/bookmark_repository.dart';
import 'package:mechanix_browser/features/browser/data/repositories/history_repository_impl.dart';
import 'package:mechanix_browser/features/browser/data/repositories/tab_repository.dart';

/// Records the URL of every browser the webview plugin is asked to create.
final created = <String>[];

/// Lets queued events, the plugin's start-up delay (300 ms) and browser
/// creation (50 ms) run.
Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 600));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BrowserBloc bloc;
  var nextId = 1;

  setUp(() async {
    created.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('webview_cef'), (
          call,
        ) async {
          if (call.method == 'create') {
            created.add((call.arguments as List)[0] as String);
            final id = nextId++;
            return [id, id];
          }
          return null;
        });
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final dir = Directory.systemTemp.createTempSync('lazy_new_tab_test');
    addTearDown(() => dir.deleteSync(recursive: true));
    final bookmarks = await BookmarkModel.load(File('${dir.path}/Bookmarks'));
    addTearDown(bookmarks.close);
    bloc = BrowserBloc(
      historyRepository: HistoryRepositoryImpl(db: db),
      tabRepository: TabRepository(db: db),
      bookmarkRepository: BookmarkRepository(model: bookmarks),
    );
    // Not closed: close() shuts down CEF, which isn't running.
  });

  /// Starts the browser as the browser screen does; it opens on one tab.
  Future<void> start() async {
    bloc.add(BrowserInitialized());
    await settle();
  }

  test('new tabs on the home page create no browser', () async {
    await start();
    for (var i = 0; i < 5; i++) {
      bloc.add(const BrowserNewTabRequested());
    }
    await settle();

    expect(bloc.state.normalTabs, hasLength(6));
    expect(bloc.state.activeTab!.isHomePage, isTrue);
    expect(created, isEmpty);
  });

  test('the first navigation creates the browser, on that URL', () async {
    await start();
    bloc.add(const BrowserNewTabRequested());
    bloc.add(const BrowserNewTabRequested());
    await settle();

    bloc.add(const BrowserUrlLoadRequested('https://a.example/'));
    await settle();

    expect(created, ['https://a.example/']);
    expect(bloc.state.activeTab!.controller.value, isTrue);
    expect(bloc.state.activeTab!.isHomePage, isFalse);
  });

  test('a URL typed while the browser is being created still loads', () async {
    final loaded = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('webview_cef'), (
          call,
        ) async {
          if (call.method == 'create') {
            created.add((call.arguments as List)[0] as String);
            final id = nextId++;
            return [id, id];
          }
          if (call.method == 'loadUrl') {
            loaded.add((call.arguments as List)[1] as String);
          }
          return null;
        });
    await start();
    bloc.add(const BrowserNewTabRequested());
    await settle();

    bloc.add(const BrowserUrlLoadRequested('https://a.example/'));
    bloc.add(const BrowserUrlLoadRequested('https://b.example/'));
    await settle();

    expect(created, ['https://a.example/'], reason: 'one browser only');
    expect(loaded, ['https://b.example/']);
  });

  test('switching to a home-page tab creates no browser', () async {
    await start();
    bloc.add(const BrowserNewTabRequested());
    await settle();
    final homeTabId = bloc.state.activeTab!.id;
    bloc.add(const BrowserNewTabRequested());
    bloc.add(const BrowserUrlLoadRequested('https://a.example/'));
    await settle();
    expect(created, hasLength(1));

    bloc.add(BrowserSwitchTabRequested(homeTabId));
    await settle();

    expect(bloc.state.activeTab!.id, homeTabId);
    expect(created, hasLength(1));
  });
}
