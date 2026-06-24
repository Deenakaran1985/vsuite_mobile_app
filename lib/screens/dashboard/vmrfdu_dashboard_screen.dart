import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/vsuite_instance.dart';
import '../../core/providers/instance_provider.dart';
import '../../core/providers/vmrfdu_provider.dart';
import '../instances/add_instance_screen.dart';
import '../auth/instance_login_screen.dart';

class VmrfduDashboardScreen extends StatefulWidget {
  const VmrfduDashboardScreen({super.key});

  @override
  State<VmrfduDashboardScreen> createState() => _VmrfduDashboardScreenState();
}

class _VmrfduDashboardScreenState extends State<VmrfduDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  List<Map<String, dynamic>> _myTickets      = [];
  List<Map<String, dynamic>> _receivedTickets = [];
  List<Map<String, dynamic>> _inwardPostal   = [];
  List<Map<String, dynamic>> _outwardPostal  = [];

  bool _loadingTickets = false;
  bool _loadingPostal  = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) {
        if (_tabs.index == 1) _loadPostal();
      }
    });
    _loadTickets();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  String get _token => context.read<VmrfduProvider>().token ?? '';
  static const _hub = VmrfduProvider.hubUrl;

  Future<void> _loadTickets() async {
    if (_loadingTickets) return;
    setState(() => _loadingTickets = true);
    final api = context.read<InstanceProvider>().api;
    final my  = await api.fetchTickets(serverUrl: _hub, token: _token, tab: 'my');
    final rec = await api.fetchTickets(serverUrl: _hub, token: _token, tab: 'received');
    if (mounted) setState(() { _myTickets = my; _receivedTickets = rec; _loadingTickets = false; });
  }

  Future<void> _loadPostal() async {
    if (_loadingPostal || (_inwardPostal.isNotEmpty || _outwardPostal.isNotEmpty)) return;
    setState(() => _loadingPostal = true);
    final api = context.read<InstanceProvider>().api;
    final inw = await api.fetchPostals(serverUrl: _hub, token: _token, type: 'Inward');
    final out = await api.fetchPostals(serverUrl: _hub, token: _token, type: 'Outward');
    if (mounted) setState(() { _inwardPostal = inw; _outwardPostal = out; _loadingPostal = false; });
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Logout from VMRFDU V-Suite?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      final nav = Navigator.of(context);
      await context.read<VmrfduProvider>().logout();
      nav.pushReplacementNamed('/select-app');
    }
  }

  @override
  Widget build(BuildContext context) {
    final vmrfdu    = context.watch<VmrfduProvider>();
    final user      = vmrfdu.user;
    final instances = vmrfdu.instances;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset('assets/images/vmrfdu.jpg', width: 28, height: 28, fit: BoxFit.cover),
            ),
            const SizedBox(width: 10),
            const Text('VMRFDU V-Suite'),
          ],
        ),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(icon: Icon(Icons.confirmation_num_outlined), text: 'Tickets'),
            Tab(icon: Icon(Icons.mail_outline),              text: 'Postal'),
            Tab(icon: Icon(Icons.dns_outlined),              text: 'Instances'),
          ],
        ),
        actions: [
          if (user != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Center(
                child: Text(
                  user['name'] as String? ?? '',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
          IconButton(icon: const Icon(Icons.logout), tooltip: 'Logout', onPressed: _logout),
        ],
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _ticketsTab(),
          _postalTab(),
          _instancesTab(instances),
        ],
      ),
    );
  }

  // ── Tickets tab ───────────────────────────────────────────────────────────

  Widget _ticketsTab() {
    if (_loadingTickets) return const Center(child: CircularProgressIndicator());
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [Tab(text: 'My Tickets'), Tab(text: 'Received')],
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textMuted,
            indicatorColor: AppColors.primary,
          ),
          Expanded(
            child: TabBarView(
              children: [
                _ticketList(_myTickets, emptyMsg: 'No tickets raised by you'),
                _ticketList(_receivedTickets, emptyMsg: 'No tickets received'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _ticketList(List<Map<String, dynamic>> tickets, {required String emptyMsg}) {
    if (tickets.isEmpty) return _empty(emptyMsg, Icons.confirmation_num_outlined);
    return RefreshIndicator(
      onRefresh: _loadTickets,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: tickets.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final t = tickets[i];
          final status = t['status'] as String? ?? '';
          return Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: _statusColor(status).withValues(alpha: 0.15),
                child: Icon(_statusIcon(status), color: _statusColor(status), size: 20),
              ),
              title: Text(t['title'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${t['ticket_from'] ?? ''} → ${t['ticket_to'] ?? ''}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  Text(t['ticket_id'] as String? ?? '', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                ],
              ),
              trailing: _statusChip(status),
              isThreeLine: true,
            ),
          );
        },
      ),
    );
  }

  // ── Postal tab ────────────────────────────────────────────────────────────

  Widget _postalTab() {
    if (_loadingPostal) return const Center(child: CircularProgressIndicator());
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [Tab(text: 'Inward'), Tab(text: 'Outward')],
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textMuted,
            indicatorColor: AppColors.primary,
          ),
          Expanded(
            child: TabBarView(
              children: [
                _postalList(_inwardPostal, emptyMsg: 'No inward postal'),
                _postalList(_outwardPostal, emptyMsg: 'No outward postal'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _postalList(List<Map<String, dynamic>> items, {required String emptyMsg}) {
    if (items.isEmpty) return _empty(emptyMsg, Icons.mail_outline);
    return RefreshIndicator(
      onRefresh: _loadPostal,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final p = items[i];
          final isRead = p['is_read'] as bool? ?? false;
          return Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: isRead
                    ? Colors.grey.withValues(alpha: 0.15)
                    : AppColors.primary.withValues(alpha: 0.15),
                child: Icon(
                  Icons.mail_outline,
                  color: isRead ? Colors.grey : AppColors.primary,
                  size: 20,
                ),
              ),
              title: Text(
                p['subject'] as String? ?? '(No subject)',
                style: TextStyle(
                  fontWeight: isRead ? FontWeight.normal : FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p['post_id'] as String? ?? '', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  if ((p['tracking_id'] as String?)?.isNotEmpty == true)
                    Text('Track: ${p['tracking_id']}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                ],
              ),
              trailing: p['category'] != null
                  ? Chip(
                      label: Text(p['category'] as String, style: const TextStyle(fontSize: 10)),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    )
                  : null,
              isThreeLine: true,
            ),
          );
        },
      ),
    );
  }

  // ── Instances tab ─────────────────────────────────────────────────────────

  Widget _instancesTab(List<VsuiteInstance> instances) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: AppColors.primary.withValues(alpha: 0.07),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: const Text(
            'Connect to a V-Suite instance for document approvals',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ),
        if (instances.isEmpty)
          Expanded(child: _empty('No V-Suite instances available.\nContact your administrator.', Icons.dns_outlined))
        else
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: instances.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final inst = instances[i];
                return Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    leading: CircleAvatar(
                      backgroundColor: AppColors.accent.withValues(alpha: 0.15),
                      child: const Icon(Icons.dns_outlined, color: AppColors.accent),
                    ),
                    title: Text(inst.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(inst.url, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                    trailing: ElevatedButton(
                      onPressed: () => _openInstance(inst),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Open', style: TextStyle(fontSize: 13)),
                    ),
                  ),
                );
              },
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: OutlinedButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddInstanceScreen())),
            icon: const Icon(Icons.add),
            label: const Text('Add Instance Manually'),
          ),
        ),
      ],
    );
  }

  void _openInstance(VsuiteInstance inst) {
    // Save instance to InstanceProvider and navigate to instance login
    final provider = context.read<InstanceProvider>();
    final existing = provider.instances.where((e) => e.url == inst.url).toList();
    if (existing.isEmpty) {
      provider.addInstance(inst, '');
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InstanceLoginScreen(instance: inst),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _empty(String msg, IconData icon) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 56, color: AppColors.border),
        const SizedBox(height: 12),
        Text(msg, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted)),
      ],
    ),
  );

  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'open':        return Colors.blue;
      case 'in progress': return Colors.orange;
      case 'completed':   return Colors.green;
      case 'closed':      return Colors.grey;
      case 'hold':        return Colors.purple;
      default:            return AppColors.textMuted;
    }
  }

  IconData _statusIcon(String s) {
    switch (s.toLowerCase()) {
      case 'open':        return Icons.radio_button_unchecked;
      case 'in progress': return Icons.pending_outlined;
      case 'completed':   return Icons.check_circle_outline;
      case 'closed':      return Icons.cancel_outlined;
      case 'hold':        return Icons.pause_circle_outline;
      default:            return Icons.help_outline;
    }
  }

  Widget _statusChip(String status) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: _statusColor(status).withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      status,
      style: TextStyle(fontSize: 11, color: _statusColor(status), fontWeight: FontWeight.w600),
    ),
  );
}
