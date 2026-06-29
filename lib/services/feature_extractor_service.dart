import 'package:camera/camera.dart';
import 'dart:math';

class FeatureExtractorService {
  static List<int> extractColorSignature(CameraImage image, Map<dynamic, dynamic> rect) {
    try {
      int startX = (rect['x'] * image.width).toInt();
      int startY = (rect['y'] * image.height).toInt();
      int boxWidth = (rect['w'] * image.width).toInt();
      int boxHeight = (rect['h'] * image.height).toInt();

      int centerX = startX + (boxWidth ~/ 2);
      int centerY = startY + (boxHeight ~/ 2);

      int rSum = 0, gSum = 0, bSum = 0;
      int pixelCount = 0;

      for (int y = max(0, centerY - 10); y < min(image.height, centerY + 10); y += 2) {
        for (int x = max(0, centerX - 10); x < min(image.width, centerX + 10); x += 2) {
          final int uvIndex = (image.planes[1].bytesPerRow * (y ~/ 2)) + (x ~/ 2) * image.planes[1].bytesPerPixel!;
          final int yIndex = (y * image.planes[0].bytesPerRow) + x;

          if (yIndex >= image.planes[0].bytes.length || uvIndex >= image.planes[1].bytes.length) continue;

          final int yValue = image.planes[0].bytes[yIndex];
          final int uValue = image.planes[1].bytes[uvIndex];
          final int vValue = image.planes[2].bytes[uvIndex];

          int r = (yValue + 1.402 * (vValue - 128)).toInt();
          int g = (yValue - 0.344136 * (uValue - 128) - 0.714136 * (vValue - 128)).toInt();
          int b = (yValue + 1.772 * (uValue - 128)).toInt();

          rSum += r.clamp(0, 255);
          gSum += g.clamp(0, 255);
          bSum += b.clamp(0, 255);
          pixelCount++;
        }
      }

      if (pixelCount == 0) return [0, 0, 0];
      return [rSum ~/ pixelCount, gSum ~/ pixelCount, bSum ~/ pixelCount];

    } catch (e) {
      return [0, 0, 0];
    }
  }
  static double calculateSimilarity(List<int> vector1, List<int> vector2) {
    if (vector1.length != 3 || vector2.length != 3) return 1000.0; 
    
    num sum = pow(vector1[0] - vector2[0], 2) + 
              pow(vector1[1] - vector2[1], 2) + 
              pow(vector1[2] - vector2[2], 2);
              
    return sqrt(sum); 
  }
}
