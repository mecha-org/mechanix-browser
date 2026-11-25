import 'package:flutter/material.dart';
import 'package:mechanix_browser/core/utils/app_theme.dart';
import 'package:mechanix_browser/features/browser/bloc/browser_bloc.dart';
import 'package:mechanix_browser/features/browser/data/models/browser_history.dart';
import 'package:mechanix_browser/features/browser/presentation/widgets/list_key_navigation.dart';

class BrowserSuggestionsPanel extends StatelessWidget {
  final TextEditingController textController;
  final BrowserBloc bloc;
  final BrowserState state;

  /// Opens a suggestion (tapped, or picked with the arrow keys and Enter).
  final ValueChanged<BrowserHistory> onSelect;

  /// The suggestion highlighted with the arrow keys from the address bar.
  final ListHighlightController highlight;

  const BrowserSuggestionsPanel({
    super.key,
    required this.textController,
    required this.bloc,
    required this.state,
    required this.onSelect,
    required this.highlight,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColorsExtension>()!;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colors.panelBackground.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.panelBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: colors.popupBarrierColor.withValues(alpha: 0.5),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      constraints: const BoxConstraints(maxHeight: 280),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        // The rows paint their ink on a Material; the coloured box above
        // would otherwise cover it.
        child: Material(
          type: MaterialType.transparency,
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: state.searchResults.length,
            separatorBuilder: (context, index) =>
                Divider(color: colors.dividerColor, height: 1),
            itemBuilder: (context, index) {
              final item = state.searchResults[index];
              return HighlightedRow(
                controller: highlight,
                index: index,
                borderRadius: BorderRadius.zero,
                child: ListTile(
                  leading: const _SuggestionLeadingIcon(),
                  title: Text(
                    item.title,
                    style: theme.textTheme.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    item.url,
                    style: theme.textTheme.labelSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  trailing: IconButton(
                    icon: Icon(
                      Icons.close,
                      size: 16,
                      color: colors.textTertiary,
                    ),
                    onPressed: () {
                      bloc.add(
                        BrowserHistoryItemDeleted(item, textController.text),
                      );
                    },
                  ),
                  onTap: () => onSelect(item),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SuggestionLeadingIcon extends StatelessWidget {
  const _SuggestionLeadingIcon();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorsExtension>()!;
    return Icon(Icons.history, color: colors.inactiveGrey, size: 20);
  }
}
