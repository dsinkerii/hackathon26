import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'state/app_state.dart';
import 'ui/screens/main_shell.dart';
import 'ui/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final appState = AppState();
  runApp(PlayGuardApp(state: appState));
}

class PlayGuardApp extends StatelessWidget {
  final AppState state;

  const PlayGuardApp({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final settings = state.settings;

        return DynamicColorBuilder(
          builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
            final isDefaultSeed =
                settings.seedColor == const Color(0xFF6750A4);

            return MaterialApp(
              title: 'PlayGuardAI',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme(
                settings.seedColor,
                isDefaultSeed ? lightDynamic : null,
              ),
              darkTheme: AppTheme.darkTheme(
                settings.seedColor,
                isDefaultSeed ? darkDynamic : null,
              ),
              themeMode: settings.themeMode,
              home: MainShell(state: state),
            );
          },
        );
      },
    );
  }
}
