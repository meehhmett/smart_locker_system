import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../features/auth/presentation/login_page.dart';
import '../features/locker/presentation/locker_home_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xff0b0d14),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xff6759ff)),
            ),
          );
        }
        final user = snapshot.data;
        if (user == null) return const LoginPage();

        return StreamBuilder<DatabaseEvent>(
          stream: FirebaseDatabase.instance.ref('users/${user.uid}').onValue,
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                backgroundColor: Color(0xff0b0d14),
                body: Center(
                  child: CircularProgressIndicator(color: Color(0xff6759ff)),
                ),
              );
            }

            final userValue = userSnapshot.data?.snapshot.value;
            final userData = userValue is Map
                ? Map<String, dynamic>.from(userValue)
                : null;
            final status = userData?['status']?.toString() ?? 'active';
            final accountIsUsable = userData != null && status != 'blocked';

            if (!accountIsUsable) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                FirebaseAuth.instance.signOut();
              });
              return const LoginPage(
                initialMessage:
                    'This account is not active. Contact your organization admin.',
              );
            }

            return const LockerHomePage();
          },
        );
      },
    );
  }
}
