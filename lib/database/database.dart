/// Canonical database schema for Maya Edu / EduAba.
///
/// All relationships use IDs. Users connect through assignment/link collections,
/// never directly to each other.
library;

export 'collection_names.dart';
export 'id_utils.dart';
export 'models/database_models.dart';
export 'relationship_resolver.dart';
export 'supabase/supabase_bootstrap.dart';
export 'repositories/supabase_school_repository.dart';
export 'repositories/in_memory_school_repository.dart';
export 'repositories/school_repository.dart';
export 'school_database_service.dart';
export 'seed/registry_seed_builder.dart';
export 'seed/school_seed_snapshot.dart';
export 'user_roles.dart';
