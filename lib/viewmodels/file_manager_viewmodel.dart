import 'package:file_tidy/models/file_operation.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path/path.dart' as path;

class FileManagerViewModel extends ChangeNotifier {
  // Mevcut dizindeki dosya ve klasörleri tutan liste
  List<FileSystemEntity> _items = [];
  // Mevcut dizin yolu
  String _currentPath = Directory.current.path;
  
  List<FileSystemEntity> get items => _items;
  String get currentPath => _currentPath;

  // Varsayılan tarama klasörleri
  final List<String> defaultScanPaths = [
    '${Platform.environment['USERPROFILE']}\\Downloads',
    '${Platform.environment['USERPROFILE']}\\Documents',
    '${Platform.environment['USERPROFILE']}\\Desktop',
    '${Platform.environment['USERPROFILE']}\\Pictures',
    '${Platform.environment['USERPROFILE']}\\Videos',
    '${Platform.environment['USERPROFILE']}\\Music',
  ];

  // Seçili tarama klasörü
  String _currentScanPath = '';
  String get currentScanPath => _currentScanPath;

  bool _isScanning = false;
  double _scanProgress = 0.0;
  String _currentScanningPath = '';
  List<FileSystemEntity> _scanResults = [];

  bool get isScanning => _isScanning;
  double get scanProgress => _scanProgress;
  String get currentScanningPath => _currentScanningPath;
  List<FileSystemEntity> get scanResults => _scanResults;

  // Taranmayacak sistem klasörleri listesi
  final List<String> _excludedPaths = [
    r'C:\$Recycle.Bin',
    r'C:\System Volume Information',
    r'C:\Windows',
    r'C:\Program Files',
    r'C:\Program Files (x86)',
    r'C:\ProgramData',
    'System Volume Information',
    '\$RECYCLE.BIN',
    'Config.Msi',
  ];

  // Klasörün taranabilir olup olmadığını kontrol et
  bool _isAccessibleDirectory(String path) {
    return !_excludedPaths.any((excluded) => 
      path.toLowerCase().contains(excluded.toLowerCase()));
  }

  // Constructor'ı güncelle
  FileManagerViewModel() {
    _currentScanPath = defaultScanPaths[0]; // Varsayılan olarak Downloads klasörü
    listDirectory(_currentPath);
  }

  // Tarama klasörünü değiştir
  void changeScanPath(String path) {
    _currentScanPath = path;
    notifyListeners();
  }

  // Dizin içeriğini listeleyen metod
  Future<void> listDirectory(String path) async {
    try {
      final dir = Directory(path);
      _items = await dir.list().toList();
      _currentPath = path;
      // Değişiklikleri dinleyenlere haber ver
      notifyListeners();
    } catch (e) {
      debugPrint('Dizin listeleme hatası: $e');
    }
  }

  // Üst dizine çıkma metodu
  void navigateUp() {
    final parent = path.dirname(_currentPath);
    if (parent != _currentPath) {
      listDirectory(parent);
    }
  }

  // Dosya/Klasör silme metodu
  Future<void> deleteItem(FileSystemEntity item) async {
    try {
      await item.delete(recursive: true);
      // Listeyi güncelle
      listDirectory(_currentPath);
    } catch (e) {
      debugPrint('Silme hatası: $e');
    }
  }

  // Dosya/klasör oluşturma metodu
  Future<void> createNewItem(String name, bool isDirectory) async {
    try {
      final newPath = path.join(_currentPath, name);
      if (isDirectory) {
        await Directory(newPath).create();
      } else {
        await File(newPath).create();
      }
      listDirectory(_currentPath);
    } catch (e) {
      debugPrint('Oluşturma hatası: $e');
    }
  }

  // Yeniden adlandırma metodu
  Future<void> renameItem(FileSystemEntity item, String newName) async {
    try {
      final newPath = path.join(path.dirname(item.path), newName);
      await item.rename(newPath);
      listDirectory(_currentPath);
    } catch (e) {
      debugPrint('Yeniden adlandırma hatası: $e');
    }
  }

