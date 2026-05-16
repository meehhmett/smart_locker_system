import 'package:flutter/material.dart';

class AppBreakpoints {
  const AppBreakpoints._();

  static const double desktop = 900;
  static const double wide = 1180;
}

bool isDesktopLayout(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= AppBreakpoints.desktop;

class ResponsiveContent extends StatelessWidget {
  final Widget child;
  final double mobileMaxWidth;
  final double desktopMaxWidth;
  final EdgeInsetsGeometry padding;

  const ResponsiveContent({
    super.key,
    required this.child,
    this.mobileMaxWidth = 500,
    this.desktopMaxWidth = AppBreakpoints.wide,
    this.padding = const EdgeInsets.all(18),
  });

  @override
  Widget build(BuildContext context) {
    final desktop = isDesktopLayout(context);
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: desktop ? desktopMaxWidth : mobileMaxWidth,
        ),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
