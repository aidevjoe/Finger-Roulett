import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';

class FingerRoulettePage extends StatefulWidget {
  const FingerRoulettePage({super.key});

  @override
  State<FingerRoulettePage> createState() => _FingerRoulettePageState();
}

class _FingerRoulettePageState extends State<FingerRoulettePage>
    with TickerProviderStateMixin {
  static const double _fingerCircleSize = 100.0;
  static const int _countdownDuration = 3;
  static const int _selectionDuration = 8;
  static const int _cyclesPerPlayer = 10;

  final Random _random = Random();
  final Map<int, Offset> _fingerPositions = {};
  final Map<int, Offset> _lastPositions = {};
  final List<Color> _playerColors = [];

  bool _isGameStarted = false;
  int _selectedFingerId = -1;
  int _countdown = _countdownDuration;
  Timer? _countdownTimer;
  bool _isCountingDown = false;
  int _currentHighlightedPlayer = 0;

  late AnimationController _pulseController;
  late AnimationController _selectionController;
  late Animation<double> _selectionAnimation;
  late AnimationController _winnerController;
  late AnimationController _highlightController;
  late AnimationController _rippleController;
  late Animation<double> _rippleAnimation;

  bool _hasVibrator = false;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _checkVibrationCapability();
  }

  Future<void> _checkVibrationCapability() async {
    _hasVibrator = await Vibration.hasVibrator() ?? false;
  }

  void _initializeControllers() {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _selectionController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: _selectionDuration),
    );

    _selectionAnimation = CurvedAnimation(
      parent: _selectionController,
      curve: Curves.easeInOutCubic,
    );

    _winnerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);

    _highlightController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _rippleAnimation = Tween<double>(begin: 1.0, end: 1.5).animate(
      CurvedAnimation(parent: _rippleController, curve: Curves.easeOut),
    );
  }

  void _vibrate({int duration = 200, int amplitude = 128}) {
    if (_hasVibrator) {
      Vibration.vibrate(duration: duration, amplitude: amplitude);
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pulseController.dispose();
    _selectionController.dispose();
    _winnerController.dispose();
    _highlightController.dispose();
    _rippleController.dispose();
    super.dispose();
  }

  void _updateFingerPosition(int id, Offset position) {
    if (!_isGameStarted) {
      setState(() {
        _fingerPositions[id] = position;
        _lastPositions[id] = position;
        if (_playerColors.length < _fingerPositions.length) {
          _playerColors
              .add(Colors.primaries[_random.nextInt(Colors.primaries.length)]);
        }
      });
      _checkGameStart();
    }
  }

  void _removeFingerPosition(int id) {
    if (!_isGameStarted) {
      setState(() {
        _fingerPositions.remove(id);
        _lastPositions.remove(id);
        if (_fingerPositions.isEmpty) {
          _playerColors.clear();
        }
      });
      if (_fingerPositions.length < 2) {
        _resetCountdown();
      }
    }
  }

  void _checkGameStart() {
    if (!_isGameStarted && _fingerPositions.length >= 2 && !_isCountingDown) {
      _startCountdown();
    }
  }

  void _startCountdown() {
    if (_isCountingDown) return;
    _isCountingDown = true;
    _countdown = _countdownDuration;
    _rippleController.forward(from: 0.0);
    _vibrate(duration: 100);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_fingerPositions.length >= 2) {
        setState(() {
          if (_countdown > 1) {
            _countdown--;
            _rippleController.forward(from: 0.0);
            _vibrate(duration: 100);
          } else {
            _startGame();
            timer.cancel();
          }
        });
      } else {
        _resetCountdown();
        timer.cancel();
      }
    });
  }

  void _resetCountdown() {
    _countdownTimer?.cancel();
    setState(() {
      _countdown = _countdownDuration;
      _isCountingDown = false;
    });
  }

  void _startGame() {
    setState(() {
      _isGameStarted = true;
      _isCountingDown = false;
      _countdown = 0;
    });
    _vibrate(duration: 300, amplitude: 255);
    _startWheelAnimation();
  }

  void _startWheelAnimation() {
    _selectionController.reset();
    _currentHighlightedPlayer = 0;
    int totalPlayers = _lastPositions.length;
    int lastHighlightedPlayer = -1;

    _selectionAnimation.addListener(() {
      double t = _selectionAnimation.value;
      int totalCycles = _cyclesPerPlayer * totalPlayers;
      int currentCycle = (t * totalCycles).floor();
      int newHighlightedPlayer = currentCycle % totalPlayers;
      setState(() {
        _currentHighlightedPlayer = currentCycle % totalPlayers;
      });

      // Vibrate only when a new player is highlighted
      if (newHighlightedPlayer != lastHighlightedPlayer) {
        _vibrate(duration: 50, amplitude: 128);
        lastHighlightedPlayer = newHighlightedPlayer;
      }
    });

    _selectionController.forward().then((_) {
      _selectWinner();
    });
  }

  void _selectWinner() {
    if (_lastPositions.isNotEmpty) {
      setState(() {
        int winnerIndex = _random.nextInt(_lastPositions.length);
        _selectedFingerId = _lastPositions.keys.elementAt(winnerIndex);
        _currentHighlightedPlayer = winnerIndex;
      });
      _winnerController.forward(from: 0.0);
      _vibrate(duration: 500, amplitude: 255);
    } else {
      _resetGame();
    }
  }

  void _resetGame() {
    _countdownTimer?.cancel();
    _selectionController.reset();
    _winnerController.reset();
    setState(() {
      _isGameStarted = false;
      _isCountingDown = false;
      _selectedFingerId = -1;
      _countdown = _countdownDuration;
      _lastPositions.clear();
      _fingerPositions.clear();
      _playerColors.clear();
      _currentHighlightedPlayer = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
          centerTitle: true,
          iconTheme: Theme.of(context).iconTheme.copyWith(color: Colors.white),
          foregroundColor: Colors.white,
          backgroundColor: Colors.transparent,
          title: const Text("Tap Roulette")),
      body: _buildGameArea(),
    );
  }

  Widget _buildGameArea() {
    return Stack(
      children: [
        _buildBackground(),
        Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (event) =>
              _updateFingerPosition(event.pointer, event.localPosition),
          onPointerMove: (event) =>
              _updateFingerPosition(event.pointer, event.localPosition),
          onPointerUp: (event) => _removeFingerPosition(event.pointer),
          onPointerCancel: (event) => _removeFingerPosition(event.pointer),
          child: Stack(
            children: [
              Center(child: _buildGameStatusText()),
              ..._buildFingerCircles(),
              if (_selectedFingerId != -1) _buildWinnerOverlay(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBackground() {
    return CustomPaint(
      painter: BackgroundPainter(),
      child: Container(),
    );
  }

  Widget _buildGameStatusText() {
    String text = _isGameStarted
        ? ''
        : _isCountingDown
            ? '$_countdown'
            : "Place at least two fingers on the screen";

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Transform.scale(
          scale: 1.0 + (_pulseController.value * 0.1),
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
        );
      },
    );
  }

  List<Widget> _buildFingerCircles() {
    final positions = _isGameStarted ? _lastPositions : _fingerPositions;
    return positions.entries.map((entry) {
      int index = positions.keys.toList().indexOf(entry.key);
      Offset position = entry.value;
      Color circleColor = _playerColors[index];
      bool isHighlighted = _isGameStarted && index == _currentHighlightedPlayer;

      return Positioned(
        left: position.dx - _fingerCircleSize / 2,
        top: position.dy - _fingerCircleSize / 2,
        child: AnimatedBuilder(
          animation: _selectionAnimation,
          builder: (context, child) {
            return _buildPlayerCircle(entry.key, circleColor, isHighlighted);
          },
        ),
      );
    }).toList();
  }

  Widget _buildPlayerCircle(int id, Color color, bool isHighlighted) {
    return AnimatedBuilder(
      animation: _rippleAnimation,
      builder: (context, child) {
        double rippleScale = _isCountingDown ? _rippleAnimation.value : 1.0;
        return TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 1.0, end: isHighlighted ? 1.2 : 1.0),
          duration: const Duration(milliseconds: 100),
          builder: (context, scale, child) {
            return Transform.scale(
              scale: scale * rippleScale,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer ripple
                  Container(
                    width: _fingerCircleSize,
                    height: _fingerCircleSize,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.3 / rippleScale),
                      shape: BoxShape.circle,
                    ),
                  ),
                  // Middle ripple
                  Container(
                    width: _fingerCircleSize * 0.8,
                    height: _fingerCircleSize * 0.8,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.5 / rippleScale),
                      shape: BoxShape.circle,
                    ),
                  ),
                  // Inner circle
                  Container(
                    width: _fingerCircleSize * 0.6,
                    height: _fingerCircleSize * 0.6,
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          color,
                          color.withOpacity(0.7),
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${_lastPositions.keys.toList().indexOf(id) + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildWinnerOverlay() {
    return AnimatedBuilder(
      animation: _winnerController,
      builder: (context, child) {
        return Container(
          color: Colors.black.withOpacity(0.7 * _winnerController.value),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Player ${_lastPositions.keys.toList().indexOf(_selectedFingerId) + 1} Wins!",
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _resetGame,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text("Start New Round",
                      style: TextStyle(fontSize: 18)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class BackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.blue.shade900,
          Colors.purple.shade900,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    // Draw some decorative circles
    final circlePaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (int i = 0; i < 5; i++) {
      double radius = (size.width - 30) * (0.1 + i * 0.1);
      canvas.drawCircle(
          Offset(size.width / 2, size.height / 2), radius, circlePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