  // Kopyalama metodu
  Future<void> copyItem(FileSystemEntity source, String destination) async {
    try {
      if (source is File) {
        final newPath = path.join(destination, path.basename(source.path));
        await source.copy(newPath);
      } else if (source is Directory) {
        final newPath = path.join(destination, path.basename(source.path));
        await _copyDirectory(source.path, newPath);
      }
      listDirectory(_currentPath);
    } catch (e) {
      debugPrint('Kopyalama hatası: $e');
    }
  }

  // Klasör kopyalama yardımcı metodu
  Future<void> _copyDirectory(String source, String destination) async {
    final dir = Directory(destination);
    await dir.create(recursive: true);
    
    await for (final entity in Directory(source).list(recursive: false)) {
      if (entity is Directory) {
        final newPath = path.join(destination, path.basename(entity.path));
        await _copyDirectory(entity.path, newPath);
      } else if (entity is File) {
        final newPath = path.join(destination, path.basename(entity.path));
        await entity.copy(newPath);
      }
    }
  }

  // Dosya arama metodu - tek versiyon
  Future<List<FileSystemEntity>> searchFiles(String query) async {
    if (query.isEmpty) {
      clearSearch();
      return _items;
    }

    try {
      List<FileSystemEntity> results = [];
      await for (final entity in Directory(_currentPath).list(recursive: true)) {
        final name = path.basename(entity.path).toLowerCase();
        if (name.contains(query.toLowerCase())) {
          results.add(entity);
        }
      }
      _items = results;
      notifyListeners();
      return results;
    } catch (e) {
      debugPrint('Arama hatası: $e');
      return [];
    }
  }

  void clearSearch() {
    listDirectory(_currentPath);
  }

  // Dosya detaylarını getiren metod
  Future<Map<String, dynamic>> getFileDetails(FileSystemEntity item) async {
    if (_fileDetailsCache.containsKey(item.path)) {
      return _getDetailsFromCache(item);
    }

    final details = await _getFileDetails(item);
    _fileDetailsCache[item.path] = item;
    return details;
  }

  // Büyük dosyaları bulan metod
  Future<List<FileSystemEntity>> findLargeFiles({int minSizeMB = 100}) async {
    List<FileSystemEntity> largeFiles = [];
    Map<String, int> fileSizes = {}; // Dosya boyutlarını önbelleğe alalım

    try {
      await for (final entity in Directory(_currentPath).list(recursive: true)) {
        if (entity is File) {
          final size = await entity.length();
          if (size > minSizeMB * 1024 * 1024) {
            largeFiles.add(entity);
            fileSizes[entity.path] = size; // Boyutu önbelleğe al
          }
        }
      }

      // Boyuta göre sırala (büyükten küçüğe)
      largeFiles.sort((a, b) {
        final sizeA = fileSizes[a.path] ?? 0;
        final sizeB = fileSizes[b.path] ?? 0;
        return sizeB.compareTo(sizeA);
      });
    } catch (e) {
      debugPrint('Büyük dosya arama hatası: $e');
    }
    return largeFiles;
  }

  // Uzun süre erişilmemiş dosyaları bulan metod
  Future<List<FileSystemEntity>> findOldFiles({int daysThreshold = 180}) async {
    List<FileSystemEntity> oldFiles = [];
    Map<String, DateTime> fileAccessTimes = {}; // Erişim zamanlarını önbelleğe alalım
    final threshold = DateTime.now().subtract(Duration(days: daysThreshold));
    
    try {
      await for (final entity in Directory(_currentPath).list(recursive: true)) {
        final stat = await entity.stat();
        if (stat.accessed.isBefore(threshold)) {
          oldFiles.add(entity);
          fileAccessTimes[entity.path] = stat.accessed; // Erişim zamanını önbelleğe al
        }
      }

      // Son erişime göre sırala (eskiden yeniye)
      oldFiles.sort((a, b) {
        final timeA = fileAccessTimes[a.path] ?? DateTime.now();
        final timeB = fileAccessTimes[b.path] ?? DateTime.now();
        return timeA.compareTo(timeB);
      });
    } catch (e) {
      debugPrint('Eski dosya arama hatası: $e');
    }
    return oldFiles;
  }

