//This is the COPY-CNN model - working image classification

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:deficam/dashboardScreen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_exit_app/flutter_exit_app.dart';
import 'package:get/get_connect/http/src/utils/utils.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tflite/tflite.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import 'package:deficam/dbHelper.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class TrialModel extends StatefulWidget {
  @override
  _CameraScreenStateTrialModel createState() => _CameraScreenStateTrialModel();
}

class _CameraScreenStateTrialModel extends State<TrialModel> {
  File? _image;
  late Interpreter _interpreter;
  List<String> _labels = [];
  bool _isModelLoaded = false;
  String _predictedClass = '';

  @override
  void initState() {
    super.initState();
    loadModel();
  }

  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/model.tflite');
      String labelsContent = await rootBundle.loadString('assets/labels.txt');
      _labels =
          labelsContent.split('\n').where((label) => label.isNotEmpty).toList();

      setState(() {
        _isModelLoaded = true;
      });
    } catch (e) {
      print('Error loading model: $e');
    }
  }

  Future<void> classifyImage(File image) async {
    try {
      if (!_isModelLoaded) return;

      final bytes = await image.readAsBytes();
      print('this the bytes image');
      print(bytes);
      final decodedImage = img.decodeImage(Uint8List.fromList(bytes))!;
      print('this the decoded bytes image');
      print(decodedImage);
      final resizedImage =
          img.copyResize(decodedImage, width: 150, height: 150);

      print('this the resizedImage image');
      print(resizedImage);

      var input = List<List<List<double>>>.generate(
        150,
        (index) => List<List<double>>.generate(
          150,
          (index) => List<double>.generate(
            3,
            (channel) =>
                resizedImage.getPixel(
                    index % 150, (index / 150).floor())[channel] /
                255.0,
          ),
        ),
      );

      // Add an extra dimension to simulate np.expand_dims(input_image, axis=0)
      var expandedInput = [input];

      print('this is the expanded input');
      print(expandedInput);

      var output = List<List<double>>.generate(
        1,
        (index) => List<double>.generate(_labels.length, (index) => 0.0),
      );

      print('this is the output');
      print(output);

      _interpreter.run(expandedInput, output);

      print('this is the input');
      print(expandedInput);

      print('this is the output');
      print(output);
      var results = output[0];
      print(results);

// Apply softmax to convert scores to probabilities
      var softmaxScores = List<double>.generate(
        results.length,
        (index) => (index == 2)
            ? 1 / (1 + exp(-results[index]))
            : exp(results[index]) / (1 + exp(results[index])),
      );
      print(softmaxScores);

// Find the index with the maximum probability
      int predictedClassIndex = softmaxScores.indexOf(
          softmaxScores.reduce((curr, next) => curr > next ? curr : next));
      print(predictedClassIndex);

// Use the predictedClassIndex to determine the final predicted class label
      String predictedClassLabel = _labels[predictedClassIndex];

      setState(() {
        _predictedClass = predictedClassLabel;
      });
    } catch (e) {
      print('Error classifying image: $e');
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedImage = await picker.getImage(source: ImageSource.gallery);

    if (pickedImage != null) {
      setState(() {
        _image = File(pickedImage.path);
      });

      classifyImage(_image!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Image Classification App'),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _image == null
              ? Text('Pick an image to classify')
              : Image.file(_image!),
          SizedBox(height: 20),
          Text(
            'Predicted Class: $_predictedClass',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _pickImage,
        tooltip: 'Pick Image',
        child: Icon(Icons.image),
      ),
    );
  }

  @override
  void dispose() {
    _interpreter.close();
    super.dispose();
  }
}

  /*CameraController? cameraController;
  List<CameraDescription>? cameras;
  bool isCameraReady = false;
  String? prediction = '';
  Timer? timer;
  bool isCapturing = false;
  double? confidence;
  File? capturedImage;
  DateTime? captureTime;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    initializeCamera();
    loadModel();
  }

  //This code will initiliaze the camera and in every 3 seconds it will classify the leaf image
  Future<void> initializeCamera() async {
    await Permission.camera.request();
    cameras = await availableCameras();
    cameraController = CameraController(cameras![0], ResolutionPreset.medium);

    await cameraController!.initialize();
    if (!mounted) return;

    setState(() {
      isCameraReady = true;
    });

    timer = Timer(Duration(seconds: 3), classifyStillImage);
  }

  //This code will load the tflite model as well as the class labels
  Future<void> loadModel() async {
    await Tflite.loadModel(
      model: 'assets/model.tflite',
      labels: 'assets/labels.txt',
    );
  }

  //This code will capture still image in front of the camera.
  void classifyStillImage() async {
    if (cameraController!.value.isTakingPicture) return;
    if (timer?.isActive == false)
      setState(() {
        isCapturing = true; // Set capturing flag to true during image capture
      });
    try {
      XFile imageFile = await cameraController!.takePicture();
      classifyImage(File(imageFile.path));
    } catch (e) {
      print('Error capturing image: $e');
    }
    setState(() {
      isCapturing = false; // Set capturing flag to false after image capture
    });
    if (mounted) {
      // Delay for 3 seconds before the next classification
      timer = Timer(Duration(seconds: 5), classifyStillImage);
    }
  }

  //Based on the captured still image. This code will run through the image to the tflite model
  void classifyImage(File imageFile) async {
    try {
      // Load the image as a Uint8List
      Uint8List imageBytes = await imageFile.readAsBytes();

      // Extract features from intermediate layer
      await extractFeaturesFromIntermediateLayer(imageBytes);
      var recognitions = await Tflite.runModelOnBinary(
        binary: imageBytes,
        numResults: 3, // Number of classification results to obtain
        threshold: 0.5, // Confidence threshold for classification
      );

      if (recognitions != null && recognitions.isNotEmpty) {
        for (var item in recognitions) {
          final className = item['label'] as String;
          final recommendation = await getRecommendationForClass(className);
          item['recommendation'] = recommendation;
        }
      }

      setState(() {
        if (recognitions != null && recognitions.isNotEmpty) {
          prediction = recognitions[0]['label'];
          confidence = recognitions[0]['confidence'];
          capturedImage = imageFile;
          captureTime = DateTime.now();
        } else {
          prediction = 'Unknown';
          confidence = null;
          capturedImage = null;
          captureTime = null;
        }
      });
    } catch (e) {
      print('Error classifying: $e');
    }
  }

  //Based on the classifed image and prediction. Recommendation of foliar fertilizer will be retrieve(recommendations.json) and displayed
  Future<String> getRecommendationForClass(String className) async {
    final jsonContent =
        await rootBundle.loadString('assets/recommendations.json');
    final recommendations = jsonDecode(jsonContent) as Map<String, dynamic>;

    if (recommendations.containsKey(className)) {
      final recommendation = recommendations[className] as String;
      return recommendation;
    } else {
      throw Exception('Recommendation not found for class: $className');
    }
  }

  Future<void> extractFeaturesFromIntermediateLayer(
      Uint8List imageBytes) async {
    // Load the model
    var interpreter = await Interpreter.fromAsset('assets/model.tflite');

    try {
      // Print output tensor details before inference
      print(
          'Output Tensor Details Before Inference: ${interpreter.getOutputTensor(0)}');

      // Decode the image using the 'image' package
      var inputImage = img.decodeImage(imageBytes);

      // Resize the image to the desired dimensions (150, 150)
      var resizedImage = img.copyResize(inputImage!, width: 150, height: 150);

      // Convert the resized image to Uint8List
      var inputBuffer = Uint8List.fromList(resizedImage.getBytes());

      // Normalize the pixel values to the range [0, 1]
      var normalizedInputBuffer = Float32List.fromList(
        inputBuffer.map((pixel) => pixel / 255.0).toList(),
      );
      print('This is the input tensor: $normalizedInputBuffer');

      // Allocate output tensor buffer
      var outputBufferLength =
          interpreter.getOutputTensor(0).shape.reduce((a, b) => a * b);
      var outputBuffer = List<double>.filled(outputBufferLength, 0);
      print('This is the output tensor before inference: $outputBuffer');

      // Run inference
      interpreter.run(normalizedInputBuffer.buffer.asUint8List(), outputBuffer);

      // Log intermediate layer shape
      print(
          'Intermediate Layer Shape: ${interpreter.getOutputTensor(0).shape}');

      // Access the values of the intermediate layer (adjust the index based on your model)
      var intermediateLayerValues = outputBuffer.toList();
      print('Intermediate Layer Values: $intermediateLayerValues');
    } finally {
      // Close the interpreter
      interpreter.close();
    }
  }

  //This dialog will show once the user clicks view result.
  //The result includes the captured image, prediction class, foliar fertilizer recommendation and confidence level
  void _showDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          child: Container(
            padding: EdgeInsets.all(16),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(
                'Classification Result',
                textAlign: TextAlign.left,
                style: GoogleFonts.roboto(
                  color: Colors.black,
                  fontSize: 25.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(
                height: 20,
              ),
              if (capturedImage != null)
                Image.file(
                  capturedImage!,
                  width: 150,
                  height: 150,
                ),
              SizedBox(
                height: 10,
              ),
              Divider(
                thickness: 1,
                height: 1,
                color: Colors.grey[350],
              ),
              SizedBox(
                height: 15,
              ),
              if (prediction != null)
                Row(
                  children: [
                    Expanded(
                      flex: 55,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Deficiency Classification: ',
                            style: GoogleFonts.roboto(
                              color: Colors.black,
                              fontSize: 17.0,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                          SizedBox(
                            height: 8,
                          ),
                          if (confidence != null)
                            Text(
                              'Confidence:',
                              style: GoogleFonts.roboto(
                                color: Colors.black,
                                fontSize: 17.0,
                                fontWeight: FontWeight.normal,
                              ),
                            ),
                          SizedBox(
                            height: 8,
                          ),
                          Text(
                            'Foliar Fertilizer',
                            style: GoogleFonts.roboto(
                              color: Colors.black,
                              fontSize: 17.0,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                          Text(
                            'Recommendation: ',
                            style: GoogleFonts.roboto(
                              color: Colors.black,
                              fontSize: 17.0,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 45,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '$prediction',
                            style: GoogleFonts.roboto(
                              color: Colors.black,
                              fontSize: 17.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(
                            height: 8,
                          ),
                          Text(
                            '${confidence!.toStringAsFixed(2)}',
                            style: GoogleFonts.roboto(
                              color: Colors.black,
                              fontSize: 17.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(
                            height: 8,
                          ),
                          if (prediction != null)
                            FutureBuilder<String>(
                              future: getRecommendationForClass(prediction!),
                              builder: (context, snapshot) {
                                if (snapshot.hasData) {
                                  return Text(
                                    snapshot.data!,
                                    style: GoogleFonts.roboto(
                                      color: Colors.black,
                                      fontSize: 17.0,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  );
                                } else if (snapshot.hasError) {
                                  return Text(
                                    'Error: ${snapshot.error}',
                                    style: TextStyle(color: Colors.red),
                                  );
                                }
                                return CircularProgressIndicator();
                              },
                            ),
                          SizedBox(
                            height: 8,
                          ),
                          Text(''),
                        ],
                      ),
                    ),
                  ],
                ),
              SizedBox(
                height: 30,
              ),

              //Loading Widget
              if (isSaving)
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: CircularProgressIndicator(),
                ),

              //Save Button
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 120,
                    height: 50,
                    child: ElevatedButton.icon(
                      icon: Icon(
                        Icons.save_alt_rounded,
                        color: Colors.white,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                      onPressed: isSaving
                          ? null
                          : () async {
                              print("Saving Started");
                              setState(() {
                                isSaving = true;
                              });
                              final classificationData = {
                                'prediction': prediction,
                                'confidence': confidence,
                                'imagePath': capturedImage!.path,
                                'captureTime': captureTime!,
                              };

                              final primaryKey = await DBHelper.saveResult(
                                prediction:
                                    classificationData['prediction'] as String,
                                confidence:
                                    classificationData['confidence'] as double,
                                imagePath:
                                    classificationData['imagePath'] as String,
                                captureTime: classificationData['captureTime']
                                    as DateTime,
                                synced: true,
                              );
                              if (primaryKey != -1) {
                                print("Saving successful");
                                setState(() {
                                  isSaving = false;
                                });
                                Timer(Duration(seconds: 2), () {
                                  Navigator.pop(context);
                                });
                              } else {
                                print('Error saving result');
                              }
                            },
                      label: Text(
                        'Save',
                        style: GoogleFonts.roboto(
                          color: Colors.white,
                          fontSize: 20.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 20,
                  ),
                  SizedBox(
                    width: 120,
                    height: 50,
                    child: ElevatedButton.icon(
                      icon: Icon(
                        Icons.restart_alt_rounded,
                        color: Colors.white,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        timer?.cancel();
                        classifyStillImage();
                      },
                      label: Text(
                        'Retake',
                        style: GoogleFonts.roboto(
                          color: Colors.white,
                          fontSize: 20.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ]),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    cameraController?.pausePreview();
    timer?.cancel();
    Tflite.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Future<bool> _onWillPop() async {
      return (await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(
                'Confirm Close',
                style: GoogleFonts.roboto(
                    fontWeight: FontWeight.bold, fontSize: 20),
              ),
              content: Text(
                'Are you sure you want to close the application? Any unsaved changes will be lost.',
                style: GoogleFonts.roboto(fontSize: 15),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('No',
                      style: GoogleFonts.roboto(
                          fontSize: 14, fontWeight: FontWeight.bold)),
                ),
                TextButton(
                    child: Text('Yes',
                        style: GoogleFonts.roboto(
                            fontSize: 14, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      FlutterExitApp.exitApp(iosForceExit: true);
                    }),
              ],
            ),
          )) ??
          false;
    }

    if (!isCameraReady) {
      return Container(); // Return an empty container while camera is initializing
    }

    //This code builds the front end of the camera classify screen
    //It will show the camera preview
    //Automatically captures the image and classify it
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        body: Column(
          children: [
            Container(
              height: MediaQuery.of(context).size.height,
              child: Stack(
                children: <Widget>[
                  Positioned(
                    top: 20,
                    child: Container(
                      color: Colors.white,
                      width: MediaQuery.of(context).size.width,
                      height: 100.0,
                      child: Center(
                        child: Text(
                          "Classify",
                          style: GoogleFonts.roboto(
                              color: Colors.black,
                              fontSize: 25.0,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 100,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0xFF88BF3B),
                              Color(0xFF178F3E),
                            ]),
                        borderRadius: BorderRadius.only(
                            topRight: Radius.circular(40),
                            topLeft: Radius.circular(40)),
                      ),
                      width: MediaQuery.of(context).size.width,
                      height: MediaQuery.of(context).size.height,
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Container(
                                padding: EdgeInsets.only(left: 5, top: 10),
                                child: IconButton(
                                  color: Colors.white,
                                  icon: Icon(Icons.arrow_back_ios),
                                  iconSize: 20,
                                  onPressed: () {
                                    cameraController?.pausePreview();
                                    Navigator.push(context, MaterialPageRoute(
                                        builder: (BuildContext) {
                                      return dashboardScreen();
                                    }));
                                  },
                                ),
                              ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.all(15.0),
                            child: Stack(
                              children: <Widget>[
                                Text('Please hold for five(5) seconds'),
                                CameraPreview(cameraController!),
                                Positioned(
                                  top: 60,
                                  left: 80,
                                  right: 80,
                                  bottom: 60,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Colors
                                            .red, // Customize the color of the border
                                        width:
                                            2.0, // Customize the width of the border
                                      ),
                                    ),
                                    width: 250,
                                    height: 350,
                                    child: Column(children: [
                                      Center(
                                        child: Container(
                                          width: double.infinity,
                                          height: 30,
                                          decoration: BoxDecoration(
                                              color: Colors.white
                                                  .withOpacity(0.5)),
                                          child: Text(
                                            'Prediction: $prediction',
                                            style: GoogleFonts.roboto(
                                              color: Colors.black,
                                              fontSize: 20.0,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            if (isCapturing) // Display capture indicator when capturing an image
                                              Column(
                                                children: [
                                                  SizedBox(
                                                    height: 100,
                                                  ),
                                                  CircularProgressIndicator(),
                                                  SizedBox(height: 10),
                                                  Text(
                                                    'Classifying...',
                                                    style: GoogleFonts.roboto(
                                                      color: Colors.white,
                                                      fontSize: 20.0,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                          ],
                                        ),
                                      ),
                                    ]),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Please hold the camera steady.',
                                style: GoogleFonts.roboto(
                                  color: Colors.white,
                                  fontSize: 18.0,
                                  fontWeight: FontWeight.normal,
                                ),
                              )
                            ],
                          ),
                          SizedBox(
                            height: 20,
                          ),
                          SizedBox(
                            width: 190,
                            height: 50,
                            child: ElevatedButton.icon(
                                icon: Icon(
                                  Icons.remove_red_eye_outlined,
                                  color: Colors.green[900],
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                ),
                                onPressed: (() {
                                  timer?.cancel();
                                  _showDialog();
                                }),
                                label: Text(
                                  'View Result',
                                  style: GoogleFonts.roboto(
                                    color: Colors.green[900],
                                    fontSize: 20.0,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )),
                          )
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 60.0,
                    left: 20.0,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 20.0),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(35),
                            border: Border.all(color: Colors.white, width: 2.0),
                            color: Colors.white),
                        child: Image.asset(
                          'assets/logo/logo.png',
                          width: 80,
                          height: 80,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }*/

