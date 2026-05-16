import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../../../core/layout/responsive.dart';
import '../../../core/services/activity_log_service.dart';
import '../../../core/utils/locker_utils.dart';
import '../../../shared/widgets/app_widgets.dart';

class AdminPage extends StatelessWidget {
  final String userId;
  const AdminPage({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return ResponsiveContent(
      desktopMaxWidth: 1180,
      child: StreamBuilder<DatabaseEvent>(
        stream: FirebaseDatabase.instance.ref('users/$userId').onValue,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xff6759ff)),
            );
          }
          final admin = safeMap(snapshot.data?.snapshot.value);
          if (!isAdminRole(admin['role'])) {
            return const _AdminDenied();
          }

          final organizationId = organizationIdOf(admin);
          final organizationName = organizationNameOf(admin);
          final canManageAccountStatus = readable(admin['role'], '') == 'admin';
          return StreamBuilder<DatabaseEvent>(
            stream: FirebaseDatabase.instance.ref('users').onValue,
            builder: (context, usersSnapshot) {
              final scopedUsers = _scopedEntries(
                safeMap(usersSnapshot.data?.snapshot.value),
                organizationId,
              );
              return StreamBuilder<DatabaseEvent>(
                stream: FirebaseDatabase.instance
                    .ref('organizations/$organizationId/lockers')
                    .onValue,
                builder: (context, lockersSnapshot) {
                  final scopedLockers = _scopedEntries(
                    safeMap(lockersSnapshot.data?.snapshot.value),
                    organizationId,
                  );
                  return StreamBuilder<DatabaseEvent>(
                    stream: FirebaseDatabase.instance
                        .ref('activityLogs')
                        .orderByChild('organizationId')
                        .equalTo(organizationId)
                        .onValue,
                    builder: (context, logsSnapshot) {
                      final logs = _lastDayLogs(
                        safeMap(logsSnapshot.data?.snapshot.value),
                        organizationId,
                      );
                      return StreamBuilder<DatabaseEvent>(
                        stream: FirebaseDatabase.instance
                            .ref('organizationRequests')
                            .orderByChild('organizationId')
                            .equalTo(organizationId)
                            .onValue,
                        builder: (context, requestsSnapshot) {
                          final requests = _pendingRequests(
                            safeMap(requestsSnapshot.data?.snapshot.value),
                          );
                          return StreamBuilder<DatabaseEvent>(
                            stream: FirebaseDatabase.instance
                                .ref('organizations/$organizationId')
                                .onValue,
                            builder: (context, orgSnapshot) {
                              final organization = safeMap(
                                orgSnapshot.data?.snapshot.value,
                              );
                              return _AdminDashboardContent(
                                adminId: userId,
                                organizationId: organizationId,
                                organizationName: organizationName,
                                users: scopedUsers,
                                lockers: scopedLockers,
                                logs: logs,
                                requests: requests,
                                organization: organization,
                                canManageAccountStatus: canManageAccountStatus,
                              );
                            },
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _AdminDenied extends StatelessWidget {
  const _AdminDenied();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: cardContainer(
        child: const Text(
          'You do not have permission to access the admin page.',
          style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _AdminDashboardContent extends StatelessWidget {
  final String adminId;
  final String organizationId;
  final String organizationName;
  final List<MapEntry<String, dynamic>> users;
  final List<MapEntry<String, dynamic>> lockers;
  final List<MapEntry<String, dynamic>> logs;
  final List<MapEntry<String, dynamic>> requests;
  final Map<String, dynamic> organization;
  final bool canManageAccountStatus;

  const _AdminDashboardContent({
    required this.adminId,
    required this.organizationId,
    required this.organizationName,
    required this.users,
    required this.lockers,
    required this.logs,
    required this.requests,
    required this.organization,
    required this.canManageAccountStatus,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final desktop = constraints.maxWidth >= AppBreakpoints.desktop;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                organizationName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Admin Dashboard',
                style: TextStyle(color: Colors.white38, fontSize: 14),
              ),
              const SizedBox(height: 22),
              _OrganizationInfoCard(
                adminId: adminId,
                organizationId: organizationId,
                organizationName: organizationName,
                users: users,
                organization: organization,
              ),
              const SizedBox(height: 18),
              _OrganizationRequestsCard(
                adminId: adminId,
                organizationId: organizationId,
                organizationName: organizationName,
                requests: requests,
              ),
              const SizedBox(height: 18),
              _SummaryGrid(users: users, lockers: lockers, desktop: desktop),
              const SizedBox(height: 18),
              _LockerManagementCard(
                adminId: adminId,
                organizationId: organizationId,
                organizationName: organizationName,
                organization: organization,
                lockers: lockers,
              ),
              const SizedBox(height: 18),
              if (desktop)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 6,
                      child: _UsersCard(
                        adminId: adminId,
                        organizationId: organizationId,
                        users: users,
                        canManageAccountStatus: canManageAccountStatus,
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      flex: 5,
                      child: Column(
                        children: [
                          _RentalsCard(users: users, lockers: lockers),
                          const SizedBox(height: 18),
                          _LogsCard(logs: logs, organizationId: organizationId),
                        ],
                      ),
                    ),
                  ],
                )
              else ...[
                _UsersCard(
                  adminId: adminId,
                  organizationId: organizationId,
                  users: users,
                  canManageAccountStatus: canManageAccountStatus,
                ),
                const SizedBox(height: 18),
                _RentalsCard(users: users, lockers: lockers),
                const SizedBox(height: 18),
                _LogsCard(logs: logs, organizationId: organizationId),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  final List<MapEntry<String, dynamic>> users;
  final List<MapEntry<String, dynamic>> lockers;
  final bool desktop;

  const _SummaryGrid({
    required this.users,
    required this.lockers,
    required this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    final activeRentals = lockers
        .where(
          (entry) => readable(safeMap(entry.value)['ownerId'], '').isNotEmpty,
        )
        .length;
    final totalRevenue = lockers.fold<int>(
      0,
      (sum, entry) => sum + toInt(safeMap(entry.value)['totalPaid']),
    );
    final items = [
      _SummaryItem('Users', users.length.toString(), Icons.groups_rounded),
      _SummaryItem(
        'Active Rentals',
        activeRentals.toString(),
        Icons.lock_clock_rounded,
      ),
      _SummaryItem(
        'Revenue',
        'TL $totalRevenue',
        Icons.account_balance_wallet_rounded,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: desktop ? 3 : 1,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: desktop ? 3.2 : 4.2,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return cardContainer(
          child: Row(
            children: [
              iconCircle(item.icon),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    item.label,
                    style: const TextStyle(color: Colors.white38),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    item.value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OrganizationInfoCard extends StatelessWidget {
  final String adminId;
  final String organizationId;
  final String organizationName;
  final List<MapEntry<String, dynamic>> users;
  final Map<String, dynamic> organization;

  const _OrganizationInfoCard({
    required this.adminId,
    required this.organizationId,
    required this.organizationName,
    required this.users,
    required this.organization,
  });

  @override
  Widget build(BuildContext context) {
    final code = readable(organization['joinCode'], '');
    final type = organizationTypeOf(organization);
    final price = organizationHourlyPrice(organization);
    return cardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: titleRow(Icons.apartment_rounded, 'Organization Info'),
              ),
              HoverScale(
                child: OutlinedButton.icon(
                  onPressed: () => _showEditOrganizationDialog(
                    context: context,
                    adminId: adminId,
                    organizationId: organizationId,
                    organizationName: organizationName,
                    organization: organization,
                    users: users,
                  ),
                  icon: const Icon(
                    Icons.edit_rounded,
                    color: Color(0xff8d81ff),
                  ),
                  label: const Text(
                    'Edit Info',
                    style: TextStyle(
                      color: Color(0xff8d81ff),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  style: outlinePurpleButtonStyle(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: innerDecoration(),
            child: Column(
              children: [
                InfoRow(left: 'Name', right: organizationName),
                InfoRow(left: 'Type', right: type),
                InfoRow(
                  left: 'Hourly Price',
                  right: isFreeOrganization(organization)
                      ? 'Free'
                      : 'TL $price',
                  green: isFreeOrganization(organization),
                ),
                InfoRow(left: 'Join Code', right: code.isEmpty ? '-' : code),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: HoverScale(
              child: ElevatedButton(
                onPressed: () => _generateOrganizationCode(
                  context: context,
                  adminId: adminId,
                  organizationId: organizationId,
                  organizationName: organizationName,
                ),
                style: purpleButtonStyle(),
                child: Text(
                  code.isEmpty ? 'Create Code' : 'Regenerate Code',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrganizationRequestsCard extends StatelessWidget {
  final String adminId;
  final String organizationId;
  final String organizationName;
  final List<MapEntry<String, dynamic>> requests;

  const _OrganizationRequestsCard({
    required this.adminId,
    required this.organizationId,
    required this.organizationName,
    required this.requests,
  });

  @override
  Widget build(BuildContext context) {
    return cardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          titleRow(Icons.how_to_reg_rounded, 'Join Requests'),
          const SizedBox(height: 16),
          if (requests.isEmpty)
            const Text(
              'No pending requests',
              style: TextStyle(color: Colors.white54),
            )
          else
            ...requests.map((entry) {
              final request = safeMap(entry.value);
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: innerDecoration(),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 560;
                    final info = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          readable(request['userName'], 'Unnamed user'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${readable(request['userEmail'], '-')} • ${formatDate(request['createdAt'])}',
                          style: const TextStyle(color: Colors.white38),
                        ),
                      ],
                    );
                    final actions = Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        HoverScale(
                          child: ElevatedButton(
                            onPressed: () => _resolveOrganizationRequest(
                              requestId: entry.key,
                              request: request,
                              adminId: adminId,
                              organizationId: organizationId,
                              organizationName: organizationName,
                              approved: true,
                            ),
                            style: purpleButtonStyle(),
                            child: const Text(
                              'Approve',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: () => _resolveOrganizationRequest(
                            requestId: entry.key,
                            request: request,
                            adminId: adminId,
                            organizationId: organizationId,
                            organizationName: organizationName,
                            approved: false,
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xffff6f8e)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Reject',
                            style: TextStyle(
                              color: Color(0xffff6f8e),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    );
                    if (compact) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [info, const SizedBox(height: 12), actions],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: info),
                        const SizedBox(width: 12),
                        actions,
                      ],
                    );
                  },
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _SummaryItem {
  final String label;
  final String value;
  final IconData icon;
  const _SummaryItem(this.label, this.value, this.icon);
}

class _UsersCard extends StatelessWidget {
  final String adminId;
  final String organizationId;
  final List<MapEntry<String, dynamic>> users;
  final bool canManageAccountStatus;

  const _UsersCard({
    required this.adminId,
    required this.organizationId,
    required this.users,
    required this.canManageAccountStatus,
  });

  @override
  Widget build(BuildContext context) {
    return cardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          titleRow(Icons.groups_rounded, 'Registered Users'),
          const SizedBox(height: 16),
          if (users.isEmpty)
            const Text(
              'No users found',
              style: TextStyle(color: Colors.white54),
            )
          else
            ...users.map((entry) {
              final user = safeMap(entry.value);
              final name =
                  '${readable(user['name'], '')} ${readable(user['surname'], '')}'
                      .trim();
              return _AdminListTile(
                icon: Icons.person_outline_rounded,
                title: name.isEmpty ? readable(user['email'], '-') : name,
                subtitle:
                    '${readable(user['email'], '-')} • ${readable(user['role'], 'student')}',
                trailingWidget: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'TL ${toInt(user['balance'])}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: Color(0xff8d81ff),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Remove from organization',
                      onPressed: entry.key == adminId
                          ? null
                          : () => _removeOrganizationUser(
                              context: context,
                              targetUserId: entry.key,
                              user: user,
                              adminId: adminId,
                              organizationId: organizationId,
                            ),
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        color: entry.key == adminId
                            ? Colors.white24
                            : const Color(0xffff6b7a),
                      ),
                    ),
                  ],
                ),
                onTap: () => _showEditUserDialog(
                  context: context,
                  adminId: adminId,
                  organizationId: organizationId,
                  userId: entry.key,
                  user: user,
                  canManageAccountStatus: canManageAccountStatus,
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _LockerManagementCard extends StatelessWidget {
  final String adminId;
  final String organizationId;
  final String organizationName;
  final Map<String, dynamic> organization;
  final List<MapEntry<String, dynamic>> lockers;

  const _LockerManagementCard({
    required this.adminId,
    required this.organizationId,
    required this.organizationName,
    required this.organization,
    required this.lockers,
  });

  @override
  Widget build(BuildContext context) {
    final sortedLockers = [
      ...lockers,
    ]..sort((a, b) => lockerIdFromKey(a.key).compareTo(lockerIdFromKey(b.key)));
    return cardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: titleRow(Icons.inventory_2_rounded, 'Lockers')),
              HoverScale(
                child: OutlinedButton.icon(
                  onPressed: () => _showBulkMaintenanceDialog(
                    context: context,
                    adminId: adminId,
                    organizationId: organizationId,
                    lockers: sortedLockers,
                  ),
                  icon: const Icon(
                    Icons.build_circle_outlined,
                    color: Color(0xff8d81ff),
                  ),
                  label: const Text(
                    'Maintenance',
                    style: TextStyle(
                      color: Color(0xff8d81ff),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  style: outlinePurpleButtonStyle(),
                ),
              ),
              const SizedBox(width: 10),
              HoverScale(
                child: OutlinedButton.icon(
                  onPressed: () => _showBulkDeleteLockersDialog(
                    context: context,
                    adminId: adminId,
                    organizationId: organizationId,
                    lockers: sortedLockers,
                  ),
                  icon: const Icon(
                    Icons.delete_sweep_outlined,
                    color: Color(0xffff6f8e),
                  ),
                  label: const Text(
                    'Bulk Delete',
                    style: TextStyle(
                      color: Color(0xffff6f8e),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xffff6f8e)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              HoverScale(
                child: ElevatedButton.icon(
                  onPressed: () => _showAddLockerDialog(
                    context: context,
                    adminId: adminId,
                    organizationId: organizationId,
                    organizationName: organizationName,
                    organization: organization,
                  ),
                  icon: const Icon(Icons.add_rounded, color: Colors.white),
                  label: const Text(
                    'Add Locker',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  style: purpleButtonStyle(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (sortedLockers.isEmpty)
            const Text(
              'No lockers have been added yet',
              style: TextStyle(color: Colors.white54),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: sortedLockers.map((entry) {
                final locker = safeMap(entry.value);
                final inUse = readable(locker['ownerId'], '').isNotEmpty;
                final maintenance =
                    locker['maintenance'] == true ||
                    readable(locker['status'], '').toLowerCase() ==
                        'maintenance';
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xff181c28),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: inUse
                          ? const Color(0xffff6f8e)
                          : maintenance
                          ? const Color(0xffffc857)
                          : const Color(0xff2a3040),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        inUse
                            ? Icons.lock_clock_rounded
                            : maintenance
                            ? Icons.build_circle_outlined
                            : Icons.lock_open_rounded,
                        color: inUse
                            ? const Color(0xffff6f8e)
                            : maintenance
                            ? const Color(0xffffc857)
                            : const Color(0xff7ce78c),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Locker ${lockerIdFromKey(entry.key)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Tooltip(
                        message: maintenance
                            ? 'Disable maintenance'
                            : 'Enable maintenance',
                        child: InkWell(
                          onTap: inUse
                              ? null
                              : () => _setLockerMaintenance(
                                  adminId: adminId,
                                  organizationId: organizationId,
                                  lockerKeys: [entry.key],
                                  maintenance: !maintenance,
                                ),
                          child: Icon(
                            maintenance
                                ? Icons.toggle_on_rounded
                                : Icons.toggle_off_rounded,
                            color: inUse
                                ? Colors.white24
                                : maintenance
                                ? const Color(0xffffc857)
                                : Colors.white38,
                            size: 24,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: inUse
                            ? null
                            : () => _deleteLocker(
                                context: context,
                                adminId: adminId,
                                organizationId: organizationId,
                                lockerKey: entry.key,
                              ),
                        child: Icon(
                          Icons.delete_outline_rounded,
                          color: inUse
                              ? Colors.white24
                              : const Color(0xffff6f8e),
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

class _RentalsCard extends StatelessWidget {
  final List<MapEntry<String, dynamic>> users;
  final List<MapEntry<String, dynamic>> lockers;

  const _RentalsCard({required this.users, required this.lockers});

  @override
  Widget build(BuildContext context) {
    final usersById = {
      for (final entry in users) entry.key: safeMap(entry.value),
    };
    final rentals = lockers.where((entry) {
      final locker = safeMap(entry.value);
      return readable(locker['ownerId'], '').isNotEmpty;
    }).toList();

    return cardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          titleRow(Icons.lock_clock_rounded, 'Rental Access'),
          const SizedBox(height: 16),
          if (rentals.isEmpty)
            const Text(
              'No active rentals',
              style: TextStyle(color: Colors.white54),
            )
          else
            ...rentals.map((entry) {
              final locker = safeMap(entry.value);
              final owner = usersById[readable(locker['ownerId'], '')] ?? {};
              final ownerName =
                  '${readable(owner['name'], '')} ${readable(owner['surname'], '')}'
                      .trim();
              return _AdminListTile(
                icon: Icons.lock_outline_rounded,
                title: 'Locker ${lockerIdFromKey(entry.key)}',
                subtitle:
                    '${ownerName.isEmpty ? readable(owner['email'], '-') : ownerName} • ${readable(locker['plan'], '-')} • ${toInt(locker['duration'])} ${unitForPlan(locker['plan'])}',
                trailing: timeLeft(locker['endsAt']),
              );
            }),
        ],
      ),
    );
  }
}

class _LogsCard extends StatelessWidget {
  final List<MapEntry<String, dynamic>> logs;
  final String organizationId;
  const _LogsCard({required this.logs, required this.organizationId});

  @override
  Widget build(BuildContext context) {
    final preview = logs.take(4).toList();
    return cardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: titleRow(Icons.receipt_long_rounded, 'Last 24h Log'),
              ),
              HoverScale(
                child: OutlinedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AdminLogsPage(
                        organizationId: organizationId,
                        initialLogs: logs,
                      ),
                    ),
                  ),
                  style: outlinePurpleButtonStyle(),
                  child: const Text(
                    'View All',
                    style: TextStyle(
                      color: Color(0xff8d81ff),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (logs.isEmpty)
            const Text(
              'No activity in the last 24 hours',
              style: TextStyle(color: Colors.white54),
            )
          else
            ...preview.map((entry) {
              final log = safeMap(entry.value);
              return _AdminListTile(
                icon: Icons.history_rounded,
                title: readable(log['message'], readable(log['type'], '-')),
                subtitle: formatDate(log['createdAt']),
                trailing: readable(log['type'], '-'),
              );
            }),
        ],
      ),
    );
  }
}

class AdminLogsPage extends StatefulWidget {
  final String organizationId;
  final List<MapEntry<String, dynamic>> initialLogs;

  const AdminLogsPage({
    super.key,
    required this.organizationId,
    required this.initialLogs,
  });

  @override
  State<AdminLogsPage> createState() => _AdminLogsPageState();
}

class _AdminLogsPageState extends State<AdminLogsPage> {
  String typeFilter = 'all';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff0b0d14),
      body: SafeArea(
        child: ResponsiveContent(
          desktopMaxWidth: 980,
          child: StreamBuilder<DatabaseEvent>(
            stream: FirebaseDatabase.instance
                .ref('activityLogs')
                .orderByChild('organizationId')
                .equalTo(widget.organizationId)
                .onValue,
            builder: (context, snapshot) {
              final logs = _lastDayLogs(
                snapshot.hasData
                    ? safeMap(snapshot.data?.snapshot.value)
                    : {
                        for (final entry in widget.initialLogs)
                          entry.key: entry.value,
                      },
                widget.organizationId,
              );
              final types = <String>{
                'all',
                ...logs.map(
                  (entry) => readable(safeMap(entry.value)['type'], '-'),
                ),
              }.toList();
              if (!types.contains(typeFilter)) typeFilter = 'all';
              final filtered = typeFilter == 'all'
                  ? logs
                  : logs
                        .where(
                          (entry) =>
                              readable(safeMap(entry.value)['type'], '-') ==
                              typeFilter,
                        )
                        .toList();
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        backButton(context),
                        const SizedBox(width: 12),
                        const Text(
                          'Logs',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    cardContainer(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          titleRow(Icons.filter_list_rounded, 'Filters'),
                          const SizedBox(height: 14),
                          _DialogDropdown(
                            value: typeFilter,
                            items: types,
                            onChanged: (value) =>
                                setState(() => typeFilter = value),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    cardContainer(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          titleRow(Icons.receipt_long_rounded, 'Last 24h Logs'),
                          const SizedBox(height: 16),
                          if (filtered.isEmpty)
                            const Text(
                              'No logs match this filter',
                              style: TextStyle(color: Colors.white54),
                            )
                          else
                            ...filtered.map((entry) {
                              final log = safeMap(entry.value);
                              return _AdminListTile(
                                icon: Icons.history_rounded,
                                title: readable(
                                  log['message'],
                                  readable(log['type'], '-'),
                                ),
                                subtitle: formatDate(log['createdAt']),
                                trailing: readable(log['type'], '-'),
                              );
                            }),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AdminListTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String trailing;
  final Widget? trailingWidget;
  final VoidCallback? onTap;

  const _AdminListTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing = '',
    this.trailingWidget,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return HoverScale(
      scale: onTap == null ? 1.005 : 1.015,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: innerDecoration(),
          child: Row(
            children: [
              iconCircle(icon),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Colors.white38),
                    ),
                  ],
                ),
              ),
              if (trailingWidget != null) ...[
                const SizedBox(width: 12),
                trailingWidget!,
              ] else if (trailing.isNotEmpty) ...[
                const SizedBox(width: 12),
                Text(
                  trailing,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: Color(0xff8d81ff),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

List<MapEntry<String, dynamic>> _scopedEntries(
  Map<String, dynamic> raw,
  String organizationId,
) {
  return raw.entries.where((entry) {
    final data = safeMap(entry.value);
    return organizationIdOf(data) == organizationId ||
        safeMap(data['organizations']).containsKey(organizationId);
  }).toList()..sort((a, b) {
    final left = readable(safeMap(a.value)['name'], a.key);
    final right = readable(safeMap(b.value)['name'], b.key);
    return left.compareTo(right);
  });
}

List<MapEntry<String, dynamic>> _lastDayLogs(
  Map<String, dynamic> raw,
  String organizationId,
) {
  final since = DateTime.now()
      .subtract(const Duration(hours: 24))
      .millisecondsSinceEpoch;
  final logs = raw.entries.where((entry) {
    final log = safeMap(entry.value);
    return organizationIdOf(log) == organizationId &&
        toInt(log['createdAtMillis']) >= since;
  }).toList();
  logs.sort(
    (a, b) => toInt(
      safeMap(b.value)['createdAtMillis'],
    ).compareTo(toInt(safeMap(a.value)['createdAtMillis'])),
  );
  return logs;
}

List<MapEntry<String, dynamic>> _pendingRequests(Map<String, dynamic> raw) {
  final requests = raw.entries
      .where(
        (entry) => readable(safeMap(entry.value)['status'], '') == 'pending',
      )
      .toList();
  requests.sort(
    (a, b) => toInt(
      safeMap(b.value)['createdAtMillis'],
    ).compareTo(toInt(safeMap(a.value)['createdAtMillis'])),
  );
  return requests;
}

String _newJoinCode(String organizationId) {
  final prefix = organizationId
      .replaceAll(RegExp('[^A-Za-z0-9]'), '')
      .toUpperCase()
      .padRight(4, 'X')
      .substring(0, 4);
  final suffix = (DateTime.now().millisecondsSinceEpoch % 100000)
      .toString()
      .padLeft(5, '0');
  return '$prefix-$suffix';
}

Future<void> _generateOrganizationCode({
  required BuildContext context,
  required String adminId,
  required String organizationId,
  required String organizationName,
}) async {
  final code = _newJoinCode(organizationId);
  final current = safeMap(
    (await FirebaseDatabase.instance.ref('organizations/$organizationId').get())
        .value,
  );
  await FirebaseDatabase.instance.ref('organizations/$organizationId').update({
    'name': organizationName,
    'organizationName': organizationName,
    'organizationId': organizationId,
    'type': organizationTypeOf(current),
    'hourlyPrice': organizationHourlyPrice(current),
    'joinCode': code,
    'updatedAt': DateTime.now().toIso8601String(),
    'updatedBy': adminId,
  });
  await ActivityLogService.write(
    organizationId: organizationId,
    actorId: adminId,
    type: 'organization_code_generated',
    message: 'Organization join code generated',
    metadata: {'joinCode': code},
  );
  if (context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Code created: $code')));
  }
}

Future<void> _showEditOrganizationDialog({
  required BuildContext context,
  required String adminId,
  required String organizationId,
  required String organizationName,
  required Map<String, dynamic> organization,
  required List<MapEntry<String, dynamic>> users,
}) async {
  final nameController = TextEditingController(
    text: readable(organization['name'], organizationName),
  );
  final priceController = TextEditingController(
    text: organizationHourlyPrice(organization).toString(),
  );
  String type = organizationTypeOf(organization);

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          final free = type == 'school' || type == 'gym';
          return AlertDialog(
            backgroundColor: const Color(0xff141824),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: Color(0xff232738)),
            ),
            title: const Text(
              'Organization Info',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
            content: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  darkInput(
                    controller: nameController,
                    hint: 'Organization name',
                    icon: Icons.apartment_rounded,
                  ),
                  const SizedBox(height: 12),
                  _DialogDropdown(
                    value: type,
                    items: const ['school', 'gym', 'museum', 'other'],
                    onChanged: (value) => setDialogState(() => type = value),
                  ),
                  const SizedBox(height: 12),
                  if (!free)
                    darkInput(
                      controller: priceController,
                      hint: 'Hourly price',
                      icon: Icons.payments_outlined,
                    )
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: innerDecoration(),
                      child: const Text(
                        'School and gym organizations are free.',
                        style: TextStyle(
                          color: Color(0xff7ce78c),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
              HoverScale(
                child: ElevatedButton(
                  style: purpleButtonStyle(),
                  onPressed: () async {
                    final name = nameController.text.trim().isEmpty
                        ? organizationName
                        : nameController.text.trim();
                    final update = {
                      'name': name,
                      'organizationName': name,
                      'organizationId': organizationId,
                      'type': type,
                      'hourlyPrice': free ? 0 : toInt(priceController.text),
                      'updatedAt': DateTime.now().toIso8601String(),
                      'updatedBy': adminId,
                    };
                    final db = FirebaseDatabase.instance.ref();
                    await db
                        .child('organizations/$organizationId')
                        .update(update);
                    final lockersSnap = await db
                        .child('organizations/$organizationId/lockers')
                        .get();
                    for (final lockerEntry in safeMap(
                      lockersSnap.value,
                    ).entries) {
                      await db
                          .child(
                            organizationLockerPath(
                              organizationId,
                              lockerEntry.key,
                            ),
                          )
                          .update({
                            'organizationName': name,
                            'organizationType': type,
                            'hourlyPrice': free
                                ? 0
                                : toInt(priceController.text),
                          });
                    }
                    for (final userEntry in users) {
                      await db.child('users/${userEntry.key}').update({
                        'organizationName': name,
                      });
                      await db
                          .child(
                            'users/${userEntry.key}/organizations/$organizationId',
                          )
                          .update({'organizationName': name, 'type': type});
                    }
                    await ActivityLogService.write(
                      organizationId: organizationId,
                      actorId: adminId,
                      type: 'organization_updated',
                      message: 'Organization information updated',
                      metadata: update,
                    );
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                  },
                  child: const Text(
                    'Save',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
    },
  );

  nameController.dispose();
  priceController.dispose();
}

List<String> _lockerKeysFromInput(
  String input,
  List<MapEntry<String, dynamic>> lockers,
) {
  final editable = lockers
      .where((entry) => readable(safeMap(entry.value)['ownerId'], '').isEmpty)
      .map((entry) => entry.key)
      .toSet();
  final keys = <String>{};
  for (final rawPart in input.split(',')) {
    final part = rawPart.trim().toLowerCase();
    if (part.isEmpty) continue;
    if (part.contains('-')) {
      final rangeParts = part.split('-');
      if (rangeParts.length != 2) continue;
      final start = int.tryParse(rangeParts[0].replaceAll('locker', '').trim());
      final end = int.tryParse(rangeParts[1].replaceAll('locker', '').trim());
      if (start == null || end == null) continue;
      final lower = start <= end ? start : end;
      final upper = start <= end ? end : start;
      for (var number = lower; number <= upper; number++) {
        final key = 'locker$number';
        if (editable.contains(key)) keys.add(key);
      }
    } else {
      final number = int.tryParse(part.replaceAll('locker', '').trim());
      if (number == null) continue;
      final key = 'locker$number';
      if (editable.contains(key)) keys.add(key);
    }
  }
  return keys.toList()
    ..sort((a, b) => lockerIdFromKey(a).compareTo(lockerIdFromKey(b)));
}

Future<void> _setLockerMaintenance({
  required String adminId,
  required String organizationId,
  required List<String> lockerKeys,
  required bool maintenance,
}) async {
  if (lockerKeys.isEmpty) return;
  final db = FirebaseDatabase.instance.ref();
  final updates = <String, Object?>{};
  for (final lockerKey in lockerKeys) {
    final basePath = organizationLockerPath(organizationId, lockerKey);
    updates['$basePath/maintenance'] = maintenance;
    updates['$basePath/status'] = maintenance ? 'maintenance' : 'available';
    updates['$basePath/updatedAt'] = DateTime.now().toIso8601String();
    updates['$basePath/updatedBy'] = adminId;
  }
  await db.update(updates);
  await ActivityLogService.write(
    organizationId: organizationId,
    actorId: adminId,
    type: maintenance ? 'lockers_maintenance_enabled' : 'lockers_available',
    message: maintenance
        ? '${lockerKeys.length} locker(s) moved to maintenance'
        : '${lockerKeys.length} locker(s) moved to available',
    metadata: {'lockerKeys': lockerKeys.join(',')},
  );
}

Future<void> _showBulkMaintenanceDialog({
  required BuildContext context,
  required String adminId,
  required String organizationId,
  required List<MapEntry<String, dynamic>> lockers,
}) async {
  final controller = TextEditingController();
  bool maintenance = true;
  String errorText = '';

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xff141824),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: Color(0xff232738)),
            ),
            title: const Text(
              'Bulk Maintenance',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
            content: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  darkInput(
                    controller: controller,
                    hint: 'Locker numbers: 1, 4, 7-12',
                    icon: Icons.tag_rounded,
                  ),
                  const SizedBox(height: 12),
                  _DialogDropdown(
                    value: maintenance ? 'maintenance' : 'available',
                    items: const ['maintenance', 'available'],
                    onChanged: (value) => setDialogState(
                      () => maintenance = value == 'maintenance',
                    ),
                  ),
                  if (errorText.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      errorText,
                      style: const TextStyle(
                        color: Color(0xffff6f8e),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
              HoverScale(
                child: ElevatedButton(
                  style: purpleButtonStyle(),
                  onPressed: () async {
                    final keys = _lockerKeysFromInput(controller.text, lockers);
                    if (keys.isEmpty) {
                      setDialogState(
                        () => errorText = 'No matching locker found.',
                      );
                      return;
                    }
                    await _setLockerMaintenance(
                      adminId: adminId,
                      organizationId: organizationId,
                      lockerKeys: keys,
                      maintenance: maintenance,
                    );
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                  },
                  child: const Text(
                    'Apply',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
    },
  );

  controller.dispose();
}

Future<void> _bulkDeleteLockers({
  required String adminId,
  required String organizationId,
  required List<String> lockerKeys,
}) async {
  if (lockerKeys.isEmpty) return;
  final db = FirebaseDatabase.instance.ref();
  final updates = <String, Object?>{};
  for (final lockerKey in lockerKeys) {
    updates[organizationLockerPath(organizationId, lockerKey)] = null;
  }
  await db.update(updates);
  await ActivityLogService.write(
    organizationId: organizationId,
    actorId: adminId,
    type: 'lockers_bulk_deleted',
    message: '${lockerKeys.length} locker(s) deleted by admin',
    metadata: {'lockerKeys': lockerKeys.join(',')},
  );
}

Future<void> _showBulkDeleteLockersDialog({
  required BuildContext context,
  required String adminId,
  required String organizationId,
  required List<MapEntry<String, dynamic>> lockers,
}) async {
  final controller = TextEditingController();
  String errorText = '';

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xff141824),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: Color(0xff232738)),
            ),
            title: const Text(
              'Bulk Delete Lockers',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
            content: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  darkInput(
                    controller: controller,
                    hint: 'Locker numbers: 1, 4, 7-12',
                    icon: Icons.tag_rounded,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'In-use lockers will be skipped.',
                    style: TextStyle(color: Colors.white38),
                  ),
                  if (errorText.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      errorText,
                      style: const TextStyle(
                        color: Color(0xffff6f8e),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
              HoverScale(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xffff4f64),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    final keys = _lockerKeysFromInput(controller.text, lockers);
                    if (keys.isEmpty) {
                      setDialogState(
                        () => errorText =
                            'No deletable locker found. In-use lockers are skipped.',
                      );
                      return;
                    }
                    final confirmed = await showDialog<bool>(
                      context: dialogContext,
                      builder: (confirmContext) {
                        return AlertDialog(
                          backgroundColor: const Color(0xff141824),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                            side: const BorderSide(color: Color(0xff232738)),
                          ),
                          title: const Text(
                            'Confirm Delete',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          content: Text(
                            'Delete ${keys.length} locker(s)? This cannot be undone.',
                            style: const TextStyle(color: Colors.white70),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.pop(confirmContext, false),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(color: Colors.white54),
                              ),
                            ),
                            OutlinedButton(
                              onPressed: () =>
                                  Navigator.pop(confirmContext, true),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: Color(0xffff6f8e),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Delete',
                                style: TextStyle(
                                  color: Color(0xffff6f8e),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                    if (confirmed != true) return;
                    await _bulkDeleteLockers(
                      adminId: adminId,
                      organizationId: organizationId,
                      lockerKeys: keys,
                    );
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                  },
                  child: const Text(
                    'Delete',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
    },
  );

  controller.dispose();
}

Future<void> _deleteLocker({
  required BuildContext context,
  required String adminId,
  required String organizationId,
  required String lockerKey,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: const Color(0xff141824),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xff232738)),
        ),
        title: const Text(
          'Delete Locker',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
        content: Text(
          'Delete Locker ${lockerIdFromKey(lockerKey)}?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xffff6f8e)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Delete',
              style: TextStyle(
                color: Color(0xffff6f8e),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      );
    },
  );
  if (confirmed != true) return;
  await FirebaseDatabase.instance
      .ref(organizationLockerPath(organizationId, lockerKey))
      .remove();
  await ActivityLogService.write(
    organizationId: organizationId,
    actorId: adminId,
    lockerKey: lockerKey,
    type: 'locker_deleted',
    message: 'Locker ${lockerIdFromKey(lockerKey)} deleted by admin',
  );
}

Future<void> _resolveOrganizationRequest({
  required String requestId,
  required Map<String, dynamic> request,
  required String adminId,
  required String organizationId,
  required String organizationName,
  required bool approved,
}) async {
  final db = FirebaseDatabase.instance.ref();
  final targetUserId = readable(request['userId'], '');
  final now = DateTime.now().toIso8601String();
  if (approved && targetUserId.isNotEmpty) {
    final targetRef = db.child('users/$targetUserId');
    final targetUser = safeMap((await targetRef.get()).value);
    final memberships = safeMap(targetUser['organizations']);
    final org = safeMap(
      (await db.child('organizations/$organizationId').get()).value,
    );
    memberships[organizationId] = {
      'organizationId': organizationId,
      'organizationName': organizationName,
      'type': organizationTypeOf(org),
      'joinedAt': now,
      'approvedBy': adminId,
    };
    await targetRef.update({
      'organizationId': organizationId,
      'organizationName': organizationName,
      'organizationJoinedAt': now,
      'organizationApprovedBy': adminId,
      'organizations': memberships,
    });
  }
  await db.child('organizationRequests/$requestId').update({
    'status': approved ? 'approved' : 'rejected',
    'resolvedAt': now,
    'resolvedBy': adminId,
  });
  await ActivityLogService.write(
    organizationId: organizationId,
    actorId: adminId,
    targetUserId: targetUserId,
    type: approved
        ? 'organization_join_approved'
        : 'organization_join_rejected',
    message: approved
        ? 'Organization join request approved'
        : 'Organization join request rejected',
  );
}

Future<void> _removeOrganizationUser({
  required BuildContext context,
  required String targetUserId,
  required Map<String, dynamic> user,
  required String adminId,
  required String organizationId,
}) async {
  final email = readable(user['email'], targetUserId);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: const Color(0xff141824),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xff232738)),
        ),
        title: const Text(
          'Remove User',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
        content: Text(
          '$email will be removed from this organization. Their login account will stay active.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          HoverScale(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xffff4f64),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text(
                'Remove',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
  if (confirmed != true) return;

  try {
    final db = FirebaseDatabase.instance.ref();
    final memberships = safeMap(user['organizations']);
    memberships.remove(organizationId);
    final nextMembership = memberships.values
        .map((value) => safeMap(value))
        .where((value) => readable(value['organizationId'], '').isNotEmpty)
        .cast<Map<String, dynamic>?>()
        .firstWhere((value) => value != null, orElse: () => null);
    final activeOrganizationId = organizationIdOf(user);
    final updatedUser = Map<String, dynamic>.from(user);
    updatedUser['organizations'] = memberships;

    if (activeOrganizationId == organizationId) {
      updatedUser['organizationId'] = nextMembership?['organizationId'] ?? '';
      updatedUser['organizationName'] =
          nextMembership?['organizationName'] ?? '';
      updatedUser['organizationJoinedAt'] = '';
      updatedUser['organizationApprovedBy'] = '';
    }
    final updates = <String, Object?>{'users/$targetUserId': updatedUser};

    final lockersSnap = await db
        .child('organizations/$organizationId/lockers')
        .orderByChild('ownerId')
        .equalTo(targetUserId)
        .get();
    for (final child in lockersSnap.children) {
      final basePath = 'organizations/$organizationId/lockers/${child.key}';
      updates['$basePath/status'] = 'available';
      updates['$basePath/ownerId'] = '';
      updates['$basePath/requestedAt'] = null;
      updates['$basePath/endsAt'] = null;
      updates['$basePath/plan'] = null;
      updates['$basePath/duration'] = null;
      updates['$basePath/totalPaid'] = null;
      updates['$basePath/subtotal'] = null;
      updates['$basePath/discount'] = null;
      updates['$basePath/coupon'] = null;
      updates['$basePath/penaltyPaid'] = null;
      updates['$basePath/lastPenaltyCalculatedAt'] = null;
    }

    await db.update(updates);
    await ActivityLogService.write(
      organizationId: organizationId,
      actorId: adminId,
      targetUserId: targetUserId,
      type: 'organization_user_removed',
      message: 'User removed from organization by admin',
      metadata: {'email': email},
    );

    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$email removed.')));
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(e.toString())));
  }
}

Future<void> _showEditUserDialog({
  required BuildContext context,
  required String adminId,
  required String organizationId,
  required String userId,
  required Map<String, dynamic> user,
  required bool canManageAccountStatus,
}) async {
  final nameController = TextEditingController(
    text: readable(user['name'], ''),
  );
  final surnameController = TextEditingController(
    text: readable(user['surname'], ''),
  );
  final balanceController = TextEditingController(
    text: toInt(user['balance']).toString(),
  );
  String role = readable(user['role'], 'student');
  String status = readable(user['status'], 'active');

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xff141824),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: Color(0xff232738)),
            ),
            title: const Text(
              'Edit User',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    darkInput(
                      controller: nameController,
                      hint: 'Name',
                      icon: Icons.person_outline_rounded,
                    ),
                    const SizedBox(height: 12),
                    darkInput(
                      controller: surnameController,
                      hint: 'Surname',
                      icon: Icons.person_outline_rounded,
                    ),
                    const SizedBox(height: 12),
                    darkInput(
                      controller: balanceController,
                      hint: 'Balance',
                      icon: Icons.account_balance_wallet_outlined,
                    ),
                    const SizedBox(height: 12),
                    if (canManageAccountStatus) ...[
                      _DialogDropdown(
                        value: role,
                        items: const ['student', 'organizationAdmin'],
                        onChanged: (value) =>
                            setDialogState(() => role = value),
                      ),
                      const SizedBox(height: 12),
                      _DialogDropdown(
                        value: status,
                        items: const ['active', 'blocked'],
                        onChanged: (value) =>
                            setDialogState(() => status = value),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
              HoverScale(
                child: ElevatedButton(
                  style: purpleButtonStyle(),
                  onPressed: () async {
                    final update = {
                      'name': nameController.text.trim(),
                      'surname': surnameController.text.trim(),
                      'balance': toInt(balanceController.text),
                      'organizationId': organizationId,
                    };
                    if (canManageAccountStatus) {
                      update['role'] = role;
                      update['status'] = status;
                    }
                    await FirebaseDatabase.instance
                        .ref('users/$userId')
                        .update(update);
                    await ActivityLogService.write(
                      organizationId: organizationId,
                      actorId: adminId,
                      targetUserId: userId,
                      type: 'user_updated',
                      message:
                          'User ${readable(user['email'], userId)} updated by admin',
                      metadata: update,
                    );
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                  },
                  child: const Text(
                    'Save',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
    },
  );

  nameController.dispose();
  surnameController.dispose();
  balanceController.dispose();
}

Future<void> _showAddLockerDialog({
  required BuildContext context,
  required String adminId,
  required String organizationId,
  required String organizationName,
  required Map<String, dynamic> organization,
}) async {
  final lockerNumberController = TextEditingController();
  String? errorText;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xff141824),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: Color(0xff232738)),
            ),
            title: const Text(
              'Add Locker',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  darkInput(
                    controller: lockerNumberController,
                    hint: 'Locker number',
                    icon: Icons.inventory_2_outlined,
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      errorText!,
                      style: const TextStyle(
                        color: Color(0xffff6f8e),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
              HoverScale(
                child: ElevatedButton(
                  style: purpleButtonStyle(),
                  onPressed: () async {
                    final number = int.tryParse(
                      lockerNumberController.text.trim(),
                    );
                    if (number == null || number <= 0) {
                      setDialogState(
                        () => errorText = 'Please enter a valid locker number',
                      );
                      return;
                    }
                    final lockerKey = 'locker$number';
                    final lockerRef = FirebaseDatabase.instance.ref(
                      organizationLockerPath(organizationId, lockerKey),
                    );
                    final existing = await lockerRef.get();
                    if (existing.exists) {
                      setDialogState(
                        () => errorText = 'Locker $number already exists',
                      );
                      return;
                    }
                    await lockerRef.set({
                      'status': 'available',
                      'maintenance': false,
                      'ownerId': '',
                      'organizationId': organizationId,
                      'organizationName': organizationName,
                      'organizationType': organizationTypeOf(organization),
                      'hourlyPrice': organizationHourlyPrice(organization),
                      'command': 'none',
                      'plan': '',
                      'duration': 0,
                      'requestedAt': '',
                      'endsAt': '',
                      'totalPaid': 0,
                      'subtotal': 0,
                      'discount': 0,
                      'coupon': '',
                      'penaltyPaid': 0,
                      'createdAt': DateTime.now().toIso8601String(),
                      'createdBy': adminId,
                    });
                    await ActivityLogService.write(
                      organizationId: organizationId,
                      actorId: adminId,
                      lockerKey: lockerKey,
                      type: 'locker_created',
                      message: 'Locker $number added by admin',
                      metadata: {'lockerNumber': number},
                    );
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                  },
                  child: const Text(
                    'Create',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
    },
  );

  lockerNumberController.dispose();
}

class _DialogDropdown extends StatelessWidget {
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  const _DialogDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: innerDecoration(),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value) ? value : items.first,
          dropdownColor: const Color(0xff181c28),
          iconEnabledColor: Colors.white54,
          isExpanded: true,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
          items: items
              .map((item) => DropdownMenuItem(value: item, child: Text(item)))
              .toList(),
          onChanged: (value) {
            if (value != null) onChanged(value);
          },
        ),
      ),
    );
  }
}
