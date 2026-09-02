import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/ai_job.dart';
import '../models/physical_order.dart';
import '../providers/auth_controller.dart';
import '../services/ai_job_service.dart';
import '../services/auth_service.dart' show ApiException;
import '../services/order_service.dart';
import '../theme/app_theme.dart';
import 'job_detail_screen.dart';
import 'orders/order_detail_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => OrdersScreenState();
}

class OrdersScreenState extends State<OrdersScreen> {
  // 'ai' = AI-generation job history (existing), 'physical' = real 3D-print
  // orders placed with a merchant (new). Kept as two sub-tabs of the same
  // bottom-nav "Pesanan" slot rather than a separate nav item.
  String _mainTab = 'ai';

  String _activeTab = 'Semua';
  static const _tabs = ['Semua', 'Aktif', 'Selesai'];

  bool _loading = true;
  List<AiJobSummary> _jobs = [];
  final Set<String> _syncingIds = {};

  String? _selectedJobId;
  String? _selectedPrompt;

  bool _ordersLoading = true;
  bool _ordersLoadedOnce = false;
  List<PhysicalOrder> _physicalOrders = [];
  String? _selectedOrderId;

  // Polls Meshy for progress on any still-processing job so the list updates
  // on its own — no more manually tapping refresh. Only ever scheduled while
  // at least one job is unfinished, and stops itself once everything's done.
  Timer? _pollTimer;
  static const _pollInterval = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  /// Refetches the job list from the server. Called by [MainShell] whenever
  /// the Pesanan tab becomes visible, since IndexedStack keeps this screen
  /// alive instead of rebuilding it.
  Future<void> reload() {
    if (_mainTab == 'physical') return _loadOrders();
    return _load();
  }

  Future<void> _loadOrders() async {
    final token = context.read<AuthController>().token;
    if (token == null) return;
    setState(() => _ordersLoading = true);
    try {
      final orders = await OrderService.listMine(token: token);
      if (!mounted) return;
      setState(() => _physicalOrders = orders);
    } catch (_) {
      // Best-effort — keep whatever list was already showing.
    } finally {
      if (mounted) setState(() => _ordersLoading = false);
      _ordersLoadedOnce = true;
    }
  }

  void _selectMainTab(String tab) {
    setState(() => _mainTab = tab);
    if (tab == 'physical' && !_ordersLoadedOnce) _loadOrders();
  }

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
    } finally {
      _scheduleNextPoll();
    }
  }

  /// Same as [_load] but without the full-screen loading spinner — used for
  /// background polling so the list doesn't flicker every few seconds.
  Future<void> _loadQuiet() async {
    final token = context.read<AuthController>().token;
    if (token == null) return;
    try {
      final jobs = await AiJobService.listMyJobs(token: token);
      if (!mounted) return;
      setState(() => _jobs = jobs);
    } catch (_) {
      // Best-effort — keep the previous list and try again next tick.
    }
  }

  void _scheduleNextPoll() {
    _pollTimer?.cancel();
    if (!_jobs.any((j) => !j.status.isJobFinished)) return;
    _pollTimer = Timer(_pollInterval, _pollActiveJobs);
  }

  Future<void> _pollActiveJobs() async {
    final token = context.read<AuthController>().token;
    if (token == null) return;
    final activeJobIds = _jobs.where((j) => !j.status.isJobFinished).map((j) => j.id).toList();
    for (final jobId in activeJobIds) {
      try {
        await AiJobService.syncJobStatus(token: token, jobId: jobId);
      } catch (_) {
        // Best-effort — a stale status for one job shouldn't stop the rest.
      }
    }
    if (!mounted) return;
    await _loadQuiet();
    _scheduleNextPoll();
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
    if (_mainTab == 'ai' && selectedJobId != null) {
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

    final selectedOrderId = _selectedOrderId;
    if (_mainTab == 'physical' && selectedOrderId != null) {
      return SafeArea(
        bottom: false,
        child: OrderDetailView(
          orderId: selectedOrderId,
          onBack: () => setState(() => _selectedOrderId = null),
        ),
      );
    }

    final filtered = _filtered;
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: reload,
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
              'Lacak desain AI dan pesanan cetak 3D kamu',
              style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _MainTab(label: 'Desain AI', active: _mainTab == 'ai', onTap: () => _selectMainTab('ai')),
                const SizedBox(width: 10),
                _MainTab(label: 'Pesanan Fisik', active: _mainTab == 'physical', onTap: () => _selectMainTab('physical')),
              ],
            ),
            const SizedBox(height: 18),
            if (_mainTab == 'ai') ...[
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
            ] else ...[
              if (_ordersLoading)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_physicalOrders.isEmpty)
                const _PhysicalEmptyState()
              else
                for (final order in _physicalOrders) ...[
                  _PhysicalOrderCard(
                    order: order,
                    onTap: () => setState(() => _selectedOrderId = order.id),
                  ),
                  if (order != _physicalOrders.last) const SizedBox(height: 12),
                ],
            ],
          ],
        ),
      ),
    );
  }
}

class _MainTab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _MainTab({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 11),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: active ? AppColors.brandGradient : null,
              color: active ? null : AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: active ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PhysicalEmptyState extends StatelessWidget {
  const _PhysicalEmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Column(
        children: [
          Icon(Icons.local_shipping_outlined, size: 44, color: AppColors.textFaint),
          const SizedBox(height: 12),
          const Text(
            'Belum ada pesanan fisik',
            style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          const Text(
            'Pilih penjual dari desain 3D kamu untuk mulai memesan',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _PhysicalOrderCard extends StatelessWidget {
  final PhysicalOrder order;
  final VoidCallback onTap;

  const _PhysicalOrderCard({required this.order, required this.onTap});

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    return '${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1]} ${dt.year}';
  }

  String _rupiah(int v) {
    final s = v.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final posFromEnd = s.length - i;
      buf.write(s[i]);
      if (posFromEnd > 1 && posFromEnd % 3 == 1) buf.write('.');
    }
    return 'Rp $buf';
  }

  @override
  Widget build(BuildContext context) {
    final status = order.status;
    final previewUrl = order.primaryItem?.aiModel?.previewUrl;
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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: previewUrl != null
                    ? Image.network(
                        previewUrl,
                        width: 46,
                        height: 46,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const _PhysicalThumbFallback(),
                      )
                    : const _PhysicalThumbFallback(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            order.orderNumber ?? 'Pesanan',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                          ),
                        ),
                        if (status != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.purple.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              status.name,
                              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.purple),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(_formatDate(order.createdAt), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(height: 4),
                    Text(
                      order.isPriced ? _rupiah(order.totalAmount!) : 'Menunggu konfirmasi harga',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: order.isPriced ? AppColors.textPrimary : AppColors.orange,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhysicalThumbFallback extends StatelessWidget {
  const _PhysicalThumbFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: const BoxDecoration(gradient: AppColors.brandGradientSoft),
      child: ShaderMask(
        shaderCallback: (rect) => AppColors.brandGradient.createShader(rect),
        child: const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 22),
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
