import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase/client.dart';

final authSessionProvider = StreamProvider<Session?>((ref) {
  return supabase.auth.onAuthStateChange.map((event) => event.session);
});
