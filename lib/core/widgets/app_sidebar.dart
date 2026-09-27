import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_typography.dart';
import '../routing/app_router.dart';
import '../constants/app_strings.dart';
import '../../models/app_user.dart';

/// الـ Sidebar الرئيسي للنظام — Dark Professional
class AppSidebar extends StatelessWidget {
  const AppSidebar({
    super.key,
    required this.currentRoute,
    required this.onRouteSelected,
    required this.user,
    required this.onLogout,
  });

  final String currentRoute;
  final ValueChanged<String> onRouteSelected;
  final AppUser user;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppDimensions.sidebarWidth,
      height: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.sidebarBg,
        border: Border(
          left: BorderSide(color: AppColors.sidebarDivider, width: 1),
        ),
      ),
      child: Column(
        children: [
          // ─── الشعار / اسم النظام ────────────────────────────────────
          _SidebarHeader(),

          Container(height: 1, color: AppColors.sidebarDivider),

          // ─── القائمة الرئيسية ────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                vertical: AppDimensions.space16,
                horizontal: AppDimensions.space10,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SidebarSection(label: AppStrings.sidebarMainMenu),
                  const SizedBox(height: AppDimensions.space6),
                  ...mainNavItems.map(
                    (item) => _SidebarItem(
                      item: item,
                      isSelected: currentRoute == item.route,
                      onTap: () => onRouteSelected(item.route),
                    ),
                  ),

                  const SizedBox(height: AppDimensions.space20),
                  Container(height: 1, color: AppColors.sidebarDivider),
                  const SizedBox(height: AppDimensions.space16),

                  _SidebarSection(label: AppStrings.sidebarManagement),
                  const SizedBox(height: AppDimensions.space6),
                  ...managementNavItems.map(
                    (item) => _SidebarItem(
                      item: item,
                      isSelected: currentRoute == item.route,
                      onTap: () => onRouteSelected(item.route),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ─── أسفل الـ Sidebar ────────────────────────────────────────
          Container(height: 1, color: AppColors.sidebarDivider),
          _SidebarFooter(user: user, onLogout: onLogout),
        ],
      ),
    );
  }
}

// ─── Sidebar Header ────────────────────────────────────────────────────────
class _SidebarHeader extends StatefulWidget {
  @override
  State<_SidebarHeader> createState() => _SidebarHeaderState();
}

class _SidebarHeaderState extends State<_SidebarHeader> {
  String _restaurantName = AppStrings.appName;

  @override
  void initState() {
    super.initState();
    _loadName();
  }

  Future<void> _loadName() async {
    final name = await DatabaseHelper.instance.getSetting('restaurant_name');
    if (mounted && name != null && name.trim().isNotEmpty) {
      setState(() => _restaurantName = name.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppDimensions.topBarHeight,
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.space16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [AppColors.primary, AppColors.primaryDark],
              ),
              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
              child: Image.asset(
                'assets/images/logo.png',
                fit: BoxFit.cover,
                width: 40,
                height: 40,
              ),
            ),
          ),
          const SizedBox(width: AppDimensions.space12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _restaurantName,
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  AppStrings.roleManager,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Sidebar Section Label ─────────────────────────────────────────────────
class _SidebarSection extends StatelessWidget {
  const _SidebarSection({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        right: AppDimensions.space8,
        bottom: AppDimensions.space4,
      ),
      child: Text(
        label.toUpperCase(),
        style: AppTypography.sidebarSection,
      ),
    );
  }
}

// ─── Sidebar Item ──────────────────────────────────────────────────────────
class _SidebarItem extends StatefulWidget {
  const _SidebarItem({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final NavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final bool isSelected = widget.isSelected;
    final bool isDisabled = !widget.item.isActive;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.space2),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: isDisabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
        child: GestureDetector(
          onTap: isDisabled ? null : widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: AppDimensions.sidebarItemHeight,
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.15)
                  : _isHovered && !isDisabled
                      ? AppColors.surfaceVariant
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(AppDimensions.sidebarItemRadius),
              border: isSelected
                  ? Border.all(color: AppColors.primary.withValues(alpha: 0.35), width: 1)
                  : null,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppDimensions.space12),
              child: Row(
                children: [
                  Icon(
                    isSelected ? widget.item.activeIcon : widget.item.icon,
                    size: AppDimensions.iconMd + 2,
                    color: isSelected
                        ? AppColors.primary
                        : isDisabled
                            ? AppColors.textDisabled
                            : _isHovered
                                ? AppColors.textPrimary
                                : AppColors.sidebarText,
                  ),
                  const SizedBox(width: AppDimensions.space12),

                  Expanded(
                    child: Text(
                      widget.item.label,
                      style: isSelected
                          ? AppTypography.sidebarItemActive.copyWith(color: AppColors.sidebarTextActive)
                          : AppTypography.sidebarItem.copyWith(
                              color: isDisabled
                                  ? AppColors.textDisabled
                                  : _isHovered
                                      ? AppColors.textPrimary
                                      : AppColors.sidebarText,
                            ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  if (isDisabled)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.space6,
                        vertical: AppDimensions.space2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        'قريباً',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textDisabled,
                          fontSize: 10,
                        ),
                      ),
                    ),

                  if (isSelected)
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Sidebar Footer ───────────────────────────────────────────────────────
class _SidebarFooter extends StatefulWidget {
  const _SidebarFooter({required this.user, required this.onLogout});
  final AppUser user;
  final VoidCallback onLogout;

  @override
  State<_SidebarFooter> createState() => _SidebarFooterState();
}

class _SidebarFooterState extends State<_SidebarFooter> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.space16, vertical: 10),
      color: AppColors.sidebarBg,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Icon(
                  Icons.person_rounded,
                  size: AppDimensions.iconMd,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppDimensions.space10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.user.name,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      widget.user.role.label,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          MouseRegion(
            onEnter: (_) => setState(() => _hovered = true),
            onExit: (_) => setState(() => _hovered = false),
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: widget.onLogout,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: _hovered
                      ? AppColors.error.withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _hovered
                        ? AppColors.error.withValues(alpha: 0.4)
                        : AppColors.sidebarDivider,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.logout_rounded,
                      size: 16,
                      color: _hovered ? AppColors.error : AppColors.sidebarText,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'تسجيل الخروج',
                      style: AppTypography.bodySmall.copyWith(
                        color: _hovered ? AppColors.error : AppColors.sidebarText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