  // Yinelenen dosyaları bulan metod (boyut ve ad bazlı basit kontrol)
  Future<Map<String, List<File>>> findDuplicateFiles() async {
    Map<String, List<File>> duplicates = {};
    Map<String, List<File>> sizeGroups = {};

    try {
      await for (final entity in Directory(_currentPath).list(recursive: true)) {
        if (entity is File) {
          final size = await entity.length();
          final key = '${path.basename(entity.path)}_$size';
          
          sizeGroups[key] ??= [];
          sizeGroups[key]!.add(entity);
          
          if (sizeGroups[key]!.length > 1) {
            duplicates[key] = sizeGroups[key]!;
          }
        }
      }
    } catch (e) {
      debugPrint('Yinelenen dosya arama hatası: $e');
    }
    return duplicates;
  }

  // Sistem dosyalarını kontrol eden metod
  bool isSystemFile(FileSystemEntity file) {
    final systemPaths = [
      r'C:\Windows',
      r'C:\Program Files',
      r'C:\Program Files (x86)',
      r'C:\ProgramData',
      '/System',
      '/Library',
      '/usr',
      '/bin',
    ];

    return systemPaths.any((path) => file.path.startsWith(path));
  }

  // Dosya türünü belirleyen metod
  String getFileType(String filePath) {
    final extension = path.extension(filePath).toLowerCase();
    switch (extension) {
      case '.exe':
      case '.msi':
        return 'Uygulama';
      case '.jpg':
      case '.jpeg':
      case '.png':
      case '.gif':
        return 'Resim';
      case '.mp4':
      case '.avi':
      case '.mkv':
        return 'Video';
      case '.mp3':
      case '.wav':
        return 'Ses';
      case '.doc':
      case '.docx':
      case '.pdf':
        return 'Belge';
      case '.zip':
      case '.rar':
        return 'Arşiv';
      default:
        return 'Diğer';
    }
  }

  // Optimize edilmiş dosya istatistikleri
  Future<Map<String, FileTypeStats>> getStorageStats() async {
    Map<String, FileTypeStats> stats = {
      'Resim': FileTypeStats(),
      'Video': FileTypeStats(),
      'Ses': FileTypeStats(),
      'Belge': FileTypeStats(),
      'Arşiv': FileTypeStats(),
      'Uygulama': FileTypeStats(),
      'Diğer': FileTypeStats(),
    };

    try {
      final dir = Directory(_currentScanPath);
      if (await dir.exists()) {
        await for (final entity in dir.list(recursive: true)) {
          if (entity is File) {
            final type = getFileType(entity.path);
            final size = await entity.length();
            stats[type]!.totalSize += size;
            stats[type]!.files.add(entity);
          }
        }
      }
    } catch (e) {
      debugPrint('İstatistik hesaplama hatası: $e');
    }

    // Boş kategorileri kaldır
    stats.removeWhere((key, value) => value.totalSize == 0);
    return stats;
  }

  // Kritik sistem klasörleri
  final List<String> _criticalPaths = [
    r'C:\Windows',
    r'C:\Program Files',
    r'C:\Program Files (x86)',
    r'C:\ProgramData',
    r'C:\System32',
    r'C:\Users\Default',
    r'C:\Boot',
    '/System',
    '/Library',
    '/usr',
    '/bin',
    '/etc',
    '/var',
  ];

  // Dosyanın kritik olup olmadığını kontrol et
  bool isCriticalPath(FileSystemEntity file) {
    return _criticalPaths.any((path) => 
      file.path.toLowerCase().startsWith(path.toLowerCase()));
  }

