import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

class AdaptivePhoneFrame extends StatefulWidget {
  final Widget child;

  const AdaptivePhoneFrame({super.key, required this.child});

  @override
  State<AdaptivePhoneFrame> createState() => _AdaptivePhoneFrameState();
}

class _AdaptivePhoneFrameState extends State<AdaptivePhoneFrame> {
  bool _forcePhoneFrame = true;

  @override
  Widget build(BuildContext context) {
    // On native mobile (Android / iOS), render directly as native app
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      return widget.child;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // If screen is wide (> 600) and phone frame enabled
        final isWideScreen = constraints.maxWidth > 650;

        if (!isWideScreen || !_forcePhoneFrame) {
          return Stack(
            children: [
              widget.child,
              if (isWideScreen)
                Positioned(
                  top: 16,
                  right: 16,
                  child: FloatingActionButton.small(
                    tooltip: 'Включить рамку смартфона',
                    onPressed: () {
                      setState(() {
                        _forcePhoneFrame = true;
                      });
                    },
                    child: const Icon(Icons.phone_android),
                  ),
                ),
            ],
          );
        }

        // Centered phone container for desktop PC testing
        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
          body: Stack(
            children: [
              Center(
                child: Container(
                  width: 412,
                  height: 860,
                  margin: const EdgeInsets.symmetric(vertical: 24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(36),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.18),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5),
                      width: 4,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: widget.child,
                  ),
                ),
              ),
              Positioned(
                top: 24,
                right: 24,
                child: FilledButton.tonalIcon(
                  onPressed: () {
                    setState(() {
                      _forcePhoneFrame = false;
                    });
                  },
                  icon: const Icon(Icons.fullscreen),
                  label: const Text('На весь экран'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
