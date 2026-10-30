import 'package:gsu_fit/core/utils/map_read.dart';

enum ExerciseCategory { strength, bodyweight, cardio, mobility }

enum MuscleGroup {
  chest,
  back,
  shoulders,
  biceps,
  triceps,
  forearms,
  abs,
  quads,
  hamstrings,
  glutes,
  calves,
  lowerBack,
  fullBody,
}

enum Equipment { barbell, dumbbell, machine, cable, bodyweight, kettlebell, band, other }

class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.category,
    required this.primaryMuscles,
    this.secondaryMuscles = const [],
    required this.equipment,
    this.instructions = const [],
    this.imageUrls = const [],
    this.videoUrl,
    this.videoUrlLow,
    this.isTimed = false,
    this.isCustom = false,
    this.createdAt,
  });

  final String id;
  final String name;
  final ExerciseCategory category;
  final List<MuscleGroup> primaryMuscles;
  final List<MuscleGroup> secondaryMuscles;
  final Equipment equipment;

  /// Step-by-step form cues, one entry per step.
  final List<String> instructions;

  /// Frames of a short animation (shown in turn) or a single picture.
  final List<String> imageUrls;

  /// Full-quality video (http(s) URL or a local file path).
  final String? videoUrl;

  /// Optional smaller version used when "low quality" is selected.
  final String? videoUrlLow;

  /// Timed holds (e.g. plank): the "reps" field stores seconds.
  final bool isTimed;
  final bool isCustom;
  final DateTime? createdAt;

  bool get usesBodyweight => equipment == Equipment.bodyweight;

  bool get hasVideo => videoFor(lowQuality: false) != null;

  /// Picks the URL for the chosen quality, falling back to whichever exists.
  String? videoFor({required bool lowQuality}) {
    final high = (videoUrl?.isNotEmpty ?? false) ? videoUrl : null;
    final low = (videoUrlLow?.isNotEmpty ?? false) ? videoUrlLow : null;
    return lowQuality ? (low ?? high) : (high ?? low);
  }

  Exercise copyWith({
    String? name,
    ExerciseCategory? category,
    List<MuscleGroup>? primaryMuscles,
    List<MuscleGroup>? secondaryMuscles,
    Equipment? equipment,
    List<String>? instructions,
    List<String>? imageUrls,
    bool? isTimed,
  }) {
    return Exercise(
      id: id,
      name: name ?? this.name,
      category: category ?? this.category,
      primaryMuscles: primaryMuscles ?? this.primaryMuscles,
      secondaryMuscles: secondaryMuscles ?? this.secondaryMuscles,
      equipment: equipment ?? this.equipment,
      instructions: instructions ?? this.instructions,
      imageUrls: imageUrls ?? this.imageUrls,
      videoUrl: videoUrl,
      videoUrlLow: videoUrlLow,
      isTimed: isTimed ?? this.isTimed,
      isCustom: isCustom,
      createdAt: createdAt,
    );
  }

  /// Copy with new video links; empty strings clear them.
  Exercise withVideos({String? high, String? low}) {
    String? clean(String? value) =>
        (value == null || value.trim().isEmpty) ? null : value.trim();
    return Exercise(
      id: id,
      name: name,
      category: category,
      primaryMuscles: primaryMuscles,
      secondaryMuscles: secondaryMuscles,
      equipment: equipment,
      instructions: instructions,
      imageUrls: imageUrls,
      videoUrl: clean(high),
      videoUrlLow: clean(low),
      isTimed: isTimed,
      isCustom: isCustom,
      createdAt: createdAt,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'category': category.name,
        'primary_muscles': primaryMuscles.map((m) => m.name).join(','),
        'secondary_muscles': secondaryMuscles.map((m) => m.name).join(','),
        'equipment': equipment.name,
        'instructions': instructions.join('\n'),
        'image_urls': imageUrls.join('\n'),
        'video_url': videoUrl,
        'video_url_low': videoUrlLow,
        'is_timed': isTimed ? 1 : 0,
        'is_custom': isCustom ? 1 : 0,
        'created_at': createdAt?.millisecondsSinceEpoch,
      };

  factory Exercise.fromMap(Map<String, Object?> map) => Exercise(
        id: map['id']! as String,
        name: readString(map['name']) ?? '',
        category: readEnum(ExerciseCategory.values, map['category'], ExerciseCategory.strength),
        primaryMuscles: readEnumList(MuscleGroup.values, map['primary_muscles']),
        secondaryMuscles: readEnumList(MuscleGroup.values, map['secondary_muscles']),
        equipment: readEnum(Equipment.values, map['equipment'], Equipment.other),
        instructions: readList(map['instructions'], '\n'),
        imageUrls: readList(map['image_urls'], '\n'),
        videoUrl: readString(map['video_url']),
        videoUrlLow: readString(map['video_url_low']),
        isTimed: readBool(map['is_timed']),
        isCustom: readBool(map['is_custom']),
        createdAt: readDate(map['created_at']),
      );
}

abstract interface class ExerciseRepository {
  /// Deleted custom exercises are included only when [includeDeleted] is
  /// set, so old workouts can still show their names.
  Future<List<Exercise>> getAll({bool includeDeleted = false});

  Future<Exercise?> getById(String id);

  Future<void> save(Exercise exercise);

  Future<void> delete(String id);
}
