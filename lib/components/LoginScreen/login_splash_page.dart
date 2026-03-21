import 'package:finamp/components/Buttons/cta_large.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:finamp/config/product_config.dart';

class LoginSplashPage extends StatelessWidget {
  static const routeName = "login/splash";

  final VoidCallback onGetStartedPressed;
  final VoidCallback? onUseCustomServerPressed;
  final bool isConnecting;

  const LoginSplashPage({
    super.key,
    required this.onGetStartedPressed,
    this.onUseCustomServerPressed,
    this.isConnecting = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 80.0, bottom: 40.0),
                child: Hero(
                  tag: "finamp_logo",
                  child: Image.asset(
                    'images/finamp_cropped.png',
                    width: 150,
                    height: 150,
                  ),
                ),
              ),
              RichText(
                text: TextSpan(
                  text:
                      "${AppLocalizations.of(context)!.loginFlowWelcomeHeading} ",
                  style: Theme.of(context).textTheme.headlineMedium,
                  children: [
                    TextSpan(
                      text: kProductName,
                      style:
                          Theme.of(context).textTheme.headlineMedium!.copyWith(
                                // color: Theme.of(context).colorScheme.secondary,
                                fontWeight: FontWeight.w600,
                              ),
                    ),
                  ],
                ),
              ),
              const SizedBox(
                height: 60,
              ),
              Text(AppLocalizations.of(context)!.loginFlowSlogan,
                  style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(
                height: 80,
              ),
              if (isConnecting)
                const SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(),
                )
              else
                CTALarge(
                  text: AppLocalizations.of(context)!.loginFlowGetStarted,
                  icon: TablerIcons.music,
                  onPressed: onGetStartedPressed,
                ),
              if (onUseCustomServerPressed != null) ...[
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: isConnecting ? null : onUseCustomServerPressed,
                  icon:
                      const Icon(TablerIcons.adjustments_horizontal, size: 18),
                  label: const Text("Use another server"),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
