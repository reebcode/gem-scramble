import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../models/match.dart';
import '../components/animated_button.dart';
import 'lobby_screen.dart';

class ResultsScreen extends StatefulWidget {
  final Match match;

  const ResultsScreen({
    super.key,
    required this.match,
  });

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen>
    with TickerProviderStateMixin {
  
  late AnimationController _slideController;
  late AnimationController _coinController;
  late AnimationController _confettiController;
  
  late Animation<Offset> _slideAnimation;
  late Animation<double> _coinAnimation;
  late Animation<double> _confettiAnimation;
  
  bool _showConfetti = false;

  @override
  void initState() {
    super.initState();
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _coinController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _confettiController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.elasticOut,
    ));
    
    _coinAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _coinController,
      curve: Curves.easeInOut,
    ));
    
    _confettiAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _confettiController,
      curve: Curves.easeInOut,
    ));
    
    _startAnimations();
  }

  void _startAnimations() {
    _slideController.forward();
    
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _coinController.forward();
      }
    });
    
    if (widget.match.isWinner) {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          setState(() {
            _showConfetti = true;
          });
          _confettiController.forward();
        }
      });
    }
  }

  @override
  void dispose() {
    _slideController.dispose();
    _coinController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF2A2A2A),
                  Color(0xFF1A1A1A),
                ],
              ),
            ),
          ),
          
          // Confetti animation
          if (_showConfetti)
            AnimatedBuilder(
              animation: _confettiAnimation,
              builder: (context, child) {
                return Opacity(
                  opacity: _confettiAnimation.value,
                  child: _buildConfetti(),
                );
              },
            ),
          
          // Main content
          SafeArea(
            child: SlideTransition(
              position: _slideAnimation,
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  
                  // Result banner
                  _buildResultBanner(),
                  
                  const SizedBox(height: 40),
                  
                  // Score comparison
                  _buildScoreComparison(),
                  
                  const SizedBox(height: 40),
                  
                  // Words found
                  _buildWordsSection(),
                  
                  const Spacer(),
                  
                  // Prize section
                  if (widget.match.myPrize > 0)
                    AnimatedBuilder(
                      animation: _coinAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _coinAnimation.value,
                          child: _buildPrizeSection(),
                        );
                      },
                    ),
                  
                  const SizedBox(height: 40),
                  
                  // Action buttons
                  _buildActionButtons(),
                  
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultBanner() {
    final isWinner = widget.match.isWinner;
    final isDraw = widget.match.isDraw;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isWinner 
            ? Colors.green.withAlpha(51)
            : isDraw 
                ? Colors.orange.withAlpha(51)
                : Colors.red.withAlpha(51),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isWinner 
              ? Colors.green
              : isDraw 
                  ? Colors.orange
                  : Colors.red,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Icon(
            isWinner 
                ? Icons.emoji_events
                : isDraw 
                    ? Icons.handshake
                    : Icons.sentiment_dissatisfied,
            size: 64,
            color: isWinner 
                ? Colors.amber
                : isDraw 
                    ? Colors.orange
                    : Colors.red,
          ),
          const SizedBox(height: 16),
          Text(
            isWinner 
                ? 'YOU WON!'
                : isDraw 
                    ? 'DRAW!'
                    : 'YOU LOST',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: isWinner 
                  ? Colors.green
                  : isDraw 
                      ? Colors.orange
                      : Colors.red,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Congratulations!',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreComparison() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text(
            'Final Scores',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildPlayerScore(
                  'You',
                  widget.match.myScore,
                  true,
                ),
              ),
              const Text(
                'VS',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              Expanded(
                child: _buildPlayerScore(
                  widget.match.opponentUsername,
                  widget.match.opponentScore,
                  false,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerScore(String name, int score, bool isMe) {
    return Column(
      children: [
        Text(
          name,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isMe ? const Color(0xFFFFD700) : Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isMe ? const Color(0xFFFFD700) : Colors.grey,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            score.toString(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isMe ? Colors.black : Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWordsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Words Found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Words (${widget.match.myWords.length})',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFFFFD700),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: widget.match.myWords.map((word) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withAlpha(51),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.green.withAlpha(128),
                            ),
                          ),
                          child: Text(
                            word.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.green,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Opponent\'s Words (${widget.match.opponentWords.length})',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: widget.match.opponentWords.map((word) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.withAlpha(51),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.blue.withAlpha(128),
                            ),
                          ),
                          child: Text(
                            word.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.blue,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPrizeSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.green.withAlpha(51),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.green,
          width: 2,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.monetization_on,
            color: Colors.amber,
            size: 32,
          ),
          const SizedBox(width: 12),
          Column(
            children: [
              const Text(
                'Prize Earned',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
              ),
              Text(
                '\$${(widget.match.myPrize / 100).toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          AnimatedButton(
            text: 'Play Again',
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) => const LobbyScreen(),
                ),
                (route) => false,
              );
            },
            backgroundColor: const Color(0xFFFFD700),
            width: double.infinity,
          ),
          const SizedBox(height: 12),
          AnimatedButton(
            text: 'Back to Lobby',
            onPressed: () {
              Navigator.of(context).pop();
            },
            backgroundColor: Colors.grey,
            textColor: Colors.white,
            width: double.infinity,
          ),
        ],
      ),
    );
  }

  Widget _buildConfetti() {
    return Positioned.fill(
      child: IgnorePointer(
        child: Lottie.asset(
          'assets/animations/confetti.json',
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
