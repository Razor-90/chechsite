import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'site_status.db');
    return await openDatabase(
      path,
      onCreate: (db, version) {
        return db.execute(
          'CREATE TABLE site_history(id INTEGER PRIMARY KEY AUTOINCREMENT, site TEXT, timestamp TEXT, status INTEGER)',
        );
      },
      version: 1,
    );
  }

  Future<void> insertSiteHistory(
      String site, DateTime timestamp, int status) async {
    final db = await database;
    await db.insert(
      'site_history',
      {
        'site': site,
        'timestamp': timestamp.toIso8601String(),
        'status': status
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getSiteHistory(String site) async {
    final db = await database;
    return await db.query(
      'site_history',
      where: 'site = ?',
      whereArgs: [site],
      orderBy: 'timestamp DESC',
    );
  }
}
