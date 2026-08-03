import 'package:equatable/equatable.dart';

class User extends Equatable {
  const User({required this.id, required this.email, required this.name});

  final String id;
  final String? email;
  final String name;

  bool get isGuest => email == null;

  @override
  List<Object?> get props => [id, email, name];
}
