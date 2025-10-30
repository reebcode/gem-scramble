import 'package:flutter/material.dart';

class AnimatedButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? textColor;
  final IconData? icon;
  final bool isLoading;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final List<BoxShadow>? boxShadow;
  final Duration animationDuration;

  const AnimatedButton({
    super.key,
    required this.text,
    this.onPressed,
    this.backgroundColor,
    this.textColor,
    this.icon,
    this.isLoading = false,
    this.width,
    this.height,
    this.padding,
    this.borderRadius,
    this.boxShadow,
    this.animationDuration = const Duration(milliseconds: 150),
  });

  @override
  State<AnimatedButton> createState() => _AnimatedButtonState();
}

class _AnimatedButtonState extends State<AnimatedButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.onPressed != null && !widget.isLoading) {
      setState(() {
        _isPressed = true;
      });
      _controller.forward();
    }
  }

  void _onTapUp(TapUpDetails details) {
    _onTapEnd();
  }

  void _onTapCancel() {
    _onTapEnd();
  }

  void _onTapEnd() {
    if (_isPressed) {
      setState(() {
        _isPressed = false;
      });
      _controller.reverse().then((_) {
        if (mounted && _isPressed) {
          widget.onPressed?.call();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onPressed != null && !widget.isLoading;
    
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
        child: Container(
          width: widget.width,
          height: widget.height ?? 48,
          padding: widget.padding ?? const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: isEnabled
                ? (widget.backgroundColor ?? const Color(0xFFFFD700))
                : Colors.grey,
            borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
            boxShadow: widget.boxShadow ?? [
              BoxShadow(
                color: (widget.backgroundColor ?? const Color(0xFFFFD700))
                    .withAlpha((255 * 0.3).round()),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.isLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                  ),
                )
              else if (widget.icon != null)
                Icon(
                  widget.icon,
                  color: widget.textColor ?? Colors.black,
                  size: 20,
                ),
              
              if (widget.isLoading || widget.icon != null)
                const SizedBox(width: 8),
              
              Text(
                widget.text,
                style: TextStyle(
                  color: widget.textColor ?? Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PulseButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final Color? color;
  final Duration pulseDuration;
  final bool isPulsing;

  const PulseButton({
    super.key,
    required this.text,
    this.onPressed,
    this.color,
    this.pulseDuration = const Duration(milliseconds: 1000),
    this.isPulsing = false,
  });

  @override
  State<PulseButton> createState() => _PulseButtonState();
}

class _PulseButtonState extends State<PulseButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.pulseDuration,
      vsync: this,
    );
    
    _animation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
    
    if (widget.isPulsing) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(PulseButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isPulsing != oldWidget.isPulsing) {
      if (widget.isPulsing) {
        _controller.repeat(reverse: true);
      } else {
        _controller.stop();
        _controller.reset();
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
        return Transform.scale(
          scale: _animation.value,
          child: child,
        );
      },
      child: AnimatedButton(
        text: widget.text,
        onPressed: widget.onPressed,
        backgroundColor: widget.color,
      ),
    );
  }
}

class ShakeButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final Color? color;
  final Duration shakeDuration;
  final bool shouldShake;

  const ShakeButton({
    super.key,
    required this.text,
    this.onPressed,
    this.color,
    this.shakeDuration = const Duration(milliseconds: 500),
    this.shouldShake = false,
  });

  @override
  State<ShakeButton> createState() => _ShakeButtonState();
}

class _ShakeButtonState extends State<ShakeButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.shakeDuration,
      vsync: this,
    );
    
    _animation = Tween<double>(
      begin: 0.0,
      end: 10.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticIn,
    ));
  }

  @override
  void didUpdateWidget(ShakeButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.shouldShake && !oldWidget.shouldShake) {
      _controller.forward().then((_) {
        _controller.reverse();
      });
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
        return Transform.translate(
          offset: Offset(_animation.value, 0),
          child: child,
        );
      },
      child: AnimatedButton(
        text: widget.text,
        onPressed: widget.onPressed,
        backgroundColor: widget.color,
      ),
    );
  }
}
