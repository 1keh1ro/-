import 'dart:async';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_hand_landmarker/google_mlkit_hand_landmarker.dart';
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const JankenApp());
}

class JankenApp extends StatelessWidget {
  const JankenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Janken Prototype',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const JankenHomePage(),
    );
  }
}

class JankenHomePage extends StatefulWidget {
  const JankenHomePage({super.key});

  @override
  State<JankenHomePage> createState() => _JankenHomePageState();
}

class _JankenHomePageState extends State<JankenHomePage> {
  CameraController? _cameraController;
  HandLandmarker? _handLandmarker;
  bool _isProcessing = false;
  String _playerHand = "認識中...";
  String _aiHand = "-";
  String _result = "じゃんけん...";
  DateTime? _lastInferenceTime;

  // AI判定の間隔（ミリ秒）: 0.5秒に1回
  static const int _inferenceIntervalMs = 500;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _initializeAI();
  }

  Future<void> _initializeCamera() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      // フロントカメラを優先的に使用
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      if (!mounted) return;

      // リアルタイム映像ストリームの開始
      _cameraController!.startImageStream(_processCameraImage);
      setState(() {});
    }
  }

  void _initializeAI() {
    // Google ML Kit Hand Landmarkerの初期化
    final options = HandLandmarkerOptions(
      baseOptions: BaseOptions(modelAssetPath: 'hand_landmarker.task'),
      runningMode: RunningMode.liveStream,
    );
    _handLandmarker = HandLandmarker.create(options);
  }

  // カメラ映像の各フレームを処理するメソッド
  void _processCameraImage(CameraImage image) async {
    final now = DateTime.now();
    
    // スロットリング処理: 前回の推論から一定時間経過していない場合はスキップ
    if (_lastInferenceTime != null &&
        now.difference(_lastInferenceTime!).inMilliseconds < _inferenceIntervalMs) {
      return;
    }

    if (_isProcessing) return;
    _isProcessing = true;
    _lastInferenceTime = now;

    try {
      // 本来はここでCameraImageをInputImageに変換し、ML Kitに渡す
      // ※ここではプロトタイプとして、骨格座標からグー・チョキ・パーを判定するロジックのプレースホルダーを実装
      
      final recognizedHand = _detectHandGesture(image);

      if (mounted) {
        setState(() {
          _playerHand = recognizedHand;
        });
      }
    } catch (e) {
      debugPrint("AI Inference Error: $e");
    } finally {
      _isProcessing = false;
    }
  }

  // 骨格検出の座標からグー・チョキ・パーを判定するロジックのプレースホルダー
  String _detectHandGesture(CameraImage image) {
    // 実際のプロジェクトでは、_handLandmarker.process(inputImage) を使用し、
    // 取得したランドマーク（指の関節座標）の相対位置関係から判定します。
    // 例:
    // - すべての指が曲がっている -> グー
    // - 人差し指と中指が伸びている -> チョキ
    // - すべての指が伸びている -> パー
    
    // デモ用にランダムに変化させる（実際の実装ではML Kitの結果を反映）
    final hands = ["グー", "チョキ", "パー", "なし"];
    return hands[Random().nextInt(3)]; // 常に何かしら出している想定
  }

  void _playJanken() {
    if (_playerHand == "なし" || _playerHand == "認識中...") return;

    final hands = ["グー", "チョキ", "パー"];
    final aiChoice = hands[Random().nextInt(3)];

    String gameResult;
    if (_playerHand == aiChoice) {
      gameResult = "あいこ！";
    } else if ((_playerHand == "グー" && aiChoice == "チョキ") ||
        (_playerHand == "チョキ" && aiChoice == "パー") ||
        (_playerHand == "パー" && aiChoice == "グー")) {
      gameResult = "あなたの勝ち！";
    } else {
      gameResult = "あなたの負け...";
    }

    setState(() {
      _aiHand = aiChoice;
      _result = gameResult;
    });
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _handLandmarker?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Stack(
        children: [
          // 画面全体：カメラプレビュー
          Positioned.fill(
            child: AspectRatio(
              aspectRatio: _cameraController!.value.aspectRatio,
              child: CameraPreview(_cameraController!),
            ),
          ),

          // 画面下部：UIオーバーレイ
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "あなたの手: $_playerHand",
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildInfoColumn("AIの手", _aiHand),
                      _buildInfoColumn("結果", _result),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _playJanken,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                    ),
                    child: const Text("ポン！", style: TextStyle(fontSize: 20)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoColumn(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 16)),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
