import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:logon/login/page/login_page.dart';
import 'package:logon/register/page/register_page.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  static const _forest = Color(0xFF0B2F23);
  static const _sage = Color(0xFFA9D3B3);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 1100;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/eldery.jpg',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0F2E22), Color(0xFF0B1220)],
                  ),
                ),
                child: SizedBox.expand(),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.30),
                    Colors.black.withOpacity(0.66),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Prevent overflow on short screens by allowing gentle scrolling.
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: isDesktop ? 1160 : 520),
                          child: _GlassHeroCard(textTheme: textTheme, isDesktop: isDesktop),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: LandingPage._sage),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassHeroCard extends StatelessWidget {
  const _GlassHeroCard({required this.textTheme, required this.isDesktop});

  final TextTheme textTheme;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(isDesktop ? 22 : 18),
      child: BackdropFilter(
        // Minimal glass: lighter blur + calmer surface.
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.28),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.26),
                blurRadius: 30,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 28 : 18,
              vertical: isDesktop ? 22 : 18,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TopNav(textTheme: textTheme, isDesktop: isDesktop),
                SizedBox(height: isDesktop ? 34 : 20),
                if (isDesktop)
                  _DesktopHero(textTheme: textTheme)
                else
                  _MobileHero(textTheme: textTheme),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopNav extends StatelessWidget {
  const _TopNav({required this.textTheme, required this.isDesktop});

  final TextTheme textTheme;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: const Icon(Icons.terrain, color: LandingPage._sage, size: 20),
        ),
        const Spacer(),
        if (isDesktop) ...[
          _NavLink(label: 'Home'),
          _NavLink(label: 'Programs'),
          _NavLink(label: 'Safety'),
          _NavLink(label: 'Stories'),
          _NavLink(label: 'Contact'),
          const SizedBox(width: 10),
        ],
        IconButton(
          tooltip: 'Search',
          onPressed: () {},
          icon: Icon(Icons.search, color: Colors.white.withOpacity(0.88)),
        ),
        const SizedBox(width: 8),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.white.withOpacity(0.10),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            side: BorderSide(color: Colors.white.withOpacity(0.14)),
          ),
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterPage()));
          },
          child: const Text('Get Started', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }
}

class _NavLink extends StatelessWidget {
  const _NavLink({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () {},
      style: TextButton.styleFrom(
        foregroundColor: Colors.white.withOpacity(0.86),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}

class _DesktopHero extends StatelessWidget {
  const _DesktopHero({required this.textTheme});

  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 6,
          child: _HeroCopy(textTheme: textTheme),
        ),
        const SizedBox(width: 28),
        Expanded(
          flex: 5,
          child: _HeroImage(),
        ),
      ],
    );
  }
}

class _MobileHero extends StatelessWidget {
  const _MobileHero({required this.textTheme});

  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    final imageHeight = (h * 0.22).clamp(160.0, 220.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HeroCopy(textTheme: textTheme),
        const SizedBox(height: 18),
        _HeroImage(height: imageHeight),
      ],
    );
  }
}

class _HeroCopy extends StatelessWidget {
  const _HeroCopy({required this.textTheme});

  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome to GabayTech',
          style: textTheme.labelLarge?.copyWith(
            color: Colors.white.withOpacity(0.78),
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Confidence on Every Trail\nGuided Hiking for Older Adults',
          style: textTheme.displaySmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            height: 1.06,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Small-group hikes designed for comfort and safety. Friendly guides, paced routes, and community—so you can enjoy the outdoors at your speed.',
          style: textTheme.bodyLarge?.copyWith(
            color: Colors.white.withOpacity(0.82),
            height: 1.50,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: const [
            _Pill(icon: Icons.speed, label: 'Paced Routes'),
            _Pill(icon: Icons.verified_user, label: 'Safety First'),
            _Pill(icon: Icons.groups, label: 'Community Groups'),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: LandingPage._sage,
                foregroundColor: LandingPage._forest,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginPage()));
              },
              child: const Text('Explore Hikes', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
            const SizedBox(width: 14),
            TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(foregroundColor: Colors.white.withOpacity(0.92)),
              child: const Text(
                'Talk to a guide',
                style: TextStyle(fontWeight: FontWeight.w700, decoration: TextDecoration.underline),
              ),
            ),
          ],
        ),
        const SizedBox(height: 26),
        Row(
          children: [
            Text(
              'Trusted by 2,500+ hikers',
              style: textTheme.bodyMedium?.copyWith(
                color: Colors.white.withOpacity(0.84),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 12),
            const _AvatarStack(),
          ],
        ),
      ],
    );
  }
}

class _HeroImage extends StatelessWidget {
  const _HeroImage({this.height});

  final double? height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.24),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/eldery.jpg',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1A3A2B), Color(0xFF0B1220)],
                ),
              ),
              child: SizedBox.expand(),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.black.withOpacity(0.10),
                  Colors.black.withOpacity(0.52),
                ],
              ),
            ),
          ),
          // Keep the right side minimal: no extra overlays/text.
        ],
      ),
    );
  }
}

class _AvatarStack extends StatelessWidget {
  const _AvatarStack();

  @override
  Widget build(BuildContext context) {
    final colors = <Color>[
      const Color(0xFFE9D5FF),
      const Color(0xFFBAE6FD),
      const Color(0xFFFDE68A),
      const Color(0xFFBBF7D0),
    ];
    return SizedBox(
      width: 92,
      height: 26,
      child: Stack(
        children: List.generate(colors.length, (i) {
          return Positioned(
            left: i * 18.0,
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: colors[i].withOpacity(0.95),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.75), width: 1.2),
              ),
            ),
          );
        }),
      ),
    );
  }
}
