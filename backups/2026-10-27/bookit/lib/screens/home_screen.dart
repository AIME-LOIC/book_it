import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Demo data for the bookings showcase.
const _categories = ['All', 'Hotels', 'Flights', 'Events', 'Cars'];

const _deals = [
  (
    title: 'Ocean-view suite',
    place: 'Bali, Indonesia',
    price: 245,
    icon: Icons.hotel_rounded,
    rating: 4.9,
  ),
  (
    title: 'Jazz night live',
    place: 'Nairobi, Kenya',
    price: 30,
    icon: Icons.music_note_rounded,
    rating: 4.7,
  ),
  (
    title: 'Nairobi → Mombasa',
    place: 'Direct · 2h 05m',
    price: 88,
    icon: Icons.flight_rounded,
    rating: 4.8,
  ),
  (
    title: 'Safari SUV rental',
    place: 'Naivasha, Kenya',
    price: 65,
    icon: Icons.directions_car_rounded,
    rating: 4.6,
  ),
];

const _upcoming = [
  (
    title: 'Ocean-view suite',
    subtitle: 'Bali · Dec 12 – 18 · 2 guests',
    when: 'in 3 days',
    icon: Icons.hotel_rounded,
  ),
  (
    title: 'Nairobi → Mombasa',
    subtitle: 'Flight KQ204 · Seat 12A',
    when: 'Dec 12',
    icon: Icons.flight_rounded,
  ),
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.userName});

  final String userName;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _category = 0;
  int _nav = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'New booking',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: IndexedStack(
        index: _nav,
        children: [
          _HomeTab(
            userName: widget.userName,
            categoryIndex: _category,
            onCategory: (i) => setState(() => _category = i),
          ),
          const _MyBookingsTab(),
          const PlaceholderTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _nav,
        onDestinationSelected: (i) => setState(() => _nav = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.explore_rounded),
            selectedIcon: Icon(Icons.explore_rounded),
            label: 'Explore',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_note_rounded),
            selectedIcon: Icon(Icons.event_note_rounded),
            label: 'Bookings',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Explore tab
// ---------------------------------------------------------------------------

class _HomeTab extends StatelessWidget {
  const _HomeTab({
    required this.userName,
    required this.categoryIndex,
    required this.onCategory,
  });

  final String userName;
  final int categoryIndex;
  final ValueChanged<int> onCategory;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: GradientBanner(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(36),
            ),
            height: 265,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.screenPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.local_activity_rounded,
                          color: AppColors.white,
                          size: 30,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'BookIt',
                          style: TextStyle(
                            color: AppColors.white.withValues(alpha: 0.9),
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () {},
                          style: IconButton.styleFrom(
                            backgroundColor:
                                AppColors.white.withValues(alpha: 0.18),
                          ),
                          icon: const Icon(
                            Icons.notifications_rounded,
                            color: AppColors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Hi $userName 👋',
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Where are we booking next?',
                      style: TextStyle(
                        color: AppColors.white.withValues(alpha: 0.85),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 18),
                    // White search field.
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Search hotels, flights, events…',
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: AppColors.primary,
                        ),
                        filled: true,
                        fillColor: AppColors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppSpacing.buttonRadius,
                          ),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Category chips.
        SliverToBoxAdapter(
          child: SizedBox(
            height: 58,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenPadding,
                vertical: 12,
              ),
              itemCount: _categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final selected = i == categoryIndex;
                final chip = ChoiceChip(
                  label: Text(_categories[i]),
                  selected: selected,
                  labelStyle: TextStyle(
                    color: selected ? AppColors.white : AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppSpacing.chipRadius),
                  ),
                  backgroundColor: AppColors.white,
                  selectedColor: AppColors.primary,
                  showCheckmark: false,
                  onSelected: (_) => onCategory(i),
                );
                return chip;
              },
            ),
          ),
        ),

        // Section title.
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenPadding,
              8,
              AppSpacing.screenPadding,
              12,
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text('Popular this week', style: TextStyle(
                    color: AppColors.textDark,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  )),
                ),
                TextButton(
                  onPressed: () {},
                  child: const Text(
                    'See all',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Deal cards.
        SliverPadding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenPadding,
          ),
          sliver: SliverList.separated(
            itemCount: _deals.length,              separatorBuilder: (_, _) => const SizedBox(height: 14),
            itemBuilder: (context, i) {
              final deal = _deals[i];
              return FadeSlideIn(
                delay: Duration(milliseconds: 90 * i),
                offset: const Offset(0, 0.5),
                child: _DealCard(deal: deal),
              );
            },
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 90)),
      ],
    );
  }
}

class _DealCard extends StatelessWidget {
  const _DealCard({required this.deal});

  final ({String title, String place, int price, IconData icon, double rating})
      deal;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.10),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(deal.icon, color: AppColors.primary, size: 30),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          deal.title,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textDark,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.star_rounded,
                        size: 16,
                        color: Color(0xFFFFB300),
                      ),
                      Text(
                        '${deal.rating}',
                        style: const TextStyle(
                          color: AppColors.textDark,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    deal.place,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'from',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
                Text(
                  '\$${deal.price}',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bookings tab
// ---------------------------------------------------------------------------

class _MyBookingsTab extends StatelessWidget {
  const _MyBookingsTab();

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        const SliverAppBar(
          title: Text('My bookings'),
          pinned: true,
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenPadding,
            12,
            AppSpacing.screenPadding,
            90,
          ),
          sliver: SliverList.separated(
            itemCount: _upcoming.length,              separatorBuilder: (_, _) => const SizedBox(height: 14),
            itemBuilder: (context, i) {
              final b = _upcoming[i];
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: AppColors.heroGradient,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child:
                          Icon(b.icon, color: AppColors.white, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            b.title,
                            style: const TextStyle(
                              color: AppColors.textDark,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            b.subtitle,
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        b.when,
                        style: const TextStyle(
                          color: AppColors.primaryDark,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Profile tab placeholder
// ---------------------------------------------------------------------------

class PlaceholderTab extends StatelessWidget {
  const PlaceholderTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BrandLogo(size: 72),
            const SizedBox(height: 16),
            const Text(
              'Profile & settings coming soon',
              style: TextStyle(color: AppColors.textMuted),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
