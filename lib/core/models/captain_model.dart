class CaptainModel {
  final String uid;
  final String name;
  final String phone;
  final String profilePic;
  final String carModel;
  final String carPlate;
  final String carColor;
  final double wallet;
  final double earnings;

  CaptainModel({
    required this.uid,
    required this.name,
    required this.phone,
    required this.profilePic,
    required this.carModel,
    required this.carPlate,
    required this.carColor,
    required this.wallet,
    required this.earnings,
  });

  // تحويل البيانات القادمة من الفايربيز (Map) إلى Model يفهمه فلاتر
  factory CaptainModel.fromMap(Map<String, dynamic> map, String documentId) {
    return CaptainModel(
      uid: documentId,
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      profilePic: map['profilePic'] ?? '',
      carModel: map['carModel'] ?? '',
      carPlate: map['carPlate'] ?? '',
      carColor: map['carColor'] ?? '',
      wallet: (map['wallet'] ?? 0).toDouble(),
      earnings: (map['earnings'] ?? 0).toDouble(),
    );
  }

  // تحويل البيانات من الموديل إلى Map لحفظها في الفايربيز عند التعديل
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'profilePic': profilePic,
      'carModel': carModel,
      'carPlate': carPlate,
      'carColor': carColor,
      'wallet': wallet,
      'earnings': earnings,
    };
  }
}
