import 'package:timelock/utils/app_settings.dart';

class AppMotion {
  static Duration duration(Duration base) {
    if (AppSettings.notifier.value.reduceAnimations) {
      return Duration.zero;
    }
    return base;
  }
}
