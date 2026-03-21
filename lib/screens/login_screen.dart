import 'dart:io';

import 'package:finamp/components/Buttons/simple_button.dart';
import 'package:finamp/components/LoginScreen/login_flow.dart';
import 'package:finamp/config/product_config.dart';
import 'package:finamp/screens/language_selection_screen.dart';
import 'package:finamp/screens/logs_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  static const routeName = "/login";

  @override
  Widget build(BuildContext context) {
    final isDesktop = !Platform.isAndroid && !Platform.isIOS;
    final isWideDesktop = isDesktop && MediaQuery.sizeOf(context).width >= 1000;

    return Theme(
      data: Theme.of(context).copyWith(
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
        ),
      ),
      child: Scaffold(
        body: SafeArea(
          child: isWideDesktop
              ? const _DesktopLoginLayout()
              : const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32.0),
                  child: LoginFlow(),
                ),
        ),
        bottomNavigationBar:
            isWideDesktop ? null : const _LoginAuxillaryOptions(),
      ),
    );
  }
}

class _DesktopLoginLayout extends StatelessWidget {
  const _DesktopLoginLayout();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        children: [
          const Expanded(
            flex: 6,
            child: _DesktopLoginHero(),
          ),
          Expanded(
            flex: 5,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32.0, vertical: 20.0),
                  child: Column(
                    children: const [
                      Expanded(
                        child: LoginFlow(),
                      ),
                      _LoginAuxillaryOptions(
                        center: false,
                        topPadding: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopLoginHero extends StatelessWidget {
  const _DesktopLoginHero();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(right: 12.0),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF071427),
            colorScheme.primary.withOpacity(0.22),
            const Color(0xFF06101E),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -80,
            left: -40,
            child: _HeroGlow(
              color: colorScheme.primary.withOpacity(0.20),
              size: 260,
            ),
          ),
          Positioned(
            right: -90,
            bottom: -120,
            child: _HeroGlow(
              color: colorScheme.secondary.withOpacity(0.18),
              size: 320,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(40, 40, 40, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Text(
                    kProductName,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Colors.white,
                          letterSpacing: 0.6,
                        ),
                  ),
                ),
                const Spacer(),
                Hero(
                  tag: "finamp_logo",
                  child: Image.asset(
                    'images/finamp_cropped.png',
                    width: 140,
                    height: 140,
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  AppLocalizations.of(context)!.loginFlowWelcomeHeading,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        height: 1.0,
                      ),
                ),
                const SizedBox(height: 14),
                Text(
                  AppLocalizations.of(context)!.loginFlowSlogan,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white.withOpacity(0.78),
                        height: 1.4,
                      ),
                ),
                const SizedBox(height: 28),
                const _DesktopFeatureRow(
                  icon: TablerIcons.server,
                  title: 'Connect',
                  subtitle:
                      'Point Spinamp at your Jellyfin server and start in seconds.',
                ),
                const SizedBox(height: 14),
                const _DesktopFeatureRow(
                  icon: TablerIcons.layout_sidebar_left_expand,
                  title: 'Browse',
                  subtitle:
                      'Use the redesigned library workspace with a persistent desktop sidebar.',
                ),
                const SizedBox(height: 14),
                const _DesktopFeatureRow(
                  icon: TablerIcons.player_play,
                  title: 'Play',
                  subtitle:
                      'Keep the player visible while you move through albums, artists, and queues.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopFeatureRow extends StatelessWidget {
  const _DesktopFeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 20,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withOpacity(0.72),
                      height: 1.4,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeroGlow extends StatelessWidget {
  const _HeroGlow({
    required this.color,
    required this.size,
  });

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color,
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}

class _LoginAuxillaryOptions extends StatelessWidget {
  const _LoginAuxillaryOptions({
    this.center = true,
    this.topPadding = 0,
  });

  final bool center;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20.0,
          right: 20.0,
          bottom: 12.0,
          top: topPadding,
        ),
        child: Row(
          mainAxisAlignment:
              center ? MainAxisAlignment.spaceBetween : MainAxisAlignment.start,
          children: [
            SimpleButton(
              text: AppLocalizations.of(context)!.viewLogs,
              icon: TablerIcons.file_text,
              onPressed: () =>
                  Navigator.of(context).pushNamed(LogsScreen.routeName),
            ),
            if (!center) const SizedBox(width: 16),
            SimpleButton(
              text: AppLocalizations.of(context)!.changeLanguage,
              icon: TablerIcons.language,
              onPressed: () => Navigator.of(context)
                  .pushNamed(LanguageSelectionScreen.routeName),
            ),
          ],
        ),
      ),
    );
  }
}
