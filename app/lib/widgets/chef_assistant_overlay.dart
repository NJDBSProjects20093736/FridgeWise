import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../screens/assistant_screen.dart';
import '../theme/app_theme.dart';
import 'thrifty_chef_logo.dart';

/// Global cooking-assistant host — FAB + slide-up chat on every app screen.
class ChefAssistantOverlay extends StatefulWidget {
  final Widget child;

  const ChefAssistantOverlay({super.key, required this.child});

  @override
  State<ChefAssistantOverlay> createState() => _ChefAssistantOverlayState();
}

class _ChefAssistantOverlayState extends State<ChefAssistantOverlay> {
  bool _open = false;

  void _close() {
    if (!_open) return;
    setState(() => _open = false);
  }

  void _openSheet() {
    if (_open) return;
    setState(() => _open = true);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final showChrome = state.bootstrapped && state.apiOk && state.onboarded;
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    // Clear bottom nav on phone; stay above content on desktop.
    final fabBottom = bottomPad + (MediaQuery.sizeOf(context).width < 900 ? 72 : 20);

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (showChrome && _open)
          Positioned.fill(
            child: _ChefChatOverlay(onClose: _close),
          ),
        if (showChrome && !_open)
          Positioned(
            right: 16,
            bottom: fabBottom,
            child: _ChefFab(onPressed: _openSheet),
          ),
      ],
    );
  }
}

class _ChefChatOverlay extends StatelessWidget {
  final VoidCallback onClose;

  const _ChefChatOverlay({required this.onClose});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final topInset = MediaQuery.paddingOf(context).top;
    final maxSheet = size.height - topInset - 8;
    final sheetHeight = (size.height * 0.86).clamp(360.0, maxSheet);
    final sheetWidth = size.width >= 720 ? 520.0 : size.width;

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Dim scrim — tap to close
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onClose,
              child: const ColoredBox(color: Color(0x99000000)),
            ),
          ),
          // Chat panel
          Align(
            alignment: Alignment.bottomCenter,
            child: GestureDetector(
              onTap: () {}, // absorb taps so scrim doesn't close when tapping chat
              child: Material(
                color: AppTheme.cardSurface,
                elevation: 12,
                shadowColor: Colors.black38,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                clipBehavior: Clip.antiAlias,
                child: SizedBox(
                  height: sheetHeight,
                  width: sheetWidth,
                  child: AssistantScreen(
                    embedded: true,
                    onClose: onClose,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChefFab extends StatelessWidget {
  final VoidCallback onPressed;

  const _ChefFab({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 6,
      shadowColor: AppTheme.primaryGreen.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(28),
      color: AppTheme.primaryGreen,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const ChefHatIcon(size: 22, color: Colors.white),
              ),
              const SizedBox(width: 10),
              const Text(
                'Chef AI',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
