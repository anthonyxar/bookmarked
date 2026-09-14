import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../providers/books_provider.dart';
import '../../theme.dart';
import '../../widgets/book_card.dart';
import 'add_book_screen.dart';
import 'book_detail_screen.dart';

const _filters = [
  ('all', 'All'),
  ('toBuy', 'To Buy'),
  ('reading', 'Reading'),
  ('read', 'Read'),
];

class WishlistScreen extends ConsumerStatefulWidget {
  const WishlistScreen({super.key});

  @override
  ConsumerState<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends ConsumerState<WishlistScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(booksProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(booksProvider);
    final user = ref.watch(authProvider).user;

    return Scaffold(
      backgroundColor: AppColors.paper,
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.green,
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddBookScreen())),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.green,
          onRefresh: () => ref.read(booksProvider.notifier).load(),
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Bookmarked', style: AppTheme.display.copyWith(fontSize: 22)),
                      CircleAvatar(
                        radius: 17,
                        backgroundColor: AppColors.green,
                        child: Text(user?.initials ?? '?', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
                sliver: SliverToBoxAdapter(
                  child: SizedBox(
                    height: 34,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _filters.length,
                      separatorBuilder: (context, i) => const SizedBox(width: 6),
                      itemBuilder: (context, i) {
                        final (key, label) = _filters[i];
                        final active = state.filter == key;
                        return GestureDetector(
                          onTap: () => ref.read(booksProvider.notifier).load(filter: key),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: active ? AppColors.green : AppColors.paperSoft,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: active ? AppColors.green : AppColors.line),
                            ),
                            child: Text(label,
                                style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: active ? Colors.white : AppColors.ink)),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              if (state.loading && state.books.isEmpty)
                const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: AppColors.green)))
              else if (state.books.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: Text('No books in this shelf yet.', style: TextStyle(color: AppColors.inkSoft)),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 90),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        final book = state.books[i];
                        return BookCard(
                          book: book,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => BookDetailScreen(bookId: book.id)),
                          ),
                        );
                      },
                      childCount: state.books.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
