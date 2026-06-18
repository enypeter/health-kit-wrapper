/// Platform health SDK availability status.
///
/// On Android this reflects Health Connect installation state.
/// On iOS this reflects whether HealthKit is available on the device.
enum SdkStatus {
  /// The health SDK is available and ready to use.
  available,

  /// Android only: Health Connect needs to be installed from the Play Store.
  notInstalled,

  /// The health SDK is not available on this device.
  unavailable;

  /// Parse the string returned by the native platform channel.
  static SdkStatus fromString(String value) => switch (value) {
    'available'    => SdkStatus.available,
    'notInstalled' => SdkStatus.notInstalled,
    _              => SdkStatus.unavailable,
  };
}
