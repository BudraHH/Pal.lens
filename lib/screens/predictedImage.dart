
import 'package:flutter/material.dart';

class PredictedImage extends StatefulWidget {
  const PredictedImage({Key? key, required this.responseBody}) : super(key: key);
  final Map<String, dynamic> responseBody;
  @override
  State<PredictedImage> createState() => _PredictedImageState();
}

class _PredictedImageState extends State<PredictedImage> {
  late Map<String, dynamic> predictionData;
  late String predictedClass;
  late double confidenceScore;
  late List<dynamic> similarClasses;
  late Map<String, dynamic> aboutPredictedImage;
  late String description;

  @override
  void initState() {
    super.initState();

    // Initialize predictionData from the widget's responseBody
    predictionData = widget.responseBody;

    // Extract prediction details
    predictedClass = predictionData['Predicted Class'];
    confidenceScore = predictionData['Confidence Score'];
    similarClasses = predictionData['Similar Classes'];
    aboutPredictedImage = predictionData['About Predicted Image'];
    description = aboutPredictedImage['Description'];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(predictedClass),
      ),
    );
  }
}
