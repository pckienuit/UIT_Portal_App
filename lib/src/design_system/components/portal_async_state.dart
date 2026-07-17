import 'package:flutter/material.dart';

import '../foundations/portal_spacing.dart';
import 'portal_empty_state.dart';
import 'portal_error_state.dart';
import 'portal_skeleton.dart';

enum PortalAsyncStateKind { data, loading, empty, unavailable, error }

class PortalAsyncState extends StatelessWidget {
  const PortalAsyncState.data({super.key, required this.child})
    : _kind = PortalAsyncStateKind.data,
      title = null,
      message = null,
      onRetry = null;

  const PortalAsyncState.loading({super.key, Widget? skeleton})
    : _kind = PortalAsyncStateKind.loading,
      child = skeleton,
      title = null,
      message = null,
      onRetry = null;

  const PortalAsyncState.empty({
    super.key,
    required this.title,
    required this.message,
  }) : _kind = PortalAsyncStateKind.empty,
       child = null,
       onRetry = null;

  const PortalAsyncState.unavailable({
    super.key,
    required this.title,
    required this.message,
  }) : _kind = PortalAsyncStateKind.unavailable,
       child = null,
       onRetry = null;

  const PortalAsyncState.error({
    super.key,
    required this.title,
    required this.message,
    this.onRetry,
  }) : _kind = PortalAsyncStateKind.error,
       child = null;

  final PortalAsyncStateKind _kind;
  final Widget? child;
  final String? title;
  final String? message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return switch (_kind) {
      PortalAsyncStateKind.data => child!,
      PortalAsyncStateKind.loading => Semantics(
        label: 'Đang tải',
        liveRegion: true,
        child: child ?? const _DefaultSkeleton(),
      ),
      PortalAsyncStateKind.empty => PortalEmptyState(
        title: title!,
        message: message!,
      ),
      PortalAsyncStateKind.unavailable => PortalEmptyState(
        title: title!,
        message: message!,
        icon: Icons.construction_outlined,
      ),
      PortalAsyncStateKind.error => PortalErrorState(
        title: title!,
        message: message!,
        onRetry: onRetry,
      ),
    };
  }
}

class _DefaultSkeleton extends StatelessWidget {
  const _DefaultSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(PortalSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PortalSkeleton(width: 180, height: 24),
          SizedBox(height: PortalSpacing.md),
          PortalSkeleton(height: 96),
          SizedBox(height: PortalSpacing.sm),
          PortalSkeleton(height: 96),
        ],
      ),
    );
  }
}
