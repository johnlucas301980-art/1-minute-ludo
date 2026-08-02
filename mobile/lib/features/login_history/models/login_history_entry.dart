/// A single login history record returned by the backend.
class LoginHistoryEntry {
  const LoginHistoryEntry({
    required this.id,
    required this.loginTime,
    this.deviceName,
    this.platform,
    this.country,
    required this.loginMethod,
  });

  final String  id;
  final String  loginTime;
  final String? deviceName;
  final String? platform;
  final String? country;
  final String  loginMethod; // 'email' | 'mobile' | 'google'

  factory LoginHistoryEntry.fromJson(Map<String, dynamic> json) {
    return LoginHistoryEntry(
      id:          json['id']           as String,
      loginTime:   json['login_time']   as String,
      deviceName:  json['device_name']  as String?,
      platform:    json['platform']     as String?,
      country:     json['country']      as String?,
      loginMethod: json['login_method'] as String,
    );
  }
}
