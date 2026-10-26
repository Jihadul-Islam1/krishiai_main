import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/app_providers.dart';

/// Home "আমার জমি" section: the farmer's farms as a swipeable stack of field
/// cards (front card on top, the next ones peeking out behind it). Read-only -
/// everything is edited from the My Farm tab; tapping a card only opens it.
class FarmsCarousel extends ConsumerWidget {
  const FarmsCarousel({super.key});

  static const _height = 240.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farmsAsync = ref.watch(farmsProvider);
    final crops = ref.watch(cropsProvider).valueOrNull ?? const [];

    return farmsAsync.when(
      loading: () => const SizedBox(
        height: _height,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => SizedBox(
        height: 120,
        child: Center(
          child: TextButton.icon(
            onPressed: () => ref.invalidate(farmsProvider),
            icon: const Icon(Icons.refresh),
            label: const Text('জমির তালিকা লোড হয়নি, আবার চেষ্টা করুন'),
          ),
        ),
      ),
      data: (farms) {
        if (farms.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              height: _height,
              child: _FieldCard(
                title: 'কোনো জমি যোগ করা হয়নি',
                location: 'আমার খামার ট্যাব থেকে জমি যোগ করুন',
                cropCount: 0,
                onTap: () => context.go('/farm'),
              ),
            ),
          );
        }
        final cards = [
          for (final f in farms)
            _FieldCard(
              title: f.name,
              location: f.location,
              photoUrl: f.photoUrl,
              cropCount: crops.where((c) => c.farmId == f.id).length,
              onTap: () => context.push('/farm/${f.id}'),
            ),
        ];
        return _FieldStack(
          height: _height,
          cards: cards,
          onOpen: (i) => context.push('/farm/${farms[i].id}'),
        );
      },
    );
  }
}

/// Swipeable deck: a transparent [PageView] captures the gestures while the
/// cards are painted by hand so the next ones tuck behind the front card.
class _FieldStack extends StatefulWidget {
  const _FieldStack({
    required this.height,
    required this.cards,
    required this.onOpen,
  });

  final double height;
  final List<Widget> cards;
  final ValueChanged<int> onOpen;

  @override
  State<_FieldStack> createState() => _FieldStackState();
}

class _FieldStackState extends State<_FieldStack> {
  static const _peek = 16.0; // visible strip of each card behind the front
  static const _peekCards = 2;
  final _controller = PageController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.cards.length;
    return SizedBox(
      height: widget.height,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: LayoutBuilder(
          builder: (context, box) {
            final multi = n > 1;
            final cardW = box.maxWidth - (multi ? _peek * _peekCards : 0);
            return Stack(
              children: [
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    final page =
                        _controller.hasClients &&
                            _controller.position.haveDimensions
                        ? (_controller.page ?? 0.0)
                        : 0.0;
                    final layers = <Widget>[];
                    // Paint from the back to the front.
                    for (var i = n - 1; i >= 0; i--) {
                      final d = i - page;
                      if (d < -1 || d > _peekCards + 0.01) continue;
                      final double dx;
                      final double scaleY;
                      final double shade;
                      if (d < 0) {
                        dx = d * cardW; // slides out to the left
                        scaleY = 1;
                        shade = 0;
                      } else {
                        dx = d * _peek;
                        scaleY = 1 - 0.07 * d;
                        shade = 0.12 * d;
                      }
                      layers.add(
                        Positioned(
                          left: dx,
                          top: 0,
                          bottom: 0,
                          width: cardW,
                          child: Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.diagonal3Values(1, scaleY, 1),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                widget.cards[i],
                                if (shade > 0)
                                  IgnorePointer(
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(
                                          alpha: shade,
                                        ),
                                        borderRadius: BorderRadius.circular(28),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }
                    return Stack(clipBehavior: Clip.none, children: layers);
                  },
                ),
                // Gesture layer: swipe to change card, tap to open it.
                Positioned.fill(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: n,
                    physics: const BouncingScrollPhysics(),
                    itemBuilder: (_, i) => GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () => widget.onOpen(i),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The original "Emerald Valley" field card, fed with real farm data.
class _FieldCard extends StatelessWidget {
  const _FieldCard({
    required this.title,
    required this.location,
    required this.cropCount,
    required this.onTap,
    this.photoUrl,
  });

  final String title;
  final String location;
  final int cropCount;
  final String? photoUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final url = photoUrl;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Material(
          color: const Color(0xFF1B4D22),
          child: InkWell(
            onTap: onTap,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (url != null && url.isNotEmpty)
                  Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const _FieldPlaceholder(),
                    loadingBuilder: (_, child, p) =>
                        p == null ? child : const _FieldPlaceholder(),
                  )
                else
                  const _FieldPlaceholder(),

                // ছবির ওপরে স্মুথ ডার্ক লিনিয়ার গ্রেডিয়েন্ট
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.1),
                        Colors.black.withValues(alpha: 0.65),
                      ],
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.eco,
                                  color: Colors.lightGreenAccent,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$cropCount ফসল',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.favorite,
                              color: Colors.red,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (location.isNotEmpty)
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.location_on,
                                        color: Colors.white.withValues(
                                          alpha: 0.6,
                                        ),
                                        size: 14,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          location,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Colors.white.withValues(
                                              alpha: 0.6,
                                            ),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                const SizedBox(height: 4),
                                Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            height: 44,
                            width: 44,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.arrow_outward,
                              color: Colors.black87,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldPlaceholder extends StatelessWidget {
  const _FieldPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1B4D22),
      child: const Center(
        child: Icon(Icons.gite_outlined, color: Colors.white24, size: 80),
      ),
    );
  }
}
