import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mechanix_browser/core/utils/app_theme.dart';
import 'package:mechanix_browser/features/browser/bloc/permission/permission_bloc.dart';
import 'package:mechanix_browser/features/browser/bloc/permission/site_permission_kind.dart';
import 'package:mechanix_browser/features/browser/data/models/site_permission.dart';
import 'package:mechanix_browser/features/browser/presentation/widgets/permission/site_permission_labels.dart';
import 'package:mechanix_browser/l10n/app_localizations.dart';

/// Lists remembered per-site decisions; each can be flipped or reset.
class SitePermissionsScreen extends StatefulWidget {
  const SitePermissionsScreen({super.key});

  @override
  State<SitePermissionsScreen> createState() => _SitePermissionsScreenState();
}

class _SitePermissionsScreenState extends State<SitePermissionsScreen> {
  @override
  void initState() {
    super.initState();
    context.read<PermissionBloc>().add(const SitePermissionsLoadRequested());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColorsExtension>()!;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(l10n.sitePermissions),
      ),
      body: BlocBuilder<PermissionBloc, PermissionState>(
        buildWhen: (a, b) => a.sitePermissions != b.sitePermissions,
        builder: (context, state) {
          final byOrigin = <String, List<SitePermission>>{};
          for (final entry in state.sitePermissions) {
            byOrigin.putIfAbsent(entry.origin, () => []).add(entry);
          }

          if (byOrigin.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.admin_panel_settings_outlined,
                      size: 48,
                      color: colors.textSecondary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.sitePermissionsEmpty,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.sitePermissionsEmptyHint,
                      style: theme.textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          final origins = byOrigin.keys.toList();
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: origins.length,
            separatorBuilder: (_, _) =>
                Divider(height: 1, color: colors.dividerColor),
            itemBuilder: (context, index) => _OriginSection(
              origin: origins[index],
              entries: byOrigin[origins[index]]!,
            ),
          );
        },
      ),
    );
  }
}

class _OriginSection extends StatelessWidget {
  final String origin;
  final List<SitePermission> entries;

  const _OriginSection({required this.origin, required this.entries});

  Future<void> _confirmReset(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final bloc = context.read<PermissionBloc>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.sitePermissionResetSite),
        content: Text(
          l10n.sitePermissionResetSiteConfirm(displayHostForOrigin(origin)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.reset),
          ),
        ],
      ),
    );
    if (confirmed == true) bloc.add(SitePermissionReset(origin));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColorsExtension>()!;
    final l10n = AppLocalizations.of(context)!;
    final bloc = context.read<PermissionBloc>();

    final kinds = <SitePermissionKind, bool>{};
    for (final entry in entries) {
      final kind = SitePermissionKind.values
          .where((k) => k.name == entry.kind)
          .firstOrNull;
      if (kind != null) kinds[kind] = entry.allowed;
    }
    final ordered = SitePermissionKind.values.where(kinds.containsKey);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 4, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  displayHostForOrigin(origin),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: l10n.sitePermissionResetSite,
                icon: Icon(Icons.restart_alt, color: colors.textSecondary),
                onPressed: () => _confirmReset(context),
              ),
            ],
          ),
        ),
        for (final kind in ordered)
          SwitchListTile(
            secondary: Icon(kind.icon, color: colors.textSecondary),
            title: Text(kind.label(l10n)),
            subtitle: Text(
              kinds[kind]!
                  ? l10n.sitePermissionAllowed
                  : l10n.sitePermissionBlocked,
            ),
            value: kinds[kind]!,
            onChanged: (allowed) => bloc.add(
              SitePermissionChanged(
                origin: origin,
                kind: kind,
                allowed: allowed,
              ),
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }
}
