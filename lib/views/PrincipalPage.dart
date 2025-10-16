import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../componentes/navbar/navbar.dart';
import '../componentes/navbar/footer.dart';
import '../services/ecommerce_api.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  bool _showNavbar = true;
  int _selectedIndex = 0;

  List<Map<String, dynamic>> _productos = [];
  String? _authToken;
  int? _usuarioId;
  Set<int> _favoriteProductIds = {};
  final Set<int> _favoritePending = {};
  final Set<int> _cartPending = {};
  int _cartItemsCount = 0;
  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    fetchProductos(); // al iniciar carga todos
    _initializeSession();
  }

  void _handleScroll() {
    if (_scrollController.position.userScrollDirection ==
        ScrollDirection.reverse) {
      if (_showNavbar) setState(() => _showNavbar = false);
    } else if (_scrollController.position.userScrollDirection ==
        ScrollDirection.forward) {
      if (!_showNavbar) setState(() => _showNavbar = true);
    }
  }

  Future<void> _initializeSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('authToken');
    final userId = prefs.getInt('usuarioId');

    if (!mounted) return;

    setState(() {
      _authToken = (token != null && token.isNotEmpty) ? token : null;
      _usuarioId = (userId != null && userId > 0) ? userId : null;
    });

    if (_authToken != null && _usuarioId != null) {
      await Future.wait([_fetchFavorites(), _refreshCartSummary()]);
    } else {
      setState(() {
        _favoriteProductIds.clear();
        _cartItemsCount = 0;
      });
    }
  }

  /// 🔹 Trae todos los productos
  Future<void> fetchProductos() async {
    try {
      final response = await http.get(
        Uri.parse(
          "https://blesshealth24-7-backecommerce.onrender.com/producto/obtenervitrina",
        ),
      );

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);

        setState(() {
          _productos = _mapearProductos(data);
        });
      } else {
        print("❌ Error fetchProductos: ${response.statusCode}");
      }
    } catch (e) {
      print("❌ Error fetchProductos: $e");
    }
  }

  /// 🔹 Buscar productos
  Future<void> buscarProductos(String query) async {
    if (query.isEmpty) {
      fetchProductos(); // si no hay búsqueda, traer todos
      return;
    }

    try {
      final response = await http.get(
        Uri.parse(
          "https://blesshealth24-7-backecommerce.onrender.com/producto/buscar/$query",
        ),
      );

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);

        setState(() {
          _productos = _mapearProductos(data);
        });
      } else {
        print("❌ Error buscarProductos: ${response.statusCode}");
      }
    } catch (e) {
      print("❌ Error buscarProductos: $e");
    }
  }

  Future<void> _fetchFavorites() async {
    if (_authToken == null || _usuarioId == null) return;

    try {
      final ids = await EcommerceApi.fetchFavoriteProductIds(
        userId: _usuarioId!,
        token: _authToken!,
      );
      if (!mounted) return;
      setState(() {
        _favoriteProductIds = ids;
      });
    } catch (e) {
      debugPrint('Error fetchFavorites: $e');
    }
  }

  Future<void> _refreshCartSummary() async {
    if (_authToken == null || _usuarioId == null) {
      if (_cartItemsCount != 0 && mounted) {
        setState(() {
          _cartItemsCount = 0;
        });
      }
      return;
    }

    try {
      final totals = await EcommerceApi.fetchCartTotals(
        userId: _usuarioId!,
        token: _authToken!,
      );
      if (!mounted) return;
      setState(() {
        _cartItemsCount = totals.cantidadTotalArticulos;
      });
    } catch (e) {
      debugPrint('Error refreshCartSummary: $e');
    }
  }

  Future<void> _toggleFavorite(int productId) async {
    if (_authToken == null || _usuarioId == null) {
      _promptLoginRequired();
      return;
    }
    if (_favoritePending.contains(productId)) return;

    setState(() {
      _favoritePending.add(productId);
    });

    final isFavorite = _favoriteProductIds.contains(productId);

    try {
      if (isFavorite) {
        await EcommerceApi.removeFavorite(
          userId: _usuarioId!,
          productId: productId,
          token: _authToken!,
        );
      } else {
        await EcommerceApi.addFavorite(
          userId: _usuarioId!,
          productId: productId,
          token: _authToken!,
        );
      }

      if (!mounted) return;
      setState(() {
        if (isFavorite) {
          _favoriteProductIds.remove(productId);
        } else {
          _favoriteProductIds.add(productId);
        }
      });

      _showSnack(
        isFavorite
            ? 'Producto eliminado de favoritos'
            : 'Producto agregado a favoritos',
      );
    } catch (e) {
      debugPrint('Error toggleFavorite: $e');
      _showSnack('No se pudo actualizar el favorito');
    } finally {
      if (mounted) {
        setState(() {
          _favoritePending.remove(productId);
        });
      } else {
        _favoritePending.remove(productId);
      }
    }
  }

  Future<void> _addToCart(int productId) async {
    if (_authToken == null || _usuarioId == null) {
      _promptLoginRequired();
      return;
    }
    if (_cartPending.contains(productId)) return;

    setState(() {
      _cartPending.add(productId);
    });

    try {
      await EcommerceApi.addProductToCart(
        userId: _usuarioId!,
        productId: productId,
        quantity: 1,
        token: _authToken!,
      );
      await _refreshCartSummary();
      _showSnack('Producto agregado al carrito');
    } catch (e) {
      debugPrint('Error addToCart: $e');
      _showSnack('No se pudo agregar al carrito');
    } finally {
      if (mounted) {
        setState(() {
          _cartPending.remove(productId);
        });
      } else {
        _cartPending.remove(productId);
      }
    }
  }

  Future<void> _openCartModal() async {
    if (_authToken == null || _usuarioId == null) {
      _promptLoginRequired();
      return;
    }

    try {
      final items = await EcommerceApi.fetchCartItems(
        userId: _usuarioId!,
        token: _authToken!,
      );
      final totals = await EcommerceApi.fetchCartTotals(
        userId: _usuarioId!,
        token: _authToken!,
      );

      if (!mounted) return;

      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (modalContext) {
          return CartModal(
            token: _authToken!,
            userId: _usuarioId!,
            initialItems: items,
            initialTotals: totals,
            onCartChanged: _refreshCartSummary,
            onFeedback: _showSnack,
          );
        },
      );

      if (mounted) {
        await _refreshCartSummary();
      }
    } catch (e) {
      debugPrint('Error openCartModal: $e');
      _showSnack('No se pudo cargar el carrito');
    }
  }

  void _promptLoginRequired() {
    _showSnack('Inicia sesión para usar esta funcionalidad');
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  List<Map<String, dynamic>> _mapearProductos(List data) {
    return data.map((e) {
      final idProducto = (e["idProducto"] as num?)?.toInt() ?? 0;
      final rawImage = (e["imgProducto"] ?? e["imagenProducto"] ?? '')
          .toString();

      final fullImageUrl = rawImage.replaceFirst(
        'https://localhost:3000',
        'https://blesshealth24-7-backecommerce.onrender.com',
      );

      return {
        "id": idProducto,
        "nombre": e["nombreProducto"]?.toString() ?? '',
        "precio": e["precioProducto"]?.toString() ?? '',
        "stock": (e["stockProducto"] as num?)?.toInt() ?? 0,
        "imagen": fullImageUrl,
        "promo": e["enPromocion"]?.toString() ?? '',
      };
    }).toList();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Navbar animado
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: _showNavbar ? null : 0,
              child: CustomNavbar(
                cartItemCount: _cartItemsCount,
                onCartPressed: _openCartModal,
              ),
            ),

            // 🔹 Barra de búsqueda
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.3),
                      blurRadius: 5,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search, color: Colors.grey),
                    hintText: "Busca aquí tus productos",
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 14),
                  ),
                  onChanged: (value) {
                    buscarProductos(value);
                  },
                ),
              ),
            ),

            // Contenido scrollable
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2, // 2 columnas
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 0.65,
                        ),
                    itemCount: _productos.length,
                    itemBuilder: (context, index) {
                      final producto = _productos[index];
                      final productId = (producto["id"] as int?) ?? 0;

                      return ProductCard(
                        imageUrl: producto["imagen"]?.toString() ?? "",
                        title: producto["nombre"]?.toString() ?? "",
                        description: producto["promo"]?.toString() ?? "",
                        price: producto["precio"]?.toString() ?? "",
                        onAdd: () => _addToCart(productId),
                        onFavorite: () => _toggleFavorite(productId),
                        isFavorite: _favoriteProductIds.contains(productId),
                        isFavoriteBusy: _favoritePending.contains(productId),
                        isAddBusy: _cartPending.contains(productId),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),

      // Footer
      bottomNavigationBar: SafeArea(
        child: CustomFooterNav(
          currentIndex: _selectedIndex,
          onTap: (index) {
            setState(() => _selectedIndex = index);
          },
        ),
      ),
    );
  }
}

