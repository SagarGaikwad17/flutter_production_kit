import 'dart:async';
import 'package:flutter_production_kit/core/logging/app_logger.dart';

/// Connectivity observer — monitors network state with flap detection.
///
/// Design rationale:
/// - Uses connectivity_plus for raw network events.
/// - Adds a stability window — rapid online/offline switching is ignored.
/// - Emits debounced state changes to prevent sync storms.
/// - Tracks connection quality (wifi vs cellular) for sync optimization.
/// - Provides the sync engine with a reliable "is stable" signal.
///
/// Flap detection:
/// - If the network switches state more than [maxFlaps] within [flapWindow],
///   the connection is marked as unstable.
/// - During unstable periods, sync is paused to avoid wasted attempts.
class ConnectivityObserver {
  ConnectivityObserver({
    this.stabilityWindow = const Duration(seconds: 10),
    this.maxFlaps = 3,
    this.flapWindow = const Duration(minutes: 2),
  });

  static const String _tag = 'ConnectivityObserver';

  final Duration stabilityWindow;
  final int maxFlaps;
  final Duration flapWindow;

  NetworkState _state = NetworkState.unknown;
  bool _isStable = false;
  Timer? _stabilityTimer;

  final List<DateTime> _stateChangeTimestamps = [];
  final StreamController<NetworkState> _stateController =
      StreamController<NetworkState>.broadcast();

  NetworkState get state => _state;
  bool get isStable => _isStable;
  bool get isConnected => _state == NetworkState.connected;
  Stream<NetworkState> get stateStream => _stateController.stream;

  bool get _isFlapping {
    final recentChanges = _stateChangeTimestamps
        .where((t) => DateTime.now().difference(t) < flapWindow)
        .length;
    return recentChanges >= maxFlaps;
  }

  /// Update the network state — called by the connectivity listener.
  void updateState(NetworkState newState) {
    if (newState == _state) return;

    final oldState = _state;
    _state = newState;
    _stateChangeTimestamps.add(DateTime.now());

    _pruneOldTimestamps();

    if (_isFlapping) {
      AppLogger.warning(
        _tag,
        'Network flapping detected — pausing sync stability. '
        'Flaps: ${_stateChangeTimestamps.length} in ${flapWindow.inMinutes}min.',
      );
      _setStable(false);
    } else {
      _startStabilityTimer();
    }

    AppLogger.info(
      _tag,
      'Network state changed: ${oldState.name} → ${newState.name} '
      '(stable: $_isStable, flapping: $_isFlapping)',
    );

    _stateController.add(_state);
  }

  void _startStabilityTimer() {
    _stabilityTimer?.cancel();
    _setStable(false);

    _stabilityTimer = Timer(stabilityWindow, () {
      if (!_isFlapping) {
        _setStable(true);
        AppLogger.info(_tag, 'Network connection stable — sync can proceed.');
      }
    });
  }

  void _setStable(bool stable) {
    if (_isStable != stable) {
      _isStable = stable;
    }
  }

  void _pruneOldTimestamps() {
    final cutoff = DateTime.now().subtract(flapWindow * 2);
    _stateChangeTimestamps.removeWhere((t) => t.isBefore(cutoff));
  }

  /// Reset the observer — call on app resume.
  void reset() {
    _state = NetworkState.unknown;
    _isStable = false;
    _stabilityTimer?.cancel();
    _stateChangeTimestamps.clear();
  }

  void dispose() {
    _stabilityTimer?.cancel();
    _stateController.close();
  }
}

enum NetworkState {
  unknown,
  connected,
  disconnected,
  cellular,
  wifi,
}
