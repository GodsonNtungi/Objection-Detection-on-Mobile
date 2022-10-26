import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:tflite/tflite.dart';
import 'dart:developer' as developer;

late List<CameraDescription> cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(MaterialApp(home: MyApp(),debugShowCheckedModeBanner: false,));
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late CameraImage cameraImage;
  late CameraController cameraController;
  bool predict = false;
  List<dynamic>? recognitionList = [];
  int countNumber = 0;
  initCamera() {
    cameraController = CameraController(cameras[0], ResolutionPreset.high);
    cameraController.initialize().then((value) {
      if (!mounted) {
        return;
      }
      setState(() {
        cameraController.startImageStream((image) {
          cameraImage = image;
          countNumber += 1;
          if (countNumber % 30 == 0) {
            if (predict) {
              developer.log('starting prediction');
              runModel();
            }
          }
        });
      });
    });
  }

  Future<void> loadModel() async {
    Tflite.close();
    await Tflite.loadModel(
        model: 'assets/ssd_mobilenet.tflite',
        labels: 'assets/ssd_mobilenet.txt');
  }

  runModel() async {
    recognitionList = await Tflite.detectObjectOnFrame(
      bytesList: cameraImage.planes.map((plane) {
        return plane.bytes;
      }).toList(),
      imageHeight: cameraImage.height,
      imageWidth: cameraImage.width,
      imageMean: 127.5,
      imageStd: 127.5,
      numResultsPerClass: 1,
      threshold: 0.5,
    );
    developer.log('predicted');
    developer.log('$recognitionList');

    setState(() {
      cameraImage;
    });
  }

  List<Widget> displayBoxes(Size screen) {
    if (recognitionList == null) return [];
    double factorX = screen.width;
    double factorY = screen.height;
    Color colorpick = Colors.blue;

    return recognitionList!.map(
      (result) {
        developer.log('$result');
        return Positioned(
            left: result['rect']['x'] * factorX,
            top: result['rect']['y'] * factorY,
            width: result['rect']['w'] * factorX,
            height: result['rect']['h'] * factorY,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.all(Radius.circular(10.0)),
                border: Border.all(color: Colors.pink, width: 2.0),
              ),
              child: Text(
                "${result['detectedClass']} ${(result['confidenceInClass'] * 100).toStringAsFixed(0)}%",
                style: TextStyle(
                  background: Paint()..color = colorpick,
                  color: Colors.black,
                  fontSize: 18.0,
                ),
              ),
            ));
      },
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    List<Widget> list = [];
    list.add(Positioned(
        top: 0,
        left: 0,
        width: size.width,
        height: size.height,
        child: Center(
          child: SizedBox(
            height: size.height * 0.8,
            child: (!cameraController.value.isInitialized)
                ? Container()
                : AspectRatio(
                    aspectRatio: cameraController.value.aspectRatio,
                    child: CameraPreview(cameraController),
                  ),
          ),
        )));

    // ignore: unnecessary_null_comparison

    list.addAll(displayBoxes(size));

    return SafeArea(
        child: Scaffold(
          backgroundColor: Colors.black,
      body: Column(
        children: [
          Container(
            width: size.width,
            height: size.height * 0.8,
            child: Stack(
              children: list,
            ),
          ),
          const SizedBox(
            height: 20,
          ),
          ElevatedButton(
              onPressed: () {
                setState(() {
                  predict = !predict;
                  recognitionList = [];
                });
              },
              child: SizedBox(width: 80,height: 50,
                child:  Center(child: !predict ? const Text('Predict'): const Text('Stop')))
      )],
      ),
    ));
  }

  @override
  void initState() {
    super.initState();
    loadModel();
    initCamera();
  }

  @override
  void dispose() {
    super.dispose();
    cameraController.stopImageStream();
    Tflite.close();
  }
}
