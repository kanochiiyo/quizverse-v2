import 'package:flutter/material.dart';
import 'package:quizverse/bottom_navbar.dart';
import 'package:quizverse/controllers/auth_controller.dart';
import 'package:quizverse/views/auth/register_view.dart';
import 'package:quizverse/services/notification_service.dart';
import 'package:geolocator/geolocator.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  // --- PERUBAHAN: Ganti ke _emailController ---
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthController _authController = AuthController();

  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _requestInitialPermissions();
    _checkLoginStatus();
  }

  @override
  void dispose() {
    _emailController
        .dispose(); // Pastikan dispose dipanggil untuk controller baru
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _requestInitialPermissions() async {
    try {
      await NotificationService().requestPermissions();
    } catch (e) {
      debugPrint("Gagal meminta izin notifikasi: $e");
    }

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint("Layanan lokasi mati, tidak meminta izin di awal.");
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint("Izin lokasi ditolak permanen oleh pengguna.");
      }
    } catch (e) {
      debugPrint("Gagal meminta izin lokasi di awal: $e");
    }
  }

  void _checkLoginStatus() async {
    setState(() {
      _isLoading = true;
    });
    try {
      bool loggedIn = await _authController.checkInitialLoginStatus();
      if (mounted) {
        if (loggedIn) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => BottomNavBar()),
          );
        } else {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Error checking login status: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Gagal memeriksa status login.";
        });
      }
    }
  }

  void _login() async {
    // --- PERUBAHAN: Validasi menggunakan _emailController ---
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.isEmpty) {
      setState(() {
        _errorMessage = "Email dan Password tidak boleh kosong!";
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // --- PERUBAHAN: Panggil login dengan parameter email ---
      await _authController.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => BottomNavBar()),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        // --- PERBAIKAN: Menangkap format error dari Controller ---
        _errorMessage = e.toString().contains('Exception:')
            ? e.toString().replaceFirst('Exception: ', '')
            : e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _goToRegister() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RegisterView()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoading &&
        // --- PERUBAHAN: Cek menggunakan _emailController ---
        _emailController.text.isEmpty &&
        _errorMessage == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: colorScheme.primary),
              const SizedBox(height: 15),
              const Text("Memeriksa status login..."),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.quiz, size: 80, color: colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                'Login',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              TextField(
                controller: _emailController, // --- PERUBAHAN ---
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: "Email", // --- PERUBAHAN: Label diganti ---
                  prefixIcon: Icon(Icons.email),
                ),
                enabled: !_isLoading,
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: "Password",
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
                enabled: !_isLoading,
              ),
              const SizedBox(height: 24),

              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: colorScheme.error, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),

              ElevatedButton(
                onPressed: _isLoading ? null : _login,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: Colors.white,
                        ),
                      )
                    : const Text("Login"),
              ),
              const SizedBox(height: 16),

              TextButton(
                onPressed: _isLoading ? null : _goToRegister,
                child: Text(
                  'Belum punya akun? Daftar di sini',
                  style: TextStyle(color: colorScheme.secondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
