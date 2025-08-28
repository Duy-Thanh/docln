import 'package:flutter_test/flutter_test.dart';
import 'package:dartz/dartz.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import 'package:docln/dcl2/features/bookmarks/domain/entities/bookmark_entity.dart';
import 'package:docln/dcl2/features/bookmarks/domain/repositories/bookmark_repository.dart';
import 'package:docln/dcl2/features/bookmarks/domain/usecases/get_bookmarks.dart';
import 'package:docln/dcl2/core/utils/use_case.dart';

import 'get_bookmarks_test.mocks.dart';

@GenerateMocks([BookmarkRepository])
void main() {
  late GetBookmarks usecase;
  late MockBookmarkRepository mockRepository;

  setUp(() {
    mockRepository = MockBookmarkRepository();
    usecase = GetBookmarks(mockRepository);
  });

  final tBookmarks = [
    const BookmarkEntity(
      id: 'bookmark_1',
      novelId: 'novel_1',
      title: 'Test Novel',
      createdAt: '2024-01-01T00:00:00Z',
      updatedAt: '2024-01-01T00:00:00Z',
    ),
  ];

  test('should get bookmarks from the repository', () async {
    // arrange
    when(mockRepository.getBookmarks())
        .thenAnswer((_) async => Right(tBookmarks));

    // act
    final result = await usecase(const NoParams());

    // assert
    expect(result, Right(tBookmarks));
    verify(mockRepository.getBookmarks());
    verifyNoMoreInteractions(mockRepository);
  });
}