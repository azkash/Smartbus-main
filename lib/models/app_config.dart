enum AppMode {
  full,
  passengerOnly,
}

class AppConfig {
  static AppMode mode = AppMode.full;

  static bool get isPassengerOnly => mode == AppMode.passengerOnly;
  static bool get isFull => mode == AppMode.full;
}
