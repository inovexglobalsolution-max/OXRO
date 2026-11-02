class OrderResponse {
  final String id;
  final String status;
  final String date;
  final List<dynamic> products;

  OrderResponse({required this.id, required this.status, required this.date, required this.products});

  factory OrderResponse.fromJson(Map<String, dynamic> json) {
    return OrderResponse(
      id: json['id'] ?? '',
      status: json['status'] ?? '',
      date: json['date'] ?? '',
      products: json['products'] ?? [],
    );
  }
}
