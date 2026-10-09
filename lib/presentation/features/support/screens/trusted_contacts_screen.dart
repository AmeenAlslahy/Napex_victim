import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import 'package:napex_victim_app/core/theme/app_colors.dart';
import 'package:napex_victim_app/core/storage/local_storage.dart';
import 'package:napex_victim_app/presentation/providers/core_providers.dart';
import 'package:napex_victim_app/presentation/shared/widgets/napex_card.dart';
import 'package:napex_victim_app/presentation/shared/widgets/napex_text_field.dart';
import 'package:napex_victim_app/presentation/shared/widgets/primary_button.dart';

/// جهة اتصال موثوقة — تُخزن محلياً وتُستخدم في وضع الطوارئ
class TrustedContact {
  const TrustedContact({required this.name, required this.phone});

  final String name;
  final String phone;

  Map<String, dynamic> toJson() => {'name': name, 'phone': phone};

  factory TrustedContact.fromJson(Map<String, dynamic> json) =>
      TrustedContact(
        name: json['name']?.toString() ?? '',
        phone: json['phone']?.toString() ?? '',
      );
}

/// مخزن جهات الاتصال الموثوقة (محلي — لا يرفع لأي خادم)
class TrustedContactsStore {
  TrustedContactsStore(this._storage);

  final LocalStorage _storage;
  static const _key = 'trusted_contacts';

  List<TrustedContact> load() {
    final raw = _storage.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => TrustedContact.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> save(List<TrustedContact> contacts) =>
      _storage.setString(_key, jsonEncode(contacts.map((c) => c.toJson()).toList()));
}

/// شاشة جهات الاتصال الموثوقة
class TrustedContactsScreen extends ConsumerStatefulWidget {
  const TrustedContactsScreen({super.key});

  @override
  ConsumerState<TrustedContactsScreen> createState() =>
      _TrustedContactsScreenState();
}

class _TrustedContactsScreenState extends ConsumerState<TrustedContactsScreen> {
  late final TrustedContactsStore _store;
  List<TrustedContact> _contacts = [];
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _store = TrustedContactsStore(ref.read(localStorageProvider));
    _contacts = _store.load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    if (name.isEmpty || phone.isEmpty) return;

    final updated = [..._contacts, TrustedContact(name: name, phone: phone)];
    await _store.save(updated);
    setState(() {
      _contacts = updated;
      _nameController.clear();
      _phoneController.clear();
    });
  }

  Future<void> _remove(int index) async {
    final updated = [..._contacts]..removeAt(index);
    await _store.save(updated);
    setState(() => _contacts = updated);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('جهات الاتصال الموثوقة')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'من تريد تجهيزه بسرعة عند الطوارئ؟ تُخزن هذه الأرقام على جهازك فقط.',
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
          ),
          const SizedBox(height: 16),

          for (var i = 0; i < _contacts.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: NapexCard(
                child: Row(
                  children: [
                    const Icon(Icons.person_pin_circle_outlined,
                        color: AppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_contacts[i].name,
                              style: theme.textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                          Text(_contacts[i].phone,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                              )),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline,
                          color: AppColors.danger),
                      onPressed: () => _remove(i),
                    ),
                  ],
                ),
              ),
            ),

          if (_contacts.isEmpty)
            NapexCard(
              child: Center(
                child: Text(
                  'لا توجد جهات موثوقة بعد — أضف شخصاً يثق به',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              ),
            ),

          const SizedBox(height: 20),
          NapexTextField(
            controller: _nameController,
            label: 'الاسم',
            prefixIcon: Icons.person_outline,
          ),
          const SizedBox(height: 12),
          NapexTextField(
            controller: _phoneController,
            label: 'رقم الهاتف',
            prefixIcon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            label: 'إضافة جهة اتصال',
            icon: Icons.add,
            onPressed: _add,
          ),
        ],
      ),
    );
  }
}

/// بناء نص إشعار الطوارئ لجهة موثوقة
String buildPanicShareText({
  required String contactName,
  String? reportNumber,
}) {
  final buffer = StringBuffer()
    ..writeln('🆘 رسالة طوارئ من تطبيق NAP-EX')
    ..writeln('إلى: $contactName')
    ..writeln('أنا بحاجة لمساعدة عاجلة — تعرضت لابتزاز إلكتروني.')
    ..writeln('التطبيق حفظ الأدلة وأرسل بلاغاً للجهات المختصة'
        '${reportNumber != null ? ' (رقم البلاغ: $reportNumber)' : ''}.')
    ..writeln('من فضلك تواصل معي الآن.');
  return buffer.toString();
}

/// مشاركة نص عبر أي تطبيق على الجهاز (SMS/واتساب…)
Future<void> shareText(String text) async {
  await Share.share(text);
}

/// نسخ نص للحافظة (بديل عند غياب مشاركة)
Future<void> copyToClipboard(String text) async {
  await Clipboard.setData(ClipboardData(text: text));
}
