import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:napex_victim_app/core/theme/app_colors.dart';
import 'package:napex_victim_app/presentation/providers/core_providers.dart';
import 'package:napex_victim_app/presentation/shared/widgets/napex_card.dart';
import 'package:napex_victim_app/presentation/shared/widgets/napex_text_field.dart';
import 'package:napex_victim_app/presentation/shared/widgets/primary_button.dart';
import 'package:uuid/uuid.dart';

/// شاشة قائمة الحظر الشخصية — أرقام حظرها المستخدم
/// محلية 100%: تُخزَّن في قاعدة بيانات الجهاز ولا تُرسل للخادم إطلاقاً
class PersonalBlocklistScreen extends ConsumerStatefulWidget {
  const PersonalBlocklistScreen({super.key});

  @override
  ConsumerState<PersonalBlocklistScreen> createState() =>
      _PersonalBlocklistScreenState();
}

class _PersonalBlocklistScreenState
    extends ConsumerState<PersonalBlocklistScreen> {
  List<Map<String, dynamic>> _entries = [];
  bool _loading = true;
  bool _busy = false;
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final rows = await ref.read(personalBlocklistDaoProvider).getAll();
      if (!mounted) return;
      setState(() {
        _entries = rows.map(Map<String, dynamic>.from).toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _add() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) return;
    setState(() => _busy = true);
    try {
      final dao = ref.read(personalBlocklistDaoProvider);
      final existing = await dao.findByHashOrPhone(senderHash: '', phone: phone);
      if (existing != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('الرقم محظور مسبقاً'),
              backgroundColor: AppColors.warning,
            ),
          );
        }
        return;
      }
      await dao.insert({
        'id': const Uuid().v4(),
        'sender_hash': '',
        'phone_number': phone,
        'display_name': _nameController.text.trim(),
        'reason': 'user_blocked',
        'added_at': DateTime.now().millisecondsSinceEpoch,
      });
      _phoneController.clear();
      _nameController.clear();
      await _refresh();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(String id) async {
    setState(() => _busy = true);
    try {
      await ref.read(personalBlocklistDaoProvider).delete(id);
      await _refresh();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('الحظر الشخصي')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'الرسائل القادمة من هذه الأرقام ستُعامل كابتزاز مؤكد تلقائياً — '
            'حتى لو صيغت بذكاء. تُخزَّن القائمة على جهازك فقط ولا تُرسل لأي خادم.',
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
          ),
          const SizedBox(height: 16),

          NapexCard(
            child: Column(
              children: [
                NapexTextField(
                  controller: _phoneController,
                  label: 'رقم الهاتف',
                  prefixIcon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                NapexTextField(
                  controller: _nameController,
                  label: 'اسم تعريفي (اختياري)',
                  prefixIcon: Icons.label_outline,
                ),
                const SizedBox(height: 14),
                PrimaryButton(
                  label: 'حظر الرقم',
                  icon: Icons.block_outlined,
                  isLoading: _busy,
                  onPressed: _add,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_entries.isEmpty)
            NapexCard(
              child: Center(
                child: Text(
                  'لا توجد أرقام محظورة شخصياً',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              ),
            )
          else
            for (final entry in _entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: NapexCard(
                  child: Row(
                    children: [
                      const Icon(Icons.block_outlined, color: AppColors.danger),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (entry['display_name'] as String?)?.isNotEmpty == true
                                  ? entry['display_name'] as String
                                  : (entry['phone_number'] as String? ?? ''),
                              style: theme.textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              entry['phone_number'] as String? ?? '',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline,
                            color: AppColors.danger),
                        onPressed: _busy ? null : () => _remove(entry['id'] as String),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
