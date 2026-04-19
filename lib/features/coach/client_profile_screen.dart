import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/ui/app_spacing.dart';
import '../../core/i18n/app_localizations.dart';
import '../../models/coach_client_row.dart';
import '../../models/client_details.dart';
import '../../models/user.dart';
import '../../services/ai/coach_training_ai_service.dart';
import '../../services/profile/coach_client_rows_service.dart';
import '../../services/profile/client_details_service.dart';
import '../../widgets/card_container.dart';
import '../../widgets/input_field.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/language_toggle_action.dart';
import '../../widgets/primary_button.dart';

class ClientProfileScreen extends StatefulWidget {
  const ClientProfileScreen({
    super.key,
    required this.client,
    required this.coachId,
  });

  final User client;
  final String coachId;

  @override
  State<ClientProfileScreen> createState() => _ClientProfileScreenState();
}

class _ClientProfileScreenState extends State<ClientProfileScreen> {
  final ClientDetailsService _svc = ClientDetailsService();
  final CoachClientRowsService _rowsSvc = CoachClientRowsService();
  final CoachTrainingAiService _aiSvc = CoachTrainingAiService();
  final _bioCtrl = TextEditingController();
  final _goalsCtrl = TextEditingController();
  final _injuriesCtrl = TextEditingController();
  final _privateCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _aiBusy = false;
  List<CoachClientRow> _rows = const [];
  Map<String, dynamic>? _aiPreview;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _bioCtrl.dispose();
    _goalsCtrl.dispose();
    _injuriesCtrl.dispose();
    _privateCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final ClientDetails? d = await _svc.getForClient(widget.client.id);
      if (d != null) {
        _bioCtrl.text = d.publicBio;
        _goalsCtrl.text = d.goals;
        _injuriesCtrl.text = d.injuries;
        _privateCtrl.text = d.privateNotes;
      }

      _rows = await _rowsSvc.listForClient(coachId: widget.coachId, clientId: widget.client.id);
      _aiPreview = await _aiSvc.latestPlanForClient(coachId: widget.coachId, clientId: widget.client.id);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _svc.upsertAsCoach(
        clientId: widget.client.id,
        coachId: widget.coachId,
        publicBio: _bioCtrl.text.trim(),
        goals: _goalsCtrl.text.trim(),
        injuries: _injuriesCtrl.text.trim(),
        privateNotes: _privateCtrl.text.trim(),
      );
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _refreshRows() async {
    final next = await _rowsSvc.listForClient(coachId: widget.coachId, clientId: widget.client.id);
    if (mounted) setState(() => _rows = next);
  }

  Future<void> _refreshAiPreview() async {
    final next = await _aiSvc.latestPlanForClient(coachId: widget.coachId, clientId: widget.client.id);
    if (mounted) setState(() => _aiPreview = next);
  }

