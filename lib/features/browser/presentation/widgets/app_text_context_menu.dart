import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Long-press menu for the app's text fields, offering Paste whenever the
/// clipboard has text.
///
/// The elinux embedder doesn't implement `Clipboard.hasStrings`, so
/// Flutter's own menu never learns that the clipboard has text and leaves
/// Paste out (Ctrl+V still works: it uses `Clipboard.getData`). This menu
/// asks with `Clipboard.getData` instead.
Widget appTextContextMenu(
  BuildContext context,
  EditableTextState editableTextState,
) => _AppTextContextMenu(editableTextState: editableTextState);

class _AppTextContextMenu extends StatefulWidget {
  final EditableTextState editableTextState;

  const _AppTextContextMenu({required this.editableTextState});

  @override
  State<_AppTextContextMenu> createState() => _AppTextContextMenuState();
}

class _AppTextContextMenuState extends State<_AppTextContextMenu> {
  bool _clipboardHasText = false;

  @override
  void initState() {
    super.initState();
    // Not `pasteEnabled`: that also waits on the hasStrings answer.
    if (!widget.editableTextState.widget.readOnly) _checkClipboard();
  }

  Future<void> _checkClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final hasText = data?.text?.isNotEmpty ?? false;
    if (mounted && hasText) setState(() => _clipboardHasText = true);
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.editableTextState;
    final items = [...state.contextMenuButtonItems];
    final hasPaste = items.any((i) => i.type == ContextMenuButtonType.paste);
    if (_clipboardHasText && !hasPaste) {
      // Where Flutter puts it: after cut/copy, before select all.
      final selectAll = items.indexWhere(
        (i) => i.type == ContextMenuButtonType.selectAll,
      );
      items.insert(
        selectAll == -1 ? items.length : selectAll,
        ContextMenuButtonItem(
          type: ContextMenuButtonType.paste,
          onPressed: () => state.pasteText(SelectionChangedCause.toolbar),
        ),
      );
    }
    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: state.contextMenuAnchors,
      buttonItems: items,
    );
  }
}
