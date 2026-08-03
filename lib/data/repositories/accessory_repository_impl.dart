import 'package:dio/dio.dart';

import '../../domain/entities/consumable.dart';
import '../../domain/entities/robot_enums.dart';
import '../../domain/repositories/accessory_repository.dart';

const Map<ConsumableType, String> _backendTypeNames = {
  ConsumableType.mainBrush: 'MAIN_BRUSH',
  ConsumableType.sideBrush: 'SIDE_BRUSH',
  ConsumableType.filter: 'FILTER',
  ConsumableType.mopPad: 'MOP_PAD',
  ConsumableType.battery: 'BATTERY',
  ConsumableType.sensor: 'SENSOR',
};

class AccessoryRepositoryImpl implements AccessoryRepository {
  AccessoryRepositoryImpl({required this._dio});

  final Dio _dio;

  @override
  Future<void> sync(String robotId, Consumable consumable) async {
    await _dio.put<void>(
      '/robots/$robotId/accessories',
      data: {
        'type': _backendTypeNames[consumable.type],
        'remainingPercent': consumable.remainingPercent,
        'ratedLifetimeMinutes': consumable.ratedLifetimeMinutes,
        'usedMinutes': consumable.usedMinutes,
      },
    );
  }

  @override
  Future<void> markReplaced(String robotId, ConsumableType type) async {
    await _dio.post<void>(
      '/robots/$robotId/accessories/replace-by-type',
      data: {'type': _backendTypeNames[type]},
    );
  }
}
