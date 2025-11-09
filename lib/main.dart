import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

// Import native splash package
import 'package:flutter_native_splash/flutter_native_splash.dart';

// Import AuthWrapper
import 'package:ecommerce_app/screens/auth_wrapper.dart';
// Provider imports for cart state
import 'package:provider/provider.dart';
import 'package:ecommerce_app/providers/cart_provider.dart';
import 'collab/screens/collab_cart_screen.dart';
// Import the new professional theme
import 'package:ecommerce_app/theme/app_theme.dart';

void main() async {
  // Preserve the native splash until initialization is finished
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Run the app wrapped with our CartProvider
  runApp(
    ChangeNotifierProvider(
      create: (context) => CartProvider(),
      child: const MyApp(),
    ),
  );

  // Remove the native splash once the app is ready
  FlutterNativeSplash.remove();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'eCommerce App',
      
      // Use the new professional theme
      theme: AppTheme.lightTheme,

      home: const AuthWrapper(),
      routes: {
        '/collab-cart': (_) => const CollabCartScreen(),
      },
    );
  }
}
