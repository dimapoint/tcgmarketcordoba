class Profile {
  final String id;
  final String username;
  final String? cityId;
  final String? cityName;

  const Profile({
    required this.id,
    required this.username,
    this.cityId,
    this.cityName,
  });

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        id: j['id'] as String,
        username: j['username'] as String,
        cityId: j['city_id'] as String?,
        cityName:
            (j['cities'] as Map<String, dynamic>?)?['name'] as String?,
      );
}

class ContactMethod {
  final String id;
  final String type;
  final String value;

  const ContactMethod({
    required this.id,
    required this.type,
    required this.value,
  });

  factory ContactMethod.fromJson(Map<String, dynamic> j) => ContactMethod(
        id: j['id'] as String,
        type: j['type'] as String,
        value: j['value'] as String,
      );
}
