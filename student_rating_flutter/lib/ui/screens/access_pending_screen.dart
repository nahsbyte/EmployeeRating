import 'package:flutter/material.dart';

import '../widgets/app_surface.dart';

class AccessPendingScreen extends StatelessWidget {
  const AccessPendingScreen({
    super.key,
    required this.onSignOut,
    required this.signingOut,
    this.role,
  });

  final VoidCallback onSignOut;
  final bool signingOut;
  final String? role;

  @override
  Widget build(BuildContext context) {
    final roleText = (role != null && role!.trim().isNotEmpty) ? role : '-';
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        safeTop: true,
        safeBottom: true,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F7),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Akses belum aktif',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1C1C1E),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Role akun belum ditemukan atau belum valid. '
                    'Hubungi super admin untuk assign role di tabel profiles.',
                    style: TextStyle(
                      color: Colors.black.withValues(alpha: 0.68),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: Text(
                      'Role saat ini: $roleText',
                      style: const TextStyle(
                        color: Color(0xFF1C1C1E),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: signingOut ? null : onSignOut,
                      child: signingOut
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Logout',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
