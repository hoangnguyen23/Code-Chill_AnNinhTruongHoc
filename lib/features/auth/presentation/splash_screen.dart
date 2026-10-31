import 'package:material_ui/material_ui.dart';

import '../../../core/config/app_config.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Semantics(
          label: 'Đang tải',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.shield_rounded, size: 64, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text(AppConfig.appName, style: theme.textTheme.titleLarge),
              const SizedBox(height: 24),
              const SizedBox(width: 160, child: LinearProgressIndicator()),
            ],
          ),
        ),
      ),
    );
  }
}
