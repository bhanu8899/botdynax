import '../entities/consumable.dart';
import '../entities/robot_enums.dart';

abstract class AccessoryRepository {
  /// Pushes the current live reading for one consumable up to the backend,
  /// so lifetime/replacement history survives beyond the live status feed.
  Future<void> sync(String robotId, Consumable consumable);

  Future<void> markReplaced(String robotId, ConsumableType type);
}
