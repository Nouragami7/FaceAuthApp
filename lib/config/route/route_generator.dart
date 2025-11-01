import 'package:face_recognition_app/feature/presentation/cubit/enroll/enroll_cubit.dart';
import 'package:face_recognition_app/feature/presentation/cubit/live/live_rec_cubit.dart';
import 'package:face_recognition_app/feature/presentation/screen/fullscreen_capture_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:face_recognition_app/config/route/routes.dart';
import 'package:face_recognition_app/feature/presentation/screen/home_page.dart';
import 'package:face_recognition_app/feature/presentation/screen/enroll_page.dart';
import 'package:face_recognition_app/feature/presentation/screen/live_recognition_page.dart';
import 'package:face_recognition_app/core/database/app_database.dart';

class RouteGenerator {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.home:
        return MaterialPageRoute(builder: (_) => const HomePage());
      case AppRoutes.enroll:
        return MaterialPageRoute(
          builder: (ctx) {
            final db = RepositoryProvider.of<AppDatabase>(ctx);
            return BlocProvider(
              create: (_) => EnrollCubit(db),
              child: const EnrollPage(),
            );
          },
        );
      case AppRoutes.recognize:
        return MaterialPageRoute(
          builder:
              (_) => BlocProvider(
                create: (_) => LiveRecCubit()..initCamera(),
                child: const LiveRecognitionPage(),
              ),
        );
      case AppRoutes.capture:
        return MaterialPageRoute(builder: (_) => const FullscreenCapturePage());

      default:
        return MaterialPageRoute(
          builder:
              (_) => Scaffold(
                body: Center(
                  child: Text('No route defined for ${settings.name}'),
                ),
              ),
        );
    }
  }
}
