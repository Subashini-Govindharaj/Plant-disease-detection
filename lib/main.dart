import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tflite/flutter_tflite.dart';
import 'package:image_picker/image_picker.dart';
import 'package:csv/csv.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Plant Classifier',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  File? _image;
  List<dynamic>? _output;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loading = true;
    loadModel().then((value) {
      setState(() {
        _loading = false;
      });
    });
  }

  Future<void> loadModel() async {
    Tflite.close();
    try {
      String modelFile = 'assets/model.tflite';
      String labelsFile = 'assets/labels.txt';
      await Tflite.loadModel(
        model: modelFile,
        labels: labelsFile,
      );
    } on PlatformException {
      print('Failed to load model.');
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final image = await ImagePicker().getImage(source: source);
    if (image == null) return;

    setState(() {
      _image = File(image.path);
    });
    classifyImage();
  }

  Future<List<String>> getPrecautions(String label) async {
    String csvString = await rootBundle.loadString('assets/disease.csv');
    List<List<dynamic>> csvTable = CsvToListConverter().convert(csvString);
    for (List<dynamic> row in csvTable) {
      if (row.isNotEmpty && row[0].toString() == label) {
        return List<String>.from(row.sublist(1));
      }
    }
    return [];
  }

  Future<void> showPredictionDetails(String label) async {
    List<String> precautions = await getPrecautions(label);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Prediction Details'),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Prediction: $label', style: TextStyle(fontSize: 18)),
              SizedBox(height: 10),
              Text('Precautions:', style: TextStyle(fontWeight: FontWeight.bold)),
              for (String precaution in precautions) Text('- $precaution'),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> classifyImage() async {
    if (_image == null) return;

    setState(() {
      _loading = true;
    });

    try {
      var output = await Tflite.runModelOnImage(
        path: _image!.path,
        numResults: 5,
        threshold: 0.2,
        imageMean: 127.5,
        imageStd: 127.5,
      );
      setState(() {
        _loading = false;
        _output = output;
      });

      if (_output != null) {
        showPredictionDetails(_output![0]['label']);
      }
    } on PlatformException {
      print('Failed to classify image.');
    }
  }

  @override
  void dispose() {
    Tflite.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Plant Classifier'),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _image == null
                ? Expanded(
              child: Center(
                child: Text('No image selected.'),
              ),
            )
                : Expanded(
              child: Image.file(
                _image!,
                fit: BoxFit.cover,
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _pickImage(ImageSource.gallery),
              child: Text('Pick Image from Gallery'),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: () => _pickImage(ImageSource.camera),
              child: Text('Take a Photo'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: classifyImage,
              child: Text('Predict'),
            ),
            SizedBox(height: 20),
            _output != null
                ? Text(
              'Prediction: ${_output![0]['label']}',
              style: TextStyle(fontSize: 18),
            )
                : Container(),
          ],
        ),
      ),
    );
  }
}
