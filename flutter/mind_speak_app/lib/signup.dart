import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import 'package:mind_speak_app/Home.dart';
import 'package:mind_speak_app/login.dart';

class SignUp extends StatefulWidget {
  const SignUp({super.key});

  @override
  State<SignUp> createState() => _SignUpState();
}

class _SignUpState extends State<SignUp> {
  String email = "", password = "", username = "", role = "parent";
  String childid = "",
      childname = "",
      childpicture = "",
      nationalid = "",
      nationalproof = "";
  bool status = true;
  File? _childImage;
  File? _nationalProofImage;

  TextEditingController usernamecontroller = TextEditingController();
  TextEditingController emailcontroller = TextEditingController();
  TextEditingController passwordcontroller = TextEditingController();
  TextEditingController childNameController = TextEditingController();
  TextEditingController nationalIdController = TextEditingController();

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

  Future<void> pickNationalProofImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _nationalProofImage = File(pickedFile.path);
      });
    }
  }

  Future<String> uploadImage(File image, String folder) async {
    String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    Reference storageRef =
        FirebaseStorage.instance.ref().child('$folder/$fileName');
    UploadTask uploadTask = storageRef.putFile(image);
    TaskSnapshot taskSnapshot = await uploadTask;
    return await taskSnapshot.ref.getDownloadURL();
  }

  registration() async {
    if (_formkey.currentState!.validate()) {
      try {
        email = emailcontroller.text.trim();
        password = passwordcontroller.text.trim();
        username = usernamecontroller.text.trim();
        childname = childNameController.text.trim();
        nationalid = nationalIdController.text.trim();

        UserCredential userCredential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(email: email, password: password);

        String userId = userCredential.user!.uid;

        if (role == 'parent') {
          String childImageUrl = "";
          String childId = uuid.v4();

          if (_childImage != null) {
            childImageUrl = await uploadImage(_childImage!, 'child_images');
          }

          await FirebaseFirestore.instance
              .collection('parent')
              .doc(userId)
              .set({
            'childid': childId,
            'childname': childname,
            'childpicture': childImageUrl,
            'userid': userId
          });
        } else if (role == 'therapist') {
          String nationalProofUrl = "";

          if (_nationalProofImage != null) {
            nationalProofUrl =
                await uploadImage(_nationalProofImage!, 'national_proofs');
          }

          await FirebaseFirestore.instance
              .collection('therapist')
              .doc(userId)
              .set({
            'nationalid': nationalid,
            'nationalproof': nationalProofUrl,
            'status': status,
            'therapistid': userId,
            'userid': userId
          });
        }

        await FirebaseFirestore.instance.collection('user').doc(userId).set({
          'email': email,
          'password': password,
          'role': role,
          'userid': userId,
          'username': username
        });

        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
          "Registered Successfully",
          style: TextStyle(fontSize: 20.0),
        )));
        Navigator.push(
            context, MaterialPageRoute(builder: (context) => const Home()));
      } on FirebaseAuthException catch (e) {
        if (e.code == 'weak-password') {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              backgroundColor: Colors.orangeAccent,
              content: Text(
                "Password Provided is too Weak",
                style: TextStyle(fontSize: 18.0),
              )));
        } else if (e.code == "email-already-in-use") {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              backgroundColor: Colors.orangeAccent,
              content: Text(
                "Account Already exists",
                style: TextStyle(fontSize: 18.0),
              )));
        } else {
          print("Error: ${e.toString()}");
        }
      } catch (e) {
        print("Error: ${e.toString()}");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Sign Up"),
        backgroundColor: Colors.blueAccent,
        centerTitle: true,
      ),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formkey,
            child: Column(
              children: [
                TextFormField(
                  controller: usernamecontroller,
                  decoration: InputDecoration(
                      labelText: "Username",
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30))),
                  validator: (value) =>
                      value!.isEmpty ? 'Enter Username' : null,
                ),
                const SizedBox(height: 20.0),
                TextFormField(
                  controller: emailcontroller,
                  decoration: InputDecoration(
                      labelText: "Email",
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30))),
                  validator: (value) => value!.isEmpty ? 'Enter Email' : null,
                ),
                const SizedBox(height: 20.0),
                TextFormField(
                  controller: passwordcontroller,
                  obscureText: true,
                  decoration: InputDecoration(
                      labelText: "Password",
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30))),
                  validator: (value) =>
                      value!.isEmpty ? 'Enter Password' : null,
                ),
                const SizedBox(height: 20.0),
                DropdownButtonFormField(
                  value: role,
                  items: ['parent', 'therapist']
                      .map((role) =>
                          DropdownMenuItem(value: role, child: Text(role)))
                      .toList(),
                  onChanged: (value) => setState(() => role = value.toString()),
                  decoration: InputDecoration(
                    labelText: 'Role',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30)),
                  ),
                ),
                if (role == 'parent') ...[
                  const SizedBox(height: 20.0),
                  TextFormField(
                    controller: childNameController,
                    decoration: InputDecoration(
                        labelText: "Child Name",
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30))),
                    validator: (value) =>
                        value!.isEmpty ? 'Enter Child Name' : null,
                  ),
                  const SizedBox(height: 20.0),
                  const Text("Child Image"),
                  GestureDetector(
                    onTap: pickChildImage,
                    child: CircleAvatar(
                      radius: 50,
                      backgroundImage:
                          _childImage != null ? FileImage(_childImage!) : null,
                      child: _childImage == null
                          ? const Icon(Icons.camera_alt, size: 50)
                          : null,
                    ),
                  ),
                ],
                if (role == 'therapist') ...[
                  const SizedBox(height: 20.0),
                  TextFormField(
                    controller: nationalIdController,
                    decoration: InputDecoration(
                        labelText: "National ID",
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30))),
                    validator: (value) =>
                        value!.isEmpty ? 'Enter National ID' : null,
                  ),
                  const SizedBox(height: 20.0),
                  const Text("National Proof"),
                  GestureDetector(
                    onTap: pickNationalProofImage,
                    child: CircleAvatar(
                      radius: 50,
                      backgroundImage: _nationalProofImage != null
                          ? FileImage(_nationalProofImage!)
                          : null,
                      child: _nationalProofImage == null
                          ? const Icon(Icons.camera_alt, size: 50)
                          : null,
                    ),
                  ),
                ],
                const SizedBox(height: 30.0),
                ElevatedButton(
                  onPressed: registration,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 50, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text(
                    "Register",
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
