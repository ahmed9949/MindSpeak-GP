import 'package:flutter/material.dart';
import 'package:mind_speak_app/controllers/LoginController.dart';
import 'package:mind_speak_app/pages/signup.dart';
import 'package:mind_speak_app/pages/forgot_password.dart';
import 'package:mind_speak_app/providers/theme_provider.dart';
import 'package:provider/provider.dart';


class LogIn extends StatefulWidget {
  const LogIn({super.key});

  @override
  State<LogIn> createState() => _LogInState();
}

class _LogInState extends State<LogIn> {
  final TextEditingController mailcontroller = TextEditingController();
  final TextEditingController passwordcontroller = TextEditingController();
  final _formkey = GlobalKey<FormState>();
  late LoginController _loginController;

  @override
  void initState() {
    super.initState();
    _loginController = LoginController(
      context: context,
      mailController: mailcontroller,
      passwordController: passwordcontroller,
      formKey: _formkey,
    );
  }

  @override
  void dispose() {
    mailcontroller.dispose();
    passwordcontroller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: Icon(themeProvider.isDarkMode
                ? Icons.wb_sunny
                : Icons.nightlight_round),
            onPressed: () {
              themeProvider.toggleTheme();
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight,
              ),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.6,
                        height: MediaQuery.of(context).size.height * 0.2,
                        child: Image.asset(
                          "assets/logo.webp",
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 20.0),
                      Expanded(
                        child: Form(
                          key: _formkey,
                          child: Column(
                            children: [
                              
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 2.0, horizontal: 30.0),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFedf0f8),
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                child: TextFormField(
                                  validator: (value) => value!.isEmpty
                                      ? 'Please enter E-mail'
                                      : null,
                                  controller: mailcontroller,
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    hintText: "Email",
                                    hintStyle: TextStyle(
                                        color: Color(0xFFb2b7bf),
                                        fontSize: 18.0),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20.0),
                              
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 2.0, horizontal: 30.0),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFedf0f8),
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                child: TextFormField(
                                  controller: passwordcontroller,
                                  validator: (value) => value!.isEmpty
                                      ? 'Please enter Password'
                                      : null,
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    hintText: "Password",
                                    hintStyle: TextStyle(
                                        color: Color(0xFFb2b7bf),
                                        fontSize: 18.0),
                                  ),
                                  obscureText: true,
                                ),
                              ),
                              const SizedBox(height: 20.0),
                             
                              GestureDetector(
                                onTap: () {
                                  if (_formkey.currentState!.validate()) {
                                    _loginController.userLogin();
                                  }
                                },
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 13.0, horizontal: 30.0),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF273671),
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      "Sign In",
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 22.0,
                                          fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20.0),
                             
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const ForgotPassword(),
                                    ),
                                  );
                                },
                                child: const Text(
                                  "Forgot Password?",
                                  style: TextStyle(
                                      color: Color(0xFF8c8e98),
                                      fontSize: 18.0,
                                      fontWeight: FontWeight.w500),
                                ),
                              ),
                              const Spacer(),
                              
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  ElevatedButton(
                                    onPressed:
                                        _loginController.signInWithGoogle,
                                    child: Image.asset(
                                      "assets/google.png",
                                      height: 45,
                                      width: 45,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  const SizedBox(width: 20.0),
                                  Image.asset(
                                    "assets/apple1.png",
                                    height: 50,
                                    width: 50,
                                    fit: BoxFit.cover,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20.0),
                              // Biometric Login Button - No changes
                              ElevatedButton.icon(
                                onPressed: () async {
                                  final authenticated = await _loginController
                                      .authenticateWithBiometrics();
                                  if (authenticated) {
                                    _loginController.userLogin();
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Biometric authentication failed!')),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.fingerprint),
                                label: const Text('Login with Biometrics'),
                              ),
                              const SizedBox(height: 20.0),
                            
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    "Don't have an account?",
                                    style: TextStyle(
                                        color: Color(0xFF8c8e98),
                                        fontSize: 15.0,
                                        fontWeight: FontWeight.w500),
                                  ),
                                  const SizedBox(width: 5.0),
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => const SignUp(),
                                        ),
                                      );
                                    },
                                    child: const Text(
                                      "SignUp",
                                      style: TextStyle(
                                          color: Color(0xFF273671),
                                          fontSize: 15.0,
                                          fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
