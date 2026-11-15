import 'package:flutter/material.dart';

class SlidePageRoute extends PageRouteBuilder {
  final Widget page;
  final bool fromLeft;

  SlidePageRoute({required this.page, this.fromLeft = false})
      : super(
          transitionDuration: const Duration(milliseconds: 800),
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const curve = Curves.easeInOutCubic;

            final tween = Tween<Offset>(
              begin: fromLeft ? const Offset(-1, 0) : const Offset(1, 0),
              end: Offset.zero,
            ).chain(CurveTween(curve: curve));

            final fade = Tween<double>(begin: 0.0, end: 1.0)
                .chain(CurveTween(curve: Curves.easeIn));

            return SlideTransition(
              position: animation.drive(tween),
              child: FadeTransition(
                opacity: animation.drive(fade),
                child: child,
              ),
            );
          },
        );
}
