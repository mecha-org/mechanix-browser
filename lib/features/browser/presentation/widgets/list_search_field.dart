import 'package:flutter/material.dart';
import 'package:mechanix_browser/core/utils/app_theme.dart';
import 'package:mechanix_browser/features/browser/presentation/widgets/app_text_context_menu.dart';
import 'package:mechanix_browser/features/browser/presentation/widgets/list_key_navigation.dart';

/// Search box above the history and bookmarks lists. Reports every change
/// through [onChanged]; the clear button resets the query to ''.
///
/// With [highlight], the Up/Down arrow keys move through the list below while
/// typing continues here, and Enter calls [onSubmitted] (which opens the
/// highlighted row).
class ListSearchField extends StatefulWidget {
  final String hintText;
  final ValueChanged<String> onChanged;
  final ListHighlightController? highlight;
  final VoidCallback? onSubmitted;

  const ListSearchField({
    super.key,
    required this.hintText,
    required this.onChanged,
    this.highlight,
    this.onSubmitted,
  });

  @override
  State<ListSearchField> createState() => _ListSearchFieldState();
}

class _ListSearchFieldState extends State<ListSearchField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    widget.highlight?.clear();
    widget.onChanged('');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorsExtension>()!;
    final field = TextField(
      controller: _controller,
      onChanged: (value) {
        // The list changes with the query, so the old row no longer applies.
        widget.highlight?.clear();
        widget.onChanged(value);
        setState(() {}); // show or hide the clear button
      },
      onSubmitted: (_) => widget.onSubmitted?.call(),
      contextMenuBuilder: appTextContextMenu,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: widget.hintText,
        hintStyle: TextStyle(color: colors.searchBarHint),
        prefixIcon: Icon(Icons.search, color: colors.searchBarHint),
        suffixIcon: _controller.text.isEmpty
            ? null
            : IconButton(
                icon: Icon(Icons.close, color: colors.searchBarHint),
                onPressed: _clear,
              ),
        filled: true,
        fillColor: colors.panelBackground,
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
    final highlight = widget.highlight;
    return highlight == null
        ? field
        : ListKeyNavigation(controller: highlight, child: field);
  }
}
