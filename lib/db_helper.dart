import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DBHelper {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _init();
    return _db!;
  }

  static Future<Database> _init() async {
    final path = join(await getDatabasesPath(), 'bizboxsa.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, v) async {
        await db.execute('''CREATE TABLE products(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT,
          price REAL,
          stock INTEGER,
          barcode TEXT,
          category TEXT,
          photo TEXT)''');

        await db.execute('''CREATE TABLE sales(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          product TEXT,
          qty INTEGER,
          total REAL,
          date TEXT,
          type TEXT)''');

        await db.execute('''CREATE TABLE debts(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          customer TEXT,
          phone TEXT,
          amount REAL,
          paid REAL,
          date TEXT)''');

        await db.execute('''CREATE TABLE expenses(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT,
          amount REAL,
          date TEXT)''');

        await db.execute('''CREATE TABLE menu(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT,
          price REAL,
          category TEXT,
          image TEXT)''');

        await db.execute('''CREATE TABLE tables(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          number INTEGER,
          status TEXT)''');

        await db.execute('''CREATE TABLE car_queue(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          plate TEXT,
          customer TEXT,
          phone TEXT,
          carType TEXT,
          service TEXT,
          price REAL,
          status TEXT,
          worker TEXT,
          timestamp TEXT)''');

        await db.execute('''CREATE TABLE appointments(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          customer TEXT,
          phone TEXT,
          service TEXT,
          duration TEXT,
          datetime TEXT,
          status TEXT)''');
      },
    );
  }
}
