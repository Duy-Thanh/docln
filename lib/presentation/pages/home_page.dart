import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../presentation/blocs/light_novel/light_novel_bloc.dart';
import '../../presentation/blocs/light_novel/light_novel_event.dart';
import '../../presentation/blocs/light_novel/light_novel_state.dart';
import '../../domain/entities/light_novel.dart';
import '../widgets/novel_card.dart';
import 'novel_detail_page.dart';
import 'search_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DocLN DCL2'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SearchPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<LightNovelBloc, LightNovelState>(
        builder: (context, state) {
          if (state is LightNovelInitial) {
            // Load initial data
            context.read<LightNovelBloc>().add(const LoadLightNovels());
            return const Center(child: CircularProgressIndicator());
          } else if (state is LightNovelLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is LightNovelLoaded) {
            return _buildNovelList(state.novels);
          } else if (state is LightNovelError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Error: ${state.message}'),
                  ElevatedButton(
                    onPressed: () {
                      context.read<LightNovelBloc>().add(const LoadLightNovels());
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          return const Center(child: Text('Unknown state'));
        },
      ),
    );
  }

  Widget _buildNovelList(List<LightNovelEntity> novels) {
    if (novels.isEmpty) {
      return const Center(child: Text('No novels found'));
    }

    return ListView.builder(
      itemCount: novels.length,
      itemBuilder: (context, index) {
        final novel = novels[index];
        return NovelCard(
          novel: novel,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => NovelDetailPage(novelId: novel.id),
              ),
            );
          },
        );
      },
    );
  }
}
