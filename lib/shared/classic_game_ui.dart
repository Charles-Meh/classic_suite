import 'package:flutter/material.dart';
import 'package:playing_cards/playing_cards.dart';

class GameStatItem {
  const GameStatItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;
}

class GameStatsRow extends StatelessWidget {
  const GameStatsRow({
    super.key,
    required this.items,
    this.dark = true,
    this.customChildren = const [],
  });

  final List<GameStatItem> items;
  final bool dark;
  final List<Widget> customChildren;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        ...customChildren,
        for (final item in items) _GameStatChip(item: item, dark: dark),
      ],
    );
  }
}

class _GameStatChip extends StatelessWidget {
  const _GameStatChip({required this.item, required this.dark});

  final GameStatItem item;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final fg = dark ? Colors.white : Theme.of(context).colorScheme.onSurface;
    final bg = dark
        ? Colors.white.withValues(alpha: 0.12)
        : Theme.of(context).colorScheme.surface;
    final border = dark
        ? Colors.white.withValues(alpha: 0.16)
        : Theme.of(context).colorScheme.outlineVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(item.icon, size: 18, color: fg.withValues(alpha: 0.92)),
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.label,
                style: TextStyle(
                  color: fg.withValues(alpha: 0.75),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                item.value,
                style: TextStyle(
                  color: fg,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class GameBottomBar extends StatelessWidget {
  const GameBottomBar({
    super.key,
    this.onUndo,
    this.onHint,
    this.leading,
    required this.onNewDeal,
    required this.onStatistics,
    this.undoEnabled = true,
    this.hintEnabled = true,
    this.showUndoButton = true,
    this.showHintButton = true,
    this.newDealLabel = 'New Deal',
  });

  final VoidCallback? onUndo;
  final VoidCallback? onHint;
  final Widget? leading;
  final VoidCallback onNewDeal;
  final VoidCallback onStatistics;
  final bool undoEnabled;
  final bool hintEnabled;
  final bool showUndoButton;
  final bool showHintButton;
  final String newDealLabel;

  @override
  Widget build(BuildContext context) {
    final leadingActions = <Widget>[
      if (leading != null) leading!,
      if (showUndoButton)
        IconButton.filledTonal(
          onPressed: undoEnabled ? onUndo : null,
          tooltip: 'Undo',
          icon: const Icon(Icons.undo_rounded),
        ),
      if (showHintButton)
        IconButton.filledTonal(
          onPressed: hintEnabled ? onHint : null,
          tooltip: 'Hint',
          icon: const Icon(Icons.lightbulb_outline_rounded),
        ),
    ];

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF111827)
              : Colors.white,
          border: Border(
            top: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 18,
              offset: Offset(0, -6),
            ),
          ],
        ),
        child: Row(
          children: [
            if (leadingActions.isNotEmpty)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (
                    int index = 0;
                    index < leadingActions.length;
                    index++
                  ) ...[
                    if (index > 0) const SizedBox(width: 8),
                    leadingActions[index],
                  ],
                ],
              ),
            if (leadingActions.isNotEmpty) const SizedBox(width: 12),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: FilledButton.icon(
                  onPressed: onNewDeal,
                  icon: const Icon(Icons.casino_outlined),
                  label: Text(newDealLabel),
                ),
              ),
            ),
            const SizedBox(width: 12),
            IconButton.filledTonal(
              onPressed: onStatistics,
              tooltip: 'Statistics',
              icon: const Icon(Icons.bar_chart_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class ClassicPlayingCard extends StatelessWidget {
  const ClassicPlayingCard({
    super.key,
    required this.card,
    required this.width,
    required this.height,
    this.showBack = false,
    this.cornerRadius = 14,
    this.borderColor,
    this.borderWidth = 1.2,
    this.highlightColor,
    this.disabled = false,
    this.valueLabel,
  });

  final PlayingCard card;
  final double width;
  final double height;
  final bool showBack;
  final double cornerRadius;
  final Color? borderColor;
  final double borderWidth;
  final Color? highlightColor;
  final bool disabled;
  final String? valueLabel;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(cornerRadius);

    final isRed = card.suit == Suit.hearts || card.suit == Suit.diamonds;
    final color = disabled
        ? (isRed ? const Color(0xFFC62828) : const Color(0xFF1A1A1A))
              .withValues(alpha: 0.45)
        : (isRed ? const Color(0xFFC62828) : const Color(0xFF1A1A1A));

    // Use the playing_cards package imagery where available for a more polished look.
    // The package provides a card back image.
    final backAsset = 'assets/card_imagery/back_001.png';

    if (showBack) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: radius,
          border: Border.all(
            color: highlightColor ?? borderColor ?? const Color(0xFFD6D6D6),
            width: borderWidth,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 5,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: Transform.scale(
            scale: 1.035,
            child: Image.asset(
              backAsset,
              fit: BoxFit.cover,
              package: 'playing_cards',
              filterQuality: FilterQuality.high,
            ),
          ),
        ),
      );
    }

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: radius,
        border: Border.all(
          color: highlightColor ?? borderColor ?? const Color(0xFFD6D6D6),
          width: borderWidth,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            // Render a polished card face using the playing_cards package.
            Positioned.fill(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: 64,
                  height: 89,
                  child: PlayingCardView(
                    card: card,
                    showBack: false,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: radius),
                    style: PlayingCardViewStyle(
                      cardBackgroundColor: Colors.white,
                      surfaceTintColor: Colors.transparent,
                      suitStyles: {
                        card.suit: SuitStyle(
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      },
                    ),
                  ),
                ),
              ),
            ),
            if (valueLabel != null)
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    valueLabel!,
                    style: TextStyle(
                      color: color.withValues(alpha: 0.72),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class ClassicCardPlaceholder extends StatelessWidget {
  const ClassicCardPlaceholder({
    super.key,
    required this.width,
    required this.height,
    required this.label,
    this.cornerRadius = 14,
    this.active = false,
    this.dark = true,
  });

  final double width;
  final double height;
  final String label;
  final double cornerRadius;
  final bool active;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final borderColor = dark
        ? (active
              ? Colors.white.withValues(alpha: 0.95)
              : Colors.white.withValues(alpha: 0.42))
        : (active
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outlineVariant);
    final backgroundColor = dark
        ? (active
              ? Colors.white.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.08))
        : (active
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surfaceContainerLow);
    final labelColor = dark
        ? Colors.white.withValues(alpha: 0.82)
        : Theme.of(context).colorScheme.onSurfaceVariant;

    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(cornerRadius),
        border: Border.all(color: borderColor, width: active ? 2 : 1.2),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: labelColor,
          fontWeight: FontWeight.w700,
          fontSize: width * 0.28,
          letterSpacing: 1,
        ),
      ),
    );
  }
}
