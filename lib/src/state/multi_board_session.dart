/// Lobby-to-match lifecycle shared by networked Bughouse and four-player.
sealed class MultiBoardSession {
  const MultiBoardSession();
}

class MbIdle extends MultiBoardSession {
  const MbIdle();
}

/// Hosting or joined, waiting for the host to start.
class MbLobby extends MultiBoardSession {
  const MbLobby();
}

class MbPlaying extends MultiBoardSession {
  const MbPlaying();
}

/// The host declared a result; it is final.
class MbFinished extends MultiBoardSession {
  const MbFinished();
}

/// The link dropped before a result. [afterStart] tells the match screen it
/// must show "disconnected" instead of a frozen board.
class MbLost extends MultiBoardSession {
  final bool afterStart;
  const MbLost({required this.afterStart});
}

sealed class MbEvent {
  const MbEvent();
}

class MbOpened extends MbEvent {
  const MbOpened();
}

class MbStarted extends MbEvent {
  const MbStarted();
}

class MbResult extends MbEvent {
  const MbResult();
}

class MbLinkClosed extends MbEvent {
  const MbLinkClosed();
}

class MbLeft extends MbEvent {
  const MbLeft();
}

MultiBoardSession reduceMultiBoard(MultiBoardSession s, MbEvent e) =>
    switch ((s, e)) {
      (_, MbLeft()) => const MbIdle(),
      (_, MbOpened()) => const MbLobby(),
      (MbLobby(), MbStarted()) => const MbPlaying(),
      (MbPlaying(), MbResult()) => const MbFinished(),
      (MbLobby(), MbLinkClosed()) => const MbLost(afterStart: false),
      (MbPlaying(), MbLinkClosed()) => const MbLost(afterStart: true),
      _ => s, // a result or a closed link after the end changes nothing
    };

/// Whether the match screen should be (or stay) open for this session.
bool matchStarted(MultiBoardSession s) => switch (s) {
  MbPlaying() || MbFinished() => true,
  MbLost(:final afterStart) => afterStart,
  _ => false,
};
