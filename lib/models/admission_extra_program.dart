/// Optional enrichment programmes families can request at admission.
/// These are placeholders for modules the school will add later.
class AdmissionExtraProgram {
  const AdmissionExtraProgram({
    required this.id,
    required this.title,
    required this.group,
    required this.blurb,
  });

  final String id;
  final String title;
  final String group;
  final String blurb;
}

/// Catalogue shown on Apply for admission. Keep ids stable when modules land.
abstract final class AdmissionExtraPrograms {
  static const filmEditing = AdmissionExtraProgram(
    id: 'film_editing',
    title: 'Film & editing class',
    group: 'Media',
    blurb: 'Story, camera, and editing for short films.',
  );
  static const football = AdmissionExtraProgram(
    id: 'football',
    title: 'Sport / football class',
    group: 'Sport',
    blurb: 'Skills, fitness, and team play.',
  );
  static const basketball = AdmissionExtraProgram(
    id: 'basketball',
    title: 'Basketball class',
    group: 'Sport',
    blurb: 'Shooting, defence, and game IQ.',
  );
  static const athletics = AdmissionExtraProgram(
    id: 'athletics',
    title: 'Athletics / track',
    group: 'Sport',
    blurb: 'Running, jumps, and field events.',
  );
  static const swimming = AdmissionExtraProgram(
    id: 'swimming',
    title: 'Swimming',
    group: 'Sport',
    blurb: 'Water safety and stroke technique.',
  );
  static const aiLearning = AdmissionExtraProgram(
    id: 'ai_learning',
    title: 'AI learning class',
    group: 'STEM',
    blurb: 'Prompting, ethics, and practical AI tools.',
  );
  static const codingRobotics = AdmissionExtraProgram(
    id: 'coding_robotics',
    title: 'Coding & robotics',
    group: 'STEM',
    blurb: 'Block and text coding with simple robots.',
  );
  static const visualArts = AdmissionExtraProgram(
    id: 'visual_arts',
    title: 'Visual arts',
    group: 'Art & creative',
    blurb: 'Drawing, painting, and mixed media.',
  );
  static const music = AdmissionExtraProgram(
    id: 'music',
    title: 'Music',
    group: 'Art & creative',
    blurb: 'Voice, instrument, and ensemble.',
  );
  static const dance = AdmissionExtraProgram(
    id: 'dance',
    title: 'Dance & performance',
    group: 'Art & creative',
    blurb: 'Movement, rhythm, and stage craft.',
  );
  static const drama = AdmissionExtraProgram(
    id: 'drama',
    title: 'Drama & theatre',
    group: 'Art & creative',
    blurb: 'Acting, voice, and production.',
  );
  static const creativeWriting = AdmissionExtraProgram(
    id: 'creative_writing',
    title: 'Creative writing',
    group: 'Art & creative',
    blurb: 'Stories, poetry, and journalism.',
  );
  static const photography = AdmissionExtraProgram(
    id: 'photography',
    title: 'Photography',
    group: 'Media',
    blurb: 'Composition, light, and photo stories.',
  );
  static const chess = AdmissionExtraProgram(
    id: 'chess',
    title: 'Chess club',
    group: 'Clubs',
    blurb: 'Strategy, tournaments, and fair play.',
  );

  static const all = <AdmissionExtraProgram>[
    filmEditing,
    football,
    basketball,
    athletics,
    swimming,
    aiLearning,
    codingRobotics,
    visualArts,
    music,
    dance,
    drama,
    creativeWriting,
    photography,
    chess,
  ];

  static List<String> get groups {
    final seen = <String>[];
    for (final item in all) {
      if (!seen.contains(item.group)) seen.add(item.group);
    }
    return seen;
  }

  static AdmissionExtraProgram? byId(String id) {
    for (final item in all) {
      if (item.id == id) return item;
    }
    return null;
  }

  static List<String> titlesFor(Iterable<String> ids) {
    return [
      for (final id in ids)
        byId(id)?.title ?? id.trim(),
    ].where((title) => title.isNotEmpty).toList();
  }
}
