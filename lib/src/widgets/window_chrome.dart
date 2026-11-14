import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:open_chess/l10n/app_localizations.dart';

/// Desktop builds draw their own window bar: the runners open an undecorated
/// window and this file supplies the move/resize/minimise/maximise/close
/// controls through the `open_chess/window` channel. Android is untouched.
///
/// Off under `flutter test` so existing screen tests keep the plain AppBar;
/// window-bar tests switch it on explicitly.
bool desktopChrome =
    !kIsWeb &&
    (Platform.isLinux || Platform.isWindows) &&
    !Platform.environment.containsKey('FLUTTER_TEST');

const _channel = MethodChannel('open_chess/window');

/// Height of the merged bar on desktop (the AppBar's own row).
const double kWindowBarHeight = 48;

/// Window state pushed by the runner: [maximized] drives the restore icon,
/// [framed] (not maximised, tiled or full-screen) enables edge resizing.
class WindowState {
  final bool maximized;
  final bool framed;
  const WindowState({this.maximized = false, this.framed = true});
}

final windowState = ValueNotifier(const WindowState());

/// Listen for state changes from the runner. Call once before `runApp`.
void initWindowChrome() {
  if (!desktopChrome) return;
  _channel.setMethodCallHandler((call) async {
    if (call.method == 'state') {
      final m = call.arguments as Map;
      windowState.value = WindowState(
        maximized: m['maximized'] == true,
        framed: m['framed'] != false,
      );
    }
  });
}

Future<void> _send(String method, [Object? args]) async {
  try {
    await _channel.invokeMethod<void>(method, args);
  } on MissingPluginException {
    // A runner without the channel (or a test): nothing to move.
  }
}

/// [edge] uses GdkWindowEdge numbering: 0 NW, 1 N, 2 NE, 3 W, 4 E, 5 SW, 6 S, 7 SE.
void startWindowResize(int edge) => _send('startResize', edge);
void startWindowDrag() => _send('startDrag');
void toggleWindowMaximize() => _send('toggleMaximize');
void minimizeWindow() => _send('minimize');

/// Same path as the system close button: the window gets a normal close
/// request, so the app's existing exit handling runs unchanged.
void closeWindow() => _send('close');

/// The app's screen header, merged with the window bar on desktop: one row
/// with the back button, title, optional state of play in the middle, the
/// screen's actions and the window buttons. On other platforms it is exactly
/// the plain [AppBar] it replaces.
class WindowAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget title;
  final List<Widget> actions;

  /// What the middle of the bar shows (the state of play), if anything.
  final Widget? center;

  const WindowAppBar({
    super.key,
    required this.title,
    this.actions = const [],
    this.center,
  });

  @override
  Size get preferredSize =>
      Size.fromHeight(desktopChrome ? kWindowBarHeight : kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    if (!desktopChrome) {
      return AppBar(title: title, actions: actions);
    }
    final c = center;
    return AppBar(
      toolbarHeight: kWindowBarHeight,
      // Hits on the title and empty space fall through to the drag area.
      title: IgnorePointer(
        child: Row(
          children: [
            Expanded(
              child: DefaultTextStyle.merge(
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                child: title,
              ),
            ),
            if (c != null) ...[
              Flexible(
                flex: 0,
                child: FittedBox(fit: BoxFit.scaleDown, child: c),
              ),
              const Expanded(child: SizedBox()),
            ],
          ],
        ),
      ),
      flexibleSpace: const _DragArea(),
      // In the route's own row so Tab reaches them after the screen's actions.
      actions: [
        ...actions,
        const SizedBox(width: 8),
        ValueListenableBuilder(
          valueListenable: windowState,
          builder: (context, state, _) =>
              WindowButtons(maximized: state.maximized),
        ),
      ],
    );
  }
}

class _DragArea extends StatelessWidget {
  const _DragArea();

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (_) => startWindowDrag(),
      onDoubleTap: toggleWindowMaximize,
    ),
  );
}

/// Wraps the whole app on desktop with the resize edges (while the window
/// is neither maximised, tiled nor full-screen).
class WindowFrame extends StatelessWidget {
  final Widget child;
  const WindowFrame({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!desktopChrome) return child;
    return ValueListenableBuilder(
      valueListenable: windowState,
      builder: (context, state, child) =>
          Stack(children: [child!, if (state.framed) ..._resizeEdges()]),
      child: child,
    );
  }
}

List<Widget> _resizeEdges() {
  const t = 5.0; // edge thickness
  const k = 12.0; // corner size
  Widget edge(int e, MouseCursor cursor) => MouseRegion(
    cursor: cursor,
    child: Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => startWindowResize(e),
    ),
  );
  return [
    Positioned(
      left: k,
      right: k,
      top: 0,
      height: t,
      child: edge(1, SystemMouseCursors.resizeUp),
    ),
    Positioned(
      left: k,
      right: k,
      bottom: 0,
      height: t,
      child: edge(6, SystemMouseCursors.resizeDown),
    ),
    Positioned(
      top: k,
      bottom: k,
      left: 0,
      width: t,
      child: edge(3, SystemMouseCursors.resizeLeft),
    ),
    Positioned(
      top: k,
      bottom: k,
      right: 0,
      width: t,
      child: edge(4, SystemMouseCursors.resizeRight),
    ),
    Positioned(
      left: 0,
      top: 0,
      width: k,
      height: k,
      child: edge(0, SystemMouseCursors.resizeUpLeft),
    ),
    Positioned(
      right: 0,
      top: 0,
      width: k,
      height: k,
      child: edge(2, SystemMouseCursors.resizeUpRight),
    ),
    Positioned(
      left: 0,
      bottom: 0,
      width: k,
      height: k,
      child: edge(5, SystemMouseCursors.resizeDownLeft),
    ),
    Positioned(
      right: 0,
      bottom: 0,
      width: k,
      height: k,
      child: edge(7, SystemMouseCursors.resizeDownRight),
    ),
  ];
}

/// Minimise, maximise/restore and close, in the app's own button style.
class WindowButtons extends StatelessWidget {
  final bool maximized;
  const WindowButtons({super.key, required this.maximized});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    ButtonStyle style({bool close = false}) =>
        IconButton.styleFrom(
          minimumSize: const Size(40, 32),
          fixedSize: const Size(40, 32),
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          foregroundColor: cs.onSurfaceVariant,
        ).copyWith(
          foregroundColor: close
              ? WidgetStateProperty.resolveWith(
                  (s) => s.contains(WidgetState.hovered)
                      ? cs.onError
                      : cs.onSurfaceVariant,
                )
              : null,
          backgroundColor: close
              ? WidgetStateProperty.resolveWith(
                  (s) => s.contains(WidgetState.hovered) ? cs.error : null,
                )
              : null,
          // A clear ring for keyboard focus (the hover tint alone is faint).
          side: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.focused)
                ? BorderSide(color: cs.primary, width: 2)
                : BorderSide.none,
          ),
        );
    return Material(
      type: MaterialType.transparency,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(end: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: t.windowMinimize,
              style: style(),
              iconSize: 18,
              icon: const Icon(Icons.remove_rounded),
              onPressed: minimizeWindow,
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: maximized ? t.windowRestore : t.windowMaximize,
              style: style(),
              iconSize: 16,
              icon: Icon(
                maximized
                    ? Icons.filter_none_rounded
                    : Icons.crop_square_rounded,
              ),
              onPressed: toggleWindowMaximize,
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: t.close,
              style: style(close: true),
              iconSize: 18,
              icon: const Icon(Icons.close_rounded),
              onPressed: closeWindow,
            ),
          ],
        ),
      ),
    );
  }
}
