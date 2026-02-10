import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'services/startup_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase before any Firebase-dependent code (e.g. Remote Config).
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const App());

  // Kick off heavy init after the first frame so the OS launcher screen
  // disappears quickly.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(StartupService.start());
  });
}
