import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show Rect, Size;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// 화면 위 얼굴 위치 목록.
class LiveFaces {
  const LiveFaces(this.boxes, this.upright);

  /// 똑바로 선 카메라 화면 기준의 얼굴 상자
  final List<Rect> boxes;

  /// 똑바로 선 카메라 화면 크기
  final Size upright;
}

/// 카메라 화면(꽉 채워 자른 상태)에서의 위치로 바꾼다. [mirror] 는 전면 카메라.
Rect mapToScreen(Rect box, Size upright, Size screen, {bool mirror = false}) {
  final s = math.max(screen.width / upright.width, screen.height / upright.height);
  final ox = (screen.width - upright.width * s) / 2;
  final oy = (screen.height - upright.height * s) / 2;
  var l = box.left * s + ox, r = box.right * s + ox;
  final t = box.top * s + oy, b = box.bottom * s + oy;
  if (mirror) {
    final nl = screen.width - r, nr = screen.width - l;
    l = nl;
    r = nr;
  }
  return Rect.fromLTRB(l, t, r, b);
}

/// 카메라 영상(미리보기 프레임)에서 얼굴을 찾는다. 폰 안에서만 처리한다.
class LiveFaceDetector {
  LiveFaceDetector() : _detector = FaceDetector(options: FaceDetectorOptions(performanceMode: FaceDetectorMode.fast));

  final FaceDetector _detector;
  bool _busy = false;

  /// Android 는 NV21, iPhone 은 BGRA 로 영상을 받아야 ML Kit 이 읽을 수 있다.
  static ImageFormatGroup get streamFormat => Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888;

  Future<LiveFaces?> detect(CameraImage image, CameraDescription cam) async {
    if (_busy || image.planes.length != 1) return null;
    _busy = true;
    try {
      final rotation = switch (cam.sensorOrientation) {
        90 => InputImageRotation.rotation90deg,
        180 => InputImageRotation.rotation180deg,
        270 => InputImageRotation.rotation270deg,
        _ => InputImageRotation.rotation0deg,
      };
      final plane = image.planes.first;
      final input = InputImage.fromBytes(
        bytes: plane.bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: Platform.isAndroid ? InputImageFormat.nv21 : InputImageFormat.bgra8888,
          bytesPerRow: plane.bytesPerRow,
        ),
      );
      final faces = await _detector.processImage(input);
      final sideways = rotation == InputImageRotation.rotation90deg || rotation == InputImageRotation.rotation270deg;
      final upright = sideways ? Size(image.height.toDouble(), image.width.toDouble()) : Size(image.width.toDouble(), image.height.toDouble());
      return LiveFaces([for (final f in faces) f.boundingBox], upright);
    } catch (e) {
      debugPrint('live face detect failed: $e');
      return null;
    } finally {
      _busy = false;
    }
  }

  Future<void> close() => _detector.close();
}
