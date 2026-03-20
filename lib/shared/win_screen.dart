import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class WinScreenStat {
  const WinScreenStat({required this.label, required this.value, this.icon});

  final String label;
  final String value;
  final IconData? icon;
}

enum WinScreenTheme {
  klondike,
  spider,
  freecell,
  hearts,
  chess,
  checkers,
  minesweeper,
  sudoku,
  twentyFortyEight,
  pyramid,
  tripeaks,
}

class GameWinScreen extends StatelessWidget {
  const GameWinScreen({
    super.key,
    required this.theme,
    required this.title,
    required this.subtitle,
    required this.stats,
    required this.onNewGame,
    required this.onBackToMenu,
    this.onShare,
    this.backgroundTint,
    this.newGameLabel = 'New Game',
    this.backToMenuLabel = 'Back to Menu',
  });

  final WinScreenTheme theme;
  final String title;
  final String subtitle;
  final List<WinScreenStat> stats;
  final VoidCallback onNewGame;
  final VoidCallback onBackToMenu;
  final VoidCallback? onShare;
  final Color? backgroundTint;
  final String newGameLabel;
  final String backToMenuLabel;

  @override
  Widget build(BuildContext context) {
    final palette = _paletteFor(theme);
    return Positioned.fill(
      child: Container(
        color: (backgroundTint ?? Colors.black).withValues(alpha: 0.42),
        alignment: Alignment.center,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableWidth = math.max(0.0, constraints.maxWidth - 32);
            final availableHeight = math.max(0.0, constraints.maxHeight - 32);
            final width = math.min(460.0, availableWidth);
            return TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.92, end: 1),
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutBack,
              builder: (context, scale, child) {
                return Transform.scale(scale: scale, child: child);
              },
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: width,
                  maxHeight: availableHeight,
                ),
                child: Container(
                  width: width,
                  padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [palette.top, palette.bottom],
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x66000000),
                        blurRadius: 28,
                        offset: Offset(0, 18),
                      ),
                    ],
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'You won',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: palette.subtleText,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 154,
                          child: _WinAnimation(theme: theme, palette: palette),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.7,
                            color: palette.text,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          subtitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14.5,
                            height: 1.35,
                            color: palette.subtleText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (stats.isNotEmpty) ...[
                          const SizedBox(height: 18),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              for (final stat in stats)
                                _StatChip(stat: stat, palette: palette),
                            ],
                          ),
                        ],
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: onNewGame,
                            icon: const Icon(Icons.refresh_rounded),
                            label: Text(newGameLabel),
                            style: FilledButton.styleFrom(
                              backgroundColor: palette.primaryButton,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            OutlinedButton.icon(
                              onPressed: onBackToMenu,
                              icon: const Icon(Icons.grid_view_rounded),
                              label: Text(backToMenuLabel),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: palette.text,
                                side: BorderSide(
                                  color: palette.text.withValues(alpha: 0.18),
                                ),
                              ),
                            ),
                            if (onShare != null)
                              OutlinedButton.icon(
                                onPressed: onShare,
                                icon: const Icon(Icons.share_outlined),
                                label: const Text('Share'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: palette.text,
                                  side: BorderSide(
                                    color: palette.text.withValues(alpha: 0.18),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.stat, required this.palette});

  final WinScreenStat stat;
  final _WinPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (stat.icon != null) ...[
            Icon(stat.icon, size: 17, color: palette.text),
            const SizedBox(width: 8),
          ],
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                stat.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: palette.subtleText,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                stat.value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: palette.text,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WinAnimation extends StatelessWidget {
  const _WinAnimation({required this.theme, required this.palette});

  final WinScreenTheme theme;
  final _WinPalette palette;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _themedBackdrop(theme, t, palette),
                _themedForeground(theme, t, palette),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _themedBackdrop(WinScreenTheme theme, double t, _WinPalette p) {
    switch (theme) {
      case WinScreenTheme.klondike:
        return _solitaireBackdrop(t, p, theme: theme);
      case WinScreenTheme.spider:
        return Stack(
          children: [
            _solitaireBackdrop(t, p, theme: theme),
            CustomPaint(
              painter: _SpiderWebPainter(t: t, color: p.accent),
            ),
          ],
        );
      case WinScreenTheme.sudoku:
        return CustomPaint(
          painter: _SudokuGridGlowPainter(t: t, color: p.accent),
        );
      case WinScreenTheme.pyramid:
        return Stack(
          children: [
            _solitaireBackdrop(t, p, theme: theme),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0x00000000),
                      p.accent.withValues(alpha: 0.14),
                    ],
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment(0, ui.lerpDouble(0.85, -0.45, t)!),
              child: Container(
                width: 70 + 20 * t,
                height: 70 + 20 * t,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: p.accent.withValues(alpha: 0.85),
                  boxShadow: [
                    BoxShadow(
                      color: p.accent.withValues(alpha: 0.4),
                      blurRadius: 34,
                      spreadRadius: 8,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      case WinScreenTheme.tripeaks:
        return CustomPaint(
          painter: _MountainPainter(
            t: t,
            color: p.accent.withValues(alpha: 0.5),
          ),
        );
      case WinScreenTheme.hearts:
        return Stack(
          children: [
            Align(
              alignment: Alignment(0.55, ui.lerpDouble(0.95, -0.15, t)!),
              child: Container(
                width: 54 + 16 * t,
                height: 54 + 16 * t,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFBE7A1).withValues(alpha: 0.95),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x66FBE7A1),
                      blurRadius: 28,
                      spreadRadius: 6,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: ui.lerpDouble(-20, 110, t)!,
              top: ui.lerpDouble(46, 20, t)!,
              child: Transform.rotate(
                angle: -0.35,
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: LinearGradient(
                      colors: [Colors.white.withValues(alpha: 0), Colors.white],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _themedForeground(WinScreenTheme theme, double t, _WinPalette p) {
    return switch (theme) {
      WinScreenTheme.klondike => _solitaireCelebration(t, p, theme: theme),
      WinScreenTheme.spider => _solitaireCelebration(t, p, theme: theme),
      WinScreenTheme.freecell => _foundationFlow(t, p),
      WinScreenTheme.hearts => _heartsRise(t, p),
      WinScreenTheme.chess => _chessMate(t, p),
      WinScreenTheme.checkers => _checkersCrown(t, p),
      WinScreenTheme.minesweeper => _minesweeperSweep(t, p),
      WinScreenTheme.sudoku => _sudokuPulse(t, p),
      WinScreenTheme.twentyFortyEight => _tilesBurst(t, p),
      WinScreenTheme.pyramid => _solitaireCelebration(t, p, theme: theme),
      WinScreenTheme.tripeaks => _triPeaksCelebrate(t, p),
    };
  }

  Widget _solitaireBackdrop(
    double t,
    _WinPalette p, {
    required WinScreenTheme theme,
  }) {
    final beamColor = switch (theme) {
      WinScreenTheme.spider => const Color(0xFFE7D8FF),
      WinScreenTheme.pyramid => const Color(0xFFFFEEA8),
      _ => Colors.white,
    };

    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, 0.15),
                radius: 0.95,
                colors: [
                  beamColor.withValues(alpha: 0.22 + (0.08 * t)),
                  beamColor.withValues(alpha: 0.08 + (0.04 * t)),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),
        ),
        Positioned(
          left: ui.lerpDouble(-44, 12, t)!,
          top: ui.lerpDouble(118, 18, Curves.easeOutQuad.transform(t))!,
          child: Transform.rotate(
            angle: -0.6,
            child: Container(
              width: 160,
              height: 24,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: LinearGradient(
                  colors: [
                    beamColor.withValues(alpha: 0),
                    beamColor.withValues(alpha: 0.3),
                    beamColor.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _solitaireCelebration(
    double t,
    _WinPalette p, {
    required WinScreenTheme theme,
  }) {
    final cards = _solitaireCardSpecs(theme);
    final sparkles = _solitaireSparkles(theme);

    return Stack(
      key: ValueKey<String>('solitaire_win_animation_${theme.name}'),
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 18,
          right: 18,
          bottom: 12,
          child: Container(
            key: const Key('solitaire_win_glow'),
            height: 16,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0),
                  p.accent.withValues(alpha: 0.42),
                  Colors.white.withValues(alpha: 0),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: p.accent.withValues(alpha: 0.22),
                  blurRadius: 20,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ),
        for (final sparkle in sparkles) _buildSolitaireSparkle(sparkle, t, p),
        for (final card in cards) _buildSolitaireCard(card, t, p),
        for (final accent in _solitaireFooterCards(theme))
          _buildSolitaireFooterCard(accent, t, p),
      ],
    );
  }

  Widget _buildSolitaireSparkle(
    _SolitaireSparkleSpec sparkle,
    double t,
    _WinPalette p,
  ) {
    final progress = _staggeredProgress(t, sparkle.delay, span: 0.5);
    return Positioned(
      left: ui.lerpDouble(
        sparkle.start.dx,
        sparkle.end.dx,
        Curves.easeOutQuad.transform(progress),
      )!,
      top: ui.lerpDouble(
        sparkle.start.dy,
        sparkle.end.dy,
        Curves.easeOutQuad.transform(progress),
      )!,
      child: Opacity(
        opacity: (1 - progress * 0.35) * sparkle.opacity,
        child: Transform.scale(
          scale: ui.lerpDouble(0.6, 1.0, progress)!,
          child: Icon(
            sparkle.icon,
            size: sparkle.size,
            color: sparkle.color ?? p.accent,
          ),
        ),
      ),
    );
  }

  Widget _buildSolitaireCard(_SolitaireCardSpec spec, double t, _WinPalette p) {
    final progress = _staggeredProgress(t, spec.delay, span: 0.62);
    final travel = Curves.easeOutCubic.transform(progress);
    final wobble = math.sin((progress * math.pi) + spec.wobblePhase) * 4;
    final lift = math.sin(progress * math.pi) * spec.arcHeight;

    return Positioned(
      left: ui.lerpDouble(spec.start.dx, spec.end.dx, travel)! + wobble,
      top: ui.lerpDouble(spec.start.dy, spec.end.dy, travel)! - lift,
      child: Opacity(
        opacity: ui.lerpDouble(0.0, 1.0, Curves.easeOut.transform(progress))!,
        child: Transform.rotate(
          angle: ui.lerpDouble(spec.startAngle, spec.endAngle, travel)!,
          child: Transform.scale(
            scale: ui.lerpDouble(0.88, spec.endScale, travel)!,
            child: _miniCard(
              color: spec.color,
              border: spec.border,
              label: spec.centerLabel,
              labelColor: spec.centerLabelColor,
              cornerLabel: spec.cornerLabel,
              cornerLabelColor: spec.cornerLabelColor,
              accent: spec.accent,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSolitaireFooterCard(
    _SolitaireFooterSpec spec,
    double t,
    _WinPalette p,
  ) {
    final progress = _staggeredProgress(t, spec.delay, span: 0.45);
    return Positioned(
      right: ui.lerpDouble(spec.right + 12, spec.right, progress)!,
      bottom: ui.lerpDouble(spec.bottom - 8, spec.bottom, progress)!,
      child: Opacity(
        opacity: ui.lerpDouble(0.0, spec.opacity, progress)!,
        child: Transform.rotate(
          angle: spec.angle,
          child: _miniCard(
            color: spec.color,
            border: spec.border,
            label: spec.centerLabel,
            labelColor: spec.centerLabelColor,
            cornerLabel: spec.cornerLabel,
            cornerLabelColor: spec.cornerLabelColor,
            accent: spec.accent,
          ),
        ),
      ),
    );
  }

  double _staggeredProgress(double t, double delay, {double span = 0.6}) {
    final shifted = ((t - delay) / span).clamp(0.0, 1.0);
    return Curves.easeOutCubic.transform(shifted);
  }

  List<_SolitaireCardSpec> _solitaireCardSpecs(WinScreenTheme theme) {
    switch (theme) {
      case WinScreenTheme.spider:
        return const [
          _SolitaireCardSpec(
            start: Offset(86, 114),
            end: Offset(18, 56),
            delay: 0.0,
            wobblePhase: 0.4,
            arcHeight: 16,
            startAngle: -0.08,
            endAngle: -0.74,
            cornerLabel: 'K',
            centerLabel: '♠',
            centerLabelColor: Color(0xFF25153A),
            cornerLabelColor: Color(0xFF25153A),
            color: Color(0xFFF8F4FF),
            border: Color(0xFFBBA5F6),
            accent: Color(0xFFB8A2FF),
          ),
          _SolitaireCardSpec(
            start: Offset(88, 114),
            end: Offset(46, 30),
            delay: 0.06,
            wobblePhase: 1.1,
            arcHeight: 22,
            startAngle: -0.03,
            endAngle: -0.42,
            cornerLabel: 'Q',
            centerLabel: '♠',
            centerLabelColor: Color(0xFF25153A),
            cornerLabelColor: Color(0xFF25153A),
            color: Color(0xFFFFFFFF),
            border: Color(0xFFD1C0FF),
            accent: Color(0xFFD9CEFF),
          ),
          _SolitaireCardSpec(
            start: Offset(90, 114),
            end: Offset(78, 14),
            delay: 0.12,
            wobblePhase: 2.2,
            arcHeight: 26,
            startAngle: 0.0,
            endAngle: -0.1,
            cornerLabel: 'J',
            centerLabel: '♠',
            centerLabelColor: Color(0xFF25153A),
            cornerLabelColor: Color(0xFF25153A),
            color: Color(0xFFF7F1FF),
            border: Color(0xFFCCB8FF),
            accent: Color(0xFFB8A2FF),
            endScale: 1.1,
          ),
          _SolitaireCardSpec(
            start: Offset(92, 114),
            end: Offset(108, 28),
            delay: 0.18,
            wobblePhase: 0.9,
            arcHeight: 20,
            startAngle: 0.06,
            endAngle: 0.26,
            cornerLabel: '10',
            centerLabel: '♠',
            centerLabelColor: Color(0xFF25153A),
            cornerLabelColor: Color(0xFF25153A),
            color: Color(0xFFFFFFFF),
            border: Color(0xFFD9CBFF),
            accent: Color(0xFFE7D8FF),
          ),
          _SolitaireCardSpec(
            start: Offset(94, 114),
            end: Offset(138, 52),
            delay: 0.24,
            wobblePhase: 2.7,
            arcHeight: 18,
            startAngle: 0.12,
            endAngle: 0.56,
            cornerLabel: '9',
            centerLabel: '♠',
            centerLabelColor: Color(0xFF25153A),
            cornerLabelColor: Color(0xFF25153A),
            color: Color(0xFFF6F0FF),
            border: Color(0xFFBBA5F6),
            accent: Color(0xFFB8A2FF),
          ),
        ];
      case WinScreenTheme.pyramid:
        return const [
          _SolitaireCardSpec(
            start: Offset(88, 116),
            end: Offset(18, 64),
            delay: 0.0,
            wobblePhase: 0.6,
            arcHeight: 14,
            startAngle: -0.06,
            endAngle: -0.78,
            cornerLabel: 'A',
            centerLabel: '♦',
            centerLabelColor: Color(0xFFC14C11),
            cornerLabelColor: Color(0xFFC14C11),
            color: Color(0xFFFFFAF0),
            border: Color(0xFFF0C46F),
            accent: Color(0xFFFFE19B),
          ),
          _SolitaireCardSpec(
            start: Offset(90, 116),
            end: Offset(48, 34),
            delay: 0.07,
            wobblePhase: 1.9,
            arcHeight: 20,
            startAngle: -0.02,
            endAngle: -0.38,
            cornerLabel: '7',
            centerLabel: '♣',
            centerLabelColor: Color(0xFF4E2D00),
            cornerLabelColor: Color(0xFF4E2D00),
            color: Color(0xFFFFFFFF),
            border: Color(0xFFF2CB82),
            accent: Color(0xFFFFE4A8),
          ),
          _SolitaireCardSpec(
            start: Offset(92, 116),
            end: Offset(78, 16),
            delay: 0.14,
            wobblePhase: 2.5,
            arcHeight: 28,
            startAngle: 0.0,
            endAngle: -0.05,
            cornerLabel: 'K',
            centerLabel: '♠',
            centerLabelColor: Color(0xFF4E2D00),
            cornerLabelColor: Color(0xFF4E2D00),
            color: Color(0xFFFFFEF8),
            border: Color(0xFFF0C46F),
            accent: Color(0xFFFFD56A),
            endScale: 1.12,
          ),
          _SolitaireCardSpec(
            start: Offset(94, 116),
            end: Offset(110, 32),
            delay: 0.2,
            wobblePhase: 1.3,
            arcHeight: 22,
            startAngle: 0.07,
            endAngle: 0.32,
            cornerLabel: '6',
            centerLabel: '♥',
            centerLabelColor: Color(0xFFC14C11),
            cornerLabelColor: Color(0xFFC14C11),
            color: Color(0xFFFFFFFF),
            border: Color(0xFFF6D692),
            accent: Color(0xFFFFE3A0),
          ),
          _SolitaireCardSpec(
            start: Offset(96, 116),
            end: Offset(140, 62),
            delay: 0.27,
            wobblePhase: 2.9,
            arcHeight: 18,
            startAngle: 0.13,
            endAngle: 0.62,
            cornerLabel: '4',
            centerLabel: '♦',
            centerLabelColor: Color(0xFFC14C11),
            cornerLabelColor: Color(0xFFC14C11),
            color: Color(0xFFFFFCF3),
            border: Color(0xFFF0C46F),
            accent: Color(0xFFFFD56A),
          ),
        ];
      default:
        return const [
          _SolitaireCardSpec(
            start: Offset(86, 114),
            end: Offset(18, 56),
            delay: 0.0,
            wobblePhase: 0.3,
            arcHeight: 16,
            startAngle: -0.08,
            endAngle: -0.76,
            cornerLabel: 'A',
            centerLabel: '♠',
            centerLabelColor: Color(0xFF2B2B2B),
            cornerLabelColor: Color(0xFF2B2B2B),
            color: Color(0xFFFFFFFF),
            border: Color(0xFFE9C76A),
            accent: Color(0xFFFFF1B8),
          ),
          _SolitaireCardSpec(
            start: Offset(88, 114),
            end: Offset(48, 28),
            delay: 0.06,
            wobblePhase: 1.4,
            arcHeight: 24,
            startAngle: -0.03,
            endAngle: -0.44,
            cornerLabel: 'K',
            centerLabel: '♥',
            centerLabelColor: Color(0xFFC73B32),
            cornerLabelColor: Color(0xFFC73B32),
            color: Color(0xFFFFFBF2),
            border: Color(0xFFE8B96A),
            accent: Color(0xFFFFE0A0),
          ),
          _SolitaireCardSpec(
            start: Offset(90, 114),
            end: Offset(78, 10),
            delay: 0.12,
            wobblePhase: 2.1,
            arcHeight: 28,
            startAngle: 0.0,
            endAngle: -0.08,
            cornerLabel: 'Q',
            centerLabel: '♣',
            centerLabelColor: Color(0xFF2B2B2B),
            cornerLabelColor: Color(0xFF2B2B2B),
            color: Color(0xFFFFFFFF),
            border: Color(0xFFE4B55F),
            accent: Color(0xFFFFF1B8),
            endScale: 1.12,
          ),
          _SolitaireCardSpec(
            start: Offset(92, 114),
            end: Offset(108, 26),
            delay: 0.18,
            wobblePhase: 0.8,
            arcHeight: 22,
            startAngle: 0.05,
            endAngle: 0.28,
            cornerLabel: 'J',
            centerLabel: '♦',
            centerLabelColor: Color(0xFFC73B32),
            cornerLabelColor: Color(0xFFC73B32),
            color: Color(0xFFFFFCF5),
            border: Color(0xFFEBC66A),
            accent: Color(0xFFFFD86C),
          ),
          _SolitaireCardSpec(
            start: Offset(94, 114),
            end: Offset(138, 54),
            delay: 0.24,
            wobblePhase: 2.8,
            arcHeight: 18,
            startAngle: 0.12,
            endAngle: 0.58,
            cornerLabel: '10',
            centerLabel: '♠',
            centerLabelColor: Color(0xFF2B2B2B),
            cornerLabelColor: Color(0xFF2B2B2B),
            color: Color(0xFFFFFFFF),
            border: Color(0xFFE0B55D),
            accent: Color(0xFFFFEEB1),
          ),
        ];
    }
  }

  List<_SolitaireSparkleSpec> _solitaireSparkles(WinScreenTheme theme) {
    final highlight = switch (theme) {
      WinScreenTheme.spider => const Color(0xFFE8DBFF),
      WinScreenTheme.pyramid => const Color(0xFFFFF0B9),
      _ => const Color(0xFFFFF4CF),
    };

    return [
      _SolitaireSparkleSpec(
        start: const Offset(84, 98),
        end: const Offset(28, 20),
        delay: 0.04,
        size: 12,
        opacity: 0.85,
        icon: Icons.auto_awesome,
        color: highlight,
      ),
      _SolitaireSparkleSpec(
        start: const Offset(92, 102),
        end: const Offset(64, 40),
        delay: 0.1,
        size: 8,
        opacity: 0.72,
        icon: Icons.circle,
        color: Colors.white,
      ),
      _SolitaireSparkleSpec(
        start: const Offset(96, 104),
        end: const Offset(108, 12),
        delay: 0.16,
        size: 10,
        opacity: 0.8,
        icon: Icons.auto_awesome,
        color: highlight,
      ),
      _SolitaireSparkleSpec(
        start: const Offset(98, 106),
        end: const Offset(144, 28),
        delay: 0.22,
        size: 8,
        opacity: 0.65,
        icon: Icons.circle,
        color: Colors.white.withValues(alpha: 0.92),
      ),
      _SolitaireSparkleSpec(
        start: const Offset(90, 106),
        end: const Offset(152, 54),
        delay: 0.28,
        size: 11,
        opacity: 0.78,
        icon: Icons.auto_awesome,
        color: highlight,
      ),
    ];
  }

  List<_SolitaireFooterSpec> _solitaireFooterCards(WinScreenTheme theme) {
    switch (theme) {
      case WinScreenTheme.spider:
        return const [
          _SolitaireFooterSpec(
            right: 18,
            bottom: 18,
            delay: 0.18,
            opacity: 0.9,
            angle: -0.06,
            cornerLabel: '8',
            centerLabel: '♠',
            centerLabelColor: Color(0xFF25153A),
            cornerLabelColor: Color(0xFF25153A),
            color: Color(0xFFFFFFFF),
            border: Color(0xFFCCB8FF),
            accent: Color(0xFFD9CEFF),
          ),
          _SolitaireFooterSpec(
            right: 28,
            bottom: 22,
            delay: 0.24,
            opacity: 0.72,
            angle: 0.02,
            cornerLabel: '7',
            centerLabel: '♠',
            centerLabelColor: Color(0xFF25153A),
            cornerLabelColor: Color(0xFF25153A),
            color: Color(0xFFF8F4FF),
            border: Color(0xFFBBA5F6),
            accent: Color(0xFFB8A2FF),
          ),
          _SolitaireFooterSpec(
            right: 38,
            bottom: 26,
            delay: 0.3,
            opacity: 0.55,
            angle: 0.08,
            cornerLabel: '6',
            centerLabel: '♠',
            centerLabelColor: Color(0xFF25153A),
            cornerLabelColor: Color(0xFF25153A),
            color: Color(0xFFF4EDFF),
            border: Color(0xFFCCB8FF),
            accent: Color(0xFFD9CEFF),
          ),
        ];
      case WinScreenTheme.pyramid:
        return const [
          _SolitaireFooterSpec(
            right: 18,
            bottom: 18,
            delay: 0.18,
            opacity: 0.9,
            angle: -0.08,
            cornerLabel: '13',
            centerLabel: '♦',
            centerLabelColor: Color(0xFFC14C11),
            cornerLabelColor: Color(0xFFC14C11),
            color: Color(0xFFFFFEF6),
            border: Color(0xFFF0C46F),
            accent: Color(0xFFFFE19B),
          ),
          _SolitaireFooterSpec(
            right: 28,
            bottom: 22,
            delay: 0.25,
            opacity: 0.68,
            angle: 0.04,
            cornerLabel: '12',
            centerLabel: '♣',
            centerLabelColor: Color(0xFF4E2D00),
            cornerLabelColor: Color(0xFF4E2D00),
            color: Color(0xFFFFFFFF),
            border: Color(0xFFF3CD84),
            accent: Color(0xFFFFE7B3),
          ),
        ];
      default:
        return const [
          _SolitaireFooterSpec(
            right: 18,
            bottom: 18,
            delay: 0.18,
            opacity: 0.94,
            angle: -0.08,
            cornerLabel: 'A',
            centerLabel: '♣',
            centerLabelColor: Color(0xFF2B2B2B),
            cornerLabelColor: Color(0xFF2B2B2B),
            color: Color(0xFFFFFFFF),
            border: Color(0xFFE4B55F),
            accent: Color(0xFFFFF1B8),
          ),
          _SolitaireFooterSpec(
            right: 28,
            bottom: 22,
            delay: 0.24,
            opacity: 0.78,
            angle: 0.0,
            cornerLabel: 'A',
            centerLabel: '♦',
            centerLabelColor: Color(0xFFC73B32),
            cornerLabelColor: Color(0xFFC73B32),
            color: Color(0xFFFFFBF2),
            border: Color(0xFFE8B96A),
            accent: Color(0xFFFFE0A0),
          ),
          _SolitaireFooterSpec(
            right: 38,
            bottom: 26,
            delay: 0.3,
            opacity: 0.62,
            angle: 0.08,
            cornerLabel: 'A',
            centerLabel: '♥',
            centerLabelColor: Color(0xFFC73B32),
            cornerLabelColor: Color(0xFFC73B32),
            color: Color(0xFFFFFFFF),
            border: Color(0xFFEBC66A),
            accent: Color(0xFFFFD86C),
          ),
          _SolitaireFooterSpec(
            right: 48,
            bottom: 30,
            delay: 0.36,
            opacity: 0.5,
            angle: 0.14,
            cornerLabel: 'A',
            centerLabel: '♠',
            centerLabelColor: Color(0xFF2B2B2B),
            cornerLabelColor: Color(0xFF2B2B2B),
            color: Color(0xFFFFFCF5),
            border: Color(0xFFE0B55D),
            accent: Color(0xFFFFEEB1),
          ),
        ];
    }
  }

  Widget _foundationFlow(double t, _WinPalette p) {
    return Stack(
      children: [
        for (int i = 0; i < 4; i++)
          Positioned(
            left: 16 + i * 35,
            top: ui.lerpDouble(104, 16, t)!,
            child: Column(
              children: [
                Icon(
                  Icons.lock_open_rounded,
                  color: p.text.withValues(alpha: 0.75),
                  size: 18,
                ),
                const SizedBox(height: 6),
                _miniCard(
                  color: Colors.white,
                  border: p.text.withValues(alpha: 0.15),
                ),
              ],
            ),
          ),
        for (int i = 0; i < 5; i++)
          Positioned(
            left: ui.lerpDouble(8 + i * 18, 22 + (i % 4) * 35, t)!,
            top: ui.lerpDouble(88 + (i % 2) * 18, 34, t)!,
            child: Transform.rotate(
              angle: -0.35 + (i * 0.18),
              child: _miniCard(
                color: const Color(0xFFF4FBFF),
                border: const Color(0xFF9ADFFF),
              ),
            ),
          ),
      ],
    );
  }

  Widget _heartsRise(double t, _WinPalette p) {
    return Stack(
      children: [
        for (int i = 0; i < 8; i++)
          Positioned(
            left: 12 + (i * 18).toDouble(),
            top: ui.lerpDouble(126 - (i % 3) * 6, 28 + (i % 4) * 12, t)!,
            child: Opacity(
              opacity: (1 - i * 0.06).clamp(0.25, 1.0),
              child: Icon(
                Icons.favorite,
                color: p.accent,
                size: 12 + (i % 3) * 5,
              ),
            ),
          ),
      ],
    );
  }

  Widget _chessMate(double t, _WinPalette p) {
    return Stack(
      children: [
        Positioned(
          left: 54,
          bottom: 18,
          child: Container(
            width: 82,
            height: 16,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
        Positioned(
          left: 82,
          bottom: ui.lerpDouble(76, 24, Curves.easeIn.transform(t))!,
          child: Transform.rotate(
            angle: ui.lerpDouble(0, 0.9, Curves.easeInBack.transform(t))!,
            alignment: Alignment.bottomCenter,
            child: Icon(Icons.workspace_premium, size: 68, color: Colors.white),
          ),
        ),
        for (int i = 0; i < 14; i++)
          Positioned(
            left: 22 + (i * 10).toDouble(),
            top: ui.lerpDouble(28, 8 + (i.isEven ? 12 : 30), t)!,
            child: Transform.rotate(
              angle: i * 0.35,
              child: Icon(
                Icons.auto_awesome,
                size: 10 + (i % 3) * 3,
                color: p.accent,
              ),
            ),
          ),
      ],
    );
  }

  Widget _checkersCrown(double t, _WinPalette p) {
    return Stack(
      children: [
        for (int i = 0; i < 2; i++)
          Positioned(
            left: 36 + i * 72,
            bottom: 26 + (i.isEven ? 12 : 0),
            child: Column(
              children: [
                Transform.translate(
                  offset: Offset(0, ui.lerpDouble(12, 0, t)!),
                  child: Icon(
                    Icons.workspace_premium,
                    size: 34,
                    color: p.accent,
                  ),
                ),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.redAccent.shade100,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ],
            ),
          ),
        for (int i = 0; i < 8; i++)
          Positioned(
            left: 24 + (i * 18).toDouble(),
            top: 22 + (i % 2) * 14,
            child: Opacity(
              opacity: t,
              child: Icon(
                Icons.auto_awesome,
                size: 11 + i % 3 * 2,
                color: Colors.white,
              ),
            ),
          ),
      ],
    );
  }

  Widget _minesweeperSweep(double t, _WinPalette p) {
    return Stack(
      children: [
        Positioned(
          left: 28,
          top: 28,
          child: Transform.translate(
            offset: Offset(math.sin(t * math.pi * 2) * 5, 0),
            child: Icon(Icons.flag, size: 46, color: p.accent),
          ),
        ),
        Positioned(
          left: 0,
          top: 96 - 70 * t,
          right: 0,
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  p.accent.withValues(alpha: 0),
                  p.accent.withValues(alpha: 0.18),
                  p.accent.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ),
        for (int i = 0; i < 10; i++)
          Positioned(
            right: 16 + (i * 10).toDouble(),
            bottom: 24 + (i % 4) * 10,
            child: Icon(
              Icons.circle,
              size: 5 + (i % 3) * 2,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
      ],
    );
  }

  Widget _sudokuPulse(double t, _WinPalette p) {
    return Stack(
      children: [
        for (int row = 0; row < 3; row++)
          for (int col = 0; col < 3; col++)
            Positioned(
              left: 42 + col * 28,
              top: 26 + row * 28,
              child: Transform.scale(
                scale: 0.9 + ((row + col) % 3) * 0.05 + 0.1 * t,
                child: Text(
                  '${(row * 3) + col + 1}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            width: 132,
            height: 8,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: p.accent.withValues(alpha: 0.75),
              boxShadow: [
                BoxShadow(
                  color: p.accent.withValues(alpha: 0.55),
                  blurRadius: 20,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _tilesBurst(double t, _WinPalette p) {
    return Stack(
      children: [
        Positioned(
          left: ui.lerpDouble(72, 56, t)!,
          top: ui.lerpDouble(58, 30, t)!,
          child: _tile(label: '2048', color: p.accent),
        ),
        for (int i = 0; i < 12; i++)
          Positioned(
            left: ui.lerpDouble(88, 18 + i * 11, t)!,
            top: ui.lerpDouble(72, 8 + (i % 4) * 22, t)!,
            child: Icon(
              i.isEven ? Icons.square : Icons.auto_awesome,
              size: 8 + (i % 3) * 3,
              color: i.isEven ? Colors.white : p.accent,
            ),
          ),
      ],
    );
  }

  Widget _triPeaksCelebrate(double t, _WinPalette p) {
    return Stack(
      children: [
        for (int i = 0; i < 3; i++)
          Positioned(
            left: 22 + i * 52,
            bottom: ui.lerpDouble(24, 10, t)!,
            child: Transform.scale(
              scale: ui.lerpDouble(1, 0.8, t)!,
              child: CustomPaint(
                size: const Size(56, 48),
                painter: _PeakPainter(
                  color: Colors.white.withValues(alpha: 0.82),
                ),
              ),
            ),
          ),
        Positioned(
          right: 20,
          top: 18,
          child: Icon(Icons.terrain, size: 34, color: p.accent),
        ),
      ],
    );
  }

  Widget _miniCard({
    required Color color,
    required Color border,
    String? label,
    Color? labelColor,
    String? cornerLabel,
    Color? cornerLabelColor,
    Color? accent,
  }) {
    return Container(
      width: 28,
      height: 38,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: border),
      ),
      child: Stack(
        children: [
          if (accent != null)
            Positioned(
              left: 4,
              right: 4,
              top: 4,
              child: Container(
                height: 5,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          if (cornerLabel != null)
            Positioned(
              left: 5,
              top: accent == null ? 4 : 10,
              child: Text(
                cornerLabel,
                style: TextStyle(
                  fontSize: cornerLabel.length > 1 ? 7.5 : 8.5,
                  fontWeight: FontWeight.w900,
                  color: cornerLabelColor ?? const Color(0xFF2B2B2B),
                ),
              ),
            ),
          if (label != null)
            Align(
              alignment: Alignment.center,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: labelColor ?? const Color(0xFF2B2B2B),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _tile({required String label, required Color color}) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 18),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w900,
          color: Color(0xFF5A2A00),
        ),
      ),
    );
  }
}

class _SolitaireCardSpec {
  const _SolitaireCardSpec({
    required this.start,
    required this.end,
    required this.delay,
    required this.wobblePhase,
    required this.arcHeight,
    required this.startAngle,
    required this.endAngle,
    required this.cornerLabel,
    required this.centerLabel,
    required this.centerLabelColor,
    required this.cornerLabelColor,
    required this.color,
    required this.border,
    required this.accent,
    this.endScale = 1.0,
  });

  final Offset start;
  final Offset end;
  final double delay;
  final double wobblePhase;
  final double arcHeight;
  final double startAngle;
  final double endAngle;
  final String cornerLabel;
  final String centerLabel;
  final Color centerLabelColor;
  final Color cornerLabelColor;
  final Color color;
  final Color border;
  final Color accent;
  final double endScale;
}

class _SolitaireSparkleSpec {
  const _SolitaireSparkleSpec({
    required this.start,
    required this.end,
    required this.delay,
    required this.size,
    required this.opacity,
    required this.icon,
    this.color,
  });

  final Offset start;
  final Offset end;
  final double delay;
  final double size;
  final double opacity;
  final IconData icon;
  final Color? color;
}

class _SolitaireFooterSpec {
  const _SolitaireFooterSpec({
    required this.right,
    required this.bottom,
    required this.delay,
    required this.opacity,
    required this.angle,
    required this.cornerLabel,
    required this.centerLabel,
    required this.centerLabelColor,
    required this.cornerLabelColor,
    required this.color,
    required this.border,
    required this.accent,
  });

  final double right;
  final double bottom;
  final double delay;
  final double opacity;
  final double angle;
  final String cornerLabel;
  final String centerLabel;
  final Color centerLabelColor;
  final Color cornerLabelColor;
  final Color color;
  final Color border;
  final Color accent;
}

class _SpiderWebPainter extends CustomPainter {
  const _SpiderWebPainter({required this.t, required this.color});

  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.22)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    final center = Offset(size.width * 0.82, size.height * 0.22);
    for (int i = 1; i <= 4; i++) {
      canvas.drawCircle(center, 18.0 * i * t, paint);
    }
    for (int i = 0; i < 6; i++) {
      final angle = -1.2 + i * 0.45;
      canvas.drawLine(
        center,
        center + Offset(math.cos(angle), math.sin(angle)) * 72 * t,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SpiderWebPainter oldDelegate) =>
      oldDelegate.t != t;
}

class _SudokuGridGlowPainter extends CustomPainter {
  const _SudokuGridGlowPainter({required this.t, required this.color});

  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..strokeWidth = 1.2;
    const startX = 34.0;
    const startY = 18.0;
    const gap = 28.0;
    for (int i = 0; i <= 3; i++) {
      canvas.drawLine(
        Offset(startX, startY + i * gap),
        Offset(startX + gap * 3 * t, startY + i * gap),
        paint,
      );
      canvas.drawLine(
        Offset(startX + i * gap, startY),
        Offset(startX + i * gap, startY + gap * 3 * t),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SudokuGridGlowPainter oldDelegate) =>
      oldDelegate.t != t;
}

class _MountainPainter extends CustomPainter {
  const _MountainPainter({required this.t, required this.color});

  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width * 0.2, size.height * 0.55)
      ..lineTo(size.width * 0.36, size.height * 0.78)
      ..lineTo(size.width * 0.52, size.height * 0.44)
      ..lineTo(size.width * 0.7, size.height * 0.72)
      ..lineTo(size.width * 0.88, size.height * 0.38)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.save();
    canvas.translate(0, 18 * (1 - t));
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MountainPainter oldDelegate) =>
      oldDelegate.t != t;
}

class _PeakPainter extends CustomPainter {
  const _PeakPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _PeakPainter oldDelegate) => false;
}

class _WinPalette {
  const _WinPalette({
    required this.top,
    required this.bottom,
    required this.accent,
    required this.text,
    required this.subtleText,
    required this.primaryButton,
  });

  final Color top;
  final Color bottom;
  final Color accent;
  final Color text;
  final Color subtleText;
  final Color primaryButton;
}

_WinPalette _paletteFor(WinScreenTheme theme) {
  return switch (theme) {
    WinScreenTheme.klondike => const _WinPalette(
      top: Color(0xFFF7E39B),
      bottom: Color(0xFFE4A73C),
      accent: Color(0xFFFFFFFF),
      text: Color(0xFF4E2D00),
      subtleText: Color(0xFF6A4300),
      primaryButton: Color(0xFF14532D),
    ),
    WinScreenTheme.spider => const _WinPalette(
      top: Color(0xFF23263E),
      bottom: Color(0xFF3E2A58),
      accent: Color(0xFFB8A2FF),
      text: Color(0xFFF5EDFF),
      subtleText: Color(0xFFD2C4F4),
      primaryButton: Color(0xFF6F49D8),
    ),
    WinScreenTheme.freecell => const _WinPalette(
      top: Color(0xFF154766),
      bottom: Color(0xFF1D7EB3),
      accent: Color(0xFF8DE3FF),
      text: Color(0xFFF2FBFF),
      subtleText: Color(0xFFCDEFFF),
      primaryButton: Color(0xFF0E5C86),
    ),
    WinScreenTheme.hearts => const _WinPalette(
      top: Color(0xFF24305E),
      bottom: Color(0xFF7A1E48),
      accent: Color(0xFFFF7BA4),
      text: Color(0xFFFFF1F5),
      subtleText: Color(0xFFF6C6D7),
      primaryButton: Color(0xFFC02863),
    ),
    WinScreenTheme.chess => const _WinPalette(
      top: Color(0xFF1F2430),
      bottom: Color(0xFF3B3328),
      accent: Color(0xFFFFD66B),
      text: Color(0xFFFFF5DA),
      subtleText: Color(0xFFE7D9B0),
      primaryButton: Color(0xFF6F4E1F),
    ),
    WinScreenTheme.checkers => const _WinPalette(
      top: Color(0xFF5B1F1F),
      bottom: Color(0xFFA33D2B),
      accent: Color(0xFFFAD46D),
      text: Color(0xFFFFF0EA),
      subtleText: Color(0xFFF6C7B9),
      primaryButton: Color(0xFF7A231B),
    ),
    WinScreenTheme.minesweeper => const _WinPalette(
      top: Color(0xFF1F4B5A),
      bottom: Color(0xFF2A7E6B),
      accent: Color(0xFFFFD166),
      text: Color(0xFFF1FFFB),
      subtleText: Color(0xFFC8F1E7),
      primaryButton: Color(0xFF146C5A),
    ),
    WinScreenTheme.sudoku => const _WinPalette(
      top: Color(0xFF7A5C12),
      bottom: Color(0xFFC79D2B),
      accent: Color(0xFFFFE28A),
      text: Color(0xFFFFF8E1),
      subtleText: Color(0xFFF7E8B5),
      primaryButton: Color(0xFF8B6B1C),
    ),
    WinScreenTheme.twentyFortyEight => const _WinPalette(
      top: Color(0xFFB76A19),
      bottom: Color(0xFFF0C86B),
      accent: Color(0xFFFFE08A),
      text: Color(0xFF5A2A00),
      subtleText: Color(0xFF7B4207),
      primaryButton: Color(0xFFC9781C),
    ),
    WinScreenTheme.pyramid => const _WinPalette(
      top: Color(0xFF8A5A14),
      bottom: Color(0xFFD8A63E),
      accent: Color(0xFFFFD56A),
      text: Color(0xFFFFF5DF),
      subtleText: Color(0xFFF7E2B1),
      primaryButton: Color(0xFF9A6817),
    ),
    WinScreenTheme.tripeaks => const _WinPalette(
      top: Color(0xFF1A4B58),
      bottom: Color(0xFF2D7D74),
      accent: Color(0xFFB6F5C3),
      text: Color(0xFFF0FFFA),
      subtleText: Color(0xFFD4F6E4),
      primaryButton: Color(0xFF17685E),
    ),
  };
}
