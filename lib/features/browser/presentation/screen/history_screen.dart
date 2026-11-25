import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mechanix_browser/core/utils/app_theme.dart';
import 'package:mechanix_browser/features/browser/bloc/browser_bloc.dart';
import 'package:mechanix_browser/features/browser/bloc/history/history_bloc.dart';
import 'package:mechanix_browser/features/browser/data/models/browser_history.dart';
import 'package:mechanix_browser/features/browser/presentation/widgets/history/history_section.dart';
import 'package:mechanix_browser/features/browser/presentation/widgets/list_key_navigation.dart';
import 'package:mechanix_browser/features/browser/presentation/widgets/list_search_field.dart';
import 'package:mechanix_browser/l10n/app_localizations.dart';
import 'package:mechanix_browser/features/browser/data/models/page_transition.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _highlight = ListHighlightController();

  @override
  void initState() {
    super.initState();
    context.read<HistoryBloc>().add(const HistoryLoadRequested());
  }

  @override
  void dispose() {
    _highlight.dispose();
    super.dispose();
  }

  /// Enter in the search field opens the row picked with the arrow keys.
  void _onSearchSubmitted(BuildContext context, HistoryState state) {
    final index = _highlight.current;
    if (index == null) return;
    final items = state.groupedSections.expand((g) => g.items).toList();
    if (index < items.length) _onItemTap(context, items[index]);
  }

  void _onItemTap(BuildContext context, BrowserHistory item) {
    if (item.url.isNotEmpty) {
      context.read<BrowserBloc>().add(
        BrowserUrlLoadRequested(item.url, transition: PageTransition.link),
      );
      Navigator.pop(context);
    }
  }

  void _onItemDelete(BuildContext context, BrowserHistory item) {
    context.read<HistoryBloc>().add(HistoryItemDeleted(item));
  }

  /// Loads the next page when the list is scrolled near its end.
  bool _onScroll(BuildContext context, ScrollNotification notification) {
    if (notification.metrics.extentAfter < 600) {
      context.read<HistoryBloc>().add(const HistoryLoadMoreRequested());
    }
    return false;
  }

  void _onClearAll(BuildContext context) {
    context.read<HistoryBloc>().add(const HistoryClearRequested());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColorsExtension>()!;
    final l10n = AppLocalizations.of(context)!;

    return BlocBuilder<HistoryBloc, HistoryState>(
      builder: (context, state) {
        final hasItems = !state.isEmpty;
        final isSearching = state.searchQuery.isNotEmpty;

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(l10n.history),
            actions: [
              if (hasItems && !isSearching)
                TextButton(
                  onPressed: () => _onClearAll(context),
                  child: Text(
                    l10n.clearAll,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: ListSearchField(
                  hintText: l10n.searchHistory,
                  highlight: _highlight,
                  onSubmitted: () => _onSearchSubmitted(context, state),
                  onChanged: (query) => context.read<HistoryBloc>().add(
                    HistorySearchQueryChanged(query),
                  ),
                ),
              ),
              Expanded(child: _buildList(context, state)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildList(BuildContext context, HistoryState state) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColorsExtension>()!;
    final l10n = AppLocalizations.of(context)!;
    // Arrow keys move through the rows on screen; sections start where the
    // previous ones end.
    final firstIndexes = <int>[];
    var rowCount = 0;
    for (final group in state.groupedSections) {
      firstIndexes.add(rowCount);
      rowCount += group.items.length;
    }
    _highlight.itemCount = state.isLoading ? 0 : rowCount;
    if (state.isEmpty && state.searchQuery.isNotEmpty && !state.isLoading) {
      return Center(
        child: Text(l10n.noSearchResults, style: theme.textTheme.bodyMedium),
      );
    }
    return state.isLoading
        ? const Center(child: CircularProgressIndicator())
        : state.isEmpty
        // ? const HistoryEmptyState()
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: colors.panelBackground,
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.dividerColor, width: 1.5),
                  ),
                  child: Icon(
                    Icons.history,
                    color: colors.textSecondary,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.comingSoon(l10n.history),
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(l10n.workingHard, style: theme.textTheme.bodySmall),
              ],
            ),
          )
        : NotificationListener<ScrollNotification>(
            onNotification: (n) => _onScroll(context, n),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              itemCount:
                  state.groupedSections.length + (state.isLoadingMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == state.groupedSections.length) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final group = state.groupedSections[index];
                return HistorySection(
                  group: group,
                  onItemTap: (item) => _onItemTap(context, item),
                  onItemDelete: (item) => _onItemDelete(context, item),
                  highlight: _highlight,
                  firstIndex: firstIndexes[index],
                );
              },
            ),
          );
  }
}
