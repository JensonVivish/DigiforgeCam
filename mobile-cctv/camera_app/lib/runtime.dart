import 'background.dart';
import 'camera_service.dart';

/// App-wide singletons. They are created and started from main(), so the
/// camera runs even when no screen exists (boot start, app swiped away).
final CameraService cameraService = CameraService();
final BackgroundController backgroundController =
    BackgroundController(cameraService);

bool _started = false;

Future<void> startRuntime() async {
  if (_started) return;
  _started = true;
  await backgroundController.init(); // registers the "camera ready" hook first
  await cameraService.start();
}
