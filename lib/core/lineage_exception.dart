class LineageException implements Exception {
  final String message;
  const LineageException([this.message = 'Missing or invalid predecessor_id: orphan data rejected.']);

  @override
  String toString() => 'LineageException: $message';
}