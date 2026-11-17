typedef Json = Map<String, dynamic>;

class Category {
  Category.fromJson(Json json)
    : id = readId(json),
      name = json['nombre'] as String;

  final int id;
  final String name;
}

class Account {
  Account.fromJson(Json json)
    : id = readId(json),
      name = json['nombre'] as String,
      email = json['correo'] as String;

  final int id;
  final String name;
  final String email;

  Json toJson() => {'id': id, 'nombre': name, 'correo': email};
}

int readId(Json json) {
  final id = json['id'];
  if (id is! int || id <= 0) throw const FormatException('ID inválido');
  return id;
}

class Coordinates {
  const Coordinates(this.latitude, this.longitude);

  final double latitude;
  final double longitude;

  Json toJson() => {
    'latitud': double.parse(latitude.toStringAsFixed(7)),
    'longitud': double.parse(longitude.toStringAsFixed(7)),
  };
}

class Business {
  Business.fromJson(Json json)
    : id = readId(json),
      categoryId = json['categoriaId'] as int,
      category = json['categoria'] as String,
      name = json['nombre'] as String,
      description = json['descripcion'] as String,
      phone = json['telefono'] as String?,
      address = json['direccionReferencia'] as String?,
      hours = json['horarioAtencion'] as String?,
      photo = json['fotoUrl'] as String?,
      published = json['publicado'] as bool,
      point = Coordinates(
        (json['latitud'] as num).toDouble(),
        (json['longitud'] as num).toDouble(),
      );

  final int id, categoryId;
  final String category, name, description;
  final String? phone, address, hours, photo;
  final bool published;
  final Coordinates point;
}

class Product {
  Product.fromJson(Json json)
    : id = readId(json),
      name = json['nombre'] as String,
      description = json['descripcion'] as String,
      price = json['precio'] as num,
      photo = json['fotoUrl'] as String?,
      published = json['publicado'] as bool? ?? true;

  final int id;
  final String name, description;
  final num price;
  final String? photo;
  final bool published;

  Json toUpdate({required bool published}) => {
    'nombre': name,
    'descripcion': description,
    'precio': price,
    'publicado': published,
  };
}

class CatalogPage<T> {
  CatalogPage.fromJson(Json json, T Function(Json) decode)
    : items = (json['items'] as List)
          .map((item) => decode(item as Json))
          .toList(),
      page = json['page'] as int,
      totalPages = json['totalPages'] as int;

  final List<T> items;
  final int page, totalPages;
  bool get hasMore => page + 1 < totalPages;
}