  Future<void> _generateAiWeek() async {
    final s = AppLocalizations.of(context);
    setState(() => _aiBusy = true);
    try {
      await _aiSvc.generateWeekPlan(
        clientId: widget.client.id,
        weekStartIso: CoachTrainingAiService.thisWeekMondayIso(),
      );
      await _refreshAiPreview();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.t('coach.ai.saved'))));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _aiBusy = false);
    }
  }

  static String _todayIso() {
    final n = DateTime.now();
    return '${n.year.toString().padLeft(4, '0')}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  Future<void> _openRowEditor({CoachClientRow? row}) async {
    final s = AppLocalizations.of(context);
    final dateCtrl = TextEditingController(text: row?.rowDateIso.isNotEmpty == true ? row!.rowDateIso : _todayIso());
    final muscleCtrl = TextEditingController(text: row?.muscle ?? '');
    final exerciseCtrl = TextEditingController(text: row?.exercise ?? '');
    final setsCtrl = TextEditingController(text: row?.sets?.toString() ?? '');
    final repsCtrl = TextEditingController(text: row?.reps?.toString() ?? '');
    final weightCtrl = TextEditingController(text: row?.weight?.toString() ?? '');
    final unitCtrl = TextEditingController(text: row?.weightUnit ?? 'kg');
    final notesCtrl = TextEditingController(text: row?.notes ?? '');

    final res = await showDialog<_RowEditorResult>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(row == null ? s.t('coach.table.addRow') : s.t('coach.table.editRow')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InputField(controller: dateCtrl, label: s.t('coach.table.date')),
                const SizedBox(height: 10),
                InputField(controller: muscleCtrl, label: s.t('coach.table.colMuscle')),
                const SizedBox(height: 10),
                InputField(controller: exerciseCtrl, label: s.t('coach.table.colExercise')),
                const SizedBox(height: 10),
                InputField(controller: notesCtrl, label: s.t('coach.table.colNotes')),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: InputField(controller: setsCtrl, label: s.t('coach.table.colSets'))),
                    const SizedBox(width: 10),
                    Expanded(child: InputField(controller: repsCtrl, label: s.t('coach.table.colReps'))),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: InputField(controller: weightCtrl, label: s.t('coach.table.colWeight'))),
                    const SizedBox(width: 10),
                    Expanded(child: InputField(controller: unitCtrl, label: s.t('coach.table.colUnit'))),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            if (row != null)
              TextButton(
                onPressed: () => Navigator.pop(context, const _RowEditorResult.delete()),
                child: Text(s.t('common.delete')),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(s.t('common.cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                context,
                _RowEditorResult.save(
                  dateIso: dateCtrl.text.trim(),
                  muscle: muscleCtrl.text.trim(),
                  exercise: exerciseCtrl.text.trim(),
                  setsText: setsCtrl.text.trim(),
                  repsText: repsCtrl.text.trim(),
                  weightText: weightCtrl.text.trim(),
                  unit: unitCtrl.text.trim(),
                  notes: notesCtrl.text.trim(),
                ),
              ),
              child: Text(s.t('common.save')),
            ),
          ],
        );
      },
    );

    if (res == null) return;
    setState(() => _saving = true);
    try {
      if (res.action == _RowEditorAction.delete && row != null) {
        await _rowsSvc.delete(id: row.id, coachId: widget.coachId, clientId: widget.client.id);
      } else if (res.action == _RowEditorAction.save) {
        final sets = int.tryParse(res.setsText);
        final reps = int.tryParse(res.repsText);
        final weight = double.tryParse(res.weightText);

        if (row == null) {
          await _rowsSvc.create(
            coachId: widget.coachId,
            clientId: widget.client.id,
            rowDateIso: res.dateIso,
            muscle: res.muscle,
            exercise: res.exercise,
            sets: sets,
            reps: reps,
            weight: weight,
            weightUnit: res.unit,
            notes: res.notes,
          );
        } else {
          await _rowsSvc.update(
            id: row.id,
            coachId: widget.coachId,
            clientId: widget.client.id,
            rowDateIso: res.dateIso,
            muscle: res.muscle,
            exercise: res.exercise,
            sets: sets,
            reps: reps,
            weight: weight,
            weightUnit: res.unit,
            notes: res.notes,
          );
        }
      }
      await _refreshRows();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.client.name),
        actions: const [LanguageToggleAction()],
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(AppSpacing.page),
            children: [
              CardContainer(
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundImage: (widget.client.avatarUrl != null && widget.client.avatarUrl!.isNotEmpty)
                          ? NetworkImage(widget.client.avatarUrl!)
                          : null,
                      child: (widget.client.avatarUrl == null || widget.client.avatarUrl!.isEmpty)
                          ? const Icon(Icons.person)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.client.name, style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 2),
                          Text(s.t('coach.client')),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sectionGap),
              CardContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(s.t('coach.clientVisible'), style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 10),
                    InputField(controller: _bioCtrl, label: 'Bio'),
                    const SizedBox(height: 10),
                    InputField(controller: _goalsCtrl, label: 'Goals'),
                    const SizedBox(height: 10),
                    InputField(controller: _injuriesCtrl, label: 'Injuries'),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sectionGap),
              CardContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(s.t('coach.coachOnlyNotes'), style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 10),
                    InputField(controller: _privateCtrl, label: s.t('coach.privateNotes')),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sectionGap),
              CardContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(s.t('coach.tableTitle'), style: Theme.of(context).textTheme.titleMedium),
                        ),
                        TextButton.icon(
                          onPressed: _saving ? null : () => _openRowEditor(),
                          icon: const Icon(Icons.add),
                          label: Text(s.t('common.add')),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (_rows.isEmpty)
                      Text(s.t('coach.table.empty'))
                    else
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: [
                            DataColumn(label: Text(s.t('coach.table.colDate'))),
                            DataColumn(label: Text(s.t('coach.table.colMuscle'))),
                            DataColumn(label: Text(s.t('coach.table.colExercise'))),
                            DataColumn(label: Text(s.t('coach.table.colSets'))),
                            DataColumn(label: Text(s.t('coach.table.colReps'))),
                            DataColumn(label: Text(s.t('coach.table.colWeight'))),
                            DataColumn(label: Text(s.t('coach.table.colUnit'))),
                            DataColumn(label: Text(s.t('coach.table.colNotes'))),
                            const DataColumn(label: Text('')),
                          ],
                          rows: _rows
                              .map(
                                (r) => DataRow(
                                  cells: [
                                    DataCell(Text(r.rowDateIso)),
                                    DataCell(Text(r.muscle)),
                                    DataCell(Text(r.exercise)),
                                    DataCell(Text(r.sets?.toString() ?? '')),
                                    DataCell(Text(r.reps?.toString() ?? '')),
                                    DataCell(Text(r.weight?.toString() ?? '')),
                                    DataCell(Text(r.weightUnit)),
                                    DataCell(Text(r.notes)),
                                    DataCell(
                                      IconButton(
                                        icon: const Icon(Icons.edit),
                                        onPressed: _saving ? null : () => _openRowEditor(row: r),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                              .toList(),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sectionGap),
              CardContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(s.t('coach.ai.title'), style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 10),
                    FilledButton(
                      onPressed: (_saving || _aiBusy) ? null : _generateAiWeek,
                      child: Text(_aiBusy ? s.t('coach.ai.generating') : s.t('coach.ai.generate')),
                    ),
                    const SizedBox(height: 12),
                    if (_aiPreview == null)
                      Text(s.t('coach.ai.empty'), style: Theme.of(context).textTheme.bodySmall)
                    else ...[
                      Text('${s.t('coach.ai.week')}: ${_aiPreview!['week_start']}', style: Theme.of(context).textTheme.bodySmall),
                      Text('${s.t('coach.ai.model')}: ${_aiPreview!['model']}', style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 8),
                      SelectableText(
                        const JsonEncoder.withIndent('  ').convert(_aiPreview!['plan'] ?? {}),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sectionGap),
              PrimaryButton(label: _saving ? s.t('common.saving') : s.t('common.save'), onPressed: _saving ? null : _save),
            ],
          ),
          if (_loading || _saving || _aiBusy) const LoadingWidget(message: 'Loading…'),
        ],
      ),
    );
  }
}

enum _RowEditorAction { save, delete }

class _RowEditorResult {
  const _RowEditorResult._(
    this.action, {
    this.dateIso = '',
    this.muscle = '',
    this.exercise = '',
    this.setsText = '',
    this.repsText = '',
    this.weightText = '',
    this.unit = '',
    this.notes = '',
  });

  final _RowEditorAction action;
  final String dateIso;
  final String muscle;
  final String exercise;
  final String setsText;
  final String repsText;
  final String weightText;
  final String unit;
  final String notes;

  const _RowEditorResult.delete() : this._(_RowEditorAction.delete);

  factory _RowEditorResult.save({
    required String dateIso,
    required String muscle,
    required String exercise,
    required String setsText,
    required String repsText,
    required String weightText,
    required String unit,
    required String notes,
  }) {
    return _RowEditorResult._(
      _RowEditorAction.save,
      dateIso: dateIso,
      muscle: muscle,
      exercise: exercise,
      setsText: setsText,
      repsText: repsText,
      weightText: weightText,
      unit: unit,
      notes: notes,
    );
  }
}

