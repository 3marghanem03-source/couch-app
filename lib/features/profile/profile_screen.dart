import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/ui/app_spacing.dart';
import '../../models/user_role.dart';
import '../../services/profile/profile_service.dart';
import '../../widgets/card_container.dart';
import '../../widgets/input_field.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/primary_button.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _coachCodeCtrl = TextEditingController();
  final ProfileService _svc = ProfileService();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = appState.currentUser?.name ?? '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _coachCodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    setState(() => _busy = true);
    try {
      await _svc.updateName(_nameCtrl.text);
      await appState.refreshAll();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setCoach() async {
    setState(() => _busy = true);
    try {
      await _svc.setCoachByCode(_coachCodeCtrl.text);
      await appState.refreshAll();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Coach linked.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickAvatar() async {
    setState(() => _busy = true);
    try {
      await _svc.pickAndUploadAvatar();
      await appState.refreshAll();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Avatar updated.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final u = appState.currentUser;
        if (u == null) {
          return const Scaffold(body: Center(child: Text('Not signed in.')));
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Profile')),
          body: Stack(
            children: [
              ListView(
                padding: const EdgeInsets.all(AppSpacing.page),
                children: [
                  CardContainer(
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundImage: (u.avatarUrl != null && u.avatarUrl!.isNotEmpty)
                              ? NetworkImage(u.avatarUrl!)
                              : null,
                          child: (u.avatarUrl == null || u.avatarUrl!.isEmpty)
                              ? const Icon(Icons.person)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(u.name, style: Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 4),
                              Text(u.role == UserRole.coach ? 'Coach' : 'Client'),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: _busy ? null : _pickAvatar,
                          child: const Text('Change photo'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sectionGap),
                  CardContainer(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Name', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 10),
                        InputField(controller: _nameCtrl, label: 'Display name'),
                        const SizedBox(height: 12),
                        PrimaryButton(label: 'Save', onPressed: _busy ? null : _saveName),
                      ],
                    ),
                  ),
                  if (u.role == UserRole.client && (u.coachId == null || u.coachId!.isEmpty)) ...[
                    const SizedBox(height: AppSpacing.sectionGap),
                    CardContainer(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Link to your coach', style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 10),
                          InputField(controller: _coachCodeCtrl, label: 'Coach code'),
                          const SizedBox(height: 12),
                          PrimaryButton(label: 'Link coach', onPressed: _busy ? null : _setCoach),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              if (_busy) const LoadingWidget(message: 'Saving…'),
            ],
          ),
        );
      },
    );
  }
}

