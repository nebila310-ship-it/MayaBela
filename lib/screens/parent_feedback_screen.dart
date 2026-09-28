import 'package:flutter/material.dart';

import 'package:mayabela/screens/qa_surveys_screen.dart';
import 'package:mayabela/services/curriculum_service.dart';
import 'package:mayabela/services/qa_monitor_service.dart';
import 'package:mayabela/utils/scroll_safe_area.dart';
import 'package:mayabela/web_erp/pages/web_curriculum_page.dart';

/// Parent feedback inbox on existing curriculum_feedback + QA surveys.
/// Replaces communication-book slips and Telegram group polls.
class ParentFeedbackScreen extends StatefulWidget {
  const ParentFeedbackScreen({super.key});

  @override
  State<ParentFeedbackScreen> createState() => _ParentFeedbackScreenState();
}

class _ParentFeedbackScreenState extends State<ParentFeedbackScreen> {
  @override
  void initState() {
    super.initState();
    CurriculumService.instance.ensureLoaded();
    QaMonitorService.instance.ensureLoaded();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFCFDBEA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF5D4037),
        title: const Text('Feedback'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showCurriculumFeedbackDialog(context),
        backgroundColor: const Color(0xFF5D4037),
        icon: const Icon(Icons.comment_outlined),
        label: const Text('Submit feedback'),
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([
          CurriculumService.instance,
          QaMonitorService.instance,
        ]),
        builder: (context, _) {
          final comments = CurriculumService.instance.feedbackForSchool();
          final surveys = QaMonitorService.instance.surveysForSchool();
          return ListView(
            padding: listPagePadding(context),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    'Send comments to the school here. Use Messages for teachers, '
                    'Daily Activities instead of a communication book, and Grades '
                    'instead of printed reports. This does not replace Telegram OTP.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'School comments',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              if (comments.isEmpty)
                const Card(
                  child: ListTile(
                    title: Text('No comments yet.'),
                    subtitle: Text('Submit school-wide or subject feedback.'),
                  ),
                )
              else
                for (final item in comments)
                  Card(
                    child: ListTile(
                      title: Text(
                        item.isSchoolWide
                            ? 'School-wide'
                            : (CurriculumService.instance
                                    .unitById(item.curriculumUnitId)
                                    ?.title ??
                                item.curriculumUnitId),
                      ),
                      subtitle: Text(
                        '${item.rating == null ? '' : '${item.rating}/5 · '}'
                        '${item.status.name}\n${item.body}',
                      ),
                    ),
                  ),
              const SizedBox(height: 16),
              Text(
                'QA surveys',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              if (surveys.isEmpty)
                const Card(
                  child: ListTile(
                    title: Text('No published surveys yet.'),
                  ),
                )
              else
                for (final survey in surveys)
                  Card(
                    child: ListTile(
                      title: Text(survey.title),
                      subtitle: Text(
                        QaMonitorService.instance
                                .responsesForSurvey(survey.id)
                                .isEmpty
                            ? 'Not submitted'
                            : 'Submitted',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const QaSurveysScreen(),
                          ),
                        );
                      },
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}
