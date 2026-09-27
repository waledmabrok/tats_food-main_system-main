import 'package:flutter/material.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_top_bar.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../models/app_user.dart';
import '../../../../repositories/user_repository.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final _repo = UserRepository();
  List<AppUser> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final users = await _repo.getAll();
    if (mounted) {
      setState(() {
        _users = users;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTopBar(title: AppStrings.usersTitle),
      body: Column(
        children: [
          // شريط الأدوات
          Container(
            padding: const EdgeInsets.all(AppDimensions.space16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(bottom: BorderSide(color: AppColors.divider)),
            ),
            child: Row(
              children: [
                Text(
                  '${_users.length} مستخدم',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () => _showDialog(),
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text(AppStrings.userAddNew),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 40),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _users.isEmpty
                ? EmptyStateWidget(
                    icon: Icons.people_outline_rounded,
                    title: AppStrings.userNoUsers,
                    actionLabel: AppStrings.userAddNew,
                    action: () => _showDialog(),
                  )
                : Padding(
                    padding: const EdgeInsets.all(AppDimensions.space24),
                    child: LayoutBuilder(
                      builder: (ctx, constraints) {
                        final cols = constraints.maxWidth > 900
                            ? 4
                            : constraints.maxWidth > 600
                            ? 3
                            : 2;
                        return GridView.builder(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: cols,
                                crossAxisSpacing: AppDimensions.space16,
                                mainAxisSpacing: AppDimensions.space16,
                                childAspectRatio: 1.8,
                              ),
                          itemCount: _users.length,
                          itemBuilder: (ctx, i) => _UserCard(
                            user: _users[i],
                            onEdit: () => _showDialog(user: _users[i]),
                            onToggle: () => _toggle(_users[i]),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggle(AppUser user) async {
    // منع تعطيل المدير الوحيد أو الأخير (يمكن تحسين هذا لاحقاً)
    if (user.role == UserRole.manager && user.isActive) {
      final activeManagers = _users
          .where((u) => u.role == UserRole.manager && u.isActive)
          .length;
      if (activeManagers <= 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('لا يمكن تعطيل مدير النظام الوحيد!'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
    }

    await _repo.setActive(user.id, !user.isActive);
    _load();
  }

  void _showDialog({AppUser? user}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _UserDialog(
        user: user,
        onSaved: () {
          Navigator.pop(ctx);
          _load();
        },
      ),
    );
  }
}

class _UserCard extends StatefulWidget {
  const _UserCard({
    required this.user,
    required this.onEdit,
    required this.onToggle,
  });
  final AppUser user;
  final VoidCallback onEdit;
  final VoidCallback onToggle;

  @override
  State<_UserCard> createState() => _UserCardState();
}

class _UserCardState extends State<_UserCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final isManager = user.role == UserRole.manager;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(AppDimensions.space16),
        decoration: BoxDecoration(
          color: _hovered ? AppColors.surfaceVariant : AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          border: Border.all(
            color: _hovered
                ? AppColors.primary.withValues(alpha: 0.4)
                : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: isManager
                  ? AppColors.primary.withValues(alpha: 0.1)
                  : AppColors.accent.withValues(alpha: 0.1),
              child: Icon(
                isManager
                    ? Icons.admin_panel_settings_rounded
                    : Icons.person_rounded,
                color: isManager ? AppColors.primary : AppColors.accent,
              ),
            ),
            const SizedBox(width: AppDimensions.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    user.name,
                    style: AppTypography.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '@${user.username}',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          user.role.label,
                          style: AppTypography.caption.copyWith(fontSize: 10),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: user.isActive
                              ? AppColors.success
                              : AppColors.textDisabled,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (_hovered)
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    color: AppColors.info,
                    onPressed: widget.onEdit,
                  ),
                  const SizedBox(height: 12),
                  IconButton(
                    icon: Icon(
                      user.isActive ? Icons.toggle_on : Icons.toggle_off,
                      size: 20,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    color: user.isActive
                        ? AppColors.success
                        : AppColors.textSecondary,
                    onPressed: widget.onToggle,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _UserDialog extends StatefulWidget {
  const _UserDialog({this.user, required this.onSaved});
  final AppUser? user;
  final VoidCallback onSaved;

  @override
  State<_UserDialog> createState() => _UserDialogState();
}

class _UserDialogState extends State<_UserDialog> {
  final _repo = UserRepository();
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _usernameCtrl;
  late final TextEditingController _pinCtrl;
  UserRole _role = UserRole.cashier;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.user?.name ?? '');
    _usernameCtrl = TextEditingController(text: widget.user?.username ?? '');
    _pinCtrl = TextEditingController(text: widget.user?.pin ?? '');
    _role = widget.user?.role ?? UserRole.cashier;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    // التحقق من تكرار اسم المستخدم
    final exists = await _repo.usernameExists(
      _usernameCtrl.text.trim(),
      excludeId: widget.user?.id,
    );
    if (exists) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('اسم المستخدم موجود بالفعل!'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    final now = DateTime.now();
    final user = AppUser(
      id: widget.user?.id ?? DatabaseHelper.generateId(),
      name: _nameCtrl.text.trim(),
      username: _usernameCtrl.text.trim(),
      pin: _pinCtrl.text.trim(),
      role: _role,
      isActive: widget.user?.isActive ?? true,
      createdAt: widget.user?.createdAt ?? now,
    );

    if (widget.user == null) {
      await _repo.insert(user);
    } else {
      await _repo.update(user);
    }
    widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.space24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      widget.user == null
                          ? AppStrings.userAddNew
                          : AppStrings.userEdit,
                      style: AppTypography.headlineSmall,
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                Text(
                  AppStrings.userName,
                  style: AppTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameCtrl,
                  validator: (v) => v!.trim().isEmpty ? 'مطلوب' : null,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusSm,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppStrings.userUsername,
                            style: AppTypography.bodySmall.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _usernameCtrl,
                            validator: (v) =>
                                v!.trim().isEmpty ? 'مطلوب' : null,
                            decoration: InputDecoration(
                              prefixText: '@ ',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  AppDimensions.radiusSm,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppStrings.userPin,
                            style: AppTypography.bodySmall.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _pinCtrl,
                            obscureText: true,
                            keyboardType: TextInputType.number,
                            validator: (v) =>
                                v!.trim().isEmpty ? 'مطلوب' : null,
                            decoration: InputDecoration(
                              hintText: '****',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  AppDimensions.radiusSm,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                Text(
                  AppStrings.userRole,
                  style: AppTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<UserRole>(
                  initialValue: _role,
                  items: UserRole.values
                      .map(
                        (r) => DropdownMenuItem(value: r, child: Text(r.label)),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _role = v!),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusSm,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                ),

                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(AppStrings.btnCancel),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(AppStrings.btnSave),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
