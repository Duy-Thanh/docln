import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/di/injection.dart';
import 'presentation/blocs/light_novel/light_novel_bloc.dart';
import 'presentation/pages/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configure dependencies
  configureDependencies();

  runApp(const DCL2App());
}

class DCL2App extends StatelessWidget {
  const DCL2App({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<LightNovelBloc>(
          create: (context) => getIt<LightNovelBloc>(),
        ),
      ],
      child: MaterialApp(
        title: 'DocLN DCL2',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
        ),
        home: const HomePage(),
      ),
    );
  }
}
