import 'package:flutter/material.dart';

import '../../core/ui/app_spacing.dart';
import '../../models/client_details.dart';
import '../../models/user.dart';
import '../../services/profile/client_details_service.dart';
import '../../widgets/card_container.dart';
import '../../widgets/input_field.dart';
import '../../widgets/loading_widget.dart';
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
  final _bioCtrl = TextEditingController();
  final _goalsCtrl = TextEditingController();
  final _injuriesCtrl = TextEditingController();
  final _privateCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.client.name)),
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
                          const Text('Client'),
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
                    Text('Client-visible info', style: Theme.of(context).textTheme.titleMedium),
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
                    Text('Coach-only notes', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 10),
                    InputField(controller: _privateCtrl, label: 'Private notes'),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sectionGap),
              PrimaryButton(label: _saving ? 'Saving…' : 'Save', onPressed: _saving ? null : _save),
            ],
          ),
          if (_loading || _saving) const LoadingWidget(message: 'Loading…'),
        ],
      ),
    );
  }
}

