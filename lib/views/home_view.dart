import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_tidy/viewmodels/file_manager_viewmodel.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:intl/intl.dart';
import 'package:file_tidy/widgets/app_logo.dart';
import 'package:file_tidy/widgets/storage_chart.dart';
import 'package:file_tidy/widgets/cleanup_suggestion.dart';
import 'package:file_tidy/widgets/file_preview.dart';
import 'package:file_tidy/widgets/quick_access_bar.dart';

// Klavye kısayolları için Intent sınıfları
class SearchIntent extends Intent {
  const SearchIntent();
}

class DeleteIntent extends Intent {
  const DeleteIntent();
}

class CopyIntent extends Intent {
  const CopyIntent();
}

class PasteIntent extends Intent {
  const PasteIntent();
}

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  List<FileSystemEntity> _selectedItems = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyF):
            const SearchIntent(),
        LogicalKeySet(LogicalKeyboardKey.delete): const DeleteIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyC):
            const CopyIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyV):
            const PasteIntent(),
      },
      child: Actions(
        actions: {
          SearchIntent: CallbackAction<SearchIntent>(
            onInvoke: (intent) => _showSearchBar(),
          ),
          DeleteIntent: CallbackAction<DeleteIntent>(
            onInvoke: (intent) => _deleteSelectedItems(),
          ),
          CopyIntent: CallbackAction<CopyIntent>(
            onInvoke: (intent) => _copySelectedItems(),
          ),
          PasteIntent: CallbackAction<PasteIntent>(
            onInvoke: (intent) => _pasteItems(),
          ),
        },
        child: Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                Hero(
                  tag: 'logo',
                  child: AppLogo(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                const Text('File Tidy'),
              ],
            ),
            actions: [
              IconButton(
                icon: Icon(
                  context.watch<FileManagerViewModel>().themeMode ==
                          ThemeMode.light
                      ? Icons.dark_mode
                      : Icons.light_mode,
                ),
                onPressed: () =>
                    context.read<FileManagerViewModel>().toggleTheme(),
              ),
            ],
            elevation: 0,
            bottom: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Genel Bakış'),
                Tab(text: 'Büyük Dosyalar'),
                Tab(text: 'Eski Dosyalar'),
                Tab(text: 'Yinelenen Dosyalar'),
                Tab(text: 'Derin Tarama'),
              ],
            ),
          ),
          body: SafeArea(
            child: Column(
              children: [
                _buildSearchBar(),
                QuickAccessBar(
                  onPathSelected: (path) {
                    context.read<FileManagerViewModel>().listDirectory(path);
                  },
                ),
                Expanded(
                  child: _buildDragTarget(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Dosya veya klasör ara...',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          suffixIcon: IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              _searchController.clear();
              context.read<FileManagerViewModel>().clearSearch();
            },
          ),
        ),
        onChanged: _handleSearch,
      ),
    );
  }

  Widget _buildDragTarget() {
    return DragTarget<FileSystemEntity>(
      onWillAccept: (data) => true,
      onAccept: (data) {
        final viewModel = context.read<FileManagerViewModel>();
        viewModel.moveItem(data, viewModel.currentPath);
      },
      builder: (context, candidateData, rejectedData) {
        return Container(
          decoration: BoxDecoration(
            border: Border.all(
              color:
                  candidateData.isNotEmpty ? Colors.blue : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(),
                    _buildLargeFilesTab(),
                    _buildOldFilesTab(),
                    _buildDuplicateFilesTab(),
                    _buildDeepScanTab(),
                  ],
                ),
              ),
              if (MediaQuery.of(context).size.width > 1200)
                const VerticalDivider(width: 1),
              if (MediaQuery.of(context).size.width > 1200)
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.25,
                  child: _buildSidePanel(),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showContextMenu(
      BuildContext context, FileSystemEntity item, Offset position) {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, 0, 0),
      items: [
        PopupMenuItem(
          child: const ListTile(
            leading: Icon(Icons.open_in_new),
            title: Text('Aç'),
          ),
          onTap: () => _openFile(item),
        ),
        PopupMenuItem(
          child: const ListTile(
            leading: Icon(Icons.preview),
            title: Text('Önizle'),
          ),
          onTap: () => _showFilePreview(item),
        ),
        PopupMenuItem(
          child: const ListTile(
            leading: Icon(Icons.delete),
            title: Text('Sil'),
          ),
          onTap: () => _showDeleteConfirmation(context, item),
        ),
        PopupMenuItem(
          child: const ListTile(
            leading: Icon(Icons.edit),
            title: Text('Yeniden Adlandır'),
          ),
          onTap: () => _showRenameDialog(context, item),
        ),
        PopupMenuItem(
          child: const ListTile(
            leading: Icon(Icons.copy),
            title: Text('Kopyala'),
          ),
          onTap: () => _showCopyDialog(context, item),
        ),
      ],
    );
  }

  void _showFilePreview(FileSystemEntity item) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: 600,
          height: 400,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(path.basename(item.path)),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: FilePreview(file: item),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidePanel() {
    final viewModel = context.watch<FileManagerViewModel>();

    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        _buildSystemInfo(),
        const SizedBox(height: 8),
        _buildAutoCleanScheduler(),
        const SizedBox(height: 8),
        _buildFileTypeFilter(),
        const SizedBox(height: 8),
        _buildOperationHistory(),
      ],
    );
  }

  Widget _buildSystemInfoItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 14),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSystemInfo() {
    return FutureBuilder<Map<String, String>>(
      future: context.read<FileManagerViewModel>().getSystemInfo(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final info = snapshot.data!;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sistem Bilgileri',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    SizedBox(
                      width: 250,
                      child: _buildSystemInfoItem(
                          'İşletim Sistemi', info['os'] ?? ''),
                    ),
                    SizedBox(
                      width: 120,
                      child: _buildSystemInfoItem(
                          'Toplam Alan', info['totalSpace'] ?? ''),
                    ),
                    SizedBox(
                      width: 120,
                      child: _buildSystemInfoItem(
                          'Boş Alan', info['freeSpace'] ?? ''),
                    ),
                    SizedBox(
                      width: 200,
                      child: _buildSystemInfoItem(
                          'En Büyük Klasör', info['largestFolder'] ?? ''),
                    ),
                    SizedBox(
                      width: 120,
                      child: _buildSystemInfoItem(
                          'Bellek Kullanımı', info['memoryUsage'] ?? ''),
                    ),
                    SizedBox(
                      width: 120,
                      child: _buildSystemInfoItem(
                          'CPU Kullanımı', info['cpuUsage'] ?? ''),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAutoCleanScheduler() {
    final viewModel = context.watch<FileManagerViewModel>();

    return Card(
      child: SwitchListTile(
        title: const Text('Otomatik Temizlik'),
        subtitle: const Text('Her hafta önbelleği temizle'),
        value: viewModel.autoCleanEnabled,
        onChanged: viewModel.toggleAutoClean,
      ),
    );
  }

  Widget _buildFileTypeFilter() {
    final viewModel = context.watch<FileManagerViewModel>();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Dosya Türü Filtresi',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildFilterChip('Resim', 'image', viewModel),
                _buildFilterChip('Video', 'video', viewModel),
                _buildFilterChip('Belge', 'document', viewModel),
                _buildFilterChip('Arşiv', 'archive', viewModel),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    String type,
    FileManagerViewModel viewModel,
  ) {
    return FilterChip(
      label: Text(label),
      selected: viewModel.selectedTypes.contains(type),
      onSelected: (selected) => viewModel.toggleFileType(type),
    );
  }

  Widget _buildOperationHistory() {
    final viewModel = context.watch<FileManagerViewModel>();

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'İşlem Geçmişi',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: viewModel.operationHistory.length,
            itemBuilder: (context, index) {
              final operation = viewModel.operationHistory[index];
              return ListTile(
                leading: Icon(
                  operation.icon,
                  color: operation.success ? Colors.green : Colors.red,
                ),
                title: Text(operation.typeText),
                subtitle: Text(
                  '${path.basename(operation.path)}\n'
                  '${DateFormat('dd/MM/yyyy HH:mm').format(operation.time)}',
                ),
                isThreeLine: true,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    final viewModel = context.watch<FileManagerViewModel>();

    return RefreshIndicator(
      onRefresh: () async {
        // Tüm verileri yenile
        await viewModel.refreshStorageStats();
        await viewModel.refreshCacheSize();
        await viewModel.refreshDownloadsSize();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Depolama grafiği - boyutu küçültüldü
          SizedBox(
            height: 200, // Yükseklik azaltıldı
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Depolama Kullanımı',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          onPressed: () => viewModel.refreshStorageStats(),
                        ),
                      ],
                    ),
                    Expanded(
                      child: FutureBuilder<Map<String, FileTypeStats>>(
                        future: viewModel.getStorageStats(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          final stats = snapshot.data!;
                          final total = stats.values.fold<int>(
                              0, (sum, stat) => sum + stat.totalSize);

                          final data = stats.map((key, value) => MapEntry(
                                key,
                                (value.totalSize / total) * 100,
                              ));

                          return StorageChart(data: data);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Temizlik önerileri
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Önerilen Temizlikler',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () async {
                  await viewModel.refreshCacheSize();
                  await viewModel.refreshDownloadsSize();
                },
              ),
            ],
          ),
          FutureBuilder<int>(
            future: viewModel.getCacheSize(),
            builder: (context, snapshot) {
              return CleanupSuggestion(
                title: 'Önbellek Dosyaları',
                description: 'Uygulamaların önbellek dosyalarını temizleyin',
                potentialSaving: snapshot.data ?? 0,
                onClean: () => _showCleanupConfirmation(
                  context,
                  'Önbellek Dosyaları',
                  'Önbellek dosyaları temizlenecek. Bu işlem geri alınamaz.',
                  viewModel.cleanupCache,
                ),
              );
            },
          ),
          FutureBuilder<int>(
            future: viewModel.getOldDownloadsSize(),
            builder: (context, snapshot) {
              return CleanupSuggestion(
                title: 'İndirilenler',
                description: '30 günden eski indirilen dosyalar',
                potentialSaving: snapshot.data ?? 0,
                onClean: () => _showCleanupConfirmation(
                  context,
                  'Eski İndirilenler',
                  '30 günden eski indirilen dosyalar silinecek. Bu işlem geri alınamaz.',
                  viewModel.cleanupDownloads,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // Temizleme onayı dialog'u
  Future<void> _showCleanupConfirmation(
    BuildContext context,
    String title,
    String message,
    Future<void> Function() onConfirm,
  ) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Bazı dosyalar kullanımda olduğu için atlanabilir.',
                      style: TextStyle(color: Colors.orange[700]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await onConfirm();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'Temizlik tamamlandı. Bazı dosyalar atlanmış olabilir.'),
                    duration: Duration(seconds: 3),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Temizle'),
          ),
        ],
      ),
    );
  }

  // Dosya türü detaylarını gösteren dialog
  void _showFileTypeDetails(
      BuildContext context, String type, List<FileSystemEntity> files) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$type Dosyaları'),
        content: SizedBox(
          width: 600,
          height: 400,
          child: ListView.builder(
            itemCount: files.length,
            itemBuilder: (context, index) => _buildFileListTile(files[index]),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  // Dosya listeleme metodlarını güncelleyelim
  Widget _buildFileListTile(FileSystemEntity file, {bool showSize = true}) {
    final viewModel = context.read<FileManagerViewModel>();

    return FutureBuilder<FileStat>(
      future: file.stat(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const ListTile(title: Text('Yükleniyor...'));
        }

        final stat = snapshot.data!;
        final isSystemFile = viewModel.isSystemFile(file);
        final lastAccessed = DateFormat('dd/MM/yyyy').format(stat.accessed);

        return ListTile(
          leading: Icon(
            file is Directory ? Icons.folder : Icons.insert_drive_file,
            color: isSystemFile ? Colors.red : Colors.blue,
          ),
          title: Text(
            path.basename(file.path),
            style: TextStyle(
              color: isSystemFile ? Colors.red : null,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Son Erişim: $lastAccessed'),
              if (showSize && file is File)
                FutureBuilder<int>(
                  future: file.length(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      return Text('Boyut: ${_formatFileSize(snapshot.data)}');
                    }
                    return const Text('Boyut hesaplanıyor...');
                  },
                ),
            ],
          ),
          trailing: isSystemFile
              ? const Tooltip(
                  message: 'Sistem dosyası silinemiyor',
                  child: Icon(Icons.warning, color: Colors.red),
                )
              : IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => _showDeleteConfirmation(context, file),
                ),
        );
      },
    );
  }

  // Silme onayı dialog'unu güncelleyelim
  Future<void> _showDeleteConfirmation(
      BuildContext context, FileSystemEntity file) async {
    final viewModel = context.read<FileManagerViewModel>();
    final warning = viewModel.getDeleteWarning(file);

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Silmeyi Onayla'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${path.basename(file.path)} silinsin mi?'),
            const SizedBox(height: 8),
            if (warning != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        warning,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            const Text(
              'Bu işlem geri alınamaz!',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          if (warning != null)
            TextButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Son Uyarı'),
                    content: const Text(
                        'Bu öğeyi silmek sistem kararlılığını etkileyebilir. '
                        'Gerçekten devam etmek istiyor musunuz?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Vazgeç'),
                      ),
                      TextButton(
                        onPressed: () {
                          viewModel.deleteItem(file);
                          Navigator.pop(context);
                          Navigator.pop(context);
                        },
                        style:
                            TextButton.styleFrom(foregroundColor: Colors.red),
                        child: const Text('Yine de Sil'),
                      ),
                    ],
                  ),
                );
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Riski Anlıyorum, Devam Et'),
            )
          else
            TextButton(
              onPressed: () {
                viewModel.deleteItem(file);
                Navigator.pop(context);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Sil'),
            ),
        ],
      ),
    );
  }

  // Eski dosyaları gösteren dialog
  Future<void> _showOldFiles(BuildContext context) async {
    final viewModel = context.read<FileManagerViewModel>();
    final oldFiles = await viewModel.findOldFiles();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eski Dosyalar'),
        content: SizedBox(
          width: 600,
          height: 400,
          child: ListView.builder(
            itemCount: oldFiles.length,
            itemBuilder: (context, index) {
              final file = oldFiles[index];
              return FutureBuilder<FileStat>(
                future: file.stat(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const ListTile(
                      title: Text('Yükleniyor...'),
                    );
                  }

                  return ListTile(
                    leading: Icon(
                      file is Directory
                          ? Icons.folder
                          : Icons.insert_drive_file,
                      color: file is Directory ? Colors.yellow : Colors.blue,
                    ),
                    title: Text(path.basename(file.path)),
                    subtitle: Text(
                        'Son erişim: ${snapshot.data!.accessed.toString().split('.')[0]}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => _showDeleteConfirmation(context, file),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  // Yinelenen dosyaları gösteren dialog
  Future<void> _showDuplicateFiles(BuildContext context) async {
    final viewModel = context.read<FileManagerViewModel>();
    final duplicates = await viewModel.findDuplicateFiles();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yinelenen Dosyalar'),
        content: SizedBox(
          width: 600,
          height: 400,
          child: ListView.builder(
            itemCount: duplicates.length,
            itemBuilder: (context, index) {
              final files = duplicates.values.elementAt(index);
              return ExpansionTile(
                title: Text(
                    '${path.basename(files.first.path)} (${files.length} kopya)'),
                children: files
                    .map((file) => ListTile(
                          leading: const Icon(Icons.insert_drive_file),
                          title: Text(file.path),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () =>
                                _showDeleteConfirmation(context, file),
                          ),
                        ))
                    .toList(),
              );
            },
          ),
        ),
      ),
    );
  }

  // Dosya gezgini dialog'u
  Future<void> _showFileExplorer(BuildContext context) async {
    final viewModel = context.read<FileManagerViewModel>();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Konum: ${viewModel.currentPath}'),
        content: SizedBox(
          width: 600,
          height: 400,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.arrow_upward),
                title: const Text('Üst Klasör'),
                onTap: () => viewModel.navigateUp(),
              ),
              const Divider(),
              Expanded(
                child: Consumer<FileManagerViewModel>(
                  builder: (context, vm, child) {
                    return ListView.builder(
                      itemCount: vm.items.length,
                      itemBuilder: (context, index) {
                        final item = vm.items[index];
                        final isDirectory = item is Directory;

                        return ListTile(
                          leading: Icon(
                            isDirectory
                                ? Icons.folder
                                : Icons.insert_drive_file,
                            color: isDirectory ? Colors.yellow : Colors.blue,
                          ),
                          title: Text(path.basename(item.path)),
                          onTap: () {
                            if (isDirectory) {
                              vm.listDirectory(item.path);
                            }
                          },
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () =>
                                    _showDeleteConfirmation(context, item),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Büyük dosyaları gösteren dialog
  Future<void> _showLargeFiles(BuildContext context) async {
    final viewModel = context.read<FileManagerViewModel>();
    final largeFiles = await viewModel.findLargeFiles();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Büyük Dosyalar'),
        content: SizedBox(
          width: 600,
          height: 400,
          child: ListView.builder(
            itemCount: largeFiles.length,
            itemBuilder: (context, index) {
              final file = largeFiles[index] as File;
              return ListTile(
                leading: const Icon(Icons.insert_drive_file),
                title: Text(path.basename(file.path)),
                subtitle: FutureBuilder<int>(
                  future: file.length(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      return Text('Boyut: ${_formatFileSize(snapshot.data)}');
                    }
                    return const Text('Boyut hesaplanıyor...');
                  },
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => _showDeleteConfirmation(context, file),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // Büyük dosyalar tab'ı
  Widget _buildLargeFilesTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Büyük Dosyalar',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '100MB üzerindeki dosyalar listeleniyor...',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<List<FileSystemEntity>>(
              future: context.read<FileManagerViewModel>().findLargeFiles(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Text('Büyük dosya bulunamadı'),
                  );
                }

                return ListView.builder(
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    final file = snapshot.data![index];
                    if (file is File) {
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.insert_drive_file),
                          title: Text(path.basename(file.path)),
                          subtitle: FutureBuilder<int>(
                            future: file.length(),
                            builder: (context, sizeSnapshot) {
                              if (!sizeSnapshot.hasData) {
                                return const Text('Boyut hesaplanıyor...');
                              }
                              return Text(
                                'Boyut: ${_formatFileSize(sizeSnapshot.data!)}',
                              );
                            },
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () =>
                                _showDeleteConfirmation(context, file),
                          ),
                        ),
                      );
                    }
                    return const SizedBox();
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Eski dosyalar tab'ı
  Widget _buildOldFilesTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Eski Dosyalar',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '180 günden eski dosyalar listeleniyor...',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<List<FileSystemEntity>>(
              future: context.read<FileManagerViewModel>().findOldFiles(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Text('Eski dosya bulunamadı'),
                  );
                }

                return ListView.builder(
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    final file = snapshot.data![index];
                    return FutureBuilder<FileStat>(
                      future: file.stat(),
                      builder: (context, statSnapshot) {
                        if (!statSnapshot.hasData) {
                          return const SizedBox();
                        }

                        return Card(
                          child: ListTile(
                            leading: Icon(
                              file is Directory
                                  ? Icons.folder
                                  : Icons.insert_drive_file,
                            ),
                            title: Text(path.basename(file.path)),
                            subtitle: Text(
                              'Son erişim: ${DateFormat('dd/MM/yyyy').format(statSnapshot.data!.accessed)}',
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () =>
                                  _showDeleteConfirmation(context, file),
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Yinelenen dosyalar tab'ı
  Widget _buildDuplicateFilesTab() {
    final viewModel = context.watch<FileManagerViewModel>();

    return FutureBuilder<Map<String, List<File>>>(
      future: viewModel.findDuplicateFiles(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final duplicates = snapshot.data!;
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: duplicates.length,
          itemBuilder: (context, index) {
            final files = duplicates.values.elementAt(index);
            return Card(
              child: ExpansionTile(
                title: Text(
                    '${path.basename(files.first.path)} (${files.length} kopya)'),
                subtitle: FutureBuilder<int>(
                  future: files.first.length(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      return Text('Boyut: ${_formatFileSize(snapshot.data)}');
                    }
                    return const Text('Boyut hesaplanıyor...');
                  },
                ),
                children:
                    files.map((file) => _buildFileListTile(file)).toList(),
              ),
            );
          },
        );
      },
    );
  }

  // Derin tarama tab'ı
  Widget _buildDeepScanTab() {
    final viewModel = context.watch<FileManagerViewModel>();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Derin Sistem Taraması',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  if (viewModel.isScanning) ...[
                    LinearProgressIndicator(
                      value: viewModel.scanProgress,
                      backgroundColor: Colors.grey[200],
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(Colors.blue),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      viewModel.currentStatus,
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      'İşlenen: ${viewModel.processedItems}/${viewModel.totalItems}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      'Tahmini kalan süre: ${viewModel.estimatedTimeRemaining}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () => viewModel.cancelScan(),
                      icon: const Icon(Icons.stop),
                      label: const Text('Taramayı Durdur'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ] else
                    AnimatedScale(
                      scale: 1.0,
                      duration: const Duration(milliseconds: 200),
                      child: ElevatedButton.icon(
                        onPressed: () => viewModel.startDeepScan(),
                        icon: const Icon(Icons.search),
                        label: const Text('Taramayı Başlat'),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (viewModel.scanResults.isNotEmpty) ...[
            const Text(
              'Bulunan Büyük Klasörler',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: viewModel.scanResults.length,
                itemBuilder: (context, index) {
                  final item = viewModel.scanResults[index];
                  return Card(
                    child: FutureBuilder<int>(
                      future:
                          viewModel.calculateDirectorySize(item as Directory),
                      builder: (context, snapshot) {
                        return ListTile(
                          leading:
                              const Icon(Icons.folder, color: Colors.orange),
                          title: Text(path.basename(item.path)),
                          subtitle: Text(item.path),
                          trailing: snapshot.hasData
                              ? Text(_formatFileSize(snapshot.data))
                              : const CircularProgressIndicator(),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(message),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hata'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  Widget _buildFileStats() {
    return FutureBuilder<Map<String, int>>(
        future: context.read<FileManagerViewModel>().getFileStatistics(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SizedBox();

          final stats = snapshot.data!;
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Dosya İstatistikleri',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  _buildStatItem('Toplam Dosya', '${stats['totalFiles']}'),
                  _buildStatItem('Toplam Klasör', '${stats['totalFolders']}'),
                  _buildStatItem(
                      'Toplam Boyut', _formatFileSize(stats['totalSize'] ?? 0)),
                ],
              ),
            ),
          );
        });
  }

  Widget _buildStatItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value),
        ],
      ),
    );
  }

  void _showSearchBar() {
    setState(() {
      // Arama çubuğunu göster/gizle
    });
  }

  void _deleteSelectedItems() {
    if (_selectedItems.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Seçili Öğeleri Sil'),
        content: Text(
            '${_selectedItems.length} öğeyi silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              for (var item in _selectedItems) {
                _deleteItem(item);
              }
              _selectedItems.clear();
              setState(() {});
            },
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  void _copySelectedItems() {
    // Kopyalama işlemi
  }

  void _pasteItems() {
    // Yapıştırma işlemi
  }

  void _deleteItem(FileSystemEntity item) {
    try {
      item.deleteSync(recursive: true);
      context
          .read<FileManagerViewModel>()
          .addOperation('delete', item.path, true);
    } catch (e) {
      context
          .read<FileManagerViewModel>()
          .addOperation('delete', item.path, false);
      _showErrorDialog('Dosya silinirken hata oluştu: $e');
    }
  }

  // Dosya açma metodu
  void _openFile(FileSystemEntity item) async {
    try {
      if (item is File) {
        final process = await Process.start('explorer', [item.path]);
        await process.exitCode;
      } else if (item is Directory) {
        final process = await Process.start('explorer', [item.path]);
        await process.exitCode;
      }
    } catch (e) {
      _showErrorDialog('Dosya açılırken hata oluştu: $e');
    }
  }

  // Yeniden adlandırma dialog'u
  void _showRenameDialog(BuildContext context, FileSystemEntity item) {
    final controller = TextEditingController(text: path.basename(item.path));
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yeniden Adlandır'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Yeni Ad',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && newName != path.basename(item.path)) {
                context.read<FileManagerViewModel>().renameItem(item, newName);
              }
              Navigator.pop(context);
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  // Kopyalama dialog'u
  void _showCopyDialog(BuildContext context, FileSystemEntity item) {
    final viewModel = context.read<FileManagerViewModel>();
    final controller = TextEditingController(text: viewModel.currentPath);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kopyala'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Kaynak: ${path.basename(item.path)}'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Hedef Klasör',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () {
              final destination = controller.text.trim();
              if (destination.isNotEmpty) {
                viewModel.copyItem(item, destination);
              }
              Navigator.pop(context);
            },
            child: const Text('Kopyala'),
          ),
        ],
      ),
    );
  }

  // Dosya boyutu formatlama yardımcı metodu
  String _formatFileSize(int? size) {
    if (size == null) return 'Bilinmiyor';
    
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double s = size.toDouble();
    
    while (s >= 1024 && i < suffixes.length - 1) {
      s /= 1024;
      i++;
    }
    
    return '${s.toStringAsFixed(2)} ${suffixes[i]}';
  }

  // Arama işlemleri için tek metod
  void _handleSearch(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (query.length >= 2) {
        context.read<FileManagerViewModel>().searchFiles(query);
      } else {
        context.read<FileManagerViewModel>().clearSearch();
      }
    });
  }
}
