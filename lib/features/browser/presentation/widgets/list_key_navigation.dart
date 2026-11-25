import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mechanix_browser/core/utils/app_theme.dart';

/// The row highlighted with the arrow keys from a search field, or null.
///
/// Down from no highlight goes to the first row, Up to the last; moving past
/// either end clears the highlight again, back to plain typing.
class ListHighlightController extends ValueNotifier<int?> {
  ListHighlightController() : super(null);

  /// Number of rows; set by the list on every build.
  int itemCount = 0;

  /// The highlighted row, if it is still in the list.
  int? get current {
    final index = value;
    return index != null && index < itemCount ? index : null;
  }

  void next() {
    if (itemCount == 0) return;
    final index = current;
    value = index == null ? 0 : (index + 1 < itemCount ? index + 1 : null);
  }

  void previous() {
    if (itemCount == 0) return;
    final index = current;
    value = index == null ? itemCount - 1 : (index > 0 ? index - 1 : null);
  }

  void clear() => value = null;
}

/// Moves [controller]'s highlight with the Up/Down arrow keys while focus
/// stays in the search field [child], so typing keeps working.
///
/// Enter isn't handled here: the elinux embedder delivers Enter to the
/// field's `onSubmitted` itself, so callers open [ListHighlightController.current]
/// from there.
class ListKeyNavigation extends StatelessWidget {
  final ListHighlightController controller;
  final Widget child;

  const ListKeyNavigation({
    super.key,
    required this.controller,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (node, event) {
        if (event is KeyUpEvent) return KeyEventResult.ignored;
        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.arrowDown && controller.itemCount > 0) {
          controller.next();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowUp && controller.itemCount > 0) {
          controller.previous();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.escape && controller.current != null) {
          controller.clear();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: child,
    );
  }
}

/// Row [index] of a list driven by [controller]: drawn highlighted while it
/// is the current row, and scrolled into view when it becomes current.
class HighlightedRow extends StatefulWidget {
  final ListHighlightController controller;
  final int index;
  final BorderRadius borderRadius;
  final Widget child;

  const HighlightedRow({
    super.key,
    required this.controller,
    required this.index,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    required this.child,
  });

  @override
  State<HighlightedRow> createState() => _HighlightedRowState();
}

class _HighlightedRowState extends State<HighlightedRow> {
  bool get _isCurrent => widget.controller.current == widget.index;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(HighlightedRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onChanged);
      widget.controller.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    setState(() {});
    if (!_isCurrent) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_isCurrent) return;
      // Scroll only as far as needed, whichever edge the row is past.
      Scrollable.ensureVisible(
        context,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
      Scrollable.ensureVisible(
        context,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorsExtension>()!;
    // A Material, not a DecoratedBox: rows (ListTile, InkWell) paint their
    // ink on the nearest Material, which a coloured box would cover.
    return Material(
      color: _isCurrent ? colors.shortcutHoverBackground : Colors.transparent,
      borderRadius: widget.borderRadius,
      child: widget.child,
    );
  }
}
