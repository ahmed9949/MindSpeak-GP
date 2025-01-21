import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image_picker/image_picker.dart';

class ImageUploader {
  static Future<String?> uploadImage(File imageFile) async {
    var url = 'http://192.168.1.17:5000/predict'; // Make sure to use the correct IP and port
    var request = http.MultipartRequest('POST', Uri.parse(url));
    request.files.add(await http.MultipartFile.fromPath('file', imageFile.path));

    try {
      var response = await request.send();
      if (response.statusCode == 200) {
        var jsonResponse = await response.stream.bytesToString();
        var prediction = jsonDecode(jsonResponse)['prediction'];
        return prediction;
      } else {
        return null;
      }
    } catch (e) {
      print(e.toString());
      return null;
    }
  }
}

class PredictScreen extends StatefulWidget {
  const PredictScreen({Key? key}) : super(key: key);

  @override
  State<PredictScreen> createState() => _PredictScreenState();
}

class _PredictScreenState extends State<PredictScreen> {
  File? _imageFile;
  String? _prediction;
  bool _isLoading = false;

  Future<void> pickImageAndUpload(BuildContext context, ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
        _prediction = null;
        _isLoading = true;
      });

      String? prediction = await ImageUploader.uploadImage(_imageFile!);
      setState(() {
        _prediction = prediction;
        _isLoading = false;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No image selected.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Image Prediction',
          style: GoogleFonts.rubik(
            textStyle: const TextStyle(
              fontSize: 20,
              color: Colors.white,
            ),
          ),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (_imageFile != null)
              Image.file(
                _imageFile!,
                height: MediaQuery.of(context).size.height * 0.5,
              )
            else
              const Text('No image selected'),
            const SizedBox(height: 20),
            Row(
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
    Flexible(
      child: ElevatedButton(
        onPressed: () => pickImageAndUpload(context, ImageSource.gallery),
        child: const Text('Select from Gallery'),
      ),
    ),
    const SizedBox(width: 10), // Reduced spacing
    Flexible(
      child: ElevatedButton(
        onPressed: () => pickImageAndUpload(context, ImageSource.camera),
        child: const Text('Take a Picture'),
      ),
    ),
  ],
),

            const SizedBox(height: 20),
            if (_isLoading)
              const CircularProgressIndicator()
            else if (_prediction != null)
              Text(
                'Prediction: $_prediction',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

void main() {
  runApp(MaterialApp(home: PredictScreen()));
}