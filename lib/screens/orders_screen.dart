import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/ai_job.dart';
import '../providers/auth_controller.dart';
import '../services/ai_job_service.dart';
import '../services/auth_service.dart' show ApiException;
import '../theme/app_theme.dart';
import 'job_detail_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => OrdersScreenState();
}

class OrdersScreenState extends State<OrdersScreen> {
  String _activeTab = 'Semua';
  static const _tabs = ['Semua', 'Aktif', 'Selesai'];

  bool _loading = true;
  List<AiJobSummary> _jobs = [];
  final Set<String> _syncingIds = {};

  String? _selectedJobId;
  String? _selectedPrompt;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Refetches the job list from the server. Called by [MainShell] whenever
  /// the Pesanan tab becomes visible, since IndexedStack keeps this screen
  /// alive instead of rebuilding it.
  Future<void> reload() => _load();

  Future<void> _load() async {
    final token = context.read<AuthController>().token;
    if (token == null) return;
    setState(() => _loading = true);
    try {
      final jobs = await AiJobService.listMyJobs(token: token);
      if (!mounted) return;
      setState(() {
        _jobs = jobs;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _sync(AiJobSummary job) async {
    final token = context.read<AuthController>().token;
    if (token == null) return;

    setState(() => _syncingIds.add(job.id));
    try {
      await AiJobService.syncJobStatus(token: token, jobId: job.id);
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal memperbarui status. Coba lagi.')),
      );
    } finally {
      if (mounted) setState(() => _syncingIds.remove(job.id));
    }
  }

  List<AiJobSummary> get _filtered {
    switch (_activeTab) {
      case 'Aktif':
        return _jobs.where((j) => !j.status.isJobFinished).toList();
      case 'Selesai':
        return _jobs.where((j) => j.status.toUpperCase() == AiJobStatus.succeeded).toList();
      default:
        return _jobs;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedJobId = _selectedJobId;
    if (selectedJobId != null) {
      return SafeArea(
        bottom: false,
        child: JobDetailView(
          jobId: selectedJobId,
          promptFallback: _selectedPrompt,
          onBack: () => setState(() {
            _selectedJobId = null;
            _selectedPrompt = null;
          }),
        ),
      );
    }

    final filtered = _filtered;
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            const Text(
              'Pesanan Saya',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Lacak status pesanan 3D printing kamu',
              style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                for (final t in _tabs) ...[
                  _OrderTab(
                    label: t,
                    active: _activeTab == t,
                    onTap: () => setState(() => _activeTab = t),
                  ),
                  const SizedBox(width: 10),
                ],
              ],
            ),
            const SizedBox(height: 18),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (filtered.isEmpty)
              const _EmptyState()
            else
              for (final job in filtered) ...[
                _OrderCard(
                  job: job,
                  syncing: _syncingIds.contains(job.id),
                  onSync: () => _sync(job),
                  onTap: () => setState(() {
                    _selectedJobId = job.id;
                    _selectedPrompt = job.prompt;
                  }),
                ),
                if (job != filtered.last) const SizedBox(height: 12),
              ],
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Column(
        children: [
          Icon(Icons.inbox_outlined, size: 44, color: AppColors.textFaint),
          const SizedBox(height: 12),
          const Text(
            'Belum ada pesanan',
            style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          const Text(
            'Buat desain 3D pertamamu di menu Buat',
            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _OrderTab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _OrderTab({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            gradient: active ? AppColors.brandGradient : null,
            color: active ? null : AppColors.surface,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: active ? Colors.transparent : AppColors.border),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: active ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final AiJobSummary job;
  final bool syncing;
  final VoidCallback onSync;
  final VoidCallback onTap;

  const _OrderCard({
    required this.job,
    required this.syncing,
    required this.onSync,
    required this.onTap,
  });

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
    ];
    return '${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final status = job.status;
    final finished = status.isJobFinished;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'ID-${job.id.substring(0, job.id.length < 8 ? job.id.length : 8).toUpperCase()}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textFaint,
                    ),
                  ),
                  Row(
                    children: [
                      _StatusBadge(status: status),
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 30,
                        height: 30,
                        child: syncing
                            ? const Padding(
                                padding: EdgeInsets.all(6),
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : IconButton(
                                padding: EdgeInsets.zero,
                                iconSize: 18,
                                tooltip: 'Cek status',
                                icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
                                onPressed: onSync,
                              ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: job.previewUrl != null
                        ? Image.network(
                            job.previewUrl!,
                            width: 46,
                            height: 46,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const _ThumbFallback(),
                          )
                        : const _ThumbFallback(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          job.prompt,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _formatDate(job.createdAt),
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (!finished) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: job.progress != null ? job.progress! / 100 : null,
                    minHeight: 7,
                    backgroundColor: AppColors.surfaceMuted,
                    valueColor: AlwaysStoppedAnimation(status.statusColor),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  job.progress != null ? '${job.progress}% selesai' : 'Menunggu update...',
                  style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ThumbFallback extends StatelessWidget {
  const _ThumbFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: const BoxDecoration(gradient: AppColors.brandGradientSoft),
      child: ShaderMask(
        shaderCallback: (rect) => AppColors.brandGradient.createShader(rect),
        child: const Icon(Icons.view_in_ar_rounded, color: Colors.white, size: 22),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = status.statusColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.statusIcon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            status.statusLabel,
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}
