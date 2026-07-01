class VsuiteInstance {
  final String id;        // unique key (uuid or index string)
  final String label;     // display name e.g. "VIMS-V-Suite"
  final String url;       // base URL e.g. "http://14.139.184.39:8101"
  final String email;     // chairman email
  String? cachedToken;    // cross-auth Bearer token (non-persistent; use StorageService)

  VsuiteInstance({
    required this.id,
    required this.label,
    required this.url,
    required this.email,
    this.cachedToken,
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'label': label, 'url': url, 'email': email,
  };

  factory VsuiteInstance.fromJson(Map<String, dynamic> j) => VsuiteInstance(
    id: (j['id'] ?? '').toString(),
    label: j['label'] as String? ?? '',
    url: j['url'] as String? ?? '',
    email: j['email'] as String? ?? '',
  );

  VsuiteInstance copyWith({String? label, String? url, String? email}) => VsuiteInstance(
    id: id,
    label: label ?? this.label,
    url: url ?? this.url,
    email: email ?? this.email,
    cachedToken: cachedToken,
  );
}
