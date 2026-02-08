/// AI Function Call model
///
/// Represents a function call made by the AI during a conversation.
/// Function calls allow the AI to interact with external systems
/// (e.g., checking stock, creating orders, etc.).
class AiFunctionCall {
  final String name;
  final Map<String, dynamic> arguments;
  final Map<String, dynamic>? result;

  const AiFunctionCall({
    required this.name,
    this.arguments = const {},
    this.result,
  });

  /// Whether this function call has been executed and has a result.
  bool get hasResult => result != null;

  /// Whether the function call result indicates success.
  bool get isSuccess {
    if (result == null) return false;
    return result!['success'] == true ||
        result!['error'] == null;
  }

  /// Get the error message from the result, if any.
  String? get errorMessage {
    if (result == null) return null;
    return result!['error'] as String?;
  }

  factory AiFunctionCall.fromJson(Map<String, dynamic> json) {
    return AiFunctionCall(
      name: json['name'] as String? ?? '',
      arguments: json['arguments'] != null
          ? Map<String, dynamic>.from(json['arguments'] as Map)
          : const {},
      result: json['result'] != null
          ? Map<String, dynamic>.from(json['result'] as Map)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'arguments': arguments,
      'result': result,
    };
  }

  AiFunctionCall copyWith({
    String? name,
    Map<String, dynamic>? arguments,
    Map<String, dynamic>? result,
  }) {
    return AiFunctionCall(
      name: name ?? this.name,
      arguments: arguments ?? this.arguments,
      result: result ?? this.result,
    );
  }

  @override
  String toString() =>
      'AiFunctionCall(name: $name, hasResult: $hasResult)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AiFunctionCall &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          arguments.toString() == other.arguments.toString();

  @override
  int get hashCode => Object.hash(name, arguments.toString());
}
