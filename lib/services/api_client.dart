/// Backend-ready API contract. Swap [MockApiClient] for [HttpApiClient]
/// when connecting to Firebase or a REST server.
abstract class ApiClient {
  Future<List<Map<String, dynamic>>> fetchAnnouncements();
  Future<void> postAnnouncement(Map<String, dynamic> data);
  Future<List<Map<String, dynamic>>> fetchGradeReports({String? className});
  Future<List<Map<String, dynamic>>> fetchConversations();
  Future<void> postMessage(String conversationId, String text);
}

/// Placeholder for future HTTP/Firebase implementation.
class HttpApiClient implements ApiClient {
  HttpApiClient({required this.baseUrl});

  final String baseUrl;

  @override
  Future<List<Map<String, dynamic>>> fetchAnnouncements() async {
    throw UnimplementedError('Connect to $baseUrl/announcements');
  }

  @override
  Future<void> postAnnouncement(Map<String, dynamic> data) async {
    throw UnimplementedError('Connect to $baseUrl/announcements');
  }

  @override
  Future<List<Map<String, dynamic>>> fetchGradeReports({String? className}) async {
    throw UnimplementedError('Connect to $baseUrl/grades');
  }

  @override
  Future<List<Map<String, dynamic>>> fetchConversations() async {
    throw UnimplementedError('Connect to $baseUrl/messages');
  }

  @override
  Future<void> postMessage(String conversationId, String text) async {
    throw UnimplementedError('Connect to $baseUrl/messages/$conversationId');
  }
}
