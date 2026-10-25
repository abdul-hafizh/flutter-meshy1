import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../providers/auth_controller.dart';
import '../services/user_address_service.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_button.dart';
import 'addresses/address_list_screen.dart';

const _monthNames = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];

String _formatBirthDate(DateTime d) => '${d.day} ${_monthNames[d.month - 1]} ${d.year}';
String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// The customer's own profile: photo, name, gender, date of birth and one
/// phone number (required — also used as their WhatsApp). Email is fixed
/// (it's the login identity) and shown read-only; at least one shipping
/// address is required, managed in "Alamat Pengiriman".
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  String? _gender;
  DateTime? _birthDate;

  bool _submitting = false;
  bool _uploadingPhoto = false;
  String? _error;

  /// Saved shipping addresses; null while loading (or if it couldn't load).
  int? _addressCount;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthController>().user;
    _nameCtrl = TextEditingController(text: user?.fullName ?? '');
    // One number: older accounts may only have the WhatsApp one filled in.
    final phone = (user?.phone ?? '').trim();
    _phoneCtrl = TextEditingController(text: phone.isNotEmpty ? phone : (user?.whatsappNumber ?? ''));
    _loadAddressCount();
    _gender = user?.gender;
    _birthDate = user?.birthDate != null ? DateTime.tryParse(user!.birthDate!) : null;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Ambil foto'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Pilih dari galeri'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final file = await ImagePicker().pickImage(source: source, imageQuality: 85, maxWidth: 1024, maxHeight: 1024);
    if (file == null || !mounted) return;
    setState(() => _uploadingPhoto = true);
    final bytes = await file.readAsBytes();
    final name = file.name.contains('.') ? file.name : '${file.name}.jpg';
    if (!mounted) return;
    final error = await context.read<AuthController>().uploadAvatar(bytes, name);
    if (!mounted) return;
    setState(() => _uploadingPhoto = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error ?? 'Foto profil diperbarui.')));
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 20, 1, 1),
      firstDate: DateTime(now.year - 100),
      lastDate: DateTime(now.year - 5, now.month, now.day),
      helpText: 'Tanggal lahir',
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _loadAddressCount() async {
    final token = context.read<AuthController>().token;
    if (token == null) return;
    try {
      final list = await UserAddressService.listMine(token: token);
      if (mounted) setState(() => _addressCount = list.length);
    } catch (_) {
      // Leave unknown — saving re-checks.
    }
  }

  Future<void> _openAddresses() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddressListScreen()));
    if (mounted) _loadAddressCount();
  }

  static String? _validatePhone(String? v) {
    final digits = (v ?? '').replaceAll(RegExp(r'[\s\-()]'), '');
    if (digits.isEmpty) return 'Nomor HP wajib diisi';
    if (!RegExp(r'^\+?\d{9,15}$').hasMatch(digits)) return 'Nomor HP tidak valid (9–15 angka)';
    return null;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_addressCount == null) await _loadAddressCount();
    if (!mounted) return;
    if (_addressCount == 0) {
      setState(() => _error = 'Alamat pengiriman wajib diisi. Tambahkan minimal satu alamat.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });

    final error = await context.read<AuthController>().updateProfile(
          fullName: _nameCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          // The same number is their WhatsApp.
          whatsappNumber: _phoneCtrl.text.trim(),
          gender: _gender ?? '',
          birthDate: _birthDate != null ? _isoDate(_birthDate!) : '',
        );

    if (!mounted) return;
    if (error != null) {
      setState(() {
        _submitting = false;
        _error = error;
      });
      return;
    }

    setState(() => _submitting = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profil berhasil diperbarui.')));
    Navigator.of(context).pop(true);
  }

  InputDecoration _decoration(String label, {String? hint, Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      suffixIcon: suffix,
      filled: true,
      fillColor: AppColors.surfaceMuted,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
      );

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().user;
    final avatarUrl = user?.avatarUrl;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Edit Profil'),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              Center(
                child: GestureDetector(
                  onTap: _uploadingPhoto ? null : _pickPhoto,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceMuted,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.border, width: 2),
                        ),
                        child: _uploadingPhoto
                            ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                            : avatarUrl != null
                                ? Image.network(
                                    avatarUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => const Icon(Icons.person_rounded, size: 46, color: AppColors.textFaint),
                                  )
                                : const Icon(Icons.person_rounded, size: 46, color: AppColors.textFaint),
                      ),
                      Positioned(
                        bottom: 0,
                        right: -2,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            gradient: AppColors.brandGradient,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.surface, width: 3),
                          ),
                          child: const Icon(Icons.photo_camera_rounded, size: 15, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const Center(
                child: Text('Ketuk untuk ganti foto profil', style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: _decoration('Nama lengkap'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama lengkap wajib diisi' : null,
              ),
              const SizedBox(height: 16),
              _label('Jenis kelamin'),
              Row(
                children: [
                  for (final option in const [('MALE', 'Laki-laki', Icons.male_rounded), ('FEMALE', 'Perempuan', Icons.female_rounded)]) ...[
                    Expanded(
                      child: ChoiceChip(
                        avatar: Icon(option.$3, size: 18, color: _gender == option.$1 ? AppColors.purple : AppColors.textSecondary),
                        label: SizedBox(width: double.infinity, child: Text(option.$2, textAlign: TextAlign.center)),
                        selected: _gender == option.$1,
                        onSelected: (v) => setState(() => _gender = v ? option.$1 : null),
                        selectedColor: AppColors.purple.withValues(alpha: 0.12),
                        labelStyle: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _gender == option.$1 ? AppColors.purple : AppColors.textSecondary,
                        ),
                        showCheckmark: false,
                      ),
                    ),
                    if (option.$1 == 'MALE') const SizedBox(width: 10),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _pickBirthDate,
                child: InputDecorator(
                  decoration: _decoration(
                    'Tanggal lahir',
                    suffix: _birthDate != null
                        ? IconButton(
                            tooltip: 'Hapus',
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () => setState(() => _birthDate = null),
                          )
                        : const Icon(Icons.cake_outlined),
                  ),
                  child: Text(
                    _birthDate != null ? _formatBirthDate(_birthDate!) : 'Pilih tanggal',
                    style: TextStyle(fontSize: 15, color: _birthDate != null ? AppColors.textPrimary : AppColors.textFaint),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: _decoration('Nomor HP *', hint: '08xxxxxxxxxx'),
                validator: _validatePhone,
              ),
              const SizedBox(height: 4),
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Text(
                  'Wajib diisi. Nomor ini juga dipakai sebagai WhatsApp agar toko bisa menghubungimu soal pesanan.',
                  style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: user?.email ?? '',
                enabled: false,
                decoration: _decoration('Email'),
              ),
              const SizedBox(height: 4),
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Text(
                  'Email tidak dapat diubah — ini identitas akun kamu.',
                  style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(height: 16),
              Material(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: _addressCount == 0 ? const Color(0xFFE0453A) : AppColors.border),
                  ),
                  leading: const Icon(Icons.location_on_outlined, color: AppColors.purple),
                  title: const Text('Alamat Pengiriman *', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(
                    _addressCount == 0
                        ? 'Wajib diisi — tambahkan minimal satu alamat'
                        : _addressCount == null
                            ? 'Atur alamat & titik lokasi di peta'
                            : '$_addressCount alamat tersimpan · atur alamat & titik lokasi',
                    style: TextStyle(color: _addressCount == 0 ? const Color(0xFFE0453A) : null),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _openAddresses,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0453A).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(_error!, style: const TextStyle(fontSize: 13, color: Color(0xFFE0453A), fontWeight: FontWeight.w600)),
                ),
              ],
              const SizedBox(height: 22),
              GradientButton(
                label: _submitting ? 'Menyimpan...' : 'Simpan Perubahan',
                icon: _submitting ? null : Icons.check_rounded,
                onPressed: _submitting ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
