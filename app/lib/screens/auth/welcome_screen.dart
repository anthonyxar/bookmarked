import 'package:flutter/material.dart';

import 'login_screen.dart';
import 'register_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _showLogin = false;

  @override
  Widget build(BuildContext context) {
    return _showLogin
        ? LoginScreen(onSwitchToRegister: () => setState(() => _showLogin = false))
        : RegisterScreen(onSwitchToLogin: () => setState(() => _showLogin = true));
  }
}
