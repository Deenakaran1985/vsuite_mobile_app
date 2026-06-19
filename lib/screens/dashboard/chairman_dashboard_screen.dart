import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/document_model.dart';
import '../../core/models/vsuite_instance.dart';
import '../../core/providers/document_provider.dart';
import '../../core/providers/instance_provider.dart';
import '../document/document_detail_screen.dart';
import '../instances/instance_manager_screen.dart';

class ChairmanDashboardScreen extends StatefulWidget {
  const ChairmanDashboardScreen({super.key});

  @override
  State<ChairmanDashboardScreen> createState() => _ChairmanDashboardScreenState();
}

class _ChairmanDashboardScreenState extends State<ChairmanDashboardScreen>
    with SingleTickerProviderStateMixin {
  TabController? _tabs;
  final Map<String, bool> _loaded = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initTabs());
  }

  void _initTabs() {
    final instances = context.read<InstanceProvider>().instances;
    if (instances.isEmpty) return;
    setState(() {
      _tabs = TabController(length: instances.length, vsync: this);
      _tabs!.addListener(() {
        if (!_tabs!.indexIsChanging) _loadTab(_tabs!.index);
      });
    });
    _loadTab(0);
  }

  Future<void> _loadTab(int idx) async {
    final instProvider = context.read<InstanceProvider>();
    final docProvider  = context.read<DocumentProvider>();
    final instance     = instProvider.instances[idx];

    if (_loaded[instance.id] == true) return;

    final token = await instProvider.getToken(instance);
    if (token == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Auth failed for ${instance.label}'), backgroundColor: AppColors.danger),
        );
      }
      return;
    }
    await docProvider.loadForInstance(instance, token);
    _loaded[instance.id] = true;
  }

  Future<void> _refresh(VsuiteInstance instance) async {
    _loaded.remove(instance.id);
    final instProvider = context.read<InstanceProvider>();
    final docProvider  = context.read<DocumentProvider>();
    final token = await instProvider.getToken(instance);
    if (token == null) return;
    await docProvider.loadForInstance(instance, token);
    _loaded[instance.id] = true;
  }

  @override
  void dispose() {
    _tabs?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final instProvider = context.watch<InstanceProvider>();
    final instances    = instProvider.instances;

    if (instances.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('VSuite')),
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.dns_outlined, size: 64, color: AppColors.border),
            const SizedBox(height: 16),
            const Text('No VSuite instances configured'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InstanceManagerScreen())),
              child: const Text('Add Instance'),
            ),
          ]),
        ),
      );
    }

    if (_tabs == null || _tabs!.length != instances.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _initTabs());
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [AppColors.primaryDark, AppColors.primary]),
          ),
        ),
        title: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.asset('assets/images/logo1.jpg', width: 28, height: 28, fit: BoxFit.cover),
          ),
          const SizedBox(width: 10),
          const Text('VSuite Dashboard', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.manage_accounts_outlined),
            tooltip: 'Manage Instances',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InstanceManagerScreen())),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (v) {
              if (v == 'refresh') {
                final idx = _tabs?.index ?? 0;
                _loaded.remove(instances[idx].id);
                _loadTab(idx);
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'refresh', child: ListTile(leading: Icon(Icons.refresh), title: Text('Refresh'))),
            ],
          ),
        ],
        bottom: _tabs == null
            ? null
            : TabBar(
                controller: _tabs,
                isScrollable: true,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white54,
                tabs: instances.map((i) {
                  final ds = context.watch<DocumentProvider>().stateFor(i);
                  return Tab(
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(i.label, style: const TextStyle(fontSize: 13)),
                      if (ds != null && ds.pendingCount > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(color: AppColors.warning, borderRadius: BorderRadius.circular(10)),
                          child: Text('${ds.pendingCount}', style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ]),
                  );
                }).toList(),
              ),
      ),
      body: _tabs == null
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabs,
              children: instances.map((inst) => _InstanceTab(
                instance: inst,
                onRefresh: () => _refresh(inst),
              )).toList(),
            ),
    );
  }
}

// ── Per-instance tab ─────────────────────────────────────────────────────────

