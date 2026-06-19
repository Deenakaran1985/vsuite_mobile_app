import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/instance_provider.dart';
import 'add_instance_screen.dart';

class InstanceManagerScreen extends StatelessWidget {
  const InstanceManagerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InstanceProvider>();
    final instances = provider.instances;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Instances'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Instance',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddInstanceScreen()),
            ),
          ),
        ],
      ),
      body: instances.isEmpty
          ? _empty(context)
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: instances.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (ctx, idx) {
                final inst = instances[idx];
                final isActive = idx == provider.activeIndex;
                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: isActive
                        ? const BorderSide(color: AppColors.accent, width: 2)
                        : BorderSide.none,
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: isActive ? AppColors.accent : AppColors.border,
                      child: Text(
                        inst.label.substring(0, 1).toUpperCase(),
                        style: TextStyle(
                          color: isActive ? Colors.white : AppColors.textMuted,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(inst.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(inst.email, style: const TextStyle(fontSize: 12)),
                        Text(inst.url,   style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isActive)
                          const Chip(
                            label: Text('Active', style: TextStyle(fontSize: 11, color: Colors.white)),
                            backgroundColor: AppColors.accent,
                            padding: EdgeInsets.zero,
                          ),
                        if (!isActive)
                          TextButton(
                            onPressed: () async {
                              await provider.switchTo(idx);
                              if (ctx.mounted) Navigator.pop(ctx);
                            },
                            child: const Text('Switch'),
                          ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => AddInstanceScreen(editing: inst)),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.danger),
                          onPressed: () => _confirmDelete(context, provider, inst.id, inst.label),
                        ),
                      ],
                    ),
                    isThreeLine: true,
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddInstanceScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Add Instance'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  Widget _empty(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.dns_outlined, size: 64, color: AppColors.border),
        const SizedBox(height: 16),
        const Text('No instances configured', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        const SizedBox(height: 8),
        const Text('Add a VSuite server to get started', style: TextStyle(color: AppColors.textMuted)),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddInstanceScreen())),
          icon: const Icon(Icons.add),
          label: const Text('Add Instance'),
        ),
      ],
    ),
  );

  void _confirmDelete(BuildContext ctx, InstanceProvider provider, String id, String label) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Remove Instance'),
        content: Text('Remove "$label"? Saved credentials will be deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await provider.removeInstance(id);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}
