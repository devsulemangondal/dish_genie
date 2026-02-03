import 'dart:async';

import 'package:flutter/material.dart';
import 'app.dart';
import 'services/startup_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const App());

  // Kick off heavy init after the first frame so the OS launcher screen
  // disappears quickly.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(StartupService.start());
  });
}
