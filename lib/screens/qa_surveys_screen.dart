import 'package:flutter/material.dart';

import 'package:mayabela/models/qa_monitor_models.dart';
import 'package:mayabela/services/qa_monitor_service.dart';

/// Parent / student / teacher survey inbox. No findings, audits, or at-risk.
class QaSurveysScreen extends StatefulWidget {
  const QaSurveysScreen({super.key});

  @override
  State<QaSurveysScreen> createState() => _QaSurveysScreenState();
}

class _QaSurveysScreenState extends State<QaSurveysScreen> {
  final _svc = QaMonitorService.instance;

  @override
  void initState() {
    super.initState();
    _svc.ensureLoaded();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QA surveys')),
      body: ListenableBuilder(
        listenable: _svc,
        builder: (context, _) {
          final surveys = _svc.surveysForSchool();
          if (surveys.isEmpty) {
            return const Center(child: Text('No published surveys yet.'));
          }
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              for (final survey in surveys)
                Card(
                  child: ListTile(
                    title: Text(survey.title),
                    subtitle: Text(
                      _svc.responsesForSurvey(survey.id).isEmpty
                          ? 'Not submitted'
                          : 'Submitted',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _respond(survey),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _respond(QaSurvey survey) async {
            final mine = _svc.responsesForSurvey(survey.id);
            final existing = mine.isEmpty ? null : mine.first;
    final answers = <String, TextEditingController>{
      for (final q in survey.questions)
        q.id: TextEditingController(text: existing?.answers[q.id] ?? ''),
    };
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(survey.title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final q in survey.questions) ...[
                Text(q.prompt, style: const TextStyle(fontWeight: FontWeight.w600)),
                TextField(
                  controller: answers[q.id],
                  decoration: InputDecoration(
                    labelText: q.kind == SurveyQuestionKind.rating
                        ? 'Score 1–5'
                        : 'Comment',
                  ),
                  maxLines: q.kind == SurveyQuestionKind.text ? 3 : 1,
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _svc.submitSurveyResponse(
      surveyId: survey.id,
      answers: {
        for (final entry in answers.entries) entry.key: entry.value.text.trim(),
      },
    );
  }
}
