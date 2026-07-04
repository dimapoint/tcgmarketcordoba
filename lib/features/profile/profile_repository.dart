import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_provider.dart';
import '../../shared/models/profile.dart';

abstract class ProfileRepository {
  Future<Profile> fetchProfile(String userId);
  Future<void> updateProfile(String userId, {String? username, String? cityId});
  Future<List<ContactMethod>> fetchContactMethods(String userId);
  Future<void> upsertContactMethod(String userId, String type, String value);
  Future<void> deleteContactMethod(String id);
  Future<List<City>> fetchCities();
}

class ApiProfileRepository implements ProfileRepository {
  final ApiClient _api;
  ApiProfileRepository(this._api);

  // los userId de los parámetros quedan por compatibilidad;
  // el backend identifica al usuario por el JWT

  @override
  Future<Profile> fetchProfile(String userId) async {
    final data = await _api.get('/me/profile', auth: true);
    return Profile.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<void> updateProfile(String userId,
      {String? username, String? cityId}) {
    return _api.patch('/me/profile', auth: true, body: {
      'username': ?username,
      'city_id': ?cityId,
    });
  }

  @override
  Future<List<ContactMethod>> fetchContactMethods(String userId) async {
    final data = await _api.get('/me/contacts', auth: true);
    return (data as List)
        .map((j) => ContactMethod.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> upsertContactMethod(String userId, String type, String value) =>
      _api.put('/me/contacts', auth: true, body: {'type': type, 'value': value});

  @override
  Future<void> deleteContactMethod(String id) =>
      _api.delete('/me/contacts/$id', auth: true);

  @override
  Future<List<City>> fetchCities() async {
    final data = await _api.get('/cities');
    return (data as List)
        .map((j) => City.fromJson(j as Map<String, dynamic>))
        .toList();
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ApiProfileRepository(ref.watch(apiClientProvider)),
);
