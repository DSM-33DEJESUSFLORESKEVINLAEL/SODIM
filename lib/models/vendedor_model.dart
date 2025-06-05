class Vendedor {
  final String  id;           // ← VENDEDOR
  final String claveCel;  // ← CLAVE_CEL
  final String nombre;    // ← NOMBRE
  final String mail;      // ← MAIL
  final int empresa;      // ← EMPRESA

  Vendedor({
    required this.id,
    required this.claveCel,
    required this.nombre,
    required this.mail,
    required this.empresa,
  });

  factory Vendedor.fromJson(Map<String, dynamic> json) {
    return Vendedor(
      id: json['VENDEDOR'].toString(),  // 🔒 Conserva ceros
      claveCel: json['CLAVE_CEL'] ?? '',
      nombre: json['NOMBRE'] ?? '',
      mail: json['MAIL'] ?? '',
      empresa: int.tryParse(json['EMPRESA'].toString()) ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'clave_cel': claveCel,
      'nombre': nombre,
      'mail': mail,
      'empresa': empresa,
    };
  }

  // ✅ Este método permite guardar en SharedPreferences
  Map<String, dynamic> toJson() {
    return {
      'VENDEDOR': id,
      'CLAVE_CEL': claveCel,
      'NOMBRE': nombre,
      'MAIL': mail,
      'EMPRESA': empresa,
    };
  }
  factory Vendedor.fromMap(Map<String, dynamic> map) {
  return Vendedor(
      id: map['id'].toString(), // 🔒 String
    claveCel: map['clave_cel'] ?? '',
    nombre: map['nombre'] ?? '',
    mail: map['mail'] ?? '',
    empresa: map['empresa'] ?? 0,
  );
}

}
