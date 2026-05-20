import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../repositories/sync_repository.dart';
import 'home_screen.dart';


class SyncingScreen extends StatefulWidget {
  const SyncingScreen({super.key});

  @override
  State<SyncingScreen> createState() => _SyncingScreenState();
}

class _SyncingScreenState extends State<SyncingScreen> {
  final List<String> _steps = [
    'Xác thực kết nối Cloud...',
    'Đang tải ghi chú từ Firestore...',
    'Đang khởi tạo cơ sở dữ liệu SQLite...',
    'Đang lưu dữ liệu cục bộ...',
    'Đồng bộ hóa hoàn tất!'
  ];

  int _currentStep = 0;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _startRealSync();
  }

  Future<void> _updateStep(int step) async {
    if (!mounted) return;
    setState(() {
      _currentStep = step;
      _progress = (step + 1) / _steps.length;
    });
    await Future.delayed(const Duration(milliseconds: 800));
  }

  void _startRealSync() async {
    try {
      final syncRepo = context.read<SyncRepository>();
      
      await _updateStep(0);
      await _updateStep(1);
      
      // Pull data from cloud
      await syncRepo.pullFromCloud();
      
      await _updateStep(2);
      await _updateStep(3);
      await _updateStep(4);
      
      if (!mounted) return;
      
      // Navigate to Home
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const HomeScreen(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 800),
        ),
      );
    } catch (e) {
      debugPrint('Sync error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi đồng bộ: $e. Tiếp tục vào Home.')),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A3A5C), Color(0xFF2E75B6), Color(0xFF0D47A1)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.sync_rounded, size: 80, color: Colors.white),
                const SizedBox(height: 32),
                Text(
                  'Đang đồng bộ dữ liệu',
                  style: GoogleFonts.roboto(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Vui lòng chờ trong giây lát...',
                  style: GoogleFonts.roboto(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 60),
                Stack(
                  children: [
                    Container(
                      height: 8,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      height: 8,
                      width: MediaQuery.of(context).size.width * 0.8 * _progress,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF64B5F6), Color(0xFF2196F3)],
                        ),
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withValues(alpha: 0.5),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                SizedBox(
                  height: 200,
                  child: ListView.builder(
                    itemCount: _steps.length,
                    physics: const NeverScrollableScrollPhysics(),
                    itemBuilder: (context, index) {
                      final isActive = index <= _currentStep;
                      final isCurrent = index == _currentStep;
                      
                      return AnimatedOpacity(
                        duration: const Duration(milliseconds: 300),
                        opacity: isActive ? 1.0 : 0.3,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              if (index < _currentStep)
                                const Icon(Icons.check_circle, color: Colors.greenAccent, size: 20)
                              else if (isCurrent)
                                const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(Colors.white),
                                  ),
                                )
                              else
                                const Icon(Icons.circle_outlined, color: Colors.white, size: 20),
                              const SizedBox(width: 16),
                              Text(
                                _steps[index],
                                style: GoogleFonts.roboto(
                                  color: Colors.white,
                                  fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
