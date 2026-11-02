class AddressRepo {
  Future<List<dynamic>> fetchAddresses() async => [
    {'id': 'addr_1', 'line': '123 Main St', 'city': 'Anna Nagar'},
  ];
  Future<dynamic> createAddress(Map<String, dynamic> data) async => data;
}
