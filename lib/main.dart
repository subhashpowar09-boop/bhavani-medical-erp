import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'database_helper.dart';

void main() => runApp(BhavaniApp());

class BhavaniApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bhavani Medicals ERP',
      theme: ThemeData(primarySwatch: Colors.teal),
      home: HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;
  final screens = [BillingScreen(), StockScreen(), ReportScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: screens[_index],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'Billing'),
          BottomNavigationBarItem(icon: Icon(Icons.inventory_2), label: 'Stock'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Reports'),
        ],
      ),
    );
  }
}

// BILLING SCREEN WITH GST
class BillingScreen extends StatefulWidget {
  @override
  _BillingScreenState createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  List<Map<String, dynamic>> cart = [];
  List<Map<String, dynamic>> medicines = [];
  TextEditingController customerName = TextEditingController();
  TextEditingController customerPhone = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadMedicines();
  }

  loadMedicines() async {
    medicines = await DatabaseHelper.instance.getAllMedicines();
    setState(() {});
  }

  double get subtotal => cart.fold(0, (sum, item) => sum + item['rate'] * item['qty']);
  double get cgst => subtotal * 0.06;
  double get sgst => subtotal * 0.06;
  double get total => subtotal + cgst + sgst;

  void addToCart(Map<String, dynamic> med) {
    showDialog(
        context: context,
        builder: (_) {
          int qty = 1;
          return AlertDialog(
            title: Text(med['name']),
            content: TextField(
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'Quantity'),
              onChanged: (v) => qty = int.tryParse(v)?? 1,
            ),
            actions: [
              TextButton(
                  onPressed: () {
                    setState(() => cart.add({...med, 'qty': qty}));
                    Navigator.pop(context);
                  },
                  child: Text('Add'))
            ],
          );
        });
  }

  Future<void> saveBill() async {
    if (cart.isEmpty) return;
    final billNo = 'BM${DateTime.now().millisecondsSinceEpoch}';
    await DatabaseHelper.instance.insertBill({
      'bill_no': billNo,
      'customer_name': customerName.text,
      'customer_phone': customerPhone.text,
      'date': DateFormat('dd-MM-yyyy').format(DateTime.now()),
      'subtotal': subtotal,
      'cgst': cgst,
      'sgst': sgst,
      'total': total,
      'items': cart.map((e) => '${e['name']} x${e['qty']}').join(', ')
    });

    // Update stock
    for (var item in cart) {
      item['qty'] = item['qty'] - item['qty'];
      await DatabaseHelper.instance.updateMedicine(item);
    }

    generatePDF(billNo);
    setState(() {
      cart.clear();
      customerName.clear();
      customerPhone.clear();
    });
    loadMedicines();
  }

  Future<void> generatePDF(String billNo) async {
    final pdf = pw.Document();
    pdf.addPage(pw.Page(
        build: (pw.Context context) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('BHAVANI MEDICALS', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                pw.Text('Cumbum, AP | GST: 37XXXXX1234Z5'),
                pw.Divider(),
                pw.Text('Bill No: $billNo'),
                pw.Text('Customer: ${customerName.text}'),
                pw.Text('Date: ${DateFormat('dd-MM-yyyy').format(DateTime.now())}'),
                pw.SizedBox(height: 20),
                pw.Table.fromTextArray(
                  headers: ['Item', 'Qty', 'Rate', 'Amount'],
                  data: cart.map((e) => [e['name'], e['qty'].toString(), e['rate'].toString(), (e['rate'] * e['qty']).toStringAsFixed(2)]).toList(),
                ),
                pw.SizedBox(height: 20),
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                    pw.Text('Subtotal: ${subtotal.toStringAsFixed(2)}'),
                    pw.Text('CGST 6%: ${cgst.toStringAsFixed(2)}'),
                    pw.Text('SGST 6%: ${sgst.toStringAsFixed(2)}'),
                    pw.Divider(),
                    pw.Text('Total: ${total.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                  ])
                ])
              ],
            )));
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Bhavani Medicals - Billing')),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(8),
            child: Row(children: [
              Expanded(child: TextField(controller: customerName, decoration: InputDecoration(labelText: 'Customer Name'))),
              SizedBox(width: 8),
              Expanded(child: TextField(controller: customerPhone, decoration: InputDecoration(labelText: 'Phone'))),
            ]),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: medicines.length,
              itemBuilder: (_, i) {
                final m = medicines[i];
                return ListTile(
                  title: Text('${m['name']} - Stock: ${m['qty']}'),
                  subtitle: Text('Exp: ${m['expiry']} | MRP: ₹${m['mrp']}'),
                  trailing: Text('₹${m['rate']}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  onTap: m['qty'] > 0? () => addToCart(m) : null,
                );
              },
            ),
          ),
          Container(
            color: Colors.teal.shade50,
            padding: EdgeInsets.all(12),
            child: Column(
              children: [
                Text('Cart: ${cart.length} items | Total: ₹${total.toStringAsFixed(2)}', style: TextStyle(fontSize: 18)),
                SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: saveBill,
                  icon: Icon(Icons.print),
                  label: Text('Save & Print Bill'),
                  style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 50)),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

// STOCK SCREEN
class StockScreen extends StatefulWidget {
  @override
  _StockScreenState createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  List<Map<String, dynamic>> medicines = [];
  List<Map<String, dynamic>> lowStock = [];

  @override
  void initState() {
    super.initState();
    loadData();
  }

  loadData() async {
    medicines = await DatabaseHelper.instance.getAllMedicines();
    lowStock = await DatabaseHelper.instance.getLowStock();
    setState(() {});
  }

  void addMedicine() {
    final name = TextEditingController();
    final salt = TextEditingController();
    final batch = TextEditingController();
    final expiry = TextEditingController();
    final mrp = TextEditingController();
    final rate = TextEditingController();
    final qty = TextEditingController();
    final rack = TextEditingController();

    showDialog(
        context: context,
        builder: (_) => AlertDialog(
              title: Text('Add Medicine'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: name, decoration: InputDecoration(labelText: 'Medicine Name*')),
                    TextField(controller: salt, decoration: InputDecoration(labelText: 'Salt/Composition')),
                    TextField(controller: batch, decoration: InputDecoration(labelText: 'Batch No')),
                    TextField(controller: expiry, decoration: InputDecoration(labelText: 'Expiry (YYYY-MM-DD)')),
                    TextField(controller: mrp, decoration: InputDecoration(labelText: 'MRP'), keyboardType: TextInputType.number),
                    TextField(controller: rate, decoration: InputDecoration(labelText: 'Selling Rate*'), keyboardType: TextInputType.number),
                    TextField(controller: qty, decoration: InputDecoration(labelText: 'Quantity*'), keyboardType: TextInputType.number),
                    TextField(controller: rack, decoration: InputDecoration(labelText: 'Rack No')),
                  ],
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () async {
                      await DatabaseHelper.instance.insertMedicine({
                        'name': name.text,
                        'salt': salt.text,
                        'batch': batch.text,
                        'expiry': expiry.text,
                        'mrp': double.tryParse(mrp.text)?? 0,
                        'rate': double.tryParse(rate.text)?? 0,
                        'qty': int.tryParse(qty.text)?? 0,
                        'rack': rack.text,
                      });
                      Navigator.pop(context);
                      loadData();
                    },
                    child: Text('Save'))
              ],
            ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Stock Management')),
      body: Column(
        children: [
          if (lowStock.isNotEmpty)
            Container(
              color: Colors.red.shade100,
              padding: EdgeInsets.all(8),
              child: Text('⚠️ Low Stock Alert: ${lowStock.length} items below 10 qty', style: TextStyle(color: Colors.red.shade900)),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: medicines.length,
              itemBuilder: (_, i) {
                final m = medicines[i];
                final isLow = m['qty'] < 10;
                return ListTile(
                  tileColor: isLow? Colors.red.shade50 : null,
                  title: Text(m['name']),
                  subtitle: Text('Batch: ${m['batch']} | Exp: ${m['expiry']} | Rack: ${m['rack']}'),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Qty: ${m['qty']}', style: TextStyle(fontWeight: FontWeight.bold, color: isLow? Colors.red : Colors.green)),
                      Text('₹${m['rate']}')
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(onPressed: addMedicine, child: Icon(Icons.add)),
    );
  }
}

// REPORT SCREEN
class ReportScreen extends StatefulWidget {
  @override
  _ReportScreenState createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  List<Map<String, dynamic>> bills = [];
  double todaySales = 0;

  @override
  void initState() {
    super.initState();
    loadBills();
  }

  loadBills() async {
    bills = await DatabaseHelper.instance.getAllBills();
    final today = DateFormat('dd-MM-yyyy').format(DateTime.now());
    todaySales = bills.where((b) => b['date'] == today).fold(0, (sum, b) => sum + b['total']);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Reports')),
      body: Column(
        children: [
          Card(
            margin: EdgeInsets.all(16),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(children: [
                Text('Today Sales', style: TextStyle(fontSize: 16)),
                Text('₹${todaySales.toStringAsFixed(2)}', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.teal)),
                Text('Total Bills: ${bills.length}')
              ]),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: bills.length,
              itemBuilder: (_, i) {
                final b = bills[i];
                return ListTile(
                  title: Text('${b['bill_no']} - ${b['customer_name']}'),
                  subtitle: Text('${b['date']} | ${b['items']}'),
                  trailing: Text('₹${b['total'].toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
