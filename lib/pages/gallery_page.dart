import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../helpers/database_helper.dart';

class GalleryPage extends StatefulWidget {
  const GalleryPage({Key? key}) : super(key: key);

  @override
  _GalleryPageState createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  final ImagePicker _picker = ImagePicker();
  List<Map<String, dynamic>> _imageFileList = [];
  Set<int> _selectedImages = {}; // Set untuk menyimpan ID gambar yang dipilih
  bool _isSelecting = false; // Untuk mengecek apakah sedang dalam mode memilih

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  // Memuat gambar-gambar dari database
  Future<void> _loadImages() async {
    final images = await DatabaseHelper.instance.getAllImages();
    setState(() {
      _imageFileList = images;
    });
  }

  // Fungsi untuk memilih gambar dan menyimpannya ke database
  Future<void> _pickImage() async {
    final pickedFiles = await _picker.pickMultiImage();

    if (pickedFiles != null && pickedFiles.isNotEmpty) {
      for (var pickedFile in pickedFiles) {
        final imageFile = File(pickedFile.path);
        final date = DateTime.now();

        // Simpan gambar ke database
        await DatabaseHelper.instance.insertImage(imageFile, date);

        // Muat gambar terbaru setelah disimpan
        _loadImages();
      }
    }
  }

  // Fungsi untuk menghapus gambar yang dipilih
  Future<void> _deleteSelectedImages() async {
    for (var id in _selectedImages) {
      await DatabaseHelper.instance.deleteImage(id);
    }
    setState(() {
      _selectedImages
          .clear(); // Setelah selesai menghapus, clear selected images
    });
    _loadImages();
  }

  // Fungsi untuk menambahkan gambar ke favorit
  Future<void> _addToFavorites(int id, bool currentFavoriteStatus) async {
    final newStatus = !currentFavoriteStatus;

    // Perbarui status favorit gambar berdasarkan id
    await DatabaseHelper.instance.updateFavoriteStatus(id, newStatus);

    // Muat ulang gambar setelah menambahkan ke favorit
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(newStatus
              ? 'Image added to favorites!'
              : 'Image removed from favorites!')),
    );

    _loadImages();
  }

  Future<void> _confirmDeleteSelectedImages() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Konfirmasi Hapus"),
          content: const Text(
              "Apakah Anda yakin ingin menghapus gambar yang dipilih?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false), // Tidak hapus
              child: const Text("Tidak"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true), // Hapus
              child: const Text("Ya"),
            ),
          ],
        );
      },
    );

    // Jika pengguna memilih "Ya", hapus gambar yang dipilih
    if (shouldDelete == true) {
      await _deleteSelectedImages();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gallery'),
        actions: [
          // Menambahkan tombol "Pilih Banyak" di AppBar
          IconButton(
            icon: Icon(_isSelecting ? Icons.cancel : Icons.check),
            onPressed: () {
              setState(() {
                _isSelecting = !_isSelecting;
                if (!_isSelecting) {
                  _selectedImages
                      .clear(); // Hapus semua pemilihan ketika keluar dari mode memilih
                }
              });
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: _imageFileList.length,
          itemBuilder: (context, index) {
            final imageData = _imageFileList[index];
            final imageBytes = imageData['image'] as List<int>;
            final image = Image.memory(
              Uint8List.fromList(imageBytes),
              fit: BoxFit.cover, // Agar gambar sesuai ukuran Card
            );
            final isFavorite = imageData['is_favorite'] == 1;
            final isSelected = _selectedImages.contains(imageData['id']);

            return GestureDetector(
              onLongPress: _isSelecting
                  ? () {
                      // Mulai memilih gambar saat pertama kali di-*longPress*
                      setState(() {
                        if (!isSelected) {
                          _selectedImages.add(imageData['id']);
                        }
                      });
                    }
                  : null, // hanya aktifkan long press jika dalam mode pemilihan
              onTap: () {
                if (_isSelecting) {
                  // Ketika dalam mode pemilihan, cukup di-tap untuk memilih gambar
                  setState(() {
                    if (isSelected) {
                      _selectedImages.remove(imageData['id']);
                    } else {
                      _selectedImages.add(imageData['id']);
                    }
                  });
                } else {
                  // Menampilkan gambar ketika tidak dalam mode pemilihan
                  showDialog(
                    context: context,
                    builder: (context) {
                      return Dialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12.0),
                              child: image,
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                // Tombol Back
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(context).pop(); // Tutup dialog
                                  },
                                  child: const Text(
                                    'Back',
                                    style: TextStyle(
                                        color: Colors.red), // Warna teks merah
                                  ),
                                ),
                                // Tombol Add to Favorites
                                TextButton(
                                  onPressed: () {
                                    _addToFavorites(
                                        imageData['id'], isFavorite);
                                    Navigator.of(context)
                                        .pop(); // Tutup dialog setelah favorit
                                  },
                                  child: Text(isFavorite
                                      ? 'Remove from Favorites'
                                      : 'Add to Favorites'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                }
              },
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    image,
                    if (isFavorite)
                      Positioned(
                        top: 5,
                        right: 5,
                        child: Icon(
                          Icons.star,
                          color: Colors.greenAccent,
                          size: 24,
                        ),
                      ),
                    if (isSelected)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.blue
                              .withOpacity(0.3), // Overlay biru opasitas rendah
                        ),
                      ),
                    if (isSelected) // Menambahkan border atau indikator untuk gambar yang dipilih
                      Positioned(
                        top: 5,
                        left: 5,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isSelecting ? _confirmDeleteSelectedImages : _pickImage,
        child: Icon(_isSelecting
            ? Icons.delete
            : Icons.add), // Ikon berubah sesuai mode
      ),
    );
  }
}
