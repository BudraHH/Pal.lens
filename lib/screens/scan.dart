import 'package:flutter/material.dart';
import 'package:medicinal_plant_identifier/screens/camera_screen.dart';
import 'package:camera/camera.dart';
import 'package:medicinal_plant_identifier/screens/imagePicker.dart';

class scanMe extends StatefulWidget {
  const scanMe({super.key});

  @override
  State<scanMe> createState() => _scanMeState();
}

class _scanMeState extends State<scanMe> {
  List<CameraDescription> cameras = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ElevatedButton(
                onPressed: () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (context) => const CameraScreen()));
                },
                child: const Text("Scan Me")),
            ElevatedButton(
                onPressed: () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (context) => const HomePage()));
                },
                child: const Text("gallery"))
          ]),
    );
  }
}
