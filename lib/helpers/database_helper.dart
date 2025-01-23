import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();

  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('gallery.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 2, onCreate: _createDB, onUpgrade: _onUpgrade);
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT';
    const blobType = 'BLOB';
    const intType = 'INTEGER';

    // Tabel untuk menyimpan gambar
    await db.execute(''' 
    CREATE TABLE images ( 
      id $idType, 
      image $blobType, 
      date $textType,
      is_favorite $intType DEFAULT 0
    )''');

    // Tabel untuk menyimpan data pengguna
    await db.execute('''
    CREATE TABLE users (
      id $idType,
      username $textType NOT NULL UNIQUE,
      password $textType NOT NULL
    )''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Menambahkan kolom is_favorite ke tabel images jika belum ada
      await db.execute('''
        ALTER TABLE images ADD COLUMN is_favorite INTEGER DEFAULT 0;
      ''');
    }

    if (oldVersion < 3) {
      // Membuat tabel users jika belum ada
      await db.execute('''
        CREATE TABLE users (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          username TEXT NOT NULL UNIQUE,
          password TEXT NOT NULL
        )''');
    }
  }

  // Fungsi untuk registrasi pengguna baru
  Future<int> registerUser(String username, String password,) async {
    final db = await instance.database;

    try {
      return await db.insert('users', {
        'username': username,
        'password': password,
      });
    } catch (e) {
      throw Exception('Username already exists');
    }
  }

  // Fungsi untuk login pengguna
  Future<Map<String, dynamic>?> loginUser(String username, String password) async {
    final db = await instance.database;

    final results = await db.query(
      'users',
      where: 'username = ? AND password = ?',
      whereArgs: [username, password],
    );

    return results.isNotEmpty ? results.first : null;
  }

  // Fungsi untuk menyisipkan gambar ke dalam database
  Future<int> insertImage(File imageFile, DateTime date, {bool isFavorite = false}) async {
    final db = await instance.database;
    final imageBytes = await imageFile.readAsBytes();
    final dateString = date.toIso8601String();

    return await db.insert('images', {
      'image': imageBytes,
      'date': dateString,
      'is_favorite': isFavorite ? 1 : 0,
    });
  }

  // Fungsi untuk menghapus gambar berdasarkan ID
  Future<int> deleteImage(int id) async {
    final db = await instance.database;
    return await db.delete(
      'images',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Fungsi untuk mengambil semua gambar
  Future<List<Map<String, dynamic>>> getAllImages() async {
    final db = await instance.database;
    return await db.query('images');
  }

  // Fungsi untuk mengambil gambar favorit (is_favorite = 1)
  Future<List<Map<String, dynamic>>> getFavorites() async {
    final db = await instance.database;
    return await db.query(
      'images',
      where: 'is_favorite = ?',
      whereArgs: [1],
    );
  }

  // Fungsi untuk mengambil gambar berdasarkan ID
  Future<Map<String, dynamic>?> getImageById(int id) async {
    final db = await instance.database;
    final results = await db.query(
      'images',
      where: 'id = ?',
      whereArgs: [id],
    );
    return results.isNotEmpty ? results.first : null;
  }

  // Fungsi untuk memperbarui status gambar sebagai favorit
  Future<int> updateFavoriteStatus(int id, bool isFavorite) async {
    final db = await instance.database;
    return await db.update(
      'images',
      {'is_favorite': isFavorite ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
