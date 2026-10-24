import '../models/incident.dart';
import '../models/visitor.dart';

abstract interface class OperatorRepository {
  Future<List<Incident>> fetchIncidents();

  Future<List<Visitor>> fetchVisitors();

  Future<List<Visitor>> fetchWhitelist();

  Future<void> confirmVisitor(String id);

  /// Полное удаление посетителя (вместе с инцидентами) на сервере.
  Future<void> removeVisitor(String id);
}
