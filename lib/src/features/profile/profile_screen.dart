import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'profile_providers.dart';
import 'profile_model.dart';
import '../../design_system/components/portal_async_state.dart';
import '../../design_system/components/portal_scaffold.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(detailedProfileProvider);

    return PortalScaffold(
      appBar: AppBar(
        title: const Text('Hồ sơ cá nhân'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: profileAsync.when(
        data: (profile) {
          if (profile == null) {
            return const Center(
              child: Text('Không thể lấy thông tin sinh viên.'),
            );
          }

          return CustomScrollView(
            slivers: [
              _buildHeader(context, profile),
              SliverPadding(
                padding: const EdgeInsets.all(16.0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildSectionTitle('Thông tin cá nhân'),
                    _buildPersonalInfoCard(profile.personal),
                    const SizedBox(height: 16),
                    _buildSectionTitle('Học vấn & Học vụ'),
                    _buildAcademicInfoCard(profile),
                    const SizedBox(height: 16),
                    _buildSectionTitle('Thông tin gia đình'),
                    _buildFamilyInfoCard(profile.family),
                    const SizedBox(height: 16),
                    _buildSectionTitle('Đoàn - Đảng & Khác'),
                    _buildMembershipCard(profile.membership, profile.bank),
                    const SizedBox(height: 40),
                  ]),
                ),
              ),
            ],
          );
        },
        loading: () => const PortalAsyncState.loading(),
        error: (err, stack) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Lỗi khi tải hồ sơ:\n$err',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  ref.invalidate(detailedProfileProvider);
                },
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, StudentProfile profile) {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.only(bottom: 24),
        decoration: BoxDecoration(
          color: Colors.blue[800],
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(32),
            bottomRight: Radius.circular(32),
          ),
        ),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 50,
              backgroundColor: Colors.white24,
              child: Icon(Icons.person, size: 60, color: Colors.white),
            ),
            const SizedBox(height: 16),
            Text(
              profile.fullName ?? profile.displayName ?? 'Chưa cập nhật',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                profile.studentCode ?? profile.username ?? 'MSSV',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            if (profile.academic?.className != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.class_, color: Colors.white70, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      '${profile.academic!.className} • ${profile.academic?.cohort ?? ''}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildPersonalInfoCard(PersonalInfo? info) {
    if (info == null)
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Không có dữ liệu'),
        ),
      );

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildInfoRow(Icons.cake, 'Ngày sinh', info.dateOfBirth),
            const Divider(height: 24),
            _buildInfoRow(
              Icons.transgender,
              'Giới tính',
              info.gender == 'male'
                  ? 'Nam'
                  : (info.gender == 'female' ? 'Nữ' : info.gender),
            ),
            const Divider(height: 24),
            _buildInfoRow(
              Icons.badge,
              'CMND/CCCD',
              '${info.idCardNumber} (${info.idCardIssueDate})',
            ),
            const Divider(height: 24),
            _buildInfoRow(Icons.email, 'Email trường', info.schoolEmail),
            const Divider(height: 24),
            _buildInfoRow(Icons.phone, 'Số điện thoại', info.phone),
            const Divider(height: 24),
            _buildInfoRow(Icons.home, 'Hộ khẩu', info.permanentAddress),
            const Divider(height: 24),
            _buildInfoRow(
              Icons.public,
              'Dân tộc / Tôn giáo',
              '${info.ethnicity ?? ''} / ${info.religion ?? ''}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAcademicInfoCard(StudentProfile profile) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildInfoRow(Icons.school, 'Ngành học', profile.academic?.major),
            const Divider(height: 24),
            _buildInfoRow(
              Icons.class_,
              'Lớp sinh hoạt',
              profile.academic?.className,
            ),
            const Divider(height: 24),
            _buildInfoRow(Icons.timeline, 'Khóa', profile.academic?.cohort),
          ],
        ),
      ),
    );
  }

  Widget _buildFamilyInfoCard(FamilyInfo? family) {
    if (family == null)
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Không có dữ liệu'),
        ),
      );

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (family.father != null) ...[
              const Text(
                'Thông tin Ba',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 8),
              _buildInfoRow(Icons.person, 'Họ và tên', family.father!.fullName),
              const SizedBox(height: 8),
              _buildInfoRow(
                Icons.work,
                'Nghề nghiệp',
                family.father!.occupation,
              ),
              const SizedBox(height: 8),
              _buildInfoRow(Icons.phone, 'Số điện thoại', family.father!.phone),
              const Divider(height: 24),
            ],
            if (family.mother != null) ...[
              const Text(
                'Thông tin Mẹ',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.pink,
                ),
              ),
              const SizedBox(height: 8),
              _buildInfoRow(Icons.person, 'Họ và tên', family.mother!.fullName),
              const SizedBox(height: 8),
              _buildInfoRow(
                Icons.work,
                'Nghề nghiệp',
                family.mother!.occupation,
              ),
              const SizedBox(height: 8),
              _buildInfoRow(Icons.phone, 'Số điện thoại', family.mother!.phone),
            ] else if (family.father == null) ...[
              const Text('Chưa cập nhật thông tin gia đình'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMembershipCard(MembershipInfo? member, BankInfo? bank) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (member != null) ...[
              _buildInfoRow(
                Icons.group,
                'Đoàn viên',
                (member.memberStatus == true)
                    ? 'Đã kết nạp (${member.memberDate ?? ''})'
                    : 'Chưa kết nạp',
              ),
              const Divider(height: 24),
              _buildInfoRow(
                Icons.star,
                'Đảng viên',
                (member.partyMemberStatus == true)
                    ? 'Đã kết nạp'
                    : 'Chưa kết nạp',
              ),
              const Divider(height: 24),
            ],
            if (bank != null) ...[
              _buildInfoRow(Icons.account_balance, 'Ngân hàng', bank.bankName),
              const SizedBox(height: 8),
              _buildInfoRow(
                Icons.credit_card,
                'Số tài khoản',
                bank.accountNumber,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String? value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: TextStyle(color: Colors.grey[700], fontSize: 14),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            value ?? 'Chưa cập nhật',
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
          ),
        ),
      ],
    );
  }
}
