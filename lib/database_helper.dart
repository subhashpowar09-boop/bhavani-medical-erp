import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database!= null) return _database!;
    _database = await _initDB('medical.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
    CREATE TABLE medicines(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      salt TEXT,
      batch TEXT,
      expiry TEXT,
      mrp REAL,
      rate REAL,
      qty INTEGER,
      rack TEXT
    )
    ''');

    await db.execute('''
    CREATE TABLE bills(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      bill_no TEXT,
      customer_name TEXT,
      customer_phone TEXT,
      date TEXT,
      subtotal REAL,
      cgst REAL,
      sgst REAL,
      total REAL,
      items TEXT
    )
    ''');
  }

  Future<int> insertMedicine(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('medicines', row);
  }

  Future<List<Map<String, dynamic>>> getAllMedicines() async {
    final db = await instance.database;
    return await db.query('medicines', orderBy: 'name');
  }

  Future<List<Map<String, dynamic>>> getLowStock() async {
    final db = await instance.database;
    return await db.query('medicines', where: 'qty < 10');
  }

  Future<List<Map<String, dynamic>>> getExpirySoon() async {
    final db = await instance.database;
    final threeMonthsLater = DateTime.now().add(Duration(days: 90)).toIso8601String();
    return await db.query('medicines', where: 'expiry <?', whereArgs: [threeMonthsLater]);
  }

  Future<int> updateMedicine(Map<String, dynamic> row) async {
    final db = await instance.database;
    int id = row['id'];
    return await db.update('medicines', row, where: 'id =?', whereArgs: [id]);
  }

  Future<int> deleteMedicine(int id) async {
    final db = await instance.database;
    return await db.delete('medicines', where: 'id =?', whereArgs: [id]);
  }

  Future<int> insertBill(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('bills', row);
  }

  Future<List<Map<String, dynamic>>> getAllBills() async {
    final db = await instance.database;
    return await db.query('bills', orderBy: 'id DESC');
  }
}
