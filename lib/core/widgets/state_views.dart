import 'package:flutter/material.dart';

export 'shimmer_view.dart';

class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.size = 28, this.message});

  final double size;
  final String? message;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(width: size, height: size, child: const CircularProgressIndicator(strokeWidth: 2.5)),
        if (message != null) ...[
          const SizedBox(height: 12),
          Text(message!, style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
        ],
      ],
    ),
  );
}

class ListLoadingFooter extends StatelessWidget {
  const ListLoadingFooter({super.key});

  @override
  Widget build(BuildContext context) => const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: LoadingView(size: 22));
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, this.onRetry, this.compact = false});

  final String message;
  final VoidCallback? onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? 12 : 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!compact) Icon(Icons.error_outline_rounded, size: 40, color: scheme.error),
            if (!compact) const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              TextButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded, size: 18), label: const Text('Tekrar dene')),
            ],
          ],
        ),
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.title, this.subtitle, this.icon = Icons.inbox_outlined, this.action});

  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(color: theme.colorScheme.primaryContainer, shape: BoxShape.circle),
              child: Icon(icon, size: 40, color: theme.colorScheme.onPrimaryContainer),
            ),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[const SizedBox(height: 18), action!],
          ],
        ),
      ),
    );
  }
}
