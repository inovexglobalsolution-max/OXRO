class ProfileRepo {
  Future<Map<String, dynamic>> fetchProfile() async => {
    'name': 'User',
    'email': 'user@oxro.in',
  };
  Future<bool> updateProfile(Map<String, dynamic> data) async => true;
}
