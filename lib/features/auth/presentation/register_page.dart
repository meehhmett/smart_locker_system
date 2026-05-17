import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../../../shared/widgets/app_widgets.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final nameController = TextEditingController();
  final surnameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool loading = false;

  @override
  void dispose() {
    nameController.dispose();
    surnameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> register() async {
    if (loading) return;
    final name = nameController.text.trim();
    final surname = surnameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    if (name.isEmpty || surname.isEmpty || email.isEmpty || password.isEmpty) {
      showMessage('Please fill all fields');
      return;
    }
    setState(() => loading = true);
    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);
      final uid = credential.user!.uid;
      await FirebaseDatabase.instance.ref('users/$uid').set({
        'name': name,
        'surname': surname,
        'email': email,
        'role': 'student',
        'organizationId': '',
        'organizationName': '',
        'organizations': {},
        'status': 'active',
        'balance': 0,
        'rfidUid': '',
        'rfidUID': '',
        'rfidStatus': 'not_connected',
        'rfidRegisteredAt': '',
        'rfidLastSeenAt': '',
      });
      if (mounted) Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      showMessage(e.message ?? 'Register failed');
    } catch (e) {
      showMessage(e.toString());
    }
    if (mounted) setState(() => loading = false);
  }

  void showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff0b0d14),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  backButton(context),
                  const SizedBox(height: 22),
                  const Text(
                    'Create Account',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 22),
                  cardContainer(
                    child: Column(
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
                          controller: emailController,
                          hint: 'Email',
                          icon: Icons.email_outlined,
                        ),
                        const SizedBox(height: 12),
                        darkInput(
                          controller: passwordController,
                          hint: 'Password',
                          icon: Icons.lock_outline_rounded,
                          obscure: true,
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed: loading ? null : register,
                            style: purpleButtonStyle(),
                            child: Text(
                              loading ? 'Creating...' : 'Register',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
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
