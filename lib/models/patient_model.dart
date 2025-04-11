class Patient {
  String? id;
  String? name;
  String? email;
  String? address;
  int? age;
  String? bloodGroup;
  String? contactNumber;
  String? gender;

  Patient({
    this.id,
    this.name,
    this.email,
    this.address,
    this.age,
    this.bloodGroup,
    this.contactNumber,
    this.gender,
  });

  factory Patient.fromJson(Map<String, dynamic> json) {
    return Patient(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      address: json['address'],
      age: json['age'],
      bloodGroup: json['bloodGroup'],
      contactNumber: json['contactNumber'],
      gender: json['gender'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'address': address,
      'age': age,
      'bloodGroup': bloodGroup,
      'contactNumber': contactNumber,
      'gender': gender,
    };
  }
}
