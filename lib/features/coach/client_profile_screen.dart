import 'package:flutter/material.dart';

import '../../core/ui/app_spacing.dart';
import '../../core/i18n/app_localizations.dart';
import '../../models/coach_client_row.dart';
import '../../models/client_details.dart';
import '../../models/user.dart';
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
  final _bioCtrl = TextEditingController();
  final _goalsCtrl = TextEditingController();
  final _injuriesCtrl = TextEditingController();
  final _privateCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  List<CoachClientRow> _rows = const [];

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

  static String _todayIso() {
    final n = DateTime.now();
    return '${n.year.toString().padLeft(4, '0')}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  Future<void> _openRowEditor({CoachClientRow? row}) async {
    final s = AppLocalizations.of(context);
    final dateCtrl = TextEditingController(text: row?.rowDateIso.isNotEmpty == true ? row!.rowDateIso : _todayIso());
    final titleCtrl = TextEditingController(text: row?.title ?? '');
    final valueCtrl = TextEditingController(text: row?.value ?? '');
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
                InputField(controller: titleCtrl, label: s.t('coach.table.colTitle')),
                const SizedBox(height: 10),
                InputField(controller: valueCtrl, label: s.t('coach.table.colValue')),
                const SizedBox(height: 10),
                InputField(controller: notesCtrl, label: s.t('coach.table.colNotes')),
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
                  title: titleCtrl.text.trim(),
                  value: valueCtrl.text.trim(),
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
        if (row == null) {
          await _rowsSvc.create(
            coachId: widget.coachId,
            clientId: widget.client.id,
            rowDateIso: res.dateIso,
            title: res.title,
            value: res.value,
            notes: res.notes,
          );
        } else {
          await _rowsSvc.update(
            id: row.id,
            coachId: widget.coachId,
            clientId: widget.client.id,
            rowDateIso: res.dateIso,
            title: res.title,
            value: res.value,
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
                            DataColumn(label: Text(s.t('coach.table.colTitle'))),
                            DataColumn(label: Text(s.t('coach.table.colValue'))),
                            DataColumn(label: Text(s.t('coach.table.colNotes'))),
                            const DataColumn(label: Text('')),
                          ],
                          rows: _rows
                              .map(
                                (r) => DataRow(
                                  cells: [
                                    DataCell(Text(r.rowDateIso)),
                                    DataCell(Text(r.title)),
                                    DataCell(Text(r.value)),
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
              PrimaryButton(label: _saving ? s.t('common.saving') : s.t('common.save'), onPressed: _saving ? null : _save),
            ],
          ),
          if (_loading || _saving) const LoadingWidget(message: 'Loading…'),
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
    this.title = '',
    this.value = '',
    this.notes = '',
  });

  final _RowEditorAction action;
  final String dateIso;
  final String title;
  final String value;
  final String notes;

  const _RowEditorResult.delete() : this._(_RowEditorAction.delete);

  factory _RowEditorResult.save({
    required String dateIso,
    required String title,
    required String value,
    required String notes,
  }) {
    return _RowEditorResult._(
      _RowEditorAction.save,
      dateIso: dateIso,
      title: title,
      value: value,
      notes: notes,
    );
  }
}

