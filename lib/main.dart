import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:face_recognition_app/config/route/route_generator.dart';
import 'package:face_recognition_app/config/route/routes.dart';
import 'package:face_recognition_app/core/database/app_database.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appDb = AppDatabase();
  runApp(MyApp(appDb: appDb));
}

class MyApp extends StatelessWidget {
  final AppDatabase appDb;
  const MyApp({super.key, required this.appDb});

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider.value(
      value: appDb,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Face Recognition App',
        theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
        initialRoute: AppRoutes.home,
        onGenerateRoute: RouteGenerator.generateRoute,
      ),
    );
  }
}
