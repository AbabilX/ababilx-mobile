import 'package:equatable/equatable.dart';

class ChatDeliverySummary extends Equatable {
  const ChatDeliverySummary({
    required this.targetedDevices,
    required this.deliveredDevices,
    required this.readDevices,
  });

  final int targetedDevices;
  final int deliveredDevices;
  final int readDevices;

  factory ChatDeliverySummary.fromJson(Map<String, dynamic> json) =>
      ChatDeliverySummary(
        targetedDevices: (json['targeted_devices'] as num? ?? 0).toInt(),
        deliveredDevices: (json['delivered_devices'] as num? ?? 0).toInt(),
        readDevices: (json['read_devices'] as num? ?? 0).toInt(),
      );

  Map<String, dynamic> toJson() => {
    'targeted_devices': targetedDevices,
    'delivered_devices': deliveredDevices,
    'read_devices': readDevices,
  };

  @override
  List<Object?> get props => [targetedDevices, deliveredDevices, readDevices];
}