/// --- Tarjeta del producto ---
class ProductCard extends StatelessWidget {
  final String imageUrl;
  final String title;
  final String description;
  final String price;
  final VoidCallback onAdd;
  final VoidCallback onFavorite;
  final bool isFavorite;
  final bool isFavoriteBusy;
  final bool isAddBusy;

  const ProductCard({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.description,
    required this.price,
    required this.onAdd,
    required this.onFavorite,
    this.isFavorite = false,
    this.isFavoriteBusy = false,
    this.isAddBusy = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey.shade200,
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.broken_image_outlined,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: _buildActionCircle(
                    child: isFavoriteBusy
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            isFavorite ? Icons.favorite : Icons.favorite_border,
                            color: isFavorite ? Colors.redAccent : Colors.teal,
                            size: 18,
                          ),
                    onTap: isFavoriteBusy ? null : onFavorite,
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: _buildActionCircle(
                    child: isAddBusy
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(
                            Icons.add_shopping_cart,
                            color: Colors.teal,
                            size: 18,
                          ),
                    onTap: isAddBusy ? null : onAdd,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                if (description.isNotEmpty)
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                const SizedBox(height: 6),
                Text(
                  price.isNotEmpty ? price : 'Precio no disponible',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCircle({required Widget child, VoidCallback? onTap}) {
    final circle = Container(
      height: 32,
      width: 32,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(child: child),
    );

    if (onTap == null) {
      return circle;
    }

    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: circle,
    );
  }
}

class CartModal extends StatefulWidget {
  const CartModal({
    super.key,
    required this.token,
    required this.userId,
    required this.initialItems,
    required this.initialTotals,
    this.onCartChanged,
    this.onFeedback,
  });

  final String token;
  final int userId;
  final List<CartItem> initialItems;
  final CartTotals initialTotals;
  final Future<void> Function()? onCartChanged;
  final void Function(String message)? onFeedback;

  @override
  State<CartModal> createState() => _CartModalState();
}

class _CartModalState extends State<CartModal> {
  late List<CartItem> _items;
  late CartTotals _totals;
  final Set<int> _processingIds = {};

  @override
  void initState() {
    super.initState();
    _items = List<CartItem>.from(widget.initialItems);
    _totals = widget.initialTotals;
  }

  @override
  Widget build(BuildContext context) {
    final modalHeight = MediaQuery.of(context).size.height * 0.75;

    return SafeArea(
      child: SizedBox(
        height: modalHeight,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                height: 4,
                width: 40,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _items.isEmpty
                    ? const Center(child: Text('Tu carrito está vacío'))
                    : ListView.separated(
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          final isProcessing = _processingIds.contains(
                            item.productId,
                          );
                          return _buildCartItemCard(item, isProcessing);
                        },
                      ),
              ),
              const SizedBox(height: 12),
              _buildTotalsSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCartItemCard(CartItem item, bool isProcessing) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                item.imageUrl,
                width: 64,
                height: 64,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 64,
                  height: 64,
                  color: Colors.grey.shade200,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.medical_services_outlined,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (item.brand.isNotEmpty)
                    Text(
                      item.brand,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  if (item.size.isNotEmpty)
                    Text(
                      'Presentación: ${item.size}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    'Subtotal: ${_formatCurrency(item.subtotal)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.teal,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        iconSize: 22,
                        icon: const Icon(Icons.remove_circle_outline),
                        color: Colors.teal,
                        onPressed: isProcessing
                            ? null
                            : () => _decrease(item.productId),
                      ),
                      Text(
                        '${item.quantity}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        iconSize: 22,
                        icon: const Icon(Icons.add_circle_outline),
                        color: Colors.teal,
                        onPressed: isProcessing
                            ? null
                            : () => _increase(item.productId),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        iconSize: 22,
                        icon: const Icon(Icons.delete_outline),
                        color: Colors.redAccent,
                        onPressed: isProcessing
                            ? null
                            : () => _remove(item.productId),
                      ),
                      if (isProcessing)
                        const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalsSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.teal.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTotalRow('Artículos', '${_totals.cantidadTotalArticulos}'),
          const SizedBox(height: 6),
          _buildTotalRow('Subtotal', _formatTotals(_totals.subtotal)),
          const SizedBox(height: 6),
          _buildTotalRow(
            'Total (IVA inc.)',
            _formatTotals(_totals.totalConIva),
          ),
          const SizedBox(height: 8),
          Text(
            _totals.mensajeEnvio,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  String _formatCurrency(double value) => '\$' + value.toStringAsFixed(2);

  String _formatTotals(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '\$0.00';
    if (trimmed.startsWith('\$')) return trimmed;
    return '\$' + trimmed;
  }

  Future<void> _increase(int productId) {
    return _runMutation(
      productId,
      () => EcommerceApi.increaseCartItem(
        userId: widget.userId,
        productId: productId,
        token: widget.token,
      ),
    );
  }

  Future<void> _decrease(int productId) {
    return _runMutation(
      productId,
      () => EcommerceApi.decreaseCartItem(
        userId: widget.userId,
        productId: productId,
        token: widget.token,
      ),
    );
  }

  Future<void> _remove(int productId) {
    return _runMutation(
      productId,
      () => EcommerceApi.removeFromCart(
        userId: widget.userId,
        productId: productId,
        token: widget.token,
      ),
      successMessage: 'Producto eliminado del carrito',
    );
  }

  Future<void> _runMutation(
    int productId,
    Future<void> Function() action, {
    String? successMessage,
  }) async {
    if (mounted) {
      setState(() {
        _processingIds.add(productId);
      });
    } else {
      _processingIds.add(productId);
    }

    try {
      await action();
      await _refreshCart();
      if (successMessage != null) {
        widget.onFeedback?.call(successMessage);
      }
    } catch (e) {
      debugPrint('Error al actualizar el carrito: $e');
      widget.onFeedback?.call('No se pudo actualizar el carrito');
    } finally {
      if (mounted) {
        setState(() {
          _processingIds.remove(productId);
        });
      } else {
        _processingIds.remove(productId);
      }
    }
  }

  Future<void> _refreshCart() async {
    final items = await EcommerceApi.fetchCartItems(
      userId: widget.userId,
      token: widget.token,
    );
    final totals = await EcommerceApi.fetchCartTotals(
      userId: widget.userId,
      token: widget.token,
    );

    if (!mounted) return;

    setState(() {
      _items = items;
      _totals = totals;
    });

    if (_items.isEmpty) {
      widget.onFeedback?.call('Tu carrito está vacío');
      if (widget.onCartChanged != null) {
        await widget.onCartChanged!();
      }
      if (mounted) {
        Navigator.of(context).pop();
      }
      return;
    }

    if (widget.onCartChanged != null) {
      await widget.onCartChanged!();
    }
  }
}
