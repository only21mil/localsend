import 'package:flutter/material.dart';

class SizingInformation {
  final bool isMobile;
  final bool isTabletOrDesktop;
  final bool isDesktop;

  /// Whether to show a side [NavigationRail] instead of a bottom [NavigationBar].
  ///
  /// Uses a rail on wide screens (`width >= 700`) and compact-height landscape
  /// viewports (`width > height && height < 550`) so a bottom bar does not
  /// crowd out tab content.
  final bool useNavigationRail;

  const SizingInformation(double width, [double height = double.infinity])
    : isMobile = width < 700,
      isTabletOrDesktop = width >= 700,
      isDesktop = width >= 800,
      useNavigationRail = width >= 700 || (width > height && height < 550);
}

class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(SizingInformation sizingInformation) builder;

  const ResponsiveBuilder({required this.builder});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return builder(SizingInformation(size.width, size.height));
  }
}
