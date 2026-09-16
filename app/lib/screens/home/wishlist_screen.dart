import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../providers/books_provider.dart';
import '../../theme.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/book_card.dart';
import '../../widgets/error_state.dart';
import '../../widgets/user_avatar.dart';
import 'add_book_screen.dart';
import 'book_detail_screen.dart';

const _filters = [
  ('all', 'All'),
  ('toBuy', 'To Buy'),
  ('reading', 'To Be Read'),
  ('read', 'Read'),
];

const _sortOptions = [
  ('title', 'Title'),
  ('author', 'Author'),
  ('pages', 'Pages'),
  ('times_read', 'Times Read'),
  ('end_date', 'Date Read'),
];

class WishlistScreen extends ConsumerStatefulWidget {
  const WishlistScreen({super.key});

  @override
  ConsumerState<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends ConsumerState<WishlistScreen> {
  final _searchCtrl = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _scrollCtrl = ScrollController();
  Timer? _debounce;
  bool _searchOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(booksProvider.notifier).load());
    _scrollCtrl.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 300) {
      ref.read(booksProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _searchFocusNode.dispose();
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => ref.read(booksProvider.notifier).load(query: value.trim()));
  }

  void _toggleSearch() {
    if (_searchOpen) {
      setState(() => _searchOpen = false);
      _debounce?.cancel();
      _searchCtrl.clear();
      if (ref.read(booksProvider).query.isNotEmpty) {
        ref.read(booksProvider.notifier).load(query: '');
      }
    } else {
      setState(() => _searchOpen = true);
      WidgetsBinding.instance.addPostFrameCallback((_) => _searchFocusNode.requestFocus());
    }
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
            controller: _scrollCtrl,
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const AppIcon(),
                          const SizedBox(width: 10),
                          Text('Bookmarked', style: AppTheme.display.copyWith(fontSize: 22)),
                        ],
                      ),
                      Row(
                        children: [
                          PopupMenuButton<String>(
                            tooltip: 'Sort by',
                            initialValue: state.sort,
                            onSelected: (value) => ref.read(booksProvider.notifier).load(sort: value),
                            icon: const Icon(Icons.sort_rounded, size: 22, color: AppColors.ink),
                            itemBuilder: (context) => _sortOptions
                                .map((o) => PopupMenuItem<String>(
                                      value: o.$1,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(o.$2),
                                          if (state.sort == o.$1) const Icon(Icons.check, size: 16, color: AppColors.green),
                                        ],
                                      ),
                                    ))
                                .toList(),
                          ),
                          IconButton(
                            onPressed: _toggleSearch,
                            icon: Icon(_searchOpen ? Icons.close : Icons.search, size: 22, color: AppColors.ink),
                          ),
                          UserAvatar(avatarUrl: user?.avatarUrl, initials: user?.initials ?? '?', size: 34),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (_searchOpen)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
                  sliver: SliverToBoxAdapter(
                    child: TextField(
                      controller: _searchCtrl,
                      focusNode: _searchFocusNode,
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        hintText: 'Search your shelf by title, author, or series',
                        prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.inkSoft),
                        suffixIcon: _searchCtrl.text.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.close, size: 18, color: AppColors.inkSoft),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  _onSearchChanged('');
                                },
                              ),
                      ),
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
              else if (state.error != null && state.books.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: ErrorState(
                    message: state.error!,
                    onRetry: () => ref.read(booksProvider.notifier).load(),
                  ),
                )
              else if (state.books.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Text(
                        state.query.isNotEmpty ? 'No books match "${state.query}".' : 'No books in this shelf yet.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.inkSoft),
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 90),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        if (i == state.books.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(child: CircularProgressIndicator(color: AppColors.green, strokeWidth: 2)),
                          );
                        }
                        final book = state.books[i];
                        return BookCard(
                          book: book,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => BookDetailScreen(bookId: book.id)),
                          ),
                        );
                      },
                      childCount: state.books.length + (state.loadingMore ? 1 : 0),
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
