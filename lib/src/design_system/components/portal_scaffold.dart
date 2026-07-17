import 'package:flutter/material.dart';

class PortalScaffold extends StatelessWidget {
  const PortalScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.resizeToAvoidBottomInset,
    this.maxContentWidth = 840,
  });

  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final bool? resizeToAvoidBottomInset;
  final double maxContentWidth;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar,
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      body: ColoredBox(
        color: Theme.of(context).colorScheme.surface,
        child: SafeArea(
          top: appBar == null,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxContentWidth),
                  child: SizedBox(
                    width: double.infinity,
                    height: constraints.maxHeight,
                    child: body,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