class _InstanceTab extends StatelessWidget {
  final VsuiteInstance instance;
  final VoidCallback   onRefresh;
  const _InstanceTab({required this.instance, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final ds = context.watch<DocumentProvider>().stateFor(instance);

    if (ds == null || ds.state == DocLoadState.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (ds.state == DocLoadState.error) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline, color: AppColors.danger, size: 48),
          const SizedBox(height: 12),
          Text(ds.errorMsg ?? 'Failed to load', textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton.icon(onPressed: onRefresh, icon: const Icon(Icons.refresh), label: const Text('Retry')),
        ]),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: CustomScrollView(slivers: [
        // Stat cards
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Expanded(child: _StatCard('Pending', ds.pendingCount, AppColors.warning, Icons.hourglass_empty)),
                const SizedBox(width: 12),
                Expanded(child: _StatCard('Approved', ds.approvedCount, AppColors.success, Icons.check_circle_outline)),
                const SizedBox(width: 12),
                Expanded(child: _StatCard('Completed', ds.completedCount, AppColors.info, Icons.flag_outlined)),
              ]),
              const SizedBox(height: 20),
              const Text('Pending Approvals', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textDark)),
            ]),
          ),
        ),
        // Pending list
        ds.pending.isEmpty
            ? SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.inbox_outlined, size: 56, color: AppColors.border),
                    const SizedBox(height: 12),
                    const Text('No pending approvals', style: TextStyle(color: AppColors.textMuted)),
                  ]),
                ),
              )
            : SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _DocTile(doc: ds.pending[i], instance: instance),
                  childCount: ds.pending.length,
                ),
              ),
        // Recent completed header
        if (ds.completed.isNotEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Text('Recent Completed', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textDark)),
            ),
          ),
        if (ds.completed.isNotEmpty)
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) => _DocTile(doc: ds.completed[i], instance: instance, isCompleted: true),
              childCount: ds.completed.take(10).length,
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ]),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int    value;
  final Color  color;
  final IconData icon;
  const _StatCard(this.label, this.value, this.color, this.icon);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 3))],
    ),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: color, size: 22),
      const SizedBox(height: 6),
      Text('$value', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: color)),
      Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
    ]),
  );
}

class _DocTile extends StatelessWidget {
  final DocumentModel  doc;
  final VsuiteInstance instance;
  final bool           isCompleted;
  const _DocTile({required this.doc, required this.instance, this.isCompleted = false});

  @override
  Widget build(BuildContext context) {
    final urgent = doc.daysPending >= 7;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: urgent ? const Color(0xFFFFF9F0) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: urgent ? AppColors.warning.withValues(alpha: 0.4) : AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(color: const Color(0xFFE8F4FD), borderRadius: BorderRadius.circular(6)),
            child: Text(doc.docId ?? '—', style: const TextStyle(fontSize: 11, color: AppColors.info, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(doc.title ?? '—', maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textDark)),
          ),
        ]),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(children: [
            _chip(doc.from ?? '—', AppColors.border, AppColors.textMuted),
            const SizedBox(width: 6),
            _chip(doc.priority ?? 'Normal', _priorityColor(doc.priority), Colors.white),
            const SizedBox(width: 6),
            if (!isCompleted)
              _chip('${doc.daysPending}d', urgent ? AppColors.danger : AppColors.success, Colors.white),
            if (isCompleted && doc.status != null)
              _chip(doc.status!, AppColors.success.withValues(alpha: 0.15), AppColors.success),
          ]),
        ),
        trailing: isCompleted
            ? doc.sanctionedAmount != null
                ? Text('₹${_fmt(doc.sanctionedAmount!)}', style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w700, fontSize: 12))
                : null
            : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('${doc.approvalProgressPct}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.accent)),
                const SizedBox(height: 4),
                SizedBox(
                  width: 40,
                  child: LinearProgressIndicator(
                    value: doc.approvalProgressPct / 100,
                    backgroundColor: AppColors.border,
                    color: AppColors.accent,
                  ),
                ),
              ]),
        onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => DocumentDetailScreen(doc: doc, instance: instance),
        )),
      ),
    );
  }

  Color _priorityColor(String? p) {
    switch ((p ?? '').toLowerCase()) {
      case 'high': case 'urgent': return AppColors.danger;
      case 'medium': case 'normal': return AppColors.warning;
      default: return AppColors.success;
    }
  }

  Widget _chip(String label, Color bg, Color fg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
    child: Text(label, style: TextStyle(fontSize: 10, color: fg, fontWeight: FontWeight.w600)),
  );

  String _fmt(double v) => NumberFormat('#,##,###').format(v);
}
