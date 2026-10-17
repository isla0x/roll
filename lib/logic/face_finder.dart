import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'retouch.dart';

/// 폰 안에서 얼굴 위치를 찾는다 (서버 없음). 실패하면 빈 목록.
Future<List<FaceBox>> findFaces(String path) async {
  final detector = FaceDetector(options: FaceDetectorOptions(performanceMode: FaceDetectorMode.fast));
  try {
    final faces = await detector.processImage(InputImage.fromFilePath(path)).timeout(const Duration(seconds: 4));
    return [
      for (final f in faces)
        FaceBox(f.boundingBox.left, f.boundingBox.top, f.boundingBox.width, f.boundingBox.height),
    ];
  } catch (e) {
    debugPrint('face detect failed: $e');
    return const [];
  } finally {
    await detector.close();
  }
}
