import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../../../shared/widgets/app_widgets.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  final String? initialMessage;

  const LoginPage({super.key, this.initialMessage});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool loading = false;
  bool initialMessageShown = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (initialMessageShown || widget.initialMessage == null) return;
    initialMessageShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showMessage(widget.initialMessage!);
    });
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> login() async {
    if (loading) return;
    setState(() => loading = true);
    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
      final uid = credential.user?.uid;
      if (uid == null) {
        await FirebaseAuth.instance.signOut();
        showMessage('Login failed');
        return;
      }

      final userSnap = await FirebaseDatabase.instance.ref('users/$uid').get();
      final value = userSnap.value;
      final userData = value is Map ? Map<String, dynamic>.from(value) : null;
      final status = userData?['status']?.toString() ?? 'active';
      if (userData == null || status == 'blocked') {
        await FirebaseAuth.instance.signOut();
        showMessage(
          'This account is not active. Contact your organization admin.',
        );
      }
    } on FirebaseAuthException catch (e) {
      showMessage(e.message ?? 'Login failed');
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
                  const Text(
                    'Smart',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 38,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Text(
                    'Locker',
                    style: TextStyle(
                      color: Color(0xff6759ff),
                      fontSize: 38,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 30),
                  cardContainer(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        sectionTitle('Login'),
                        const SizedBox(height: 18),
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
                            onPressed: loading ? null : login,
                            style: purpleButtonStyle(),
                            child: Text(
                              loading ? 'Loading...' : 'Login',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: OutlinedButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const RegisterPage(),
                              ),
                            ),
                            style: outlinePurpleButtonStyle(),
                            child: const Text(
                              'Create Account',
                              style: TextStyle(
                                color: Color(0xff8d81ff),
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
