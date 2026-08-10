import 'package:flutter/material.dart';
import 'main.dart';

// Re-export for convenience — the app entry point is in main.dart.
// This file exists so that future feature modules can import from lib/app.dart
// without creating circular dependencies with main.dart.

export 'main.dart' show VillageCalendarApp;
