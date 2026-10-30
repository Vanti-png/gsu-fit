import 'package:gsu_fit/core/utils/map_read.dart';

enum FitnessGoal { muscleGain, weightLoss, endurance, generalHealth }

enum ExperienceLevel { beginner, intermediate, advanced }

/// Only used for the calorie estimate; "unspecified" averages both formulas.
enum Sex { male, female, unspecified }

class UserProfile {
  const UserProfile({
    required this.id,
    required this.name,
    required this.age,
    required this.heightCm,
    required this.weightKg,
    required this.sex,
    required this.goal,
    required this.experience,
    required this.daysPerWeek,
    this.createdAt,
  });

  final String id;
  final String name;
  final int age;
  final double heightCm;
  final double weightKg;
  final Sex sex;
  final FitnessGoal goal;
  final ExperienceLevel experience;
  final int daysPerWeek;
  final DateTime? createdAt;

  UserProfile copyWith({
    String? name,
    int? age,
    double? heightCm,
    double? weightKg,
    Sex? sex,
    FitnessGoal? goal,
    ExperienceLevel? experience,
    int? daysPerWeek,
  }) {
    return UserProfile(
      id: id,
      name: name ?? this.name,
      age: age ?? this.age,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      sex: sex ?? this.sex,
      goal: goal ?? this.goal,
      experience: experience ?? this.experience,
      daysPerWeek: daysPerWeek ?? this.daysPerWeek,
      createdAt: createdAt,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'age': age,
        'height_cm': heightCm,
        'weight_kg': weightKg,
        'sex': sex.name,
        'goal': goal.name,
        'experience': experience.name,
        'days_per_week': daysPerWeek,
        'created_at': createdAt?.millisecondsSinceEpoch,
      };

  factory UserProfile.fromMap(Map<String, Object?> map) => UserProfile(
        id: map['id']! as String,
        name: readString(map['name']) ?? '',
        age: readInt(map['age']) ?? 30,
        heightCm: readDouble(map['height_cm']) ?? 170,
        weightKg: readDouble(map['weight_kg']) ?? 70,
        sex: readEnum(Sex.values, map['sex'], Sex.unspecified),
        goal: readEnum(FitnessGoal.values, map['goal'], FitnessGoal.generalHealth),
        experience: readEnum(ExperienceLevel.values, map['experience'], ExperienceLevel.beginner),
        daysPerWeek: readInt(map['days_per_week']) ?? 3,
        createdAt: readDate(map['created_at']),
      );
}

abstract interface class ProfileRepository {
  Future<UserProfile?> get();

  Future<void> save(UserProfile profile);
}
