class IceServer {
  const IceServer({required this.urls, this.username, this.credential});

  final List<String> urls;
  final String? username;
  final String? credential;

  factory IceServer.fromJson(Map<String, dynamic> json) => IceServer(
    urls: (json['urls'] as List<dynamic>? ?? const [])
        .map((value) => value.toString())
        .where((value) => value.isNotEmpty)
        .toList(),
    username: json['username'] as String?,
    credential: json['credential'] as String?,
  );

  Map<String, dynamic> toWebRtcJson() => {
    'urls': urls,
    if (username != null && username!.isNotEmpty) 'username': username,
    if (credential != null && credential!.isNotEmpty) 'credential': credential,
  };
}
