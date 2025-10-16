import 'dart:convert';

import 'package:http/http.dart' as http;

/// Cliente simple para consumir los endpoints del backend de e-commerce.
class EcommerceApi {
  static const String baseUrl =
      'https://blesshealth24-7-backecommerce.onrender.com';
  static const Duration _defaultTimeout = Duration(seconds: 25);

  static Map<String, String> _headers({String? token}) {
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  /// Obtiene la lista de IDs de productos favoritos del usuario.
  static Future<Set<int>> fetchFavoriteProductIds({
    required int userId,
    required String token,
  }) async {
    final uri = Uri.parse('$baseUrl/favorito/$userId');
    final response = await http
        .get(uri, headers: _headers(token: token))
        .timeout(_defaultTimeout);

    if (response.statusCode != 200) {
      throw Exception(
        'Error al obtener favoritos: ${response.statusCode} - ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is List) {
      return decoded
          .map((item) => (item['idProducto'] as num?)?.toInt())
          .whereType<int>()
          .toSet();
    }

    return {};
  }

  static Future<void> addFavorite({
    required int userId,
    required int productId,
    required String token,
  }) async {
    final uri = Uri.parse('$baseUrl/favorito/agregar');
    final payload = jsonEncode({'idUsuario': userId, 'idProducto': productId});
    final response = await http
        .post(
          uri,
          headers: _headers(token: token),
          body: payload,
        )
        .timeout(_defaultTimeout);

    if (response.statusCode != 201 && response.statusCode != 200) {
      throw Exception(
        'Error al agregar favorito: ${response.statusCode} - ${response.body}',
      );
    }
  }

  static Future<void> removeFavorite({
    required int userId,
    required int productId,
    required String token,
  }) async {
    final uri = Uri.parse('$baseUrl/favorito/eliminar');
    final payload = jsonEncode({'idUsuario': userId, 'idProducto': productId});
    final response = await http
        .delete(
          uri,
          headers: _headers(token: token),
          body: payload,
        )
        .timeout(_defaultTimeout);

    if (response.statusCode != 200) {
      throw Exception(
        'Error al eliminar favorito: ${response.statusCode} - ${response.body}',
      );
    }
  }

  static Future<CartTotals> fetchCartTotals({
    required int userId,
    required String token,
  }) async {
    final uri = Uri.parse('$baseUrl/carrito/totales/$userId');
    final response = await http
        .get(uri, headers: _headers(token: token))
        .timeout(_defaultTimeout);

    if (response.statusCode != 200) {
      throw Exception(
        'Error al obtener totales del carrito: ${response.statusCode} - ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return CartTotals.fromJson(decoded);
    }

    throw Exception('Formato inesperado en los totales del carrito');
  }

  static Future<List<CartItem>> fetchCartItems({
    required int userId,
    required String token,
  }) async {
    final uri = Uri.parse('$baseUrl/carrito/$userId');
    final response = await http
        .get(uri, headers: _headers(token: token))
        .timeout(_defaultTimeout);

    if (response.statusCode != 200) {
      throw Exception(
        'Error al obtener carrito: ${response.statusCode} - ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    final List<dynamic> rawItems;

    if (decoded is List) {
      rawItems = decoded;
    } else if (decoded is Map<String, dynamic>) {
      final productos = decoded['productos'];
      if (productos is List) {
        rawItems = productos;
      } else {
        rawItems = const [];
      }
    } else {
      rawItems = const [];
    }

    return rawItems
        .whereType<Map<String, dynamic>>()
        .map(CartItem.fromJson)
        .toList();
  }

  static Future<void> addProductToCart({
    required int userId,
    required int productId,
    required int quantity,
    required String token,
  }) async {
    final uri = Uri.parse('$baseUrl/carrito/agregar');
    final payload = jsonEncode({
      'usuarioId': userId,
      'productoId': productId,
      'cantidad': quantity,
    });

    final response = await http
        .post(
          uri,
          headers: _headers(token: token),
          body: payload,
        )
        .timeout(_defaultTimeout);

    if (response.statusCode != 200) {
      throw Exception(
        'Error al agregar al carrito: ${response.statusCode} - ${response.body}',
      );
    }
  }

  static Future<void> increaseCartItem({
    required int userId,
    required int productId,
    required String token,
  }) async {
    await _mutateCartQuantity(
      endpoint: 'aumentar',
      userId: userId,
      productId: productId,
      token: token,
    );
  }

  static Future<void> decreaseCartItem({
    required int userId,
    required int productId,
    required String token,
  }) async {
    await _mutateCartQuantity(
      endpoint: 'disminuir',
      userId: userId,
      productId: productId,
      token: token,
    );
  }

  static Future<void> removeFromCart({
    required int userId,
    required int productId,
    required String token,
  }) async {
    final uri = Uri.parse('$baseUrl/carrito/eliminar');
    final payload = jsonEncode({'usuarioId': userId, 'productoId': productId});
    final response = await http
        .delete(
          uri,
          headers: _headers(token: token),
          body: payload,
        )
        .timeout(_defaultTimeout);

    if (response.statusCode != 200) {
      throw Exception(
        'Error al eliminar del carrito: ${response.statusCode} - ${response.body}',
      );
    }
  }

  static Future<void> _mutateCartQuantity({
    required String endpoint,
    required int userId,
    required int productId,
    required String token,
  }) async {
    final uri = Uri.parse('$baseUrl/carrito/$endpoint');
    final payload = jsonEncode({'usuarioId': userId, 'productoId': productId});
    final response = await http
        .put(
          uri,
          headers: _headers(token: token),
          body: payload,
        )
        .timeout(_defaultTimeout);

    if (response.statusCode != 200) {
      throw Exception(
        'Error al actualizar cantidad: ${response.statusCode} - ${response.body}',
      );
    }
  }
}

class CartTotals {
  final String subtotal;
  final int cantidadTotalArticulos;
  final String totalConIva;
  final String mensajeEnvio;

  CartTotals({
    required this.subtotal,
    required this.cantidadTotalArticulos,
    required this.totalConIva,
    required this.mensajeEnvio,
  });

  factory CartTotals.fromJson(Map<String, dynamic> json) {
    return CartTotals(
      subtotal: json['Subtotal']?.toString() ?? '0.00',
      cantidadTotalArticulos:
          (json['CantidadTotalArticulos'] as num?)?.toInt() ?? 0,
      totalConIva: json['TotalConIVA']?.toString() ?? '0.00',
      mensajeEnvio: json['MensajeEnvio']?.toString() ?? '',
    );
  }
}

class CartItem {
  final int productId;
  final String name;
  final String size;
  final String brand;
  final int quantity;
  final double unitPrice;
  final double subtotal;
  final String imageUrl;

  CartItem({
    required this.productId,
    required this.name,
    required this.size,
    required this.brand,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
    required this.imageUrl,
  });

  factory CartItem.fromJson(Map<String, dynamic> json) {
    double _toDouble(dynamic value) {
      if (value == null) return 0;
      if (value is num) return value.toDouble();
      final sanitized = value.toString().replaceAll(RegExp(r'[^0-9.,-]'), '');
      return double.tryParse(sanitized.replaceAll(',', '.')) ?? 0;
    }

    return CartItem(
      productId: (json['idProducto'] as num?)?.toInt() ?? 0,
      name:
          json['Producto']?.toString() ??
          json['nombreProducto']?.toString() ??
          '',
      size: json['Talla']?.toString() ?? '',
      brand: json['Marca']?.toString() ?? '',
      quantity: (json['Cantidad'] as num?)?.toInt() ?? 0,
      unitPrice: _toDouble(json['PrecioUnitario']),
      subtotal: _toDouble(json['Subtotal']),
      imageUrl:
          json['Imagen']?.toString() ?? json['imgProducto']?.toString() ?? '',
    );
  }
}
