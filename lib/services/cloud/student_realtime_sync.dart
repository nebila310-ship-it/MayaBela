import 'package:flutter/foundation.dart';

import 'package:mayabela/database/supabase/supabase_bootstrap.dart';
import 'package:mayabela/services/auth_service.dart';

/// Student portal no longer opens ~25 `app_documents` streams.
///
/// Conversations stay live via [ConversationRealtimeSync]. Grades, homework,
/// and the rest arrive on the 5s/30s poll. Opening a stream per collection
/// and then pulling the whole student pack on any change piled onto PostgREST
/// after a few sign-ins.
abstract final class StudentRealtimeSync {
  static bool _active = false;

  @visibleForTesting
  static List<String> get watchedCollections => const [];

  static void start() {
    if (!SupabaseBootstrap.isInitialized) return;
    if (AuthService.currentUser?.roleKey != AuthService.roleStudent) return;
    if (_active) return;
    _active = true;
  }

  static void stop() {
    _active = false;
  }
}
