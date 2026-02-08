import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/pos_refund_repository.dart';

final posRefundRepositoryProvider = Provider((ref) => PosRefundRepository());
