import 'package:flutter/material.dart';

class TimerBar extends StatefulWidget {
  final int timeRemaining;
  final int totalTime;
  final Color? color;
  final Color? backgroundColor;

  const TimerBar({
    super.key,
    required this.timeRemaining,
    required this.totalTime,
    this.color,
    this.backgroundColor,
  });

  @override
  State<TimerBar> createState() => _TimerBarState();
}

class _TimerBarState extends State<TimerBar> {
  @override
  Widget build(BuildContext context) {
    final progress = widget.timeRemaining / widget.totalTime;
    final isLowTime = widget.timeRemaining <= 30;
    final isCriticalTime = widget.timeRemaining <= 10;
    
    Color timerColor = widget.color ?? const Color(0xFFFFD700);
    if (isCriticalTime) {
      timerColor = Colors.red;
    } else if (isLowTime) {
      timerColor = Colors.orange;
    }

    return Container(
      width: 200,
      height: 20,
      decoration: BoxDecoration(
        color: widget.backgroundColor ?? Colors.grey.withAlpha(77),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: timerColor.withAlpha(128),
          width: 1,
        ),
      ),
      child: Stack(
        children: [
          // Progress bar
          Container(
            width: 200 * progress,
            height: 20,
            decoration: BoxDecoration(
              color: timerColor,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          
          // Glow effect for low time
          if (isLowTime)
            Container(
              width: 200 * progress,
              height: 20,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: timerColor.withAlpha(153),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          
          // Time text
          Center(
            child: Text(
              _formatTime(widget.timeRemaining),
              style: TextStyle(
                color: isLowTime ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                shadows: isLowTime ? [
                  const Shadow(
                    color: Colors.black,
                    blurRadius: 2,
                  ),
                ] : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    
    if (minutes > 0) {
      return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
    } else {
      return remainingSeconds.toString();
    }
  }
}

class AnimatedTimerBar extends StatefulWidget {
  final int timeRemaining;
  final int totalTime;
  final VoidCallback? onTimeUp;
  final Color? color;
  final Color? backgroundColor;

  const AnimatedTimerBar({
    super.key,
    required this.timeRemaining,
    required this.totalTime,
    this.onTimeUp,
    this.color,
    this.backgroundColor,
  });

  @override
  State<AnimatedTimerBar> createState() => _AnimatedTimerBarState();
}

class _AnimatedTimerBarState extends State<AnimatedTimerBar> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  int _previousTime = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _previousTime = widget.timeRemaining;
  }

  @override
  void didUpdateWidget(AnimatedTimerBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.timeRemaining != oldWidget.timeRemaining) {
      _previousTime = oldWidget.timeRemaining;
      _controller.forward(from: 0.0);
      
      if (widget.timeRemaining == 0 && widget.onTimeUp != null) {
        Future.delayed(const Duration(milliseconds: 500), widget.onTimeUp!);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final animatedTime = (_previousTime + 
            (widget.timeRemaining - _previousTime) * _animation.value).round();
        
        return TimerBar(
          timeRemaining: animatedTime,
          totalTime: widget.totalTime,
          color: widget.color,
          backgroundColor: widget.backgroundColor,
        );
      },
    );
  }
}
