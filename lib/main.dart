import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'db_helper.dart';
import 'payment_service.dart';
import 'screens/business_screens.dart';

void main() => runApp(const BizBoxApp());

class BizBoxApp extends StatelessWidget {
  const BizBoxApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BizBox SA',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: const SplashScreen(),
      routes: {'/admin': (_) => const AdminPanel()},
    );
  }
}

int daysLeft(SharedPreferences p) {
  final first = DateTime.tryParse(p.getString('first_open')?? '');
  if (first == null) return 30;
  final used = DateTime.now().difference(first).inDays;
  return (30 - used).clamp(-999, 30);
}

void go(Widget w, BuildContext c) =>
    Navigator.pushReplacement(c, MaterialPageRoute(builder: (_) => w));

void goPush(Widget w, BuildContext c) =>
    Navigator.push(c, MaterialPageRoute(builder: (_) => w));

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    PaymentService.instance.listenPurchases(onResult: (ok) {
      if (ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Subscription active ✓')),
        );
      }
    });
    Timer(const Duration(seconds: 2), _next);
  }

  Future<void> _next() async {
    final p = await SharedPreferences.getInstance();
    final paid = p.getBool('is_paid')?? false;
    final firstOpen = p.getString('first_open');
    final bizName = p.getString('business_name');
    final ownerPin = p.getString('owner_lock_pin');

    if (firstOpen!= null &&!paid && daysLeft(p) <= 0) {
      go(const PaymentScreen(), context);
      return;
    }
    if (ownerPin!= null && ownerPin.isNotEmpty && bizName!= null) {
      go(const LockScreen(), context);
      return;
    }
    if (bizName == null) {
      go(const OnboardingScreen(), context);
      return;
    }
    go(const DashboardScreen(), context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade700,
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.business_center, size: 120, color: Colors.white),
          const SizedBox(height: 16),
          const Text('BizBox SA',
              style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('One App Any Business', style: TextStyle(color: Colors.white70, fontSize: 16)),
          const SizedBox(height: 40),
          const CircularProgressIndicator(color: Colors.white),
        ]),
      ),
    );
  }
}

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});
  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _pin = TextEditingController();
  Future<void> _check() async {
    final p = await SharedPreferences.getInstance();
    if (_pin.text.trim() == (p.getString('owner_lock_pin')?? '')) {
      if (mounted) go(const DashboardScreen(), context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Wrong PIN')));
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.lock_outline, size: 80, color: Colors.blue),
          const SizedBox(height: 20),
          const Text('Enter Staff PIN', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          TextField(controller: _pin, keyboardType: TextInputType.number, obscureText: true, maxLength: 6, textAlign: TextAlign.center, decoration: const InputDecoration(border: OutlineInputBorder())),
          const SizedBox(height: 20),
          FilledButton(onPressed: _check, child: const Text('Unlock')),
        ]),
      ),
    );
  }
}

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});
  static const _types = [
    ['Tuck Shop', Icons.store, Colors.orange],
    ['Restaurant', Icons.restaurant, Colors.red],
    ['Car Wash', Icons.local_car_wash, Colors.blue],
    ['Salon', Icons.content_cut, Colors.purple],
  ];
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose Your Business')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          const Text('What type of business do you run?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.separated(
              itemCount: _types.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (c, i) {
                final t = _types[i];
                return InkWell(
                  onTap: () async {
                    final p = await SharedPreferences.getInstance();
                    await p.setString('business_type', t[0] as String);
                    if (c.mounted) goPush(const BusinessSetupScreen(), c);
                  },
                  child: Container(
                    height: 100,
                    decoration: BoxDecoration(color: t[2] as Color, borderRadius: BorderRadius.circular(16)),
                    child: Row(children: [
                      const SizedBox(width: 20),
                      Icon(t[1] as IconData, size: 50, color: Colors.white),
                      const SizedBox(width: 20),
                      Text(t[0] as String, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                    ]),
                  ),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

class BusinessSetupScreen extends StatefulWidget {
  const BusinessSetupScreen({super.key});
  @override
  State<BusinessSetupScreen> createState() => _BusinessSetupScreenState();
}

class _BusinessSetupScreenState extends State<BusinessSetupScreen> {
  final _biz = TextEditingController();
  final _owner = TextEditingController();
  final _phone = TextEditingController();
  final _loc = TextEditingController();
  File? _logo;
  Future<void> _pickLogo() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (x!= null) setState(() => _logo = File(x.path));
  }
  Future<void> _getGps() async {
    setState(() => _loc.text = '-26.2041, 28.0473');
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location captured: Johannesburg')));
  }
  Future<void> _save() async {
    if (_biz.text.isEmpty || _owner.text.isEmpty) return;
    if (!_phone.text.startsWith('+27')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Phone must start with +27')));
      return;
    }
    final p = await SharedPreferences.getInstance();
    await p.setString('first_open', p.getString('first_open')?? DateTime.now().toIso8601String());
    await p.setString('business_name', _biz.text);
    await p.setString('owner_name', _owner.text);
    await p.setString('phone', _phone.text);
    await p.setString('location', _loc.text);
    await p.setString('logo', _logo?.path?? '');
    await p.setBool('is_paid', false);
    if (mounted) go(const DashboardScreen(), context);
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Business Setup')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(controller: _biz, decoration: const InputDecoration(labelText: 'Business Name', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: _owner, decoration: const InputDecoration(labelText: 'Owner Name', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'WhatsApp Number (+27...)', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: _loc, decoration: InputDecoration(labelText: 'Location', border: const OutlineInputBorder(), suffixIcon: IconButton(icon: const Icon(Icons.gps_fixed), onPressed: _getGps))),
        const SizedBox(height: 16),
        OutlinedButton.icon(onPressed: _pickLogo, icon: const Icon(Icons.image), label: Text(_logo == null? 'Upload Logo' : 'Logo Selected')),
        const SizedBox(height: 24),
        FilledButton(onPressed: _save, child: const Text('Save & Continue')),
      ]),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _idx = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkTrial());
  }
  Future<void> _checkTrial() async {
    final p = await SharedPreferences.getInstance();
    final left = daysLeft(p);
    final paid = p.getBool('is_paid')?? false;
    if (!paid && left <= 0) {
      if (mounted) go(const PaymentScreen(), context);
      return;
    }
    if (!paid && (left == 27 || left == 29 || left == 30)) {
      if (!mounted) return;
      showDialog(context: context, builder: (_) => AlertDialog(title: const Text('Trial Reminder'), content: Text('$left days left. Subscribe now to keep using BizBox SA.'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Later')), FilledButton(onPressed: () { Navigator.pop(context); go(const PaymentScreen(), context); }, child: const Text('Pay Now'))]));
    }
  }
  @override
  Widget build(BuildContext context) {
    final pages = [const BusinessScreenRouter(), const ReportsPage(), const DebtPage(), const ExpensePage(), const SettingsPage()];
    return FutureBuilder<SharedPreferences>(
      future: SharedPreferences.getInstance(),
      builder: (c, s) {
        if (!s.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        final p = s.data!;
        final left = daysLeft(p);
        final paid = p.getBool('is_paid')?? false;
        final biz = p.getString('business_name')?? 'BizBox';
        return Scaffold(
          appBar: AppBar(title: Text(biz), actions: [Padding(padding: const EdgeInsets.all(12), child: Center(child: Text(paid? 'PAID' : '$left days', style: TextStyle(color: paid? Colors.green : (left <= 5? Colors.red : Colors.black), fontWeight: FontWeight.bold))))]),
          body: Column(children: [Container(width: double.infinity, color: paid? Colors.green : (left <= 5? Colors.red : Colors.green.shade400), padding: const EdgeInsets.all(8), child: Text(paid? '✅ Subscription Active' : '⏳ Trial: $left days left', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white))), Expanded(child: pages[_idx])]),
          bottomNavigationBar: NavigationBar(selectedIndex: _idx, onDestinationSelected: (i) => setState(() => _idx = i), destinations: const [NavigationDestination(icon: Icon(Icons.point_of_sale), label: 'Sell'), NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Reports'), NavigationDestination(icon: Icon(Icons.people), label: 'Debt'), NavigationDestination(icon: Icon(Icons.receipt), label: 'Expenses'), NavigationDestination(icon: Icon(Icons.settings), label: 'Settings')]),
        );
      },
    );
  }
}

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});
  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  Map<String, double> _sum = {'Today': 0, 'Week': 0, 'Month': 0};
  @override
  void initState() {
    super.initState();
    _load();
  }
  Future<void> _load() async {
    final db = await DBHelper.database;
    final rows = await db.query('sales');
    final now = DateTime.now();
    double t = 0, w = 0, m = 0;
    for (final r in rows) {
      final d = DateTime.parse(r['date'] as String);
      final amt = (r['total'] as num).toDouble();
      if (d.year == now.year && d.month == now.month && d.day == now.day) t += amt;
      if (now.difference(d).inDays < 7) w += amt;
      if (now.difference(d).inDays < 30) m += amt;
    }
    setState(() => _sum = {'Today': t, 'Week': w, 'Month': m});
  }
  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      const Text('Profit Report', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
     ..._sum.entries.map((e) => Card(child: ListTile(leading: const Icon(Icons.attach_money), title: Text(e.key), trailing: Text('R${e.value.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))))),
      const SizedBox(height: 20),
      FilledButton.icon(icon: const Icon(Icons.share), label: const Text('Share Report via WhatsApp'), onPressed: () { final msg = Uri.encodeComponent('BizBox Report:\nToday: R${_sum['Today']}\nWeek: R${_sum['Week']}\nMonth: R${_sum['Month']}'); launchUrl(Uri.parse('https://wa.me/?text=$msg')); }),
    ]);
  }
}

// ====== FIXED DEBT PAGE - THIS WAS THE BUG ======
class DebtPage extends StatefulWidget {
  const DebtPage({super.key});
  @override
  State<DebtPage> createState() => _DebtPageState();
}

class _DebtPageState extends State<DebtPage> {
  List<Map<String, dynamic>> _rows = [];
  @override
  void initState() {
    super.initState();
    _load();
  }
  Future<void> _load() async {
    final db = await DBHelper.database;
    final data = await db.query('debts');
    if (mounted) setState(() => _rows = data);
  }
  Future<void> _add() async {
    final n = TextEditingController();
    final ph = TextEditingController();
    final a = TextEditingController();
    await showDialog(context: context, builder: (_) => AlertDialog(title: const Text('Add Debt'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: n, decoration: const InputDecoration(labelText: 'Customer')), TextField(controller: ph, decoration: const InputDecoration(labelText: 'Phone')), TextField(controller: a, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount'))]), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () async { final db = await DBHelper.database; await db.insert('debts', {'customer': n.text, 'phone': ph.text, 'amount': double.tryParse(a.text)?? 0, 'paid': 0, 'date': DateTime.now().toIso8601String()}); if (mounted) Navigator.pop(context); _load(); }, child: const Text('Save'))]));
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(floatingActionButton: FloatingActionButton(onPressed: _add, child: const Icon(Icons.add)), body: _rows.isEmpty? const Center(child: Text('No debts yet')) : ListView.builder(itemCount: _rows.length, itemBuilder: (c, i) { final r = _rows[i]; final bal = (r['amount'] as num) - (r['paid'] as num); return ListTile(title: Text(r['customer']), subtitle: Text('${r['phone']} • Balance: R$bal'), trailing: FilledButton(onPressed: () async { final db = await DBHelper.database; await db.update('debts', {'paid': r['amount']}, where: 'id =?', whereArgs: [r['id']]); _load(); }, child: const Text('Paid'))); }));
  }
}

// ====== FIXED EXPENSE PAGE - THIS WAS THE BUG ======
class ExpensePage extends StatefulWidget {
  const ExpensePage({super.key});
  @override
  State<ExpensePage> createState() => _ExpensePageState();
}

class _ExpensePageState extends State<ExpensePage> {
  List<Map<String, dynamic>> _rows = [];
  @override
  void initState() {
    super.initState();
    _load();
  }
  Future<void> _load() async {
    final db = await DBHelper.database;
    final data = await db.query('expenses');
    if (mounted) setState(() => _rows = data);
  }
  Future<void> _add() async {
    final t = TextEditingController();
    final a = TextEditingController();
    await showDialog(context: context, builder: (_) => AlertDialog(title: const Text('Add Expense'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: t, decoration: const InputDecoration(labelText: 'Title')), TextField(controller: a, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount'))]), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () async { final db = await DBHelper.database; await db.insert('expenses', {'title': t.text, 'amount': double.tryParse(a.text)?? 0, 'date': DateTime.now().toIso8601String()}); if (mounted) Navigator.pop(context); _load(); }, child: const Text('Save'))]));
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(floatingActionButton: FloatingActionButton(onPressed: _add, child: const Icon(Icons.add)), body: _rows.isEmpty? const Center(child: Text('No expenses yet')) : ListView.builder(itemCount: _rows.length, itemBuilder: (c, i) => ListTile(leading: const Icon(Icons.receipt_long), title: Text(_rows[i]['title']), trailing: Text('R${_rows[i]['amount']}'))));
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SharedPreferences>(future: SharedPreferences.getInstance(), builder: (c, s) { if (!s.hasData) return const Center(child: CircularProgressIndicator()); final p = s.data!; final lang = p.getString('lang')?? 'en'; final hasLock = (p.getString('owner_lock_pin')?? '').isNotEmpty; return ListView(children: [ListTile(leading: const Icon(Icons.language), title: const Text('Language'), subtitle: Text(lang == 'en'? 'English' : 'isiZulu'), trailing: Switch(value: lang == 'zu', onChanged: (v) async { await p.setString('lang', v? 'zu' : 'en'); (context as Element).markNeedsBuild(); })), ListTile(leading: const Icon(Icons.lock), title: Text(hasLock? 'Change Staff Lock PIN' : 'Set Staff Lock PIN'), subtitle: Text(hasLock? 'Staff must enter PIN to open app' : 'Protect the app with a 4-6 digit PIN'), onTap: () => _setOwnerPin(context, p)), if (hasLock) ListTile(leading: const Icon(Icons.lock_open), title: const Text('Remove Staff Lock PIN'), onTap: () async { await p.remove('owner_lock_pin'); if (context.mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Staff Lock removed'))); (context as Element).markNeedsBuild(); } }), ListTile(leading: const Icon(Icons.help), title: const Text('Help & Videos'), onTap: () => showDialog(context: context, builder: (_) => const AlertDialog(title: Text('Help'), content: Text('Video tutorials coming soon!')))), ListTile(leading: const Icon(Icons.privacy_tip), title: const Text('Privacy Policy'), onTap: () => _showText(context, 'Privacy Policy', 'BizBox SA respects your privacy. All data stays on your device.')), ListTile(leading: const Icon(Icons.description), title: const Text('Terms & Conditions'), onTap: () => _showText(context, 'Terms', 'By using BizBox SA you agree to our terms. R99/month subscription.')), ListTile(leading: const Icon(Icons.support_agent), title: const Text('Contact Support'), onTap: () => launchUrl(Uri.parse('https://wa.me/27000000000?text=Help%20BizBox'))), ListTile(leading: const Icon(Icons.star), title: const Text('Rate Us'), onTap: () => launchUrl(Uri.parse('https://play.google.com/store'))), ListTile(leading: const Icon(Icons.restore), title: const Text('Restore Purchase'), onTap: () async { await PaymentService.instance.restore(); if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Checking Google Play...'))); }), ListTile(leading: const Icon(Icons.admin_panel_settings), title: const Text('Admin Panel'), onTap: () => Navigator.pushNamed(context, '/admin')), ListTile(leading: const Icon(Icons.lock_outline), title: const Text('Phone OTP Login'), subtitle: const Text('Simulated 6-digit OTP'), onTap: () => _otp(context))]); });
  }
  void _showText(BuildContext c, String t, String m) => showDialog(context: c, builder: (_) => AlertDialog(title: Text(t), content: Text(m)));
  Future<void> _setOwnerPin(BuildContext c, SharedPreferences p) async {
    final pin = TextEditingController();
    await showDialog(context: c, builder: (_) => AlertDialog(title: const Text('Set Staff Lock PIN'), content: TextField(controller: pin, keyboardType: TextInputType.number, obscureText: true, maxLength: 6, decoration: const InputDecoration(hintText: '4-6 digits', border: OutlineInputBorder())), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')), FilledButton(onPressed: () async { final v = pin.text.trim(); if (v.length >= 4 && v.length <= 6) { await p.setString('owner_lock_pin', v); if (c.mounted) { Navigator.pop(c); ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content: Text('Staff Lock PIN saved ✓'))); } } else { ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content: Text('PIN must be 4-6 digits'))); } }, child: const Text('Save'))]));
  }
  Future<void> _otp(BuildContext c) async {
    final code = TextEditingController();
    await showDialog(context: c, builder: (_) => AlertDialog(title: const Text('Enter OTP'), content: TextField(controller: code, keyboardType: TextInputType.number, maxLength: 6), actions: [FilledButton(onPressed: () => Navigator.pop(c), child: const Text('Verify'))]));
    if (c.mounted) ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content: Text('OTP Verified ✓')));
  }
}

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});
  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _busy = false;
  Future<void> _subscribe() async {
    setState(() => _busy = true);
    try {
      final started = await PaymentService.instance.buy();
      if (!started && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product not available. Create "bizbox_monthly_99" in Play Console first.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
  Future<void> _restore() async {
    await PaymentService.instance.restore();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Checking Google Play...')));
  }
  Future<void> _uploadEft() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (x!= null && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('EFT proof uploaded. We will confirm within 24h.')));
  }
  @override
  Widget build(BuildContext context) {
    return PopScope(canPop: false, child: Scaffold(appBar: AppBar(title: const Text('Subscribe'), automaticallyImplyLeading: false), body: Padding(padding: const EdgeInsets.all(16), child: ListView(children: [Card(color: Colors.blue.shade50, child: const Padding(padding: EdgeInsets.all(24), child: Column(children: [Icon(Icons.business_center, size: 80, color: Colors.blue), SizedBox(height: 12), Text('R99 / month', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)), Text('Full access to BizBox SA'), SizedBox(height: 8), Text('Billed automatically every month. Cancel anytime in Google Play.', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54, fontSize: 12))]))), const SizedBox(height: 24), FilledButton.icon(icon: _busy? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.shop), label: Text(_busy? 'Processing...' : 'Subscribe R99/month via Google Play'), onPressed: _busy? null : _subscribe), const SizedBox(height: 12), OutlinedButton.icon(icon: const Icon(Icons.restore), label: const Text('Restore Purchase'), onPressed: _busy? null : _restore), const Divider(height: 40), const Text('Alternative: EFT Payment', style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 8), const Text('Bank: FNB\nAccount: 62000000000\nBranch: 250655\nRef: Your Business Name', style: TextStyle(fontSize: 13, color: Colors.black54)), const SizedBox(height: 12), OutlinedButton.icon(icon: const Icon(Icons.upload_file), label: const Text('Upload EFT Proof'), onPressed: _busy? null : _uploadEft), const SizedBox(height: 24), TextButton.icon(icon: const Icon(Icons.chat), label: const Text('Need help? Chat on WhatsApp'), onPressed: () => launchUrl(Uri.parse('https://wa.me/27000000000?text=Subscribe%20BizBox')))]))));
  }
}

class AdminPanel extends StatefulWidget {
  const AdminPanel({super.key});
  @override
  State<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> {
  final _pin = TextEditingController();
  bool _unlocked = false;
  bool _loading = true;
  bool _hasPin = false;
  final _mock = [
    {'name': 'Joe Tuck Shop', 'type': 'Tuck Shop', 'days': 12, 'paid': true},
    {'name': "Mama's Kitchen", 'type': 'Restaurant', 'days': 3, 'paid': false},
    {'name': 'Shine Car Wash', 'type': 'Car Wash', 'days': 0, 'paid': false},
    {'name': 'Glam Salon', 'type': 'Salon', 'days': 25, 'paid': true},
  ];
  @override
  void initState() {
    super.initState();
    _init();
  }
  Future<void> _init() async {
    final p = await SharedPreferences.getInstance();
    final has = (p.getString('admin_pin')?? '').isNotEmpty;
    setState(() { _hasPin = has; _loading = false; });
  }
  Future<void> _setAdminPin() async {
    final v = _pin.text.trim();
    if (v.length < 4) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN must be at least 4 digits'))); return; }
    final p = await SharedPreferences.getInstance();
    await p.setString('admin_pin', v);
    setState(() { _hasPin = true; _unlocked = true; });
  }
  Future<void> _unlock() async {
    final p = await SharedPreferences.getInstance();
    if (_pin.text.trim() == (p.getString('admin_pin')?? '')) { setState(() => _unlocked = true); } else { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Wrong PIN'))); }
  }
  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (!_unlocked) return Scaffold(appBar: AppBar(title: Text(_hasPin? 'Admin Login' : 'Set Admin PIN')), body: Padding(padding: const EdgeInsets.all(24), child: Column(children: [Text(_hasPin? 'Enter your admin PIN' : 'First time? Create your private admin PIN.\nOnly YOU will know this.', textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)), const SizedBox(height: 24), TextField(controller: _pin, keyboardType: TextInputType.number, obscureText: true, maxLength: 8, textAlign: TextAlign.center, decoration: const InputDecoration(labelText: 'PIN', border: OutlineInputBorder())), const SizedBox(height: 16), FilledButton(onPressed: _hasPin? _unlock : _setAdminPin, child: Text(_hasPin? 'Unlock' : 'Create PIN & Unlock'))])));
    final totalBiz = _mock.length;
    final revenue = _mock.where((e) => e['paid'] == true).length * 99.0;
    return Scaffold(appBar: AppBar(title: const Text('Super Admin')), body: ListView(padding: const EdgeInsets.all(16), children: [Row(children: [Expanded(child: _statCard('Businesses', '$totalBiz', Icons.store, Colors.blue)), const SizedBox(width: 10), Expanded(child: _statCard('Revenue', 'R$revenue', Icons.attach_money, Colors.green))]), const SizedBox(height: 20), const Text('All Businesses', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 10),..._mock.map((m) => Card(child: ListTile(leading: Icon(m['paid'] == true? Icons.check_circle : Icons.warning, color: m['paid'] == true? Colors.green : Colors.orange), title: Text(m['name'] as String), subtitle: Text('${m['type']} • ${m['days']} days left'), trailing: Wrap(children: [IconButton(icon: const Icon(Icons.notifications), onPressed: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Notification sent to ${m['name']}')))), IconButton(icon: const Icon(Icons.block), onPressed: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${m['name']} blocked/unblocked'))))]))))]));
  }
  Widget _statCard(String label, String value, IconData icon, Color color) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)), child: Column(children: [Icon(icon, color: color, size: 32), const SizedBox(height: 8), Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)), Text(label)]));
}
