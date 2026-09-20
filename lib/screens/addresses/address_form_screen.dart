import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../../models/region.dart';
import '../../models/user_address.dart';
import '../../providers/auth_controller.dart';
import '../../services/auth_service.dart' show ApiException;
import '../../services/location_service.dart';
import '../../services/user_address_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/gradient_button.dart';

class AddressFormScreen extends StatefulWidget {
  final UserAddress? existing;

  const AddressFormScreen({super.key, this.existing});

  @override
  State<AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends State<AddressFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _labelCtrl;
  late final TextEditingController _recipientCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _whatsappCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _postalCodeCtrl;
  late bool _isDefault;
  double? _latitude;
  double? _longitude;
  bool _locating = false;

  List<CountryRef> _countries = [];
  List<ProvinceRef> _provinces = [];
  List<CityRef> _cities = [];
  int? _countryId;
  int? _provinceId;
  int? _cityId;

  bool _loadingRegions = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _labelCtrl = TextEditingController(text: existing?.label ?? '');
    _recipientCtrl = TextEditingController(text: existing?.recipientName ?? '');
    _phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    _whatsappCtrl = TextEditingController(text: existing?.whatsappNumber ?? '');
    _addressCtrl = TextEditingController(text: existing?.address ?? '');
    _postalCodeCtrl = TextEditingController(text: existing?.postalCode ?? '');
    _isDefault = existing?.isDefault ?? false;
    _latitude = existing?.latitude;
    _longitude = existing?.longitude;
    _countryId = existing?.countryId;
    _provinceId = existing?.provinceId;
    _cityId = existing?.cityId;
    _loadRegions();
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _recipientCtrl.dispose();
    _phoneCtrl.dispose();
    _whatsappCtrl.dispose();
    _addressCtrl.dispose();
    _postalCodeCtrl.dispose();
    super.dispose();
  }

  String? get _token => context.read<AuthController>().token;

  Future<void> _loadRegions() async {
    final token = _token;
    if (token == null) return;
    setState(() => _loadingRegions = true);
    try {
      final countries = await LocationService.listCountries(token: token);
      List<ProvinceRef> provinces = [];
      List<CityRef> cities = [];
      if (_countryId != null) {
        provinces = await LocationService.listProvinces(token: token, countryId: _countryId);
      }
      if (_provinceId != null) {
        cities = await LocationService.listCities(token: token, provinceId: _provinceId);
      }
      if (!mounted) return;
      setState(() {
        _countries = countries;
        _provinces = provinces;
        _cities = cities;
      });
    } catch (_) {
      // Best-effort — the free-text Address field still works without region pickers.
    } finally {
      if (mounted) setState(() => _loadingRegions = false);
    }
  }

  Future<void> _onCountryChanged(int? countryId) async {
    setState(() {
      _countryId = countryId;
      _provinceId = null;
      _cityId = null;
      _provinces = [];
      _cities = [];
    });
    final token = _token;
    if (token == null || countryId == null) return;
    try {
      final provinces = await LocationService.listProvinces(token: token, countryId: countryId);
      if (!mounted) return;
      setState(() => _provinces = provinces);
    } catch (_) {
      // Best-effort.
    }
  }

  Future<void> _onProvinceChanged(int? provinceId) async {
    setState(() {
      _provinceId = provinceId;
      _cityId = null;
      _cities = [];
    });
    final token = _token;
    if (token == null || provinceId == null) return;
    try {
      final cities = await LocationService.listCities(token: token, provinceId: provinceId);
      if (!mounted) return;
      setState(() => _cities = cities);
    } catch (_) {
      // Best-effort.
    }
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _locating = true;
      _error = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw 'Aktifkan layanan lokasi (GPS) di perangkat kamu.';
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        throw 'Izin lokasi ditolak. Aktifkan izin lokasi untuk aplikasi ini di pengaturan.';
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      ).timeout(const Duration(seconds: 20));
      if (!mounted) return;
      setState(() {
        _latitude = pos.latitude;
        _longitude = pos.longitude;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e is String ? e : 'Gagal mengambil lokasi. Coba lagi.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final token = _token;
    if (token == null) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final existing = widget.existing;
      if (existing == null) {
        await UserAddressService.create(
          token: token,
          label: _labelCtrl.text.trim().isEmpty ? 'Rumah' : _labelCtrl.text.trim(),
          recipientName: _recipientCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          whatsappNumber: _whatsappCtrl.text.trim(),
          address: _addressCtrl.text.trim(),
          countryId: _countryId,
          provinceId: _provinceId,
          cityId: _cityId,
          postalCode: _postalCodeCtrl.text.trim(),
          latitude: _latitude,
          longitude: _longitude,
          isDefault: _isDefault,
        );
      } else {
        await UserAddressService.update(
          token: token,
          id: existing.id,
          label: _labelCtrl.text.trim().isEmpty ? 'Rumah' : _labelCtrl.text.trim(),
          recipientName: _recipientCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          whatsappNumber: _whatsappCtrl.text.trim(),
          address: _addressCtrl.text.trim(),
          countryId: _countryId,
          provinceId: _provinceId,
          cityId: _cityId,
          postalCode: _postalCodeCtrl.text.trim(),
          latitude: _latitude,
          longitude: _longitude,
          isDefault: _isDefault,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Gagal menyimpan alamat. Coba lagi.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  InputDecoration _decoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: AppColors.surfaceMuted,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Alamat' : 'Tambah Alamat'),
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
              TextFormField(
                controller: _labelCtrl,
                decoration: _decoration('Label alamat', hint: 'Rumah, Kantor, dll'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _recipientCtrl,
                decoration: _decoration('Nama penerima'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama penerima wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: _decoration('Nomor telepon'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Nomor telepon wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _whatsappCtrl,
                keyboardType: TextInputType.phone,
                decoration: _decoration('Nomor WhatsApp (opsional)'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressCtrl,
                maxLines: 3,
                decoration: _decoration('Alamat lengkap', hint: 'Nama jalan, nomor rumah, RT/RW'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Alamat wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              if (_loadingRegions)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                )
              else ...[
                DropdownButtonFormField<int>(
                  initialValue: _countryId,
                  decoration: _decoration('Negara'),
                  items: [
                    for (final c in _countries) DropdownMenuItem(value: c.id, child: Text(c.name)),
                  ],
                  onChanged: _onCountryChanged,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: _provinceId,
                  decoration: _decoration('Provinsi'),
                  items: [
                    for (final p in _provinces) DropdownMenuItem(value: p.id, child: Text(p.name)),
                  ],
                  onChanged: _countryId == null ? null : _onProvinceChanged,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: _cityId,
                  decoration: _decoration('Kota/Kabupaten'),
                  items: [
                    for (final c in _cities) DropdownMenuItem(value: c.id, child: Text(c.name)),
                  ],
                  onChanged: _provinceId == null ? null : (v) => setState(() => _cityId = v),
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _postalCodeCtrl,
                keyboardType: TextInputType.number,
                decoration: _decoration('Kode pos (opsional)'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _locating ? null : _useCurrentLocation,
                icon: _locating
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(_latitude != null ? Icons.location_on_rounded : Icons.my_location_rounded, size: 18),
                label: Text(_latitude != null ? 'Titik lokasi tersimpan — perbarui' : 'Gunakan lokasi saya sekarang'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  side: const BorderSide(color: AppColors.purple),
                  foregroundColor: AppColors.purple,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  minimumSize: const Size(double.infinity, 0),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'Titik lokasi dibutuhkan agar kurir instan (Gojek, Grab, dll.) muncul saat cek ongkir. Lakukan saat kamu berada di alamat pengiriman.',
                  style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _isDefault,
                activeThumbColor: AppColors.purple,
                title: const Text(
                  'Jadikan alamat utama',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                onChanged: (v) => setState(() => _isDefault = v),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
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
                label: _submitting ? 'Menyimpan...' : 'Simpan Alamat',
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
