import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:mind_speak_app/Home.dart';
import 'package:mind_speak_app/login.dart';
import 'package:uuid/uuid.dart';

class SignUp extends StatefulWidget {
  const SignUp({super.key});

  @override
  State<SignUp> createState() => _SignUpState();
}

class _SignUpState extends State<SignUp> {
  String email = "",
      password = "",
      role = "parent",
      username = "",
      userid = "",
      childid = "",
      childname = "",
      childpicture = "",
      nationalid = "",
      nationalproof = "";
  bool status = true;
  File? _childImage;

  TextEditingController emailcontroller = TextEditingController();
  TextEditingController passwordcontroller = TextEditingController();
  TextEditingController usernamecontroller = TextEditingController();
  TextEditingController childNameController = TextEditingController();
  TextEditingController nationalIdController = TextEditingController();
  TextEditingController nationalProofController = TextEditingController();

  final _formkey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();
  final Uuid uuid = Uuid();

  Future<void> pickChildImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _childImage = File(pickedFile.path);
      });
    }
  }

  Future<String> uploadImage(File image) async {
    String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    Reference storageRef =
        FirebaseStorage.instance.ref().child('child_images/$fileName');
    UploadTask uploadTask = storageRef.putFile(image);
    TaskSnapshot taskSnapshot = await uploadTask;
    return await taskSnapshot.ref.getDownloadURL();
  }

  registration() async {
    if (password.isNotEmpty && email.isNotEmpty && username.isNotEmpty) {
      try {
        UserCredential userCredential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(email: email, password: password);

        String generatedUserId = uuid.v4();
        String childImageUrl = "";
        if (role == 'parent' && _childImage != null) {
          childImageUrl = await uploadImage(_childImage!);
        }

        if (role == 'parent') {
          String generatedChildId = uuid.v4();
          await FirebaseFirestore.instance
              .collection('parent')
              .doc(userCredential.user!.uid)
              .set({
            'userid': generatedUserId,
            'childid': generatedChildId,
            'childname': childNameController.text,
            'childpicture': childImageUrl
          });
        } else if (role == 'therapist') {
          await FirebaseFirestore.instance
              .collection('therapist')
              .doc(userCredential.user!.uid)
              .set({
            'userid': generatedUserId,
            'nationalid': nationalIdController.text,
            'nationalproof': nationalProofController.text,
            'status': status
          });
        }

        await FirebaseFirestore.instance
            .collection('user')
            .doc(userCredential.user!.uid)
            .set({
          'userid': generatedUserId,
          'username': usernamecontroller.text,
          'email': email,
          'password': password,
          'role': role
        });

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
          "Registered Successfully",
          style: TextStyle(fontSize: 20.0),
        )));

        Navigator.push(
            context, MaterialPageRoute(builder: (context) => Home()));
      } on FirebaseAuthException catch (e) {
        if (e.code == 'weak-password') {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              backgroundColor: Colors.orangeAccent,
              content: Text(
                "Password Provided is too Weak",
                style: TextStyle(fontSize: 18.0),
              )));
        } else if (e.code == "email-already-in-use") {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              backgroundColor: Colors.orangeAccent,
              content: Text(
                "Account Already exists",
                style: TextStyle(fontSize: 18.0),
              )));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
                width: MediaQuery.of(context).size.width,
                child: Image.asset(
                  "assets/car.PNG",
                  fit: BoxFit.cover,
                )),
            SizedBox(
              height: 30.0,
            ),
            Padding(
              padding: const EdgeInsets.only(left: 20.0, right: 20.0),
              child: Form(
                key: _formkey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: usernamecontroller,
                      decoration: InputDecoration(
                          hintText: "Username",
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30))),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please Enter Username';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 20.0),
                    TextFormField(
                      controller: emailcontroller,
                      decoration: InputDecoration(
                          hintText: "Email",
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30))),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please Enter Email';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 20.0),
                    TextFormField(
                      controller: passwordcontroller,
                      obscureText: true,
                      decoration: InputDecoration(
                          hintText: "Password",
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30))),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please Enter Password';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 20.0),
                    DropdownButtonFormField(
                      value: role,
                      items: ['parent', 'therapist']
                          .map((role) => DropdownMenuItem(
                                value: role,
                                child: Text(role),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          role = value.toString();
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Role',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30)),
                      ),
                    ),
                    SizedBox(height: 20.0),
                    if (role == 'parent') ...[
                      TextFormField(
                        controller: childNameController,
                        decoration: InputDecoration(
                            hintText: "Child Name",
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30))),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please Enter Child Name';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 20.0),
                      GestureDetector(
                        onTap: pickChildImage,
                        child: CircleAvatar(
                          radius: 50,
                          backgroundImage: _childImage != null
                              ? FileImage(_childImage!)
                              : null,
                          child: _childImage == null
                              ? Icon(Icons.camera_alt, size: 50)
                              : null,
                        ),
                      ),
                      SizedBox(height: 20.0),
                    ]
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
