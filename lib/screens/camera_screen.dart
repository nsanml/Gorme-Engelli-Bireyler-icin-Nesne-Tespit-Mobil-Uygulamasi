import 'dart:convert';
import 'dart:ui'; 
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tflite_v2/tflite_v2.dart';
import '../services/tts_service.dart';
import '../services/feature_extractor_service.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  final TTSService _tts = TTSService();
  bool _isWorking = false;
  String _detectedObject = "Sistem Başlatılıyor...";
  String _lastSpokenText = "";
  int _frameCount = 0;
  
  DateTime _lastSpeechTime = DateTime.now(); 
  final Duration _shortCooldown = const Duration(seconds: 4); 
  final Duration _longCooldown = const Duration(seconds: 12); 

  bool _isCalibrating = false;         
  bool _isRegisteringObject = false; 

  double _currentMaxBottomY = 0.0;     
  double _dangerThresholdY = 0.85; 
  
  String _currentClosestObject = ""; 
  Map<dynamic, dynamic>? _currentClosestRect; 
  CameraImage? _lastFrame; 

  Map<String, List<int>> _familiarObjects = {};
  Set<String> _recentlySeenClasses = {}; 

  final String _welcomeMessage = "Uygulamaya hoş geldiniz. Bu uygulama nesneleri algılar ve yakından uzağa seslendirir. Sağ üstteki butonla tehlike mesafesini belirleyebilirsiniz. Sol alttaki butonla size ait özel bir nesneyi sisteme tanıtabilirsiniz. Yardımı tekrar dinlemek için sol üstteki butona basın.";


  final Map<String, String> _targetMap = {
    "person": "İnsan",
    "chair": "Sandalye",
    "dining table": "Masa",
    "tv": "Televizyon",
    "tvmonitor": "Televizyon",
    "couch": "Koltuk",
    "bed": "Yatak",
    "refrigerator": "Buzdolabı",
    "book": "Kitap",
    "laptop": "Bilgisayar",
    "microwave": "Mikrodalga",
    "cell phone": "Telefon"
  };

  @override
  void initState() {
    super.initState();
    _startSystem();
    _loadSettings(); 
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    setState(() {
      String? jsonStr = prefs.getString('familiar_objects_map');
      if (jsonStr != null) {
        Map<String, dynamic> decoded = json.decode(jsonStr);
        _familiarObjects = decoded.map((key, value) => MapEntry(key, List<int>.from(value)));
      }
    });

    bool isFirstRun = prefs.getBool('is_first_run') ?? true;
    if (isFirstRun) {
      await Future.delayed(const Duration(seconds: 2));
      _tts.speak(_welcomeMessage);
      await prefs.setBool('is_first_run', false);
    }
  }

  Future<void> _startSystem() async {
    try {
      await Tflite.loadModel(model: "assets/detect.tflite", labels: "assets/labelmap.txt");
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;
      _controller = CameraController(cameras[0], ResolutionPreset.low, enableAudio: false);
      await _controller!.initialize();
      if (mounted) setState(() => _detectedObject = "Kamera Hazır...");
      _controller!.startImageStream((CameraImage image) {
        _frameCount++;
        if (_frameCount % 30 == 0 && !_isWorking) {
          _isWorking = true;
          _lastFrame = image; 
          _analyzeFrame(image);
        }
      });
    } catch (e) {
      debugPrint("Hata: $e");
    }
  }

  Future<void> _analyzeFrame(CameraImage image) async {
    try {
      var results = await Tflite.detectObjectOnFrame(
        bytesList: image.planes.map((p) => p.bytes).toList(),
        model: "SSDMobileNet",
        imageHeight: image.height,
        imageWidth: image.width,
        imageMean: 127.5,
        imageStd: 127.5,
        rotation: 90,
        numResultsPerClass: 5,
        threshold: 0.55, 
      );

      Map<String, int> currentFrameDetections = {};
      Map<String, double> closestEdgePerClass = {}; 
      Set<String> currentFrameClasses = {}; 
      
      double frameMaxBottomY = 0.0;
      String closestObject = "";
      Map<dynamic, dynamic>? closestRect;
      
      bool delaySpeechForFocus = false; 

      if (results != null && results.isNotEmpty) {
        for (var res in results) {
          String label = res['detectedClass'];
          if (_targetMap.containsKey(label)) {
            
            String originalName = _targetMap[label]!;
            currentFrameClasses.add(originalName);
            String finalName = originalName;
            var rect = res['rect'];
            
            if (_familiarObjects.containsKey(originalName)) {
              List<int> currentVector = FeatureExtractorService.extractColorSignature(image, rect);
              List<int> savedVector = _familiarObjects[originalName]!;
              
              double distance = FeatureExtractorService.calculateSimilarity(savedVector, currentVector);
              
              if (distance < 120.0) {
                finalName = "Bilinen $originalName";
              } else {
                if (!_recentlySeenClasses.contains(originalName)) {
                  delaySpeechForFocus = true;
                }
              }
            }

            currentFrameDetections[finalName] = (currentFrameDetections[finalName] ?? 0) + 1;
            double bottomEdge = rect['y'] + rect['h'];
            
            if (bottomEdge > frameMaxBottomY) {
              frameMaxBottomY = bottomEdge;
              closestObject = finalName;
              closestRect = rect;
            }
            if (!closestEdgePerClass.containsKey(finalName) || bottomEdge > closestEdgePerClass[finalName]!) {
              closestEdgePerClass[finalName] = bottomEdge;
            }
          }
        }
      }

      _recentlySeenClasses = currentFrameClasses;
      _currentMaxBottomY = frameMaxBottomY;
      _currentClosestObject = closestObject;
      _currentClosestRect = closestRect;

      if (_isCalibrating || _isRegisteringObject) { _isWorking = false; return; }

      if (currentFrameDetections.isNotEmpty) {
        List<String> sortedClasses = currentFrameDetections.keys.toList();
        sortedClasses.sort((a, b) => closestEdgePerClass[b]!.compareTo(closestEdgePerClass[a]!));

        List<String> detectedItems = [];
        for (String className in sortedClasses) {
          detectedItems.add("${currentFrameDetections[className]} $className");
        }

        String displayText = detectedItems.join("\n");
        String speechText = "";
        
        bool dangerActive = closestObject.isNotEmpty && (closestEdgePerClass[closestObject]! >= _dangerThresholdY);

        int totalUniqueItems = detectedItems.length;
        String listSpeech = "";
        if (totalUniqueItems == 1) {
          listSpeech = "${detectedItems[0]} var.";
        } else {
          List<String> itemsCopy = List.from(detectedItems);
          String lastItem = itemsCopy.removeLast();
          String joinedText = itemsCopy.join(", ") + " ve " + lastItem;
          listSpeech = "$joinedText var.";
        }

        if (dangerActive) {
          if (totalUniqueItems == 1) {
            speechText = "DİKKAT! Önünüzde $closestObject var.";
          } else {
            speechText = "DİKKAT! Önünüzde $closestObject var, $listSpeech";
          }
          displayText += "\n⚠️ Tehlike: $closestObject";
        } else {
          speechText = "Önünüzde $listSpeech";
        }

        if (delaySpeechForFocus) {
          if (mounted) setState(() => _detectedObject = displayText);
        } else {
          if (mounted) setState(() => _detectedObject = displayText);

          bool isShortCooldownOver = DateTime.now().difference(_lastSpeechTime) > _shortCooldown;
          bool isLongCooldownOver = DateTime.now().difference(_lastSpeechTime) > _longCooldown;
          bool isContextChanged = speechText != _lastSpokenText;
          bool isUpgrade = speechText.contains("Bilinen") && !_lastSpokenText.contains("Bilinen");

          if ((isContextChanged && isShortCooldownOver) || isLongCooldownOver || isUpgrade) {
               _tts.speak(speechText);
               _lastSpokenText = speechText;
               _lastSpeechTime = DateTime.now();
          }
        }
      } else {
        if (mounted) setState(() => _detectedObject = "Taranıyor...");
      }
    } catch (e) {
      debugPrint("Hata: $e");
    } finally {
      await Future.delayed(const Duration(milliseconds: 600));
      _isWorking = false;
    }
  }

  Widget _buildGlassButton({required IconData icon, required VoidCallback onTap, Color color = Colors.white}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 55,
            height: 55,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: Colors.white)));
    }
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: CameraPreview(_controller!)),
          
          if (!_isCalibrating && !_isRegisteringObject)
            Positioned(
              top: MediaQuery.of(context).size.height * _dangerThresholdY,
              left: 20, right: 20,
              child: Container(
                height: 2, 
                decoration: BoxDecoration(
                  boxShadow: [BoxShadow(color: Colors.redAccent.withOpacity(0.8), blurRadius: 10, spreadRadius: 2)],
                  color: Colors.redAccent,
                ),
              ),
            ),
          Positioned(
            top: 60, left: 20, 
            child: _buildGlassButton(icon: Icons.help_outline_rounded, onTap: () => _tts.speak(_welcomeMessage))
          ),

          Positioned(
            top: 60, right: 20, 
            child: _buildGlassButton(icon: Icons.height_rounded, onTap: () { setState(() => _isCalibrating = true); _tts.speak("Kalibrasyon modu aktif."); })
          ),

          Positioned(
            bottom: 150, left: 20,
            child: _buildGlassButton(icon: Icons.star_border_rounded, color: Colors.amberAccent, onTap: () {
              setState(() => _isRegisteringObject = true);
              _tts.speak("Nesne tanıtma modu. Lütfen tanıtmak istediğiniz nesneye yaklaşıp ekrana dokunun.");
            })
          ),

   
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 40, left: 20, right: 20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Text(
                      _detectedObject, 
                      textAlign: TextAlign.center, 
                      style: const TextStyle(
                        color: Colors.white, 
                        fontSize: 22, 
                        fontWeight: FontWeight.w600, 
                        letterSpacing: 0.5,
                        height: 1.4
                      )
                    ),
                  ),
                ),
              ),
            ),
          ),


          if (_isCalibrating || _isRegisteringObject)
            Positioned.fill(
              child: GestureDetector(
                onTap: () async { 
                  if (_isCalibrating) {
                    if (_currentMaxBottomY > 0) { 
                      setState(() { _dangerThresholdY = _currentMaxBottomY; _isCalibrating = false; }); 
                      _tts.speak("Mesafe kaydedildi."); 
                    } else { 
                      _tts.speak("Nesne bulunamadı, tekrar dokunun."); 
                    } 
                  }
                  else if (_isRegisteringObject) {
                    if (_currentClosestObject.isNotEmpty && _lastFrame != null && _currentClosestRect != null) {
                      String rawName = _currentClosestObject.replaceAll("Bilinen ", "");
                      
                      List<int> extractedVector = FeatureExtractorService.extractColorSignature(_lastFrame!, _currentClosestRect!);
                      
                      _familiarObjects[rawName] = extractedVector;
                      
                      final prefs = await SharedPreferences.getInstance();
                      String jsonStr = json.encode(_familiarObjects);
                      await prefs.setString('familiar_objects_map', jsonStr);
                      
                      setState(() { _isRegisteringObject = false; });
                      
                      _tts.speak("$rawName başarıyla kişisel nesneleriniz arasına eklendi.");
                    } else {
                      _tts.speak("Ekranda nesne algılanamadı, tekrar dokunun.");
                    }
                  }
                },
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    color: Colors.black.withOpacity(0.3), 
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(30),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(25),
                          border: Border.all(color: Colors.white.withOpacity(0.2)),
                        ),
                        child: Text(
                          _isCalibrating ? "KALİBRASYON MODU\n\nKAYDETMEK İÇİN\nEKRANA DOKUNUN" : "NESNE TANITMA\n\nKAYDETMEK İÇİN\nEKRANA DOKUNUN", 
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500, height: 1.5), 
                          textAlign: TextAlign.center
                        ),
                      )
                    )
                  ),
                )
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() { _controller?.dispose(); Tflite.close(); super.dispose(); }
}
