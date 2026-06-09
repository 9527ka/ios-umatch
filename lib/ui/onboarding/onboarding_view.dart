import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/um_theme.dart';
import '../../core/store/match_store.dart';
import '../../l10n/um_strings.dart';
import '../components/crest.dart';

class OnboardingView extends StatefulWidget {
  const OnboardingView({super.key});

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  final _controller = PageController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UMColors.bg,
      body: PageView(
        controller: _controller,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _WelcomePage(onNext: _next),
          _PickTeamsPage(onNext: _next, onSkip: _next),
          _EnableNotifsPage(onDone: _finish, onSkip: _finish),
        ],
      ),
    );
  }

  void _next() {
    _controller.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  void _finish() {
    context.read<MatchStore>().completeOnboarding();
  }
}

class _WelcomePage extends StatelessWidget {
  final VoidCallback onNext;

  const _WelcomePage({required this.onNext});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final s = UMStrings.of(locale);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 2),
            // Artwork: radial glow + football glyph
            Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    UMColors.primary.withValues(alpha: 0.15),
                    UMColors.primary.withValues(alpha: 0.0),
                  ],
                ),
              ),
              child: Center(
                child: Image.asset('assets/brand/logo.png', width: 80, height: 80),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              s.onbWelcomeTag,
              style: UMFont.caption(size: 12, tracking: 0.15).copyWith(
                color: UMColors.primary,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              s.brand,
              style: UMFont.display(size: 44, weight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            Text(
              s.onbWelcomeBody,
              textAlign: TextAlign.center,
              style: UMFont.body(size: 16).copyWith(color: UMColors.textSecondary, height: 1.5),
            ),
            const Spacer(flex: 3),
            // CTA
            GestureDetector(
              onTap: onNext,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  color: UMColors.primary,
                  borderRadius: BorderRadius.circular(UMRadius.button),
                  boxShadow: UMShadows.ctaButton,
                ),
                child: Text(
                  s.onbStart,
                  textAlign: TextAlign.center,
                  style: UMFont.body(size: 16, weight: FontWeight.w600).copyWith(color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _PickTeamsPage extends StatelessWidget {
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const _PickTeamsPage({required this.onNext, required this.onSkip});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MatchStore>();
    final locale = Localizations.localeOf(context);
    final s = UMStrings.of(locale);
    final teams = store.teams.values.toList();
    final allSelected = teams.isNotEmpty && store.followedTeams.length >= teams.length;

    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 20),
          Text(s.onbStepLabel(1, 2), style: UMFont.caption(size: 11, tracking: 0.1).copyWith(color: UMColors.textTertiary, letterSpacing: 1.5)),
          const SizedBox(height: 8),
          Text(s.onbTeamsTitle, style: UMFont.display(size: 22, weight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(s.onbTeamsSub, style: UMFont.body(size: 14).copyWith(color: UMColors.textSecondary)),
          const SizedBox(height: 12),
          // Select all / deselect all
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  store.setAllTeamsFollowed(!allSelected);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        allSelected ? Icons.remove_done : Icons.done_all,
                        size: 16,
                        color: UMColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        allSelected ? s.onbDeselectAll : s.onbSelectAll,
                        style: UMFont.body(size: 14, weight: FontWeight.w600).copyWith(color: UMColors.primary),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.85,
              ),
              itemCount: teams.length,
              itemBuilder: (context, index) {
                final team = teams[index];
                final selected = store.followedTeams.contains(team.id);
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    store.toggleFollowTeam(team.id);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: selected ? UMColors.primaryTint : UMColors.surface,
                      borderRadius: BorderRadius.circular(UMRadius.small),
                      border: Border.all(
                        color: selected ? UMColors.primary : UMColors.border,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Crest(team: team, size: 48),
                              const SizedBox(height: 8),
                              Text(
                                team.alias.resolve(locale),
                                style: UMFont.body(size: 12, weight: FontWeight.w600),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        if (selected)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: UMColors.primary,
                              ),
                              child: const Icon(Icons.check, size: 14, color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: onSkip,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        s.onbSkip,
                        textAlign: TextAlign.center,
                        style: UMFont.body(size: 15).copyWith(color: UMColors.textSecondary),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: onNext,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: UMColors.primary,
                        borderRadius: BorderRadius.circular(UMRadius.button),
                      ),
                      child: Text(
                        s.onbContinue,
                        textAlign: TextAlign.center,
                        style: UMFont.body(size: 15, weight: FontWeight.w600).copyWith(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EnableNotifsPage extends StatelessWidget {
  final VoidCallback onDone;
  final VoidCallback onSkip;

  const _EnableNotifsPage({required this.onDone, required this.onSkip});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final s = UMStrings.of(locale);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Text(s.onbStepLabel(2, 2), style: UMFont.caption(size: 11, tracking: 0.1).copyWith(color: UMColors.textTertiary, letterSpacing: 1.5)),
            const Spacer(flex: 2),
            // Bell artwork
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: UMColors.primaryTint,
              ),
              child: const Icon(Icons.notifications_outlined, size: 56, color: UMColors.primary),
            ),
            const SizedBox(height: 32),
            Text(s.onbNotifTitle, style: UMFont.display(size: 22, weight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              s.onbNotifSub,
              textAlign: TextAlign.center,
              style: UMFont.body(size: 14).copyWith(color: UMColors.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 32),
            // Sample notification mockup
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: UMColors.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: UMShadows.card,
              ),
              child: Row(
                children: [
                  Image.asset('assets/brand/logo.png', width: 36, height: 36),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.onbNotifFakeTitle,
                          style: UMFont.caption(size: 11).copyWith(color: UMColors.textTertiary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          s.onbNotifFakeBody,
                          style: UMFont.body(size: 13),
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(flex: 3),
            GestureDetector(
              onTap: onDone,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  color: UMColors.primary,
                  borderRadius: BorderRadius.circular(UMRadius.button),
                  boxShadow: UMShadows.ctaButton,
                ),
                child: Text(
                  s.onbNotifEnable,
                  textAlign: TextAlign.center,
                  style: UMFont.body(size: 16, weight: FontWeight.w600).copyWith(color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: onSkip,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  s.onbNotifNot,
                  textAlign: TextAlign.center,
                  style: UMFont.body(size: 15).copyWith(color: UMColors.textSecondary),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
