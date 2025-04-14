import 'package:flutter/material.dart';
import 'package:mind_speak_app/controllers/LoginController.dart';
import 'package:mind_speak_app/pages/signup.dart';
import 'package:mind_speak_app/pages/forgot_password.dart';
import 'package:mind_speak_app/providers/theme_provider.dart';
import 'package:mind_speak_app/providers/color_provider.dart';
import 'package:provider/provider.dart';
import 'package:lottie/lottie.dart';

class LogIn extends StatefulWidget {
  const LogIn({super.key});

  @override
  State<LogIn> createState() => _LogInState();
}

class _LogInState extends State<LogIn> with SingleTickerProviderStateMixin {
  final TextEditingController mailcontroller = TextEditingController();
  final TextEditingController passwordcontroller = TextEditingController();
  final _formkey = GlobalKey<FormState>();
  late LoginController _loginController;
  late AnimationController _appBarController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _loginController = LoginController(
      context: context,
      mailController: mailcontroller,
      passwordController: passwordcontroller,
      formKey: _formkey,
    );

    _appBarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _appBarController, curve: Curves.easeOut));

    _fadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _appBarController, curve: Curves.easeIn));

    _appBarController.forward();
  }

  @override
  void dispose() {
    mailcontroller.dispose();
    passwordcontroller.dispose();
    _appBarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final colorProvider = Provider.of<ColorProvider>(context);

    return Scaffold(
      backgroundColor: themeProvider.isDarkMode ? Colors.black : Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: AnimatedBuilder(
          animation: _appBarController,
          builder: (context, child) {
            return SlideTransition(
              position: _slideAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: AppBar(
                  elevation: 0,
                  flexibleSpace: Container(
                    decoration: BoxDecoration(
                      gradient: themeProvider.isDarkMode
                          ? LinearGradient(
                              colors: [Colors.grey[900]!, Colors.black],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : LinearGradient(
                              colors: [
                                colorProvider.primaryColor,
                                colorProvider.primaryColor.withOpacity(0.8),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                      borderRadius: const BorderRadius.vertical(),
                    ),
                  ),
                  centerTitle: true,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(25),
                    ),
                  ),
                  title: const Text(
                    "Welcome Back!",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF7A7A7A),
                    ),
                  ),
                  actions: [
                    IconButton(
                      icon: Icon(
                        themeProvider.isDarkMode
                            ? Icons.wb_sunny
                            : Icons.nightlight_round,
                        color: Colors.white,
                      ),
                      onPressed: () => themeProvider.toggleTheme(),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              ignoring: true,
              child: Opacity(
                opacity: 1,
                child: Lottie.asset(
                  "assets/Login_background.json",
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 600),
                              curve: Curves.easeInOut,
                              width: MediaQuery.of(context).size.width * 0.6,
                              height: MediaQuery.of(context).size.height * 0.2,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        const Color.fromARGB(255, 255, 255, 255)
                                            .withOpacity(0.2),
                                    blurRadius: 20,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: Image.asset(
                                "assets/MindSpeakLogo.png",
                                fit: BoxFit.contain,
                              ),
                            ),
                            const SizedBox(height: 20.0),
                            Form(
                              key: _formkey,
                              child: Column(
                                children: [
                                  _buildInputField(
                                    hint: "Email",
                                    controller: mailcontroller,
                                    validator: (value) => value!.isEmpty
                                        ? 'Please enter E-mail'
                                        : null,
                                  ),
                                  const SizedBox(height: 20.0),
                                  _buildInputField(
                                    hint: "Password",
                                    controller: passwordcontroller,
                                    validator: (value) => value!.isEmpty
                                        ? 'Please enter Password'
                                        : null,
                                    obscure: true,
                                  ),
                                  const SizedBox(height: 20.0),
                                  GestureDetector(
                                    onTap: () {
                                      if (_formkey.currentState!.validate()) {
                                        _loginController.userLogin();
                                      }
                                    },
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 300),
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 13.0, horizontal: 30.0),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            colorProvider.primaryColor
                                                .withOpacity(0.8),
                                            colorProvider.primaryColor,
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(30),
                                        boxShadow: [
                                          BoxShadow(
                                            color: colorProvider.primaryColor
                                                .withOpacity(0.4),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: const Center(
                                        child: Text(
                                          "Sign In",
                                          style: TextStyle(
                                            color: Color(0xFF4A4A4A),
                                            fontSize: 18.0,
                                            fontWeight: FontWeight.w600,
                                          ),
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
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 40.0),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      ElevatedButton(
                                        onPressed:
                                            _loginController.signInWithGoogle,
                                        style: ElevatedButton.styleFrom(
                                          shape: const CircleBorder(),
                                          padding: const EdgeInsets.all(12),
                                          backgroundColor: Colors.white,
                                        ),
                                        child: Image.asset(
                                          "assets/google.png",
                                          height: 40,
                                          width: 40,
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
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Text(
                                        "Don't have an account?",
                                        style: TextStyle(
                                          color: Color(0xFF8c8e98),
                                          fontSize: 15.0,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(width: 5.0),
                                      GestureDetector(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            PageRouteBuilder(
                                              pageBuilder: (context, animation,
                                                      secondaryAnimation) =>
                                                  const SignUp(),
                                              transitionsBuilder: (context,
                                                  animation,
                                                  secondaryAnimation,
                                                  child) {
                                                const begin = Offset(1.0, 0.0);
                                                const end = Offset.zero;
                                                final tween = Tween(
                                                    begin: begin, end: end);
                                                final offsetAnimation =
                                                    animation.drive(tween);

                                                return SlideTransition(
                                                  position: offsetAnimation,
                                                  child: child,
                                                );
                                              },
                                            ),
                                          );
                                        },
                                        child: const Text(
                                          "SignUp",
                                          style: TextStyle(
                                            color: Color(0xFF273671),
                                            fontSize: 15.0,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
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
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required String hint,
    required TextEditingController controller,
    required String? Function(String?) validator,
    bool obscure = false,
  }) {
    final isDark =
        Provider.of<ThemeProvider>(context, listen: false).isDarkMode;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 30.0),
      decoration: BoxDecoration(
        gradient: isDark
            ? null
            : LinearGradient(
                colors: [
                  Color(0xFFFFFCF9),
                  Color(0xFFFDEBD0),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        color: isDark ? const Color(0xFF1E1E1E) : null,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: isDark
              ? const Color(0xFF3A3A3A)
              : const Color(0xFFFAD4D4).withOpacity(0.6),
          width: 1.2,
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: const Color(0xFFFAD4D4).withOpacity(0.15),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: TextFormField(
        controller: controller,
        validator: validator,
        obscureText: obscure,
        style: TextStyle(
          color: isDark ? Colors.white : const Color(0xFF4A4A4A),
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          hintStyle: TextStyle(
            color: isDark ? Colors.white60 : const Color(0xFF9E9E9E),
            fontSize: 17.0,
          ),
        ),
      ),
    );
  }
}
