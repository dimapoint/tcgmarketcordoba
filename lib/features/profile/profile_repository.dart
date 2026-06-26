import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase/client.dart';
import '../../shared/models/profile.dart';

abstract class ProfileRepository {
  Future<Profile> fetchProfile(String userId);
  Future<void> updateProfile(String userId, {String? username, String? cityId});
  Future<List<ContactMethod>> fetchContactMethods(String userId);
  Future<void> upsertContactMethod(String userId, String type, String value);
  Future<void> deleteContactMethod(String id);
}

class SupabaseProfileRepository implements ProfileRepository {
  final SupabaseClient _client;
  SupabaseProfileRepository(this._client);

  @override
  Future<Profile> fetchProfile(String userId) async {
    final data = await _client
        .from('profiles')
        .select('id, username, city_id, cities(name)')
        .eq('id', userId)
        .single();
    return Profile.fromJson(data);
  }

  @override
  Future<void> updateProfile(
    String userId, {
    String? username,
    String? cityId,
  }) async {
    final updates = <String, dynamic>{};
    if (username != null) updates['username'] = username;
    if (cityId != null) updates['city_id'] = cityId;
    await _client.from('profiles').update(updates).eq('id', userId);
  }

  @override
  Future<List<ContactMethod>> fetchContactMethods(String userId) async {
    final data = await _client
        .from('contact_methods')
        .select('id, type, value')
        .eq('profile_id', userId);
    return (data as List)
        .map((j) => ContactMethod.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> upsertContactMethod(
    String userId,
    String type,
    String value,
  ) async {
    await _client.from('contact_methods').upsert(
      {'profile_id': userId, 'type': type, 'value': value},
      onConflict: 'profile_id,type',
    );
  }

  @override
  Future<void> deleteContactMethod(String id) async {
    await _client.from('contact_methods').delete().eq('id', id);
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => SupabaseProfileRepository(supabase),
);
