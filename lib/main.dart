import 'package:file_tidy/viewmodels/file_manager_viewmodel.dart';
import 'package:file_tidy/views/home_view.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => FileManagerViewModel(),
      child: Consumer<FileManagerViewModel>(
        builder: (context, viewModel, child) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'File Tidy',
            themeMode: viewModel.themeMode,
            theme: ThemeData(
              useMaterial3: true,
              colorSchemeSeed: Colors.blue,
              brightness: Brightness.light,
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              colorSchemeSeed: Colors.blue,
              brightness: Brightness.dark,
            ),
            home: const HomeView(),
          );
        },
      ),
    );
  }
}
