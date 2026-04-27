import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() {
  runApp(BhavaniApp());
}

class BhavaniApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bhavani Medicals',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
        fontFamily: 'Roboto',
      ),
      home: BillingScreen(),
    );
  }
}

class BillingScreen extends StatefulWidget {
  @override
  _BillingScreenState createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  List<Map<String, dynamic>> medicines = [];
  List<Map<String, dynamic>> bills = [];
  TextEditingController nameController = TextEditingController();
  TextEditingController qtyController = TextEditingController();
  TextEditingController priceController = TextEditingController();
  TextEditingController customerController = TextEditingController();
  
  double total = 0;
  int billNumber = 1;

  @override
  void initState() {
    super.initState();
    loadBills();
  }

  void loadBills() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? billsData = prefs.getString('bills');
    String? billNum = prefs.getString('billNumber');
    if (billsData!= null) {
      bills = List<Map<String, dynamic>>.from(json.decode(billsData));
    }
    if (billNum!= null) {
      billNumber = int.parse(billNum);
    }
    setState(() {});
  }

  void saveBills() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('bills', json.encode(bills));
    prefs.setString('billNumber', billNumber.toString());
  }

  void addMedicine() {
    if (nameController.text.isEmpty || qtyController.text.isEmpty || priceController.text.isEmpty) {
      return;
    }
    setState(() {
      double price = double.parse(priceController.text);
      int qty = int.parse(qtyController.text);
      medicines.add({
        'name': nameController.text,
        'qty': qty,
        'price': price,
        'total': price * qty
      });
      total += price * qty;
      nameController.clear();
      qtyController.clear();
      priceController.clear();
    });
  }

  void generateBill() async {
    if (medicines.isEmpty || customerController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Customer name and medicines required'))
      );
      return;
    }

    final pdf = pw.Document();
    final now = DateTime.now();
    final dateFormat = DateFormat('dd/MM/yyyy hh:mm a');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text('BHAVANI MEDICALS', 
                  style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold))
              ),
              pw.Center(child: pw.Text('HYD - Call: 9876543210')),
              pw.SizedBox(height: 20),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Bill No: $billNumber'),
                  pw.Text('Date: ${dateFormat.format(now)}'),
                ]
              ),
              pw.Text('Customer: ${customerController.text}'),
              pw.SizedBox(height: 20),
              pw.Table.fromTextArray(
                headers: ['Medicine', 'Qty', 'Price', 'Total'],
                data: medicines.map((m) => [
                  m['name'],
                  m['qty'].toString(),
                  'Rs.${m['price'].toStringAsFixed(2)}',
                  'Rs.${m['total'].toStringAsFixed(2)}'
                ]).toList(),
              ),
              pw.SizedBox(height: 20),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text('Grand Total: Rs.${total.toStringAsFixed(2)}',
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold))
              ),
              pw.SizedBox(height: 40),
              pw.Center(child: pw.Text('Thank You! Visit Again')),
            ]
          );
        }
      )
    );

    bills.add({
      'billNo': billNumber,
      'customer': customerController.text,
      'date': now.toIso8601String(),
      'total': total,
      'items': medicines
    });
    billNumber++;
    saveBills();

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save()
    );

    setState(() {
      medicines.clear();
      total = 0;
      customerController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bhavani Medicals Billing'),
        centerTitle: true,
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: customerController,
              decoration: InputDecoration(
                labelText: 'Customer Name',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Medicine Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: qtyController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Qty',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: priceController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Price',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: addMedicine,
              child: Text('Add Medicine'),
              style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 45)),
            ),
            SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: medicines.length,
                itemBuilder: (context, index) {
                  return Card(
                    child: ListTile(
                      title: Text(medicines[index]['name']),
                      subtitle: Text('Qty: ${medicines[index]['qty']} x Rs.${medicines[index]['price']}'),
                      trailing: Text('Rs.${medicines[index]['total'].toStringAsFixed(2)}',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  );
                },
              ),
            ),
            Container(
              padding: EdgeInsets.all(16),
              color: Colors.green.shade50,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total:', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  Text('Rs.${total.toStringAsFixed(2)}', 
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
                ],
              ),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: generateBill,
              child: Text('Generate PDF Bill', style: TextStyle(fontSize: 18)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                minimumSize: Size(double.infinity, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
