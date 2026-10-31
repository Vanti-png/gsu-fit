import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gsu_fit/core/l10n/l10n.dart';
import 'package:gsu_fit/core/theme/app_theme.dart';

export 'package:gsu_fit/core/widgets/charts.dart';

/// Centered placeholder for screens without content: a quiet icon, one
/// line of explanation and at most one action.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(color: palette.fill, shape: BoxShape.circle),
                child: Icon(icon, size: 30, color: palette.textSecondary),
              ),
              const SizedBox(height: 16),
              Text(title, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
              if (message != null) ...[
                const SizedBox(height: 6),
                Text(
                  message!,
                  style: theme.textTheme.bodyMedium?.copyWith(color: palette.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
              if (action != null) ...[const SizedBox(height: 20), action!],
            ],
          ),
        ),
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return EmptyState(
      icon: CupertinoIcons.exclamationmark_triangle,
      title: message,
      action: onRetry == null
          ? null
          : FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(CupertinoIcons.arrow_clockwise, size: 18),
              label: Text(l.commonRetry),
            ),
    );
  }
}

/// Renders an [AsyncValue] with consistent loading and error states.
class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({
    super.key,
    required this.value,
    required this.data,
    this.onRetry,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: data,
      loading: () => const Center(child: CircularProgressIndicator.adaptive()),
      error: (error, stackTrace) =>
          ErrorView(message: context.l10n.errorLoadFailed, onRetry: onRetry),
    );
  }
}

/// Grouped section in the style of Apple's Settings: a small header above
/// a rounded card with a hairline border.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.title,
    this.trailing,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final String? title;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null || trailing != null)
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 32),
              child: Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title ?? '',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: context.palette.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    ?trailing,
                  ],
                ),
              ),
            ),
          Card(child: Padding(padding: padding, child: child)),
        ],
      ),
    );
  }
}

/// Keeps content at a readable width on wide (desktop browser) screens.
class ReadableWidth extends StatelessWidget {
  const ReadableWidth({super.key, required this.child, this.maxWidth = 760});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: child),
    );
  }
}

const BorderRadius _fieldRadius = BorderRadius.all(Radius.circular(10));

/// Filled, borderless field like macOS/iOS inputs; the accent underline
/// only appears while focused.
InputDecoration fieldDecoration(
  String label, {
  String? suffix,
  String? hint,
  String? helper,
  Widget? suffixIcon,
  bool dense = false,
}) {
  return InputDecoration(
    labelText: label,
    suffixText: suffix,
    hintText: hint,
    helperText: helper,
    suffixIcon: suffixIcon,
    isDense: dense,
    filled: true,
    contentPadding: dense ? const EdgeInsets.symmetric(horizontal: 10, vertical: 10) : null,
    border: const UnderlineInputBorder(borderRadius: _fieldRadius),
    enabledBorder: const UnderlineInputBorder(
      borderRadius: _fieldRadius,
      borderSide: BorderSide.none,
    ),
  );
}

/// The rounded gray search field used in Apple apps.
InputDecoration searchDecoration(BuildContext context, String hint, {Widget? suffixIcon}) {
  final palette = context.palette;
  return InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: palette.fill,
    isDense: true,
    prefixIcon: Icon(CupertinoIcons.search, size: 18, color: palette.textSecondary),
    suffixIcon: suffixIcon,
    contentPadding: const EdgeInsets.symmetric(vertical: 10),
    border: const OutlineInputBorder(borderRadius: _fieldRadius, borderSide: BorderSide.none),
  );
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final l = context.l10n;
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      final palette = context.palette;
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.commonCancel),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: destructive ? palette.red : palette.accent,
              textStyle: Theme.of(context).textTheme.labelLarge,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return result ?? false;
}

/// Short toast at the bottom of the window.
void showMessage(BuildContext context, String message, {SnackBarAction? action}) {
  final width = MediaQuery.sizeOf(context).width;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      action: action,
      width: width > 520 ? 440 : null,
      duration: const Duration(seconds: 3),
    ));
}

/// Settings shortcut shown in the app bar of the main tabs on phones.
class SettingsAction extends StatelessWidget {
  const SettingsAction({super.key, required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: context.l10n.settingsTitle,
      icon: const Icon(CupertinoIcons.gear),
      onPressed: onOpen,
    );
  }
}

/// Small rounded badge, e.g. "Aktif".
class Pill extends StatelessWidget {
  const Pill(this.label, {super.key, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color ?? palette.accentTint,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color == null ? palette.accentText : palette.textPrimary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class ProgressBar extends StatelessWidget {
  const ProgressBar({super.key, required this.value, this.color, this.height = 8});

  final double value;
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: value.clamp(0.0, 1.0).toDouble()),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        builder: (context, animated, _) => LinearProgressIndicator(
          value: animated,
          minHeight: height,
          color: color,
          backgroundColor: context.palette.fill,
        ),
      ),
    );
  }
}

/// Apple's sliding segmented control, stretched to the available width.
class AppleSegmented<T extends Object> extends StatelessWidget {
  const AppleSegmented({
    super.key,
    required this.value,
    required this.segments,
    required this.onChanged,
  });

  final T value;
  final Map<T, String> segments;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(color: palette.textPrimary);
    return SizedBox(
      width: double.infinity,
      child: CupertinoSlidingSegmentedControl<T>(
        groupValue: value,
        backgroundColor: palette.fill,
        thumbColor: palette.brightness == Brightness.dark
            ? const Color(0xFF636366)
            : const Color(0xFFFFFFFF),
        padding: const EdgeInsets.all(3),
        onValueChanged: (selected) {
          if (selected != null) onChanged(selected);
        },
        children: {
          for (final entry in segments.entries)
            entry.key: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
              child: Text(
                entry.value,
                style: style,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        },
      ),
    );
  }
}

/// Keyboard shortcut hint such as "⌥1", drawn as a small key cap.
class KbdHint extends StatelessWidget {
  const KbdHint(this.label, {super.key});

  final String label;

  /// "⌥" on a Mac, "Alt+" elsewhere.
  static String alt(String key) =>
      defaultTargetPlatform == TargetPlatform.macOS ? '⌥$key' : 'Alt+$key';

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: palette.textSecondary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: palette.textSecondary.withValues(alpha: 0.2), width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: 10.5,
          fontWeight: FontWeight.w500,
          color: palette.textSecondary,
        ),
      ),
    );
  }
}

/// Rounded-square app mark used in the sidebar, splash and welcome page.
class AppMark extends StatelessWidget {
  const AppMark({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.23),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF34C759), Color(0xFF0A84FF)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: size * 0.2,
            offset: Offset(0, size * 0.05),
          ),
        ],
      ),
      child: Icon(Icons.fitness_center_rounded, color: Colors.white, size: size * 0.55),
    );
  }
}
