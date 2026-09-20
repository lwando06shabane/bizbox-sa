import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../db_helper.dart';

/* ============================================================
   BUSINESS SCREEN ROUTER
   ============================================================ */
class BusinessScreenRouter extends StatefulWidget {
  const BusinessScreenRouter({super.key});
  @override
  State<BusinessScreenRouter> createState() => _BusinessScreenRouterState();
}

class _BusinessScreenRouterState extends State<BusinessScreenRouter> {
  String? _type;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    setState(() => _type = p.getString('business_type'));
  }

  @override
  Widget build(BuildContext context) {
    if (_type == null) {
      return const Center(child: CircularProgressIndicator());
    }
    switch (_type) {
      case 'Restaurant':
        return const RestaurantScreen();
      case 'Car Wash':
        return const CarWashScreen();
      case 'Salon':
        return const SalonScreen();
      case 'Tuck Shop':
      default:
        return const TuckShopScreen();
    }
  }
}

/* ============================================================
   TUCK SHOP SCREEN
   ============================================================ */
class TuckShopScreen extends StatefulWidget {
  const TuckShopScreen({super.key});
  @override
  State<TuckShopScreen> createState() => _TuckShopScreenState();
}

class _TuckShopScreenState extends State<TuckShopScreen> {
  List<Map<String, dynamic>> _products = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = await DBHelper.database;
    _products = await db.query('products');
    if (mounted) setState(() {});
  }

  Future<void> _addProduct() async {
    final name = TextEditingController();
    final price = TextEditingController();
    final stock = TextEditingController();
    final category = TextEditingController(text: 'General');
    File? photo;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Add Product'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
              TextField(controller: price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Price')),
              TextField(controller: stock, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Stock')),
              TextField(controller: category, decoration: const InputDecoration(labelText: 'Category')),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.camera_alt),
                label: Text(photo == null ? 'Add Photo' : 'Photo Added'),
                onPressed: () async {
                  final x = await ImagePicker().pickImage(source: ImageSource.camera);
                  if (x != null) setSt(() => photo = File(x.path));
                },
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (name.text.isEmpty) return;
                final db = await DBHelper.database;
                await db.insert('products', {
                  'name': name.text,
                  'price': double.tryParse(price.text) ?? 0,
                  'stock': int.tryParse(stock.text) ?? 0,
                  'category': category.text,
                  'barcode': '',
                  'photo': photo?.path ?? '',
                });
                if (ctx.mounted) Navigator.pop(ctx);
                _load();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sell(Map<String, dynamic> p) async {
    final qtyCtrl = TextEditingController(text: '1');
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Sell ${p['name']}'),
        content: TextField(
          controller: qtyCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Quantity'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final q = int.tryParse(qtyCtrl.text) ?? 1;
              if (q > (p['stock'] as int)) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Not enough stock')));
                return;
              }
              final db = await DBHelper.database;
              final total = (p['price'] as num) * q;
              await db.insert('sales', {
                'product': p['name'],
                'qty': q,
                'total': total,
                'date': DateTime.now().toIso8601String(),
                'type': 'tuckshop',
              });
              await db.update('products', {'stock': (p['stock'] as int) - q},
                  where: 'id = ?', whereArgs: [p['id']]);
              if (mounted) Navigator.pop(context);
              _load();
              if (mounted) _receipt('${p['name']} x$q', total);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _receipt(String item, num total) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Receipt'),
        content: Text('Item: $item\nTotal: R$total\nDate: ${DateTime.now()}'),
        actions: [
          TextButton(
            onPressed: () {
              final msg = Uri.encodeComponent('Receipt: $item - R$total');
              launchUrl(Uri.parse('https://wa.me/?text=$msg'));
            },
            child: const Text('Share WhatsApp'),
          ),
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lowStock = _products.where((p) => (p['stock'] as int) < 5).toList();
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addProduct,
        icon: const Icon(Icons.add),
        label: const Text('Add Product'),
      ),
      body: Column(children: [
        if (lowStock.isNotEmpty)
          Container(
            width: double.infinity,
            color: Colors.amber.shade200,
            padding: const EdgeInsets.all(8),
            child: Text('⚠️ Low stock: ${lowStock.map((e) => e['name']).join(", ")}'),
          ),
        Expanded(
          child: _products.isEmpty
              ? const Center(child: Text('No products yet. Tap + to add.'))
              : ListView.builder(
                  itemCount: _products.length,
                  itemBuilder: (c, i) {
                    final p = _products[i];
                    return ListTile(
                      leading: (p['photo'] != null && (p['photo'] as String).isNotEmpty)
                          ? Image.file(File(p['photo']), width: 40, height: 40, fit: BoxFit.cover)
                          : const Icon(Icons.inventory_2),
                      title: Text(p['name']),
                      subtitle: Text('R${p['price']} • Stock: ${p['stock']} • ${p['category']}'),
                      trailing: FilledButton(
                        onPressed: () => _sell(p),
                        child: const Text('Sell'),
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}

/* ============================================================
   RESTAURANT SCREEN
   ============================================================ */
class RestaurantScreen extends StatefulWidget {
  const RestaurantScreen({super.key});
  @override
  State<RestaurantScreen> createState() => _RestaurantScreenState();
}

class _RestaurantScreenState extends State<RestaurantScreen> {
  static const _categories = ['Kota', 'Chips', 'Drinks', 'Chicken', 'Braai'];
  String _selectedCat = 'Kota';
  String _selectedTable = 'Table 1';
  final List<Map<String, dynamic>> _cart = [];
  List<Map<String, dynamic>> _menu = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = await DBHelper.database;
    _menu = await db.query('menu');
    if (mounted) setState(() {});
  }

  Future<void> _addMenuItem() async {
    final name = TextEditingController();
    final price = TextEditingController();
    String cat = _selectedCat;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Add Menu Item'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
            TextField(controller: price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Price')),
            DropdownButton<String>(
              value: cat,
              isExpanded: true,
              items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setSt(() => cat = v ?? cat),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (name.text.isEmpty) return;
                final db = await DBHelper.database;
                await db.insert('menu', {
                  'name': name.text,
                  'price': double.tryParse(price.text) ?? 0,
                  'category': cat,
                  'image': '',
                });
                if (ctx.mounted) Navigator.pop(ctx);
                _load();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _addToCart(Map<String, dynamic> item) {
    final existing = _cart.indexWhere((e) => e['name'] == item['name']);
    if (existing >= 0) {
      _cart[existing]['qty'] = (_cart[existing]['qty'] as int) + 1;
    } else {
      _cart.add({
        'name': item['name'],
        'price': item['price'],
        'qty': 1,
        'note': '',
      });
    }
    setState(() {});
  }

  Future<void> _checkout() async {
    if (_cart.isEmpty) return;
    final note = TextEditingController();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Kitchen Note'),
        content: TextField(
          controller: note,
          decoration: const InputDecoration(hintText: 'e.g. no onions, extra sauce'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Skip')),
          FilledButton(
            onPressed: () async {
              if (mounted) Navigator.pop(context);
              await _saveOrder(note.text);
            },
            child: const Text('Save Order'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveOrder(String note) async {
    final db = await DBHelper.database;
    double total = 0;
    for (final item in _cart) {
      final lineTotal = (item['price'] as num) * (item['qty'] as int);
      total += lineTotal;
      await db.insert('sales', {
        'product': '${item['name']} x${item['qty']}',
        'qty': item['qty'],
        'total': lineTotal,
        'date': DateTime.now().toIso8601String(),
        'type': 'restaurant',
      });
    }
    _showBill(total, note);
    setState(() => _cart.clear());
  }

  void _showBill(double total, String note) {
    final lines = _cart
        .map((e) => '${e['name']} x${e['qty']}  R${(e['price'] as num) * (e['qty'] as int)}')
        .join('\n');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Bill • $_selectedTable'),
        content: SingleChildScrollView(
          child: Text('$lines\n\nTotal: R${total.toStringAsFixed(2)}'
              '${note.isNotEmpty ? '\n\nNote: $note' : ''}'),
        ),
        actions: [
          TextButton(
            onPressed: () {
              final msg = Uri.encodeComponent(
                  'Bill • $_selectedTable\n$lines\n\nTotal: R${total.toStringAsFixed(2)}'
                  '${note.isNotEmpty ? '\nNote: $note' : ''}');
              launchUrl(Uri.parse('https://wa.me/?text=$msg'));
            },
            child: const Text('WhatsApp'),
          ),
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _menu.where((m) => m['category'] == _selectedCat).toList();
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addMenuItem,
        icon: const Icon(Icons.add),
        label: const Text('Add Menu Item'),
      ),
      body: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: Colors.red.shade50,
          child: Row(children: [
            const Icon(Icons.table_restaurant, color: Colors.red),
            const SizedBox(width: 8),
            DropdownButton<String>(
              value: _selectedTable,
              items: [
                ...List.generate(10, (i) => 'Table ${i + 1}'),
                'Takeaway',
              ].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (v) => setState(() => _selectedTable = v ?? _selectedTable),
            ),
          ]),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _categories
                .map((c) => Padding(
                      padding: const EdgeInsets.all(6),
                      child: ChoiceChip(
                        label: Text(c),
                        selected: _selectedCat == c,
                        onSelected: (_) => setState(() => _selectedCat = c),
                      ),
                    ))
                .toList(),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text('No items in this category'))
              : ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (c, i) {
                    final m = filtered[i];
                    return ListTile(
                      leading: const Icon(Icons.fastfood, color: Colors.red),
                      title: Text(m['name']),
                      subtitle: Text('R${m['price']}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.add_shopping_cart),
                        onPressed: () => _addToCart(m),
                      ),
                    );
                  },
                ),
        ),
        if (_cart.isNotEmpty)
          Container(
            color: Colors.red.shade100,
            padding: const EdgeInsets.all(8),
            child: Row(children: [
              Text('${_cart.length} item(s) • R${_cartTotal().toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              FilledButton(onPressed: _checkout, child: const Text('Bill')),
            ]),
          ),
      ]),
    );
  }

  double _cartTotal() => _cart.fold(0, (s, e) => s + (e['price'] as num) * (e['qty'] as int));
}

/* ============================================================
   CAR WASH SCREEN
   ============================================================ */
class CarWashScreen extends StatefulWidget {
  const CarWashScreen({super.key});
  @override
  State<CarWashScreen> createState() => _CarWashScreenState();
}

class _CarWashScreenState extends State<CarWashScreen> {
  static const _services = {
    'Small Car': 80.0,
    'SUV': 120.0,
    'Bakkie': 150.0,
    'Interior': 100.0,
    'Polish': 250.0,
    'Engine Wash': 200.0,
  };
  List<Map<String, dynamic>> _queue = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = await DBHelper.database;
    _queue = await db.query('car_queue', orderBy: 'id DESC');
    if (mounted) setState(() {});
  }

  Future<void> _addCar() async {
    final plate = TextEditingController();
    final customer = TextEditingController();
    final phone = TextEditingController();
    final worker = TextEditingController(text: 'Worker 1');
    String carType = 'Small Car';
    String service = 'Small Car';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Add Car to Queue'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: plate, decoration: const InputDecoration(labelText: 'Plate Number')),
              TextField(controller: customer, decoration: const InputDecoration(labelText: 'Customer Name')),
              TextField(controller: phone, decoration: const InputDecoration(labelText: 'Phone (+27...)')),
              TextField(controller: worker, decoration: const InputDecoration(labelText: 'Worker')),
              const SizedBox(height: 8),
              DropdownButton<String>(
                value: carType,
                isExpanded: true,
                items: _services.keys.map((k) => DropdownMenuItem(value: k, child: Text('Car: $k'))).toList(),
                onChanged: (v) => setSt(() => carType = v ?? carType),
              ),
              DropdownButton<String>(
                value: service,
                isExpanded: true,
                items: _services.keys.map((k) => DropdownMenuItem(value: k, child: Text('Service: $k (R${_services[k]})'))).toList(),
                onChanged: (v) => setSt(() => service = v ?? service),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (plate.text.isEmpty) return;
                final db = await DBHelper.database;
                await db.insert('car_queue', {
                  'plate': plate.text.toUpperCase(),
                  'customer': customer.text,
                  'phone': phone.text,
                  'carType': carType,
                  'service': service,
                  'price': _services[service],
                  'status': 'Washing',
                  'worker': worker.text,
                  'timestamp': DateTime.now().toIso8601String(),
                });
                if (ctx.mounted) Navigator.pop(ctx);
                _load();
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _markDone(Map<String, dynamic> row) async {
    final db = await DBHelper.database;
    await db.update('car_queue', {'status': 'Done'},
        where: 'id = ?', whereArgs: [row['id']]);
    await db.insert('sales', {
      'product': '${row['service']} • ${row['plate']}',
      'qty': 1,
      'total': row['price'],
      'date': DateTime.now().toIso8601String(),
      'type': 'carwash',
    });
    _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${row['plate']} marked DONE')),
    );
  }

  Future<void> _sendReady(Map<String, dynamic> row) async {
    final phone = (row['phone'] as String).replaceAll('+', '');
    final msg = Uri.encodeComponent(
        'Hi ${row['customer']}, your car (${row['plate']}) is READY. '
        'Service: ${row['service']}. Total: R${row['price']}. Thank you!');
    final url = phone.isEmpty
        ? 'https://wa.me/?text=$msg'
        : 'https://wa.me/$phone?text=$msg';
    launchUrl(Uri.parse(url));
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todaysDone = _queue.where((q) {
      final t = DateTime.tryParse(q['timestamp'] ?? '');
      return q['status'] == 'Done' &&
          t != null &&
          t.year == today.year &&
          t.month == today.month &&
          t.day == today.day;
    }).toList();
    final income = todaysDone.fold<double>(0, (s, q) => s + (q['price'] as num));
    final commission = income * 0.3;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addCar,
        icon: const Icon(Icons.add),
        label: const Text('Add Car'),
      ),
      body: Column(children: [
        Container(
          width: double.infinity,
          color: Colors.blue.shade50,
          padding: const EdgeInsets.all(12),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _stat('Cars today', '${todaysDone.length}'),
            _stat('Income', 'R${income.toStringAsFixed(0)}'),
            _stat('Commission', 'R${commission.toStringAsFixed(0)}'),
          ]),
        ),
        Expanded(
          child: _queue.isEmpty
              ? const Center(child: Text('No cars in queue'))
              : ListView.builder(
                  itemCount: _queue.length,
                  itemBuilder: (c, i) {
                    final q = _queue[i];
                    final done = q['status'] == 'Done';
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        leading: Icon(
                          done ? Icons.check_circle : Icons.local_car_wash,
                          color: done ? Colors.green : Colors.blue,
                        ),
                        title: Text('${q['plate']} • ${q['carType']}'),
                        subtitle: Text(
                            '${q['customer']} • ${q['service']} • R${q['price']}\nWorker: ${q['worker']} • ${q['status']}'),
                        isThreeLine: true,
                        trailing: Wrap(children: [
                          IconButton(
                            icon: const Icon(Icons.check, color: Colors.green),
                            tooltip: 'Mark Done',
                            onPressed: done ? null : () => _markDone(q),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chat, color: Colors.green),
                            tooltip: 'WhatsApp Ready',
                            onPressed: () => _sendReady(q),
                          ),
                        ]),
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }

  Widget _stat(String label, String value) => Column(children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        Text(label, style: const TextStyle(fontSize: 12)),
      ]);
}

/* ============================================================
   SALON SCREEN
   ============================================================ */
class SalonScreen extends StatefulWidget {
  const SalonScreen({super.key});
  @override
  State<SalonScreen> createState() => _SalonScreenState();
}

class _SalonScreenState extends State<SalonScreen> {
  static const _services = {
    'Haircut': ['R80', '30min'],
    'Dye': ['R250', '60min'],
    'Nails': ['R150', '60min'],
    'Treatment': ['R200', '60min'],
  };

  List<Map<String, dynamic>> _appointments = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = await DBHelper.database;
    _appointments = await db.query('appointments', orderBy: 'datetime ASC');
    if (mounted) setState(() {});
  }

  Future<void> _book() async {
    final name = TextEditingController();
    final phone = TextEditingController();
    String service = 'Haircut';
    DateTime selected = DateTime.now().add(const Duration(hours: 1));

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Book Appointment'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Customer Name')),
              TextField(controller: phone, decoration: const InputDecoration(labelText: 'Phone (+27...)')),
              const SizedBox(height: 8),
              DropdownButton<String>(
                value: service,
                isExpanded: true,
                items: _services.keys
                    .map((k) => DropdownMenuItem(
                        value: k,
                        child: Text('$k • ${_services[k]![0]} • ${_services[k]![1]}')))
                    .toList(),
                onChanged: (v) => setSt(() => service = v ?? service),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today),
                label: Text('Date: ${selected.toString().substring(0, 16)}'),
                onPressed: () async {
                  final d = await showDatePicker(
                    context: ctx,
                    initialDate: selected,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 90)),
                  );
                  if (d != null) {
                    final t = await showTimePicker(
                        context: ctx,
                        initialTime: TimeOfDay.fromDateTime(selected));
                    if (t != null) {
                      setSt(() => selected =
                          DateTime(d.year, d.month, d.day, t.hour, t.minute));
                    }
                  }
                },
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (name.text.isEmpty) return;
                final db = await DBHelper.database;
                await db.insert('appointments', {
                  'customer': name.text,
                  'phone': phone.text,
                  'service': service,
                  'duration': _services[service]![1],
                  'datetime': selected.toIso8601String(),
                  'status': 'Booked',
                });
                if (ctx.mounted) Navigator.pop(ctx);
                _load();
              },
              child: const Text('Book'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _markDone(Map<String, dynamic> row) async {
    final db = await DBHelper.database;
    await db.update('appointments', {'status': 'Done'},
        where: 'id = ?', whereArgs: [row['id']]);
    final priceStr = _services[row['service']]?[0] ?? 'R0';
    final price = double.tryParse(priceStr.replaceAll('R', '')) ?? 0;
    await db.insert('sales', {
      'product': '${row['service']} • ${row['customer']}',
      'qty': 1,
      'total': price,
      'date': DateTime.now().toIso8601String(),
      'type': 'salon',
    });
    _load();
  }

  void _showStyles() {
    final styles = List.generate(
      20,
      (i) => 'https://picsum.photos/seed/hair$i/300/300',
    );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (_, ctrl) => Column(children: [
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('Hairstyle Gallery',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: GridView.builder(
              controller: ctrl,
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3, crossAxisSpacing: 6, mainAxisSpacing: 6),
              itemCount: styles.length,
              itemBuilder: (c, i) => ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(styles[i], fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Container(color: Colors.purple.shade100, child: const Icon(Icons.cut))),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'styles',
            onPressed: _showStyles,
            child: const Icon(Icons.photo_library),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.extended(
            heroTag: 'book',
            onPressed: _book,
            icon: const Icon(Icons.add),
            label: const Text('Book'),
          ),
        ],
      ),
      body: _appointments.isEmpty
          ? const Center(child: Text('No appointments yet'))
          : ListView.builder(
              itemCount: _appointments.length,
              itemBuilder: (c, i) {
                final a = _appointments[i];
                final dt = DateTime.tryParse(a['datetime'] ?? '');
                final done = a['status'] == 'Done';
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    leading: Icon(
                      done ? Icons.check_circle : Icons.calendar_today,
                      color: done ? Colors.green : Colors.purple,
                    ),
                    title: Text('${a['customer']} • ${a['service']}'),
                    subtitle: Text(
                        '${a['phone']}\n${dt?.toString().substring(0, 16) ?? ''} • ${a['duration']} • ${a['status']}'),
                    isThreeLine: true,
                    trailing: done
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.check, color: Colors.green),
                            onPressed: () => _markDone(a),
                          ),
                  ),
                );
              },
            ),
    );
  }
}
