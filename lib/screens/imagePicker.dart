import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:image_picker/image_picker.dart';
import 'package:medicinal_plant_identifier/screens/predictedImage.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
  }

  Uint8List? _image = Uint8List(8);
  File? selectedIMage;
  List Items = [];
  late Map<String, dynamic> jsonResponse;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(31, 13, 215, 27),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 96, 0, 148),
        title: const Center(
            child: Text(
          'Medicinal Plants Identification',
          style: TextStyle(
              color: Color.fromARGB(255, 255, 255, 255),
              fontWeight: FontWeight.bold),
        )),
      ),
      //bulding the list view for all the data getting from the api.
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
                width: 300, // Width of the rectangle
                height: 400, // Height of the rectangle
                color: Colors.grey,
                child: selectedIMage == null
                    ? const Center(
                        child: Text(
                          'Image Display Here',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                          ),
                        ),
                      )
                    : kIsWeb
                        ? Image.memory(
                            _image!,
                            fit: BoxFit.fill,
                          )
                        : Image.file(
                            selectedIMage!,
                            fit: BoxFit.fill,
                          )),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _pickImageFromGallery,
              child: const Text('Upload'),
            ),
            const SizedBox(height: 20), // Spacer between buttons
            ElevatedButton(
              onPressed: _pickImageFromCamera,
              child: const Text('Scan'),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => PredictedImage(
                          responseBody: jsonResponse,
                        )));
          },
          label: const Text('Predict')),
    );
  }

  Future<void> _pickImageFromGallery() async {
    try {
      if (!kIsWeb) {
        final ImagePicker picker = ImagePicker();
        XFile? image = await picker.pickImage(source: ImageSource.gallery);
        if (image != null) {
          var selected = File(image.path);
          setState(() {
            selectedIMage = selected;
          });
          var request = http.MultipartRequest('POST',
              Uri.parse('http://192.168.137.231:8000/api/recognition/'));
          request.files
              .add(await http.MultipartFile.fromPath('image', image.path));

          var response = await request.send();
          if (response.statusCode == 200) {
            List<int> responseBody = await response.stream.toBytes();
            // Decode the JSON response
            jsonResponse = json.decode(utf8.decode(responseBody));
            print('Response from Django: $jsonResponse');
            // Update your UI or state based on the response
          } else {
            print(
                'Failed to upload image. Status code: ${response.statusCode}');
          }
        }
      }
    } catch (e) {
      print(e);
    }
  }

  Future<void> _pickImageFromCamera() async {
    if (!kIsWeb) {
      final ImagePicker picker = ImagePicker();
      XFile? image = await picker.pickImage(source: ImageSource.camera);
      if (image != null) {
        var selected = File(image.path);
        setState(() {
          selectedIMage = selected;
        });
      }
    } else if (kIsWeb) {
      final ImagePicker picker = ImagePicker();
      XFile? image = await picker.pickImage(source: ImageSource.camera);
      if (image != null) {
        var f = await image.readAsBytes();
        setState(() {
          _image = f;
          selectedIMage = File('path');
        });
      }
    }
  }
}
