import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design_system/components/portal_async_state.dart';
import '../../design_system/components/portal_info_row.dart';
import '../../design_system/components/portal_scaffold.dart';
import '../../design_system/foundations/portal_spacing.dart';
import '../auth/auth_providers.dart';
import 'profile_model.dart';
import 'profile_providers.dart';
import 'widgets/profile_identity_header.dart';
import 'widgets/profile_info_section.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(detailedProfileProvider);

    return PortalScaffold(
      appBar: AppBar(
        title: const Text('Hồ sơ cá nhân'),
        actions: [
          IconButton(
            tooltip: 'Làm mới hồ sơ',
            onPressed: () => ref.invalidate(detailedProfileProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: profileAsync.when(
        data: (profile) {
          if (profile == null) {
            return const _ProfileFallback(
              child: PortalAsyncState.empty(
                title: 'Chưa có thông tin sinh viên',
                message:
                    'Hồ sơ sẽ xuất hiện khi hệ thống UIT cung cấp dữ liệu.',
              ),
            );
          }
          return _ProfileContent(profile: profile);
        },
        loading: () =>
            const _ProfileFallback(child: PortalAsyncState.loading()),
        error: (error, stack) => _ProfileFallback(
          child: PortalAsyncState.error(
            title: 'Không thể tải hồ sơ',
            message: 'Vui lòng kiểm tra kết nối và thử lại.',
            onRetry: () => ref.invalidate(detailedProfileProvider),
          ),
        ),
      ),
    );
  }
}

class _ProfileContent extends ConsumerWidget {
  const _ProfileContent({required this.profile});

  final StudentProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(PortalSpacing.md),
      children: [
        ProfileIdentityHeader(profile: profile),
        const SizedBox(height: PortalSpacing.md),
        ProfileInfoSection(
          title: 'Thông tin cá nhân',
          icon: Icons.person_outline,
          children: _personalRows(profile.personal),
        ),
        const SizedBox(height: PortalSpacing.sm),
        ProfileInfoSection(
          title: 'Học tập',
          icon: Icons.school_outlined,
          initiallyExpanded: true,
          children: [
            _row('Ngành học', profile.academic?.major),
            _row('Lớp sinh hoạt', profile.academic?.className),
            _row('Khóa', profile.academic?.cohort),
          ],
        ),
        const SizedBox(height: PortalSpacing.sm),
        ProfileInfoSection(
          title: 'Thông tin gia đình',
          icon: Icons.family_restroom_outlined,
          children: _familyRows(profile.family),
        ),
        const SizedBox(height: PortalSpacing.sm),
        ProfileInfoSection(
          title: 'Đoàn, Đảng và thành tích',
          icon: Icons.groups_outlined,
          children: _membershipRows(profile.membership),
        ),
        const SizedBox(height: PortalSpacing.sm),
        ProfileInfoSection(
          title: 'Thông tin ngân hàng',
          icon: Icons.account_balance_outlined,
          children: _bankRows(profile.bank),
        ),
        const SizedBox(height: PortalSpacing.lg),
        const _SignOutButton(),
        const SizedBox(height: PortalSpacing.lg),
      ],
    );
  }

  List<Widget> _personalRows(PersonalInfo? info) {
    return [
      _row('Ngày sinh', info?.dateOfBirth),
      _row('Giới tính', _gender(info?.gender)),
      _row('Email trường', info?.schoolEmail),
      _row('Email cá nhân', info?.personalEmail),
      _row('Số điện thoại', info?.phone),
      _row('Hộ khẩu', info?.permanentAddress),
      _row('Nơi ở hiện tại', info?.currentAddress),
      PortalInfoRow(
        label: 'CMND/CCCD',
        value: _SensitiveValue(value: _value(info?.idCardNumber)),
      ),
    ];
  }

  List<Widget> _familyRows(FamilyInfo? family) {
    return [
      _row('Họ tên cha', family?.father?.fullName),
      _row('Nghề nghiệp của cha', family?.father?.occupation),
      _row('Số điện thoại của cha', family?.father?.phone),
      _row('Họ tên mẹ', family?.mother?.fullName),
      _row('Nghề nghiệp của mẹ', family?.mother?.occupation),
      _row('Số điện thoại của mẹ', family?.mother?.phone),
    ];
  }

  List<Widget> _membershipRows(MembershipInfo? membership) {
    return [
      _row(
        'Đoàn viên',
        membership?.memberStatus == null
            ? null
            : membership!.memberStatus!
            ? 'Đã kết nạp'
            : 'Chưa kết nạp',
      ),
      _row('Ngày kết nạp Đoàn', membership?.memberDate),
      _row(
        'Đảng viên',
        membership?.partyMemberStatus == null
            ? null
            : membership!.partyMemberStatus!
            ? 'Đã kết nạp'
            : 'Chưa kết nạp',
      ),
      _row('Chức vụ cao nhất', membership?.highestPosition),
      _row('Thành tích và khen thưởng', membership?.achievementsAndAwards),
    ];
  }

  List<Widget> _bankRows(BankInfo? bank) {
    return [
      _row('Ngân hàng', bank?.bankName),
      PortalInfoRow(
        label: 'Số tài khoản',
        value: _SensitiveValue(value: _value(bank?.accountNumber)),
      ),
      _row('Chi nhánh', bank?.branch),
    ];
  }

  PortalInfoRow _row(String label, String? value) {
    return PortalInfoRow(label: label, value: Text(_value(value)));
  }

  String _value(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty
        ? 'Chưa cập nhật'
        : normalized;
  }

  String? _gender(String? value) {
    return switch (value?.trim().toLowerCase()) {
      'male' => 'Nam',
      'female' => 'Nữ',
      final value? when value.isNotEmpty => value,
      _ => null,
    };
  }
}

class _ProfileFallback extends StatelessWidget {
  const _ProfileFallback({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: child),
        const Padding(
          padding: EdgeInsets.fromLTRB(
            PortalSpacing.md,
            PortalSpacing.xs,
            PortalSpacing.md,
            PortalSpacing.md,
          ),
          child: SizedBox(width: double.infinity, child: _SignOutButton()),
        ),
      ],
    );
  }
}

class _SignOutButton extends ConsumerWidget {
  const _SignOutButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return OutlinedButton.icon(
      onPressed: () => _confirmSignOut(context, ref),
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.error,
        side: BorderSide(color: scheme.error),
      ),
      icon: const Icon(Icons.logout),
      label: const Text('Đăng xuất'),
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final scheme = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          title: const Text('Xác nhận đăng xuất'),
          content: const Text(
            'Bạn sẽ cần đăng nhập lại để sử dụng dữ liệu từ UIT Portal.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: scheme.error,
                foregroundColor: scheme.onError,
              ),
              child: const Text('Đăng xuất'),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      await ref.read(authControllerProvider).signOut();
    }
  }
}

class _SensitiveValue extends StatefulWidget {
  const _SensitiveValue({required this.value});

  final String value;

  @override
  State<_SensitiveValue> createState() => _SensitiveValueState();
}

class _SensitiveValueState extends State<_SensitiveValue> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    final unavailable = widget.value == 'Chưa cập nhật';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            unavailable || _visible ? widget.value : '••••••••',
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (!unavailable)
          IconButton(
            tooltip: _visible ? 'Ẩn thông tin' : 'Hiện thông tin',
            visualDensity: VisualDensity.compact,
            onPressed: () => setState(() => _visible = !_visible),
            icon: Icon(
              _visible
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              size: 20,
            ),
          ),
      ],
    );
  }
}