  // Silme işlemi için güvenlik kontrolü
  String? getDeleteWarning(FileSystemEntity file) {
    if (isCriticalPath(file)) {
      return 'Bu öğe sistem için kritik öneme sahip olabilir. Silmek veri kaybına veya sistem sorunlarına yol açabilir.';
    }
    
    if (file is Directory && file.path.contains('Program')) {
      return 'Bu bir program klasörü olabilir. Silmek yüklü uygulamaları bozabilir.';
    }

    return null; // Normal dosya/klasör
  }

  // Tarama durumu için yeni alanlar
  DateTime? _scanStartTime;
  int _processedItems = 0;
  int _totalItems = 0;
  String _currentStatus = '';
  
  String get currentStatus => _currentStatus;
  String get estimatedTimeRemaining => _calculateEstimatedTime();
  int get processedItems => _processedItems;
  int get totalItems => _totalItems;

  String _calculateEstimatedTime() {
    if (_scanStartTime == null || _processedItems == 0) return 'Hesaplanıyor...';
    
    final elapsed = DateTime.now().difference(_scanStartTime!);
    final itemsPerSecond = _processedItems / elapsed.inSeconds;
    if (itemsPerSecond == 0) return 'Hesaplanıyor...';
    
    final remainingItems = _totalItems - _processedItems;
    final remainingSeconds = (remainingItems / itemsPerSecond).round();
    
    if (remainingSeconds < 60) {
      return '$remainingSeconds saniye';
    } else if (remainingSeconds < 3600) {
      return '${(remainingSeconds / 60).round()} dakika';
    } else {
      return '${(remainingSeconds / 3600).round()} saat';
    }
  }

  bool _isCancelled = false;
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  // Taramayı durdur
  void cancelScan() {
    _isCancelled = true;
    _isScanning = false;
    _currentStatus = 'Tarama kullanıcı tarafından durduruldu';
    notifyListeners();
  }

