import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mind_speak_app/controllers/SignupController.dart';
import 'package:mind_speak_app/providers/theme_provider.dart';
import 'package:mind_speak_app/pages/login.dart';
import 'package:provider/provider.dart';

class SignUp extends StatefulWidget {
  const SignUp({super.key});

  @override
  State<SignUp> createState() => _SignUpState();
}

class _SignUpState extends State<SignUp> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _usernameSlide;
  late Animation<Offset> _emailSlide;
  late Animation<Offset> _passwordSlide;
  late Animation<Offset> _roleSlide;
  late AnimationController _appBarController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _parentPhoneSlide;
  late Animation<Offset> _childNameSlide;
  late Animation<Offset> _childAgeSlide;
  late Animation<Offset> _childInterestSlide;

  final _formkey = GlobalKey<FormState>();

  late TextEditingController usernamecontroller;
  late TextEditingController emailcontroller;
  late TextEditingController passwordcontroller;
  late TextEditingController childNameController;
  late TextEditingController childAgeController;
  late TextEditingController childInterestController;
  late TextEditingController nationalIdController;
  late TextEditingController bioController;
  late TextEditingController parentPhoneNumberController;
  late TextEditingController therapistPhoneNumberController;

  String role = "parent";
  File? _childImage;
  File? _nationalProofImage;
  File? _therapistImage;
  bool isLoading = false;
  bool fieldsVisible = false;
  bool _obscurePassword = true;
  late SignUpController _signUpController;

  @override
  void initState() {
    super.initState();

    usernamecontroller = TextEditingController();
    emailcontroller = TextEditingController();
    passwordcontroller = TextEditingController();
    childNameController = TextEditingController();
    childAgeController = TextEditingController();
    childInterestController = TextEditingController();
    nationalIdController = TextEditingController();
    bioController = TextEditingController();
    parentPhoneNumberController = TextEditingController();
    therapistPhoneNumberController = TextEditingController();

    _signUpController = SignUpController(
      context: context,
      formKey: _formkey,
      usernameController: usernamecontroller,
      emailController: emailcontroller,
      passwordController: passwordcontroller,
      childNameController: childNameController,
      childAgeController: childAgeController,
      childInterestController: childInterestController,
      nationalIdController: nationalIdController,
      bioController: bioController,
      parentPhoneNumberController: parentPhoneNumberController,
      therapistPhoneNumberController: therapistPhoneNumberController,
      role: role,
      childImage: _childImage,
      nationalProofImage: _nationalProofImage,
      therapistImage: _therapistImage,
    );

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Define intervals to stagger animation
    _usernameSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
    ));

    _emailSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.2, 0.5, curve: Curves.easeOut),
    ));

    _passwordSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.4, 0.7, curve: Curves.easeOut),
    ));

    _roleSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.6, 0.9, curve: Curves.easeOut),
    ));

    _appBarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _parentPhoneSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _childNameSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _childAgeSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _childInterestSlide = Tween<Offset>(
      begin: const Offset(0, 0.3), // slides in from top
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _appBarController, curve: Curves.easeOut),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(parent: _appBarController, curve: Curves.easeIn),
    );

    _appBarController.forward();

    _animationController.forward();
  }

  @override
  void dispose() {
    usernamecontroller.dispose();
    emailcontroller.dispose();
    passwordcontroller.dispose();
    childNameController.dispose();
    childAgeController.dispose();
    childInterestController.dispose();
    nationalIdController.dispose();
    bioController.dispose();
    parentPhoneNumberController.dispose();
    therapistPhoneNumberController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> pickChildImage() async {
    File? pickedImage = await _signUpController.pickImage(ImageSource.gallery);
    setState(() {
      _childImage = pickedImage;
      _signUpController.childImage = pickedImage;
    });
  }

  Future<void> pickNationalProofImage() async {
    File? pickedImage = await _signUpController.pickImage(ImageSource.gallery);
    setState(() {
      _nationalProofImage = pickedImage;
      _signUpController.nationalProofImage = pickedImage;
    });
  }

  Future<void> pickTherapistImage() async {
    File? pickedImage = await _signUpController.pickImage(ImageSource.gallery);
    setState(() {
      _therapistImage = pickedImage;
      _signUpController.therapistImage = pickedImage;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
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
                      gradient: LinearGradient(
                        colors: themeProvider.isDarkMode
                            ? [Colors.grey[900]!, Colors.black]
                            : [Color(0xFF6A11CB), Color(0xFF2575FC)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius:
                          BorderRadius.vertical(bottom: Radius.circular(25)),
                    ),
                  ),
                  centerTitle: true,
                  shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(bottom: Radius.circular(25)),
                  ),
                  title: const Text(
                    "Create Account",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 1.2,
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
      backgroundColor:
          themeProvider.isDarkMode ? Colors.grey[900] : Colors.white,
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Form(
                  key: _formkey,
                  child: Column(
                    children: [
                      SlideTransition(
                        position: _usernameSlide, // <-- animation variable
                        child: TextFormField(
                          controller: usernamecontroller,
                          decoration: InputDecoration(
                            labelText: "Username",
                            labelStyle: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w500),
                            prefixIcon: const Icon(Icons.person),
                            filled: true,
                            fillColor:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.grey[800]
                                    : Colors.grey[100],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 18),
                          ),
                          style: const TextStyle(fontSize: 16),
                          validator: (value) =>
                              value!.isEmpty ? 'Enter Username' : null,
                        ),
                      ),
                      const SizedBox(height: 20.0),
                      SlideTransition(
                        position: _emailSlide, // <-- another animation variable
                        child: TextFormField(
                          controller: emailcontroller,
                          decoration: InputDecoration(
                            labelText: "Email",
                            labelStyle: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w500),
                            prefixIcon: const Icon(Icons.email),
                            filled: true,
                            fillColor:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.grey[800]
                                    : Colors.grey[100],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 18),
                          ),
                          style: const TextStyle(fontSize: 16),
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Enter Email';
                            }
                            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w]{2,4}$')
                                .hasMatch(value.trim())) {
                              return 'Enter a valid email address';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 20.0),
                      SlideTransition(
                        position: _passwordSlide,
                        child: TextFormField(
                          controller: passwordcontroller,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: "Password",
                            labelStyle: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w500),
                            prefixIcon: const Icon(Icons.lock),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: Colors.grey,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            filled: true,
                            fillColor:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.grey[800]
                                    : Colors.grey[100],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 18),
                          ),
                          style: const TextStyle(fontSize: 16),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Enter Password';
                            }
                            if (value.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 20.0),
                      SlideTransition(
                        position: _roleSlide,
                        child: DropdownButtonFormField(
                          value: role,
                          items: ['parent', 'therapist'].map((roleOption) {
                            return DropdownMenuItem(
                              value: roleOption,
                              child: Text(
                                roleOption[0].toUpperCase() +
                                    roleOption.substring(1),
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w500),
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              role = value.toString();
                              _signUpController.role = role;
                            });
                          },
                          decoration: InputDecoration(
                            labelText: 'Select Role',
                            labelStyle: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w500),
                            prefixIcon: const Icon(Icons.person),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.grey[800]
                                    : Colors.grey[100],
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 15),
                          ),
                          dropdownColor:
                              Theme.of(context).scaffoldBackgroundColor,
                          style: TextStyle(
                            fontSize: 16,
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                          validator: (value) =>
                              value == null || value.toString().isEmpty
                                  ? 'Please select a role'
                                  : null,
                        ),
                      ),
                      if (role == 'parent') ...[
                        const SizedBox(height: 20.0),

                        // Parent Phone Number
                        SlideTransition(
                          position:
                              _parentPhoneSlide, // This animation should be initialized in initState
                          child: TextFormField(
                            controller: parentPhoneNumberController,
                            decoration: InputDecoration(
                              labelText: "Parent Phone Number",
                              prefixIcon: Icon(Icons.phone,
                                  color: Theme.of(context).iconTheme.color),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.grey[800]
                                  : Colors.grey[100],
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 15),
                              labelStyle: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w500),
                            ),
                            style: TextStyle(
                              color:
                                  Theme.of(context).textTheme.bodyLarge?.color,
                            ),
                            keyboardType: TextInputType.phone,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Enter parent phone number';
                              }
                              if (value.length != 11) {
                                return 'Phone number must be exactly 11 digits';
                              }
                              if (!RegExp(r'^\d{11}$').hasMatch(value)) {
                                return 'Phone number must contain only numbers';
                              }
                              return null;
                            },
                          ),
                        ),

                        const SizedBox(height: 20.0),

                        // Child Name
                        SlideTransition(
                          position: _childNameSlide,
                          child: TextFormField(
                            controller: childNameController,
                            decoration: InputDecoration(
                              labelText: "Child Name",
                              prefixIcon: const Icon(Icons.person),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.grey[800]
                                  : Colors.grey[100],
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 15),
                              labelStyle: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w500),
                            ),
                            style: TextStyle(
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.color),
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                    ? 'Enter Child Name'
                                    : null,
                          ),
                        ),

                        const SizedBox(height: 20.0),

                        // Child Age
                        SlideTransition(
                          position: _childAgeSlide,
                          child: TextFormField(
                            controller: childAgeController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: "Child Age",
                              prefixIcon: Icon(Icons.cake_outlined,
                                  color: Theme.of(context).iconTheme.color),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.grey[800]
                                  : Colors.grey[100],
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 15),
                              labelStyle: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w500),
                            ),
                            style: TextStyle(
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.color),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Enter Child Age';
                              }
                              int? age = int.tryParse(value);
                              if (age == null || age < 3 || age > 12) {
                                return 'Age must be between 3 and 12';
                              }
                              return null;
                            },
                          ),
                        ),

                        const SizedBox(height: 20.0),

                        // Child Interest
                        SlideTransition(
                          position: _childInterestSlide,
                          child: TextFormField(
                            controller: childInterestController,
                            decoration: InputDecoration(
                              labelText: "Child Interest",
                              prefixIcon: Icon(Icons.star_outline,
                                  color: Theme.of(context).iconTheme.color),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.grey[800]
                                  : Colors.grey[100],
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 15),
                              labelStyle: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w500),
                            ),
                            style: TextStyle(
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.color),
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                    ? 'Enter Child Interest'
                                    : null,
                          ),
                        ),

                        const SizedBox(height: 25.0),

                        // Child Image Upload
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Upload Child Image",
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 10),
                            GestureDetector(
                              onTap: pickChildImage,
                              child: Center(
                                child: CircleAvatar(
                                  radius: 50,
                                  backgroundColor: Colors.grey[300],
                                  backgroundImage: _childImage != null
                                      ? FileImage(_childImage!)
                                      : null,
                                  child: _childImage == null
                                      ? const Icon(Icons.camera_alt,
                                          size: 40, color: Colors.grey)
                                      : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (role == 'therapist') ...[
                        const SizedBox(height: 20.0),

                        // Therapist Phone
                        TextFormField(
                          controller: therapistPhoneNumberController,
                          decoration: InputDecoration(
                            labelText: "Therapist Phone",
                            prefixIcon: Icon(Icons.phone_android,
                                color: Theme.of(context).iconTheme.color),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.grey[800]
                                    : Colors.grey[100],
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 15),
                            labelStyle: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w500),
                          ),
                          style: TextStyle(
                              color:
                                  Theme.of(context).textTheme.bodyLarge?.color),
                          keyboardType: TextInputType.phone,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Enter Therapist Phone Number';
                            }
                            if (value.length != 11) {
                              return 'Phone number must be exactly 11 digits';
                            }
                            if (!RegExp(r'^\d{11}$').hasMatch(value)) {
                              return 'Phone number must contain only numbers';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 20.0),

                        // Bio
                        TextFormField(
                          controller: bioController,
                          decoration: InputDecoration(
                            labelText: "Short Bio",
                            prefixIcon: Icon(Icons.info_outline,
                                color: Theme.of(context).iconTheme.color),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.grey[800]
                                    : Colors.grey[100],
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 15),
                            labelStyle: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w500),
                          ),
                          style: TextStyle(
                              color:
                                  Theme.of(context).textTheme.bodyLarge?.color),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                                  ? 'Enter a short bio'
                                  : null,
                        ),

                        const SizedBox(height: 20.0),

                        // National ID
                        TextFormField(
                          controller: nationalIdController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: "National ID",
                            prefixIcon: Icon(Icons.credit_card,
                                color: Theme.of(context).iconTheme.color),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.grey[800]
                                    : Colors.grey[100],
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 15),
                            labelStyle: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w500),
                          ),
                          style: TextStyle(
                              color:
                                  Theme.of(context).textTheme.bodyLarge?.color),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Enter National ID';
                            }
                            if (value.length != 14) {
                              return 'National ID must be exactly 14 digits';
                            }
                            if (!RegExp(r'^\d{14}$').hasMatch(value)) {
                              return 'National ID must contain only numbers';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 25.0),

                        // National Proof Upload
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Upload National Proof",
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 10),
                            GestureDetector(
                              onTap: pickNationalProofImage,
                              child: Center(
                                child: CircleAvatar(
                                  radius: 50,
                                  backgroundColor: Colors.grey[300],
                                  backgroundImage: _nationalProofImage != null
                                      ? FileImage(_nationalProofImage!)
                                      : null,
                                  child: _nationalProofImage == null
                                      ? const Icon(Icons.upload_file,
                                          size: 40, color: Colors.grey)
                                      : null,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 25.0),

                        // Therapist Image Upload
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Upload Therapist Image",
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 10),
                            GestureDetector(
                              onTap: pickTherapistImage,
                              child: Center(
                                child: CircleAvatar(
                                  radius: 50,
                                  backgroundColor: Colors.grey[300],
                                  backgroundImage: _therapistImage != null
                                      ? FileImage(_therapistImage!)
                                      : null,
                                  child: _therapistImage == null
                                      ? const Icon(Icons.person_add_alt_1,
                                          size: 40, color: Colors.grey)
                                      : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 30.0),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            isLoading = true;
                          });
                          _signUpController.registration().then((_) {
                            setState(() {
                              isLoading = false;
                            });
                          }).catchError((error) {
                            setState(() {
                              isLoading = false;
                            });
                          });
                        },
                        icon: const Icon(Icons.check_circle_outline,
                            color: Colors.white),
                        label: const Text(
                          "Register",
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 30, vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 6,
                          shadowColor: Colors.blueAccent.withOpacity(0.5),
                        ),
                      ),
                      const SizedBox(height: 20.0),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const LogIn()),
                          );
                        },
                        child: RichText(
                          text: const TextSpan(
                            text: "Already have an account? ",
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 16.0,
                            ),
                            children: [
                              TextSpan(
                                text: "Log In",
                                style: TextStyle(
                                  color: Colors.blueAccent,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                ),
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
  }
}
