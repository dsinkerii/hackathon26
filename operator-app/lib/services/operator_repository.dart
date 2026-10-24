import '../models/incident.dart';
import '../models/visitor.dart';

abstract interface class OperatorRepository {
  Future<List<Incident>> fetchIncidents();

  Future<List<Visitor>> fetchVisitors();

  Future<void> confirmVisitor(String id);
}
