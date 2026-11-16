import 'package:caspertrainingstudio/features/protocols/data/protocol_repository.dart';
import 'package:caspertrainingstudio/features/protocols/domain/protocol_models.dart';

class FakeProtocolRepository implements ProtocolRepository {
  List<Protocol> protocols = [];
  final Map<String, Protocol?> memberProtocols = {};
  PublicPriceList priceList = const PublicPriceList(
    categories: [],
    protocols: [],
  );
  final List<({String memberId, String? protocolId})> setCalls = [];
  final List<Map<String, Object?>> saveCalls = [];

  @override
  Future<List<Protocol>> list() async => protocols;

  @override
  Future<void> save({
    String? id,
    required String name,
    required int discountPercent,
    required bool isActive,
    DateTime? validUntil,
    String? note,
  }) async {
    saveCalls.add({
      'id': id,
      'name': name,
      'discount_percent': discountPercent,
      'is_active': isActive,
      'valid_until': validUntil,
      'note': note,
    });
  }

  @override
  Future<Protocol?> memberProtocol(String memberId) async =>
      memberProtocols[memberId];

  @override
  Future<void> setMemberProtocol(String memberId, String? protocolId) async {
    setCalls.add((memberId: memberId, protocolId: protocolId));
    memberProtocols[memberId] = protocolId == null
        ? null
        : protocols.firstWhere((p) => p.id == protocolId);
  }

  @override
  Future<PublicPriceList> publicPriceList() async => priceList;
}
