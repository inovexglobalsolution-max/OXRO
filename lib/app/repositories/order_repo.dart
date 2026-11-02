import '../models/order_models.dart';

class OrderRepo {
  Future<List<OrderResponse>> fetchOrders() async => [
    OrderResponse(id: 'OXRO123457', status: 'shipped', date: '12 Aug', products: []),
  ];

  Future<OrderResponse> fetchOrderById(String id) async => OrderResponse(
    id: id, status: 'scaffold', date: 'Today', products: [],
  );

  Future<List<dynamic>> trackingSteps(String id) async => [
    {'label': 'Order Placed', 'time': '10:30 AM'},
  ];
}
