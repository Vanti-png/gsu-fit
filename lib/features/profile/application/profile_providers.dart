import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gsu_fit/core/providers.dart';
import 'package:gsu_fit/features/profile/data/sqlite_profile_repository.dart';
import 'package:gsu_fit/features/profile/domain/user_profile.dart';

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => SqliteProfileRepository(ref.watch(appDatabaseProvider)),
);

/// Null until onboarding is finished.
final profileProvider = FutureProvider<UserProfile?>(
  (ref) => ref.watch(profileRepositoryProvider).get(),
);
