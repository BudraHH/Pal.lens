import 'dart:developer';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_player/video_player.dart';

// import 'dart:math';

import '../main.dart';
import 'preview_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? controller;
  VideoPlayerController? videoController;

  File? _imageFile;
  File? _videoFile;
  bool isFlashOn = false;

  // Initial values
  bool _isCameraInitialized = false;
  bool _isCameraPermissionGranted = false;
  final bool _isRearCameraSelected = true;
  final bool _isVideoCameraSelected = false;
  bool _isRecordingInProgress = false;
  double _minAvailableExposureOffset = 0.0;
  double _maxAvailableExposureOffset = 0.0;
  double _minAvailableZoom = 1.0;
  double _maxAvailableZoom = 1.0;

  // Current values
  double _currentZoomLevel = 1.0;
  double _currentExposureOffset = 0.0;
  FlashMode? _currentFlashMode;

  String _selectedOption = '';

  List<File> allFileList = [];

  final resolutionPresets = ResolutionPreset.values;

  ResolutionPreset currentResolutionPreset = ResolutionPreset.veryHigh;

  getPermissionStatus() async {
    await Permission.camera.request();
    var status = await Permission.camera.status;

    if (status.isGranted) {
      log('Camera Permission: GRANTED');
      setState(() {
        _isCameraPermissionGranted = true;
      });
      // Set and initialize the new camera
      onNewCameraSelected(cameras[0]);
      refreshAlreadyCapturedImages();
    } else {
      log('Camera Permission: DENIED');
    }
  }

  refreshAlreadyCapturedImages() async {
    final directory = await getApplicationDocumentsDirectory();
    List<FileSystemEntity> fileList = await directory.list().toList();
    allFileList.clear();
    List<Map<int, dynamic>> fileNames = [];

    for (var file in fileList) {
      if (file.path.contains('.jpg') || file.path.contains('.mp4')) {
        allFileList.add(File(file.path));

        String name = file.path.split('/').last.split('.').first;
        fileNames.add({0: int.parse(name), 1: file.path.split('/').last});
      }
    }

    if (fileNames.isNotEmpty) {
      final recentFile =
          fileNames.reduce((curr, next) => curr[0] > next[0] ? curr : next);
      String recentFileName = recentFile[1];
      if (recentFileName.contains('.mp4')) {
        _videoFile = File('${directory.path}/$recentFileName');
        _imageFile = null;
        _startVideoPlayer();
      } else {
        _imageFile = File('${directory.path}/$recentFileName');
        _videoFile = null;
      }

      setState(() {});
    }
  }

  Future<XFile?> takePicture() async {
    final CameraController? cameraController = controller;

    if (cameraController!.value.isTakingPicture) {
      // A capture is already pending, do nothing.
      return null;
    }

    try {
      XFile file = await cameraController.takePicture();
      return file;
    } on CameraException catch (e) {
      print('Error occured while taking picture: $e');
      return null;
    }
  }

  Future<void> _startVideoPlayer() async {
    if (_videoFile != null) {
      videoController = VideoPlayerController.file(_videoFile!);
      await videoController!.initialize().then((_) {
        // Ensure the first frame is shown after the video is initialized,
        // even before the play button has been pressed.
        setState(() {});
      });
      await videoController!.setLooping(true);
      await videoController!.play();
    }
  }

  Future<void> startVideoRecording() async {
    final CameraController? cameraController = controller;

    if (controller!.value.isRecordingVideo) {
      // A recording has already started, do nothing.
      return;
    }

    try {
      await cameraController!.startVideoRecording();
      setState(() {
        _isRecordingInProgress = true;
        print(_isRecordingInProgress);
      });
    } on CameraException catch (e) {
      print('Error starting to record video: $e');
    }
  }

  Future<XFile?> stopVideoRecording() async {
    if (!controller!.value.isRecordingVideo) {
      // Recording is already is stopped state
      return null;
    }

    try {
      XFile file = await controller!.stopVideoRecording();
      setState(() {
        _isRecordingInProgress = false;
      });
      return file;
    } on CameraException catch (e) {
      print('Error stopping video recording: $e');
      return null;
    }
  }

  Future<void> pauseVideoRecording() async {
    if (!controller!.value.isRecordingVideo) {
      // Video recording is not in progress
      return;
    }

    try {
      await controller!.pauseVideoRecording();
    } on CameraException catch (e) {
      print('Error pausing video recording: $e');
    }
  }

  Future<void> resumeVideoRecording() async {
    if (!controller!.value.isRecordingVideo) {
      // No video recording was in progress
      return;
    }

    try {
      await controller!.resumeVideoRecording();
    } on CameraException catch (e) {
      print('Error resuming video recording: $e');
    }
  }

  Future<void> openGallery(BuildContext context) async {
    final picker = ImagePicker();
    final pickedImage = await picker.pickImage(source: ImageSource.gallery);

    // Handle the picked image (You can store it, display it, etc.)
    if (pickedImage != null) {
      // Do something with the picked image (e.g., display it)
      // For example:
      // Navigator.of(context).push(MaterialPageRoute(
      //   builder: (context) => ImagePreview(imagePath: pickedImage.path),
      // ));
    } else {
      // User canceled the picker
    }
  }

  void resetCameraValues() async {
    _currentZoomLevel = 1.0;
    _currentExposureOffset = 0.0;
  }

  void onNewCameraSelected(CameraDescription cameraDescription) async {
    final previousCameraController = controller;

    final CameraController cameraController = CameraController(
      cameraDescription,
      currentResolutionPreset,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    await previousCameraController?.dispose();

    resetCameraValues();

    if (mounted) {
      setState(() {
        controller = cameraController;
      });
    }

    // Update UI if controller updated
    cameraController.addListener(() {
      if (mounted) setState(() {});
    });

    try {
      await cameraController.initialize();
      await Future.wait([
        cameraController
            .getMinExposureOffset()
            .then((value) => _minAvailableExposureOffset = value),
        cameraController
            .getMaxExposureOffset()
            .then((value) => _maxAvailableExposureOffset = value),
        cameraController
            .getMaxZoomLevel()
            .then((value) => _maxAvailableZoom = value),
        cameraController
            .getMinZoomLevel()
            .then((value) => _minAvailableZoom = value),
      ]);

      _currentFlashMode = controller!.value.flashMode;
    } on CameraException catch (e) {
      print('Error initializing camera: $e');
    }

    if (mounted) {
      setState(() {
        _isCameraInitialized = controller!.value.isInitialized;
      });
    }
  }

  void goToPreviewScreen(File imageFile, List<File> fileList) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PreviewScreen(
          imageFile: imageFile,
          fileList: fileList,
        ),
      ),
    );
  }

  void onViewFinderTap(TapDownDetails details, BoxConstraints constraints) {
    if (controller == null) {
      return;
    }

    final offset = Offset(
      details.localPosition.dx / constraints.maxWidth,
      details.localPosition.dy / constraints.maxHeight,
    );
    controller!.setExposurePoint(offset);
    controller!.setFocusPoint(offset);
  }

  @override
  void initState() {
    // Hide the status bar in Android
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
    getPermissionStatus();
    super.initState();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = controller;

    // App state changed before we got the chance to initialize.
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      onNewCameraSelected(cameraController.description);
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.175),
                  // spreadRadius: 1,
                  blurRadius: 20,
                  // offset: Offset(0, 1), // changes position of shadow
                ),
              ],
            ),
            child: AppBar(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              leading: InkWell(
                onTap: () async {
                  setState(() {
                    isFlashOn = !isFlashOn;
                    _currentFlashMode =
                        isFlashOn ? FlashMode.torch : FlashMode.off;
                  });
                  await controller!.setFlashMode(
                    _currentFlashMode ?? FlashMode.off,
                  );
                },
                child: Icon(
                  isFlashOn ? Icons.flash_on : Icons.flash_off,
                  color: isFlashOn ? Colors.amber : Colors.white,
                ),
              ),
              title: const Row(
                mainAxisAlignment:
                    MainAxisAlignment.center, // Center the title horizontally
                children: [
                  Text(
                    "Pal",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24.0,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2.0,
                      wordSpacing: 4.0,
                    ),
                  ),
                  Text(
                    ".vision",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24.0,
                      letterSpacing: 2.0,
                      wordSpacing: 4.0,
                    ),
                  ),
                ],
              ),
              centerTitle: true,
              actions: [
                PopupMenuButton(
                  icon: const Icon(
                    FontAwesomeIcons.ellipsisVertical,
                    // size: 35,
                    color: Colors.white,
                  ),
                  // iconSize: 35,
                  color: Colors.white,
                  initialValue: _selectedOption,
                  onSelected: (value) {
                    setState(() {
                      _selectedOption = value.toString();
                    });
                  },
                  itemBuilder: (BuildContext context) {
                    return [
                      const PopupMenuItem(
                        value: 'Option 1',
                        child: Text(
                          'Option 1',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'Option 2',
                        child: Text('Option 2'),
                      ),
                      const PopupMenuItem(
                        value: 'Option 3',
                        child: Text('Option 3'),
                      ),
                    ];
                  },
                ),
              ],
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        body: _isCameraPermissionGranted
            ? _isCameraInitialized
                ? Column(
                    children: [
                      AspectRatio(
                        aspectRatio: 1 / controller!.value.aspectRatio,
                        child: Stack(
                          children: [
                            CameraPreview(
                              controller!,
                              child: LayoutBuilder(builder:
                                  (BuildContext context,
                                      BoxConstraints constraints) {
                                return GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTapDown: (details) =>
                                      onViewFinderTap(details, constraints),
                                );
                              }),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                16.0,
                                8.0,
                                16.0,
                                8.0,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  // Align(
                                  //   alignment: Alignment.topRight,
                                  //   child: Container(
                                  //     decoration: BoxDecoration(
                                  //       color: Colors.black87,
                                  //       borderRadius:
                                  //           BorderRadius.circular(10.0),
                                  //     ),
                                  //     child: Padding(
                                  //       padding: const EdgeInsets.only(
                                  //         left: 8.0,
                                  //         right: 8.0,
                                  //       ),
                                  //       child: DropdownButton<ResolutionPreset>(
                                  //         dropdownColor: Colors.black87,
                                  //         underline: Container(),
                                  //         value: currentResolutionPreset,
                                  //         items: [
                                  //           for (ResolutionPreset preset
                                  //               in resolutionPresets)
                                  //             DropdownMenuItem(
                                  //               child: Text(
                                  //                 preset
                                  //                     .toString()
                                  //                     .split('.')[1]
                                  //                     .toUpperCase(),
                                  //                 style: TextStyle(
                                  //                     color: Colors.white),
                                  //               ),
                                  //               value: preset,
                                  //             )
                                  //         ],
                                  //         onChanged: (value) {
                                  //           setState(() {
                                  //             currentResolutionPreset = value!;
                                  //             _isCameraInitialized = false;
                                  //           });
                                  //           onNewCameraSelected(
                                  //               controller!.description);
                                  //         },
                                  //         hint: Text("Select item"),
                                  //       ),
                                  //     ),
                                  //   ),
                                  // ),
                                  // Spacer(),
                                  // Padding(
                                  //   padding: const EdgeInsets.only(
                                  //       right: 8.0, top: 16.0),
                                  //   child: Container(
                                  //     decoration: BoxDecoration(
                                  //       color: Colors.white,
                                  //       borderRadius:
                                  //           BorderRadius.circular(10.0),
                                  //     ),
                                  //     child: Padding(
                                  //       padding: const EdgeInsets.all(8.0),
                                  //       child: Text(
                                  //         _currentExposureOffset
                                  //                 .toStringAsFixed(1) +
                                  //             'x',
                                  //         style: TextStyle(color: Colors.black),
                                  //       ),
                                  //     ),
                                  //   ),
                                  // ),
                                  // Expanded(
                                  //   child: RotatedBox(
                                  //     quarterTurns: 3,
                                  //     child: Container(
                                  //       height: 30,
                                  //       child: Slider(
                                  //         value: _currentExposureOffset,
                                  //         min: _minAvailableExposureOffset,
                                  //         max: _maxAvailableExposureOffset,
                                  //         activeColor: Colors.white,
                                  //         inactiveColor: Colors.white30,
                                  //         onChanged: (value) async {
                                  //           setState(() {
                                  //             _currentExposureOffset = value;
                                  //           });
                                  //           await controller!
                                  //               .setExposureOffset(value);
                                  //         },
                                  //       ),
                                  //     ),
                                  //   ),
                                  // ),
                                  // Row(
                                  //   children: [
                                  // Expanded(
                                  //   child: Slider(
                                  //     value: _currentZoomLevel,
                                  //     min: _minAvailableZoom,
                                  //     max: _maxAvailableZoom,
                                  //     activeColor: Colors.white,
                                  //     inactiveColor: Colors.white30,
                                  //     onChanged: (value) async {
                                  //       setState(() {
                                  //         _currentZoomLevel = value;
                                  //       });
                                  //       await controller!
                                  //           .setZoomLevel(value);
                                  //     },
                                  //   ),
                                  // ),
                                  // Padding(
                                  //   padding:
                                  //       const EdgeInsets.only(right: 8.0),
                                  //   child: Container(
                                  //     decoration: BoxDecoration(
                                  //       color: Colors.black87,
                                  //       borderRadius:
                                  //           BorderRadius.circular(10.0),
                                  //     ),
                                  //     child: Padding(
                                  //       padding: const EdgeInsets.all(8.0),
                                  //       child: Text(
                                  //         _currentZoomLevel
                                  //                 .toStringAsFixed(1) +
                                  //             'x',
                                  //         style: TextStyle(
                                  //             color: Colors.white),
                                  //       ),
                                  //     ),
                                  //   ),
                                  // ),
                                  //   ],
                                  // ),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      const SizedBox(
                                        width: 55,
                                        height: 55,
                                      ),
                                      Align(
                                        alignment: Alignment.bottomCenter,
                                        child: InkWell(
                                          onTap: () async {
                                            XFile? rawImage =
                                                await takePicture();
                                            File imageFile =
                                                File(rawImage!.path);

                                            int currentUnix = DateTime.now()
                                                .millisecondsSinceEpoch;

                                            final directory =
                                                await getApplicationDocumentsDirectory();

                                            String fileFormat =
                                                imageFile.path.split('.').last;

                                            print(fileFormat);

                                            await imageFile.copy(
                                              '${directory.path}/$currentUnix.$fileFormat',
                                            );

                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    PreviewScreen(
                                                  imageFile: _imageFile!,
                                                  fileList: allFileList,
                                                ),
                                              ),
                                            );

                                            refreshAlreadyCapturedImages();
                                          },
                                          child: Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              Stack(
                                                alignment: Alignment.center,
                                                children: [
                                                  Container(
                                                    width: 90,
                                                    height: 90,
                                                    decoration: BoxDecoration(
                                                      color: Colors.transparent,
                                                      borderRadius:
                                                          const BorderRadius.all(
                                                              Radius.circular(
                                                                  1000)),
                                                      border: Border.all(
                                                        color: Colors.white
                                                            .withOpacity(0.5),
                                                        width: 2.5,
                                                      ),
                                                    ),
                                                  ),
                                                  Icon(
                                                    Icons.circle,
                                                    color: Colors.white
                                                        .withOpacity(0.90),
                                                    size: 80,
                                                  ),
                                                ],
                                              ),
                                              const Icon(
                                                FontAwesomeIcons.search,
                                                color: Colors.black,
                                                size: 32,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      Align(
                                        alignment: Alignment.bottomRight,
                                        child: InkWell(
                                          onTap: () {
                                            openGallery(
                                                context); // Call a function to open the gallery
                                          },
                                          // onTap: _imageFile != null
                                          //     ? () {
                                          //         Navigator.of(context).push(
                                          //           MaterialPageRoute(
                                          //             builder: (context) =>
                                          //                 PreviewScreen(
                                          //               imageFile:
                                          //                   _imageFile!,
                                          //               fileList: allFileList,
                                          //             ),
                                          //           ),
                                          //         );
                                          //       }
                                          //     : null,
                                          child: Container(
                                            width: 55,
                                            height: 55,
                                            decoration: BoxDecoration(
                                              color: Colors.black,
                                              borderRadius:
                                                  BorderRadius.circular(10.0),
                                              border: Border.all(
                                                color: Colors.white
                                                    .withOpacity(0.5),
                                                width: 2,
                                              ),
                                              image: _imageFile != null
                                                  ? DecorationImage(
                                                      image: FileImage(
                                                          _imageFile!),
                                                      fit: BoxFit.cover,
                                                    )
                                                  : null,
                                            ),
                                          ),
                                        ),
                                      )
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Align(
                              alignment: Alignment.center,
                              child: Container(
                                width: 200,
                                height: 200,
                                decoration: BoxDecoration(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                              ),
                            )
                          ],
                        ),
                      ),
                      // Expanded(
                      //   child: SingleChildScrollView(
                      //     physics: BouncingScrollPhysics(),
                      //     child: Column(
                      //       children: [
                      //         Padding(
                      //           padding: const EdgeInsets.fromLTRB(
                      //               16.0, 8.0, 16.0, 8.0),
                      //           child: Row(
                      //             mainAxisAlignment:
                      //                 MainAxisAlignment.spaceBetween,
                      //             children: [
                      //               InkWell(
                      //                 onTap: () async {
                      //                   setState(() {
                      //                     _currentFlashMode = FlashMode.off;
                      //                   });
                      //                   await controller!.setFlashMode(
                      //                     FlashMode.off,
                      //                   );
                      //                 },
                      //                 child: Icon(
                      //                   Icons.flash_off,
                      //                   color:
                      //                       _currentFlashMode == FlashMode.off
                      //                           ? Colors.amber
                      //                           : Colors.white,
                      //                 ),
                      //               ),
                      //               InkWell(
                      //                 onTap: () async {
                      //                   setState(() {
                      //                     _currentFlashMode = FlashMode.auto;
                      //                   });
                      //                   await controller!.setFlashMode(
                      //                     FlashMode.auto,
                      //                   );
                      //                 },
                      //                 child: Icon(
                      //                   Icons.flash_auto,
                      //                   color:
                      //                       _currentFlashMode == FlashMode.auto
                      //                           ? Colors.amber
                      //                           : Colors.white,
                      //                 ),
                      //               ),
                      //               InkWell(
                      //                 onTap: () async {
                      //                   setState(() {
                      //                     _currentFlashMode = FlashMode.always;
                      //                   });
                      //                   await controller!.setFlashMode(
                      //                     FlashMode.always,
                      //                   );
                      //                 },
                      //                 child: Icon(
                      //                   Icons.flash_on,
                      //                   color: _currentFlashMode ==
                      //                           FlashMode.always
                      //                       ? Colors.amber
                      //                       : Colors.white,
                      //                 ),
                      //               ),
                      //               InkWell(
                      //                 onTap: () async {
                      //                   setState(() {
                      //                     _currentFlashMode = FlashMode.torch;
                      //                   });
                      //                   await controller!.setFlashMode(
                      //                     FlashMode.torch,
                      //                   );
                      //                 },
                      //                 child: Icon(
                      //                   Icons.highlight,
                      //                   color:
                      //                       _currentFlashMode == FlashMode.torch
                      //                           ? Colors.amber
                      //                           : Colors.white,
                      //                 ),
                      //               ),
                      //             ],
                      //           ),
                      //         )
                      //       ],
                      //     ),
                      //   ),
                      // ),
                    ],
                  )
                : const Center(
                    child: Text(
                      'LOADING',
                      style: TextStyle(color: Colors.white),
                    ),
                  )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Row(),
                  const Text(
                    'Permission denied',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      getPermissionStatus();
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text(
                        'Give permission',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
