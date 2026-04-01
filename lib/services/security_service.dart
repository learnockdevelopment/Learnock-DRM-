import 'dart:io';
import 'package:no_screenshot/no_screenshot.dart';
import 'package:safe_device/safe_device.dart';

class SecurityService {
  static final _noScreenshot = NoScreenshot.instance;

  static Future<void> setupSecurity() async {
    await _noScreenshot.screenshotOff();
  }

  static Future<bool> isDeviceSafe() async {
    bool isReal = await SafeDevice.isRealDevice;
    bool isJailBroken = await SafeDevice.isJailBroken;
    bool isDeveloperOptionsEnabled = await SafeDevice.isDevelopmentModeEnable;

    if (!isReal) return false;
    if (isJailBroken) return false;
    if (isDeveloperOptionsEnabled && Platform.isAndroid) return false;
    return true;
  }
  static void exitApp() {
    exit(0);
  }
}
