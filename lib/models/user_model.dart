import 'dart:convert';

class UserModel {
  final String uid;
  String email;
  String displayName;
  String birthDate;
  String birthPlace;
  String city;

  UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.birthDate,
    required this.birthPlace,
    required this.city,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'display_name': displayName,
      'birth_date': birthDate,
      'birth_place': birthPlace,
      'city': city,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      displayName: map['display_name'] ?? '',
      birthDate: map['birth_date'] ?? '',
      birthPlace: map['birth_place'] ?? '',
      city: map['city'] ?? '',
    );
  }
  String toJson() {
    return json.encode({
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'birthDate': birthDate,
      'birthPlace': birthPlace,
      'city': city,
    });
  }
}
