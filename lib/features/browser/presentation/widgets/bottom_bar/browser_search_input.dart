import 'package:flutter/material.dart';
import 'package:mechanix_browser/core/utils/app_theme.dart';
import 'package:mechanix_browser/features/browser/presentation/widgets/app_text_context_menu.dart';
import 'package:mechanix_browser/l10n/app_localizations.dart';

/// [TapRegion] group of the address bar and everything that belongs to it
/// (suggestions, its long-press menu): a tap outside the group closes them.
const browserSearchTapGroup = 'browser_search';

class BrowserSearchInput extends StatelessWidget {
  final FocusNode focusNode;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final bool isPrivate;

  const BrowserSearchInput({
    super.key,
    required this.focusNode,
    required this.controller,
    required this.onChanged,
    required this.onSubmitted,
    this.isPrivate = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColorsExtension>()!;
    final l10n = AppLocalizations.of(context)!;

    return SearchBar(
      focusNode: focusNode,
      controller: controller,
      elevation: const WidgetStatePropertyAll(0),
      backgroundColor: WidgetStatePropertyAll(colors.searchBarBackground),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: colors.searchBarBorder, width: 1),
        ),
      ),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 16),
      ),
      constraints: const BoxConstraints(minHeight: 48, maxHeight: 48),
      leading: isPrivate
          ? Icon(
              Icons.visibility_off_outlined,
              color: colors.inactiveGrey,
              size: 18,
            )
          : Icon(Icons.lock_outline, color: colors.inactiveGrey, size: 18),
      hintText: isPrivate
          ? l10n.appTitlePrivate(l10n.searchOrEnterAddress)
          : l10n.searchOrEnterAddress,
      hintStyle: WidgetStatePropertyAll(
        theme.textTheme.bodyLarge?.copyWith(color: colors.searchBarHint),
      ),
      textStyle: WidgetStatePropertyAll(
        theme.textTheme.bodyLarge?.copyWith(color: colors.searchBarText),
      ),
      keyboardType: TextInputType.url,
      // On Linux a text field unfocuses on any touch outside it, which closed
      // the suggestions before a tap on one could land. The bottom bar's
      // [browserSearchTapGroup] TapRegion (bar + suggestions) handles
      // outside taps.
      onTapOutside: (_) {},
      contextMenuBuilder: appTextContextMenuInGroup(browserSearchTapGroup),
      onChanged: onChanged,
      onSubmitted: onSubmitted,
    );
  }
}
