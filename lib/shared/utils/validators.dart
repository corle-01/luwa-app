/// Utility class for form validation
class Validators {
  /// Validate required field
  static String? required(String? value, {String fieldName = 'Field'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName tidak boleh kosong';
    }
    return null;
  }

  /// Validate email
  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email tidak boleh kosong';
    }

    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    if (!emailRegex.hasMatch(value)) {
      return 'Email tidak valid';
    }

    return null;
  }

  /// Validate phone number (Indonesian format)
  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Nomor telepon tidak boleh kosong';
    }

    final cleaned = value.replaceAll(RegExp(r'\D'), '');

    if (cleaned.length < 10 || cleaned.length > 13) {
      return 'Nomor telepon tidak valid (10-13 digit)';
    }

    if (!cleaned.startsWith('0') && !cleaned.startsWith('62')) {
      return 'Nomor telepon harus diawali 0 atau 62';
    }

    return null;
  }

  /// Validate password
  static String? password(String? value, {int minLength = 6}) {
    if (value == null || value.isEmpty) {
      return 'Password tidak boleh kosong';
    }

    if (value.length < minLength) {
      return 'Password minimal $minLength karakter';
    }

    return null;
  }

  /// Validate password confirmation
  static String? confirmPassword(String? value, String? originalPassword) {
    if (value == null || value.isEmpty) {
      return 'Konfirmasi password tidak boleh kosong';
    }

    if (value != originalPassword) {
      return 'Password tidak cocok';
    }

    return null;
  }

  /// Validate minimum length
  static String? minLength(String? value, int min, {String? fieldName}) {
    if (value == null || value.isEmpty) {
      return '${fieldName ?? 'Field'} tidak boleh kosong';
    }

    if (value.length < min) {
      return '${fieldName ?? 'Field'} minimal $min karakter';
    }

    return null;
  }

  /// Validate maximum length
  static String? maxLength(String? value, int max, {String? fieldName}) {
    if (value == null) return null;

    if (value.length > max) {
      return '${fieldName ?? 'Field'} maksimal $max karakter';
    }

    return null;
  }

  /// Validate number
  static String? number(String? value, {String? fieldName}) {
    if (value == null || value.trim().isEmpty) {
      return '${fieldName ?? 'Field'} tidak boleh kosong';
    }

    if (num.tryParse(value) == null) {
      return '${fieldName ?? 'Field'} harus berupa angka';
    }

    return null;
  }

  /// Validate minimum value
  static String? minValue(String? value, num min, {String? fieldName}) {
    if (value == null || value.trim().isEmpty) {
      return '${fieldName ?? 'Field'} tidak boleh kosong';
    }

    final numValue = num.tryParse(value);
    if (numValue == null) {
      return '${fieldName ?? 'Field'} harus berupa angka';
    }

    if (numValue < min) {
      return '${fieldName ?? 'Field'} minimal $min';
    }

    return null;
  }

  /// Validate maximum value
  static String? maxValue(String? value, num max, {String? fieldName}) {
    if (value == null || value.trim().isEmpty) {
      return '${fieldName ?? 'Field'} tidak boleh kosong';
    }

    final numValue = num.tryParse(value);
    if (numValue == null) {
      return '${fieldName ?? 'Field'} harus berupa angka';
    }

    if (numValue > max) {
      return '${fieldName ?? 'Field'} maksimal $max';
    }

    return null;
  }

  /// Validate URL
  static String? url(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'URL tidak boleh kosong';
    }

    final urlRegex = RegExp(
      r'^https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)$',
    );

    if (!urlRegex.hasMatch(value)) {
      return 'URL tidak valid';
    }

    return null;
  }

  /// Validate alphanumeric
  static String? alphanumeric(String? value, {String? fieldName}) {
    if (value == null || value.trim().isEmpty) {
      return '${fieldName ?? 'Field'} tidak boleh kosong';
    }

    final alphanumericRegex = RegExp(r'^[a-zA-Z0-9]+$');

    if (!alphanumericRegex.hasMatch(value)) {
      return '${fieldName ?? 'Field'} hanya boleh huruf dan angka';
    }

    return null;
  }

  /// Combine multiple validators
  static String? combine(List<String? Function(String?)> validators,
      String? value) {
    for (final validator in validators) {
      final error = validator(value);
      if (error != null) {
        return error;
      }
    }
    return null;
  }

  /// Custom validator
  static String? custom(
      String? value, bool Function(String?) test, String errorMessage) {
    if (!test(value)) {
      return errorMessage;
    }
    return null;
  }
}