  // Tema değiştirme
  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.light 
        ? ThemeMode.dark 
        : ThemeMode.light;
    notifyListeners();
  }

  // Derin tarama metodunu güncelle
  Future<void> startDeepScan() async {
    if (_isScanning) return;

    try {
      _isScanning = true;
      _isCancelled = false;
      _scanProgress = 0.0;
      _scanResults.clear();
      _scanStartTime = DateTime.now();
      _processedItems = 0;
      _currentStatus = 'Sürücüler hazırlanıyor...';
      notifyListeners();

      List<Directory> roots = await _getWindowsDrives();
      if (_isCancelled) return;

      _currentStatus = 'Klasörler sayılıyor...';
      notifyListeners();

      _totalItems = await _countTotalItems(roots);
      if (_isCancelled) return;

      for (final root in roots) {
        if (_isCancelled) return;
        
        if (_isAccessibleDirectory(root.path)) {
          _currentStatus = 'Taranan sürücü: ${root.path}';
          notifyListeners();
          
          await _scanDirectory(root);
        }
      }
    } catch (e) {
      debugPrint('Tarama hatası: $e');
      _currentStatus = 'Tarama hatası: $e';
    } finally {
      _isScanning = false;
      _scanProgress = 1.0;
      if (!_isCancelled) {
        final totalSize = await _getTotalScannedSize();
        _currentStatus = 'Tarama tamamlandı - ${_formatSize(totalSize)} incelendi';
      }
      notifyListeners();
    }
  }

  // Paralel tarama için
  Future<void> _scanDirectory(Directory dir) async {
    if (_isCancelled || !_isAccessibleDirectory(dir.path)) return;

    try {
      final entities = await dir.list().toList();
      final futures = <Future>[];
      
      for (final entity in entities) {
        if (_isCancelled) return;
        
        if (entity is Directory) {
          _processedItems++;
          _scanProgress = _processedItems / _totalItems;
          
          futures.add(_processDirectory(entity));
        }
      }
      
      await Future.wait(futures);
    } catch (e) {
      debugPrint('Dizin tarama hatası: ${dir.path} - $e');
    }
  }

  Future<void> _processDirectory(Directory dir) async {
    try {
      final size = await calculateDirectorySize(dir);
      if (size > 500 * 1024 * 1024) {
        _scanResults.add(dir);
        debugPrint('Büyük klasör: ${dir.path} (${_formatSize(size)})');
      }

      _currentStatus = 'İncelenen: ${dir.path}';
      notifyListeners();

      await _scanDirectory(dir);
    } catch (e) {
      debugPrint('Klasör işleme hatası: ${dir.path} - $e');
    }
  }

  // Toplam taranan boyutu hesapla
  Future<int> _getTotalScannedSize() async {
    int total = 0;
    for (var entity in _scanResults) {
      if (entity is Directory) {
        total += await calculateDirectorySize(entity);
      }
    }
    return total;
  }

  // Windows sürücülerini getirme metodunu güncelle
  Future<List<Directory>> _getWindowsDrives() async {
    List<Directory> drives = [];
    try {
      final process = await Process.run('cmd', ['/c', 'wmic logicaldisk get name']);
      final output = process.stdout.toString();
      
      for (var line in output.split('\n')) {
        line = line.trim();
        if (line.length == 2 && line.endsWith(':')) {
          final drive = Directory('$line\\');
          if (await drive.exists()) {
            drives.add(drive);
          }
        }
      }
    } catch (e) {
      debugPrint('Sürücü listesi alınamadı: $e');
    }

    // Hiç sürücü bulunamazsa varsayılan olarak C: ekle
    if (drives.isEmpty) {
      drives.add(Directory('C:\\'));
    }
    return drives;
  }

  // Toplam öğe sayısını hesaplama metodunu güncelle
  Future<int> _countTotalItems(List<Directory> roots) async {
    int count = 0;
    for (final root in roots) {
      try {
        if (!_isAccessibleDirectory(root.path)) continue;

        await for (final entity in root.list(recursive: true)) {
          if (entity is Directory && _isAccessibleDirectory(entity.path)) {
            count++;
          }
        }
      } catch (e) {
        // Hata durumunda devam et
      }
    }
    return count > 0 ? count : 1;
  }

  // Klasör boyutu hesaplama metodunu güncelle
  Future<int> calculateDirectorySize(Directory dir) async {
    if (_directorySizeCache.containsKey(dir.path)) {
      return _directorySizeCache[dir.path]!;
    }

    int size = await _calculateDirectorySize(dir);
    _directorySizeCache[dir.path] = size;
    return size;
  }

  // Boyut formatlamak için yardımcı metod
  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  // Önbellek klasörleri
  final List<String> _cachePaths = [
    '${Platform.environment['LOCALAPPDATA']}\\Temp',
    '${Platform.environment['USERPROFILE']}\\AppData\\Local\\Temp',
    '${Platform.environment['SYSTEMROOT']}\\Temp',
  ];

  // Önbellek dosyalarını temizle
  Future<void> cleanupCache() async {
    try {
      int totalCleaned = 0;
      List<String> skippedFiles = [];
      
      for (final cachePath in _cachePaths) {
        final cacheDir = Directory(cachePath);
        if (await cacheDir.exists()) {
          await for (final entity in cacheDir.list()) {
            try {
              if (!_isCriticalPath(entity.path) && !_isInUseDirectory(entity.path)) {
                if (entity is File) {
                  try {
                    final size = await entity.length();
                    await entity.delete();
                    totalCleaned += size;
                  } catch (e) {
                    skippedFiles.add(path.basename(entity.path));
                  }
                } else if (entity is Directory) {
                  try {
                    final size = await _calculateDirectorySize(entity);
                    await entity.delete(recursive: true);
                    totalCleaned += size;
                  } catch (e) {
                    skippedFiles.add(path.basename(entity.path));
                  }
                }
              }
            } catch (e) {
              debugPrint('Dosya atlama: ${entity.path} - $e');
            }
          }
        }
      }
      
      if (skippedFiles.isNotEmpty) {
        debugPrint('Atlanılan dosyalar: ${skippedFiles.join(", ")}');
      }
      
      debugPrint('Temizlenen önbellek: ${_formatSize(totalCleaned)}');
    } catch (e) {
      debugPrint('Önbellek temizleme hatası: $e');
    }
    notifyListeners();
  }

  // Kullanımda olan klasörleri kontrol et
  bool _isInUseDirectory(String path) {
    final inUsePaths = [
      'Wondershare',
      'Microsoft',
      'Google',
      'Adobe',
      'Teams',
      'Discord',
      'Spotify',
      'Chrome',
      'Firefox',
      'Edge',
    ];
    
    return inUsePaths.any((name) => 
      path.toLowerCase().contains(name.toLowerCase()));
  }

  // Klasör boyutunu hesapla
  Future<int> _calculateDirectorySize(Directory dir) async {
    int size = 0;
    try {
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          try {
            size += await entity.length();
          } catch (e) {
            // Dosya boyutu alınamazsa atla
          }
        }
      }
    } catch (e) {
      // Erişilemeyen klasörleri atla
    }
    return size;
  }

  // Eski indirilen dosyaları temizle (30 günden eski)
  Future<void> cleanupDownloads() async {
    try {
      final downloadsPath = '${Platform.environment['USERPROFILE']}\\Downloads';
      final downloadsDir = Directory(downloadsPath);
      int totalCleaned = 0;
      
      if (await downloadsDir.exists()) {
        final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
        
        await for (final entity in downloadsDir.list()) {
          try {
            final stat = await entity.stat();
            if (stat.modified.isBefore(thirtyDaysAgo)) {
              if (entity is File) {
                totalCleaned += await entity.length();
              }
              await entity.delete(recursive: true);
            }
          } catch (e) {
            debugPrint('İndirilenler temizleme hatası: $e');
          }
        }
      }
      
      debugPrint('Temizlenen indirilenler: ${_formatSize(totalCleaned)}');
    } catch (e) {
      debugPrint('İndirilenler temizleme hatası: $e');
    }
    notifyListeners();
  }

  // Kritik sistem dosyası kontrolü
  bool _isCriticalPath(String path) {
    return _criticalPaths.any((criticalPath) => 
      path.toLowerCase().contains(criticalPath.toLowerCase()));
  }

  // Önbellek boyutunu hesapla
  Future<int> getCacheSize() async {
    int totalSize = 0;
    for (final cachePath in _cachePaths) {
      final cacheDir = Directory(cachePath);
      if (await cacheDir.exists()) {
        await for (final entity in cacheDir.list(recursive: true)) {
          if (entity is File) {
            try {
              totalSize += await entity.length();
            } catch (e) {
              // Dosya boyutu alınamazsa atla
            }
          }
        }
      }
    }
    return totalSize;
  }

  // Eski indirilen dosyaların boyutunu hesapla
  Future<int> getOldDownloadsSize() async {
    int totalSize = 0;
    final downloadsPath = '${Platform.environment['USERPROFILE']}\\Downloads';
    final downloadsDir = Directory(downloadsPath);
    
    if (await downloadsDir.exists()) {
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      
      await for (final entity in downloadsDir.list(recursive: true)) {
        if (entity is File) {
          try {
            final stat = await entity.stat();
            if (stat.modified.isBefore(thirtyDaysAgo)) {
              totalSize += await entity.length();
            }
          } catch (e) {
            // Dosya boyutu alınamazsa atla
          }
        }
      }
    }
    return totalSize;
  }

  // Depolama istatistiklerini yenile
  Future<void> refreshStorageStats() async {
    notifyListeners();
  }

  // Önbellek boyutunu yenile
  Future<void> refreshCacheSize() async {
    notifyListeners();
  }

  // İndirilenler boyutunu yenile
  Future<void> refreshDownloadsSize() async {
    notifyListeners();
  }

  List<FileOperation> _operationHistory = [];
  List<FileOperation> get operationHistory => _operationHistory;
  bool _autoCleanEnabled = false;
  bool get autoCleanEnabled => _autoCleanEnabled;
  Set<String> _selectedTypes = {};
  Set<String> get selectedTypes => _selectedTypes;

  // Sistem bilgileri
  Future<Map<String, String>> getSystemInfo() async {
    try {
      final totalSpace = await _getTotalSpace();
      final freeSpace = await _getFreeSpace();
      final largestFolder = await _findLargestFolder();
      final memoryUsage = await _getMemoryUsage();
      final cpuUsage = await _getCpuUsage();

      return {
        'totalSpace': _formatSize(totalSpace),
        'freeSpace': _formatSize(freeSpace),
        'largestFolder': largestFolder,
        'memoryUsage': memoryUsage,
        'cpuUsage': cpuUsage,
        'os': Platform.operatingSystemVersion,
      };
    } catch (e) {
      debugPrint('Sistem bilgileri alınamadı: $e');
      return {};
    }
  }

  // İşlem geçmişine ekle
  void addOperation(String type, String path, bool success) {
    _operationHistory.insert(0, FileOperation(
      type: type,
      path: path,
      time: DateTime.now(),
      success: success,
    ));
    if (_operationHistory.length > 100) {
      _operationHistory.removeLast();
    }
    notifyListeners();
  }

  // Otomatik temizlik ayarı
  void toggleAutoClean(bool enabled) {
    _autoCleanEnabled = enabled;
    if (enabled) {
      _scheduleAutoClean();
    }
    notifyListeners();
  }

  // Otomatik temizlik zamanla
  void _scheduleAutoClean() {
    // Her hafta çalışacak temizlik işlemi
    Future.delayed(const Duration(days: 7), () async {
      if (_autoCleanEnabled) {
        await cleanupCache();
        _scheduleAutoClean();
      }
    });
  }

  // Dosya türü filtreleme
  void toggleFileType(String type) {
    if (_selectedTypes.contains(type)) {
      _selectedTypes.remove(type);
    } else {
      _selectedTypes.add(type);
    }
    // Filtreleme değiştiğinde listeyi güncelle
    listDirectory(_currentPath);
    notifyListeners();
  }

  // Sistem bilgileri yardımcı metodları
  Future<int> _getTotalSpace() async {
    try {
      final process = await Process.run('wmic', ['logicaldisk', 'get', 'size']);
      final output = process.stdout.toString();
      int totalSize = 0;
      
      final lines = output.split('\n')
          .where((line) => line.trim().isNotEmpty)
          .skip(1); // Başlığı atla
          
      for (final line in lines) {
        final size = int.tryParse(line.trim()) ?? 0;
        totalSize += size;
      }
      
      return totalSize;
    } catch (e) {
      debugPrint('Disk alanı hesaplama hatası: $e');
      return 0;
    }
  }

  Future<int> _getFreeSpace() async {
    try {
      final process = await Process.run('wmic', ['logicaldisk', 'get', 'freespace']);
      final output = process.stdout.toString();
      int totalFreeSpace = 0;
      
      final lines = output.split('\n')
          .where((line) => line.trim().isNotEmpty)
          .skip(1); // Başlığı atla
          
      for (final line in lines) {
        final space = int.tryParse(line.trim()) ?? 0;
        totalFreeSpace += space;
      }
      
      return totalFreeSpace;
    } catch (e) {
      debugPrint('Boş alan hesaplama hatası: $e');
      return 0;
    }
  }

  Future<String> _findLargestFolder() async {
    try {
      String largest = '';
      int maxSize = 0;
      
      for (final defaultPath in defaultScanPaths) {
        final dir = Directory(defaultPath);
        if (await dir.exists()) {
          final size = await calculateDirectorySize(dir);
          if (size > maxSize) {
            maxSize = size;
            largest = path.basename(defaultPath);
          }
        }
      }
      
      return largest.isEmpty ? 'Bulunamadı' : '$largest (${_formatSize(maxSize)})';
    } catch (e) {
      debugPrint('En büyük klasör bulma hatası: $e');
      return 'Hesaplanamadı';
    }
  }

  Future<String> _getMemoryUsage() async {
    try {
      final process = await Process.run('wmic', ['OS', 'get', 'FreePhysicalMemory,TotalVisibleMemorySize']);
      final output = process.stdout.toString();
      final lines = output.split('\n').where((line) => line.trim().isNotEmpty).toList();
      if (lines.length > 1) {
        final values = lines[1].trim().split(RegExp(r'\s+'));
        if (values.length >= 2) {
          final free = int.tryParse(values[0]) ?? 0;
          final total = int.tryParse(values[1]) ?? 1;
          final used = total - free;
          final percentage = (used / total * 100).round();
          return '$percentage%';
        }
      }
      return 'Hesaplanamadı';
    } catch (e) {
      debugPrint('Bellek kullanımı hesaplama hatası: $e');
      return 'Hesaplanamadı';
    }
  }

  Future<String> _getCpuUsage() async {
    try {
      final process = await Process.run('wmic', ['cpu', 'get', 'loadpercentage']);
      final output = process.stdout.toString();
      final usage = output.split('\n')
          .where((line) => line.trim().isNotEmpty)
          .skip(1)
          .map((line) => int.tryParse(line.trim()) ?? 0)
          .firstOrNull ?? 0;
      return '$usage%';
    } catch (e) {
      debugPrint('CPU kullanımı hesaplama hatası: $e');
      return 'Hesaplanamadı';
    }
  }

  // Filtrelenmiş dosyaları getir
  List<FileSystemEntity> getFilteredItems() {
    if (_selectedTypes.isEmpty) return _items;
    
    return _items.where((item) {
      if (item is File) {
        final type = getFileType(item.path);
        return _selectedTypes.contains(type.toLowerCase());
      }
      return true; // Klasörleri her zaman göster
    }).toList();
  }

  // Önbellekleme için map
  final Map<String, int> _directorySizeCache = {};
  final Map<String, FileSystemEntity> _fileDetailsCache = {};

  // Önbellekten dosya detaylarını getir
  Future<Map<String, dynamic>> _getDetailsFromCache(FileSystemEntity item) async {
    final stat = await item.stat();
    return {
      'isDirectory': item is Directory,
      'size': item is File ? await (item as File).length() : null,
      'modified': stat.modified,
      'accessed': stat.accessed,
      'created': stat.changed,
      'path': item.path,
    };
  }

  // Dosya detaylarını getir
  Future<Map<String, dynamic>> _getFileDetails(FileSystemEntity item) async {
    final stat = await item.stat();
    final details = {
      'isDirectory': item is Directory,
      'size': item is File ? await (item as File).length() : null,
      'modified': stat.modified,
      'accessed': stat.accessed,
      'created': stat.changed,
      'path': item.path,
      'type': item is File ? getFileType(item.path) : 'Klasör',
      'isSystemFile': isSystemFile(item),
    };

    if (item is File) {
      try {
        details['extension'] = path.extension(item.path);
      } catch (e) {
        details['extension'] = '';
      }
    }

    return details;
  }

  // Dosya taşıma
  Future<void> moveItem(FileSystemEntity source, String destinationPath) async {
    try {
      final newPath = path.join(destinationPath, path.basename(source.path));
      await source.rename(newPath);
      addOperation('move', source.path, true);
      listDirectory(_currentPath);
    } catch (e) {
      debugPrint('Taşıma hatası: $e');
      addOperation('move', source.path, false);
    }
  }

  // Dosya istatistikleri
  Future<Map<String, int>> getFileStatistics() async {
    int totalFiles = 0;
    int totalFolders = 0;
    int totalSize = 0;

    for (var item in _items) {
      if (item is File) {
        totalFiles++;
        totalSize += await item.length();
      } else if (item is Directory) {
        totalFolders++;
        totalSize += await calculateDirectorySize(item);
      }
    }

    return {
      'totalFiles': totalFiles,
      'totalFolders': totalFolders,
      'totalSize': totalSize,
    };
  }
}

// Dosya türü istatistikleri için yeni sınıf
class FileTypeStats {
  int totalSize = 0;
  List<FileSystemEntity> files = [];
} 