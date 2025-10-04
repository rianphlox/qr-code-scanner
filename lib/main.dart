import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gal/gal.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart' as mlkit;
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:convert';

// Custom blue color swatch
const MaterialColor customBlue = MaterialColor(
  0xFF0051AA,
  <int, Color>{
    50: Color(0xFFE3F2FD),
    100: Color(0xFFBBDEFB),
    200: Color(0xFF90CAF9),
    300: Color(0xFF64B5F6),
    400: Color(0xFF42A5F5),
    500: Color(0xFF0051AA),
    600: Color(0xFF1E88E5),
    700: Color(0xFF1976D2),
    800: Color(0xFF1565C0),
    900: Color(0xFF0D47A1),
  },
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HistoryManager.loadHistory();
  await ThemeManager().loadTheme();
  await ScanSettingsManager().loadSettings();
  runApp(MyApp());
}

// Scan Settings Manager
class ScanSettingsManager {
  static final ScanSettingsManager _instance = ScanSettingsManager._internal();
  factory ScanSettingsManager() => _instance;
  ScanSettingsManager._internal();

  bool _vibrationEnabled = false;
  bool _soundEnabled = true;

  bool get vibrationEnabled => _vibrationEnabled;
  bool get soundEnabled => _soundEnabled;

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _vibrationEnabled = prefs.getBool('vibrationEnabled') ?? false;
    _soundEnabled = prefs.getBool('soundEnabled') ?? true;
  }

  Future<void> setVibration(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    _vibrationEnabled = enabled;
    await prefs.setBool('vibrationEnabled', enabled);
  }

  Future<void> setSound(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    _soundEnabled = enabled;
    await prefs.setBool('soundEnabled', enabled);
  }

  Future<void> triggerScanFeedback() async {
    // Trigger vibration if enabled
    if (_vibrationEnabled) {
      HapticFeedback.heavyImpact();
    }

    // Trigger sound if enabled
    if (_soundEnabled) {
      HapticFeedback.lightImpact();
    }
  }
}

// Theme Manager
class ThemeManager extends ChangeNotifier {
  static final ThemeManager _instance = ThemeManager._internal();
  factory ThemeManager() => _instance;
  ThemeManager._internal();

  bool _isDarkMode = false;

  bool get isDarkMode => _isDarkMode;

  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    notifyListeners();
  }

  Future<void> setTheme(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = isDark;
    await prefs.setBool('isDarkMode', isDark);
    notifyListeners();
  }
}

// Enhanced History Manager with persistence
class HistoryManager {
  static List<Map<String, dynamic>> _history = [];
  
  static Future<void> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getStringList('qr_history') ?? [];
    
    _history = historyJson.map((item) {
      final Map<String, dynamic> data = json.decode(item);
      data['timestamp'] = DateTime.parse(data['timestamp']);
      data['icon'] = _getIconForType(data['type']);
      return data;
    }).toList();
  }
  
  static Future<void> saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = _history.map((item) {
      final Map<String, dynamic> data = Map.from(item);
      data['timestamp'] = data['timestamp'].toIso8601String();
      data.remove('icon'); // Don't save icon data
      return json.encode(data);
    }).toList();
    
    await prefs.setStringList('qr_history', historyJson);
  }
  
  static Future<void> addToHistory(String data, String type, String action) async {
    _history.insert(0, {
      'data': data,
      'type': type,
      'action': action, // 'scan' or 'create'
      'timestamp': DateTime.now(),
      'icon': _getIconForType(type),
    });
    
    // Keep only last 100 items
    if (_history.length > 100) {
      _history.removeRange(100, _history.length);
    }
    
    await saveHistory();
  }
  
  static List<Map<String, dynamic>> getHistory([String? filterAction]) {
    if (filterAction == null) {
      return List.from(_history);
    }
    return _history.where((item) => item['action'] == filterAction).toList();
  }
  
  static Future<void> clearHistory() async {
    _history.clear();
    await saveHistory();
  }
  
  static IconData _getIconForType(String type) {
    switch (type.toLowerCase()) {
      case 'url':
        return Icons.link;
      case 'email':
        return Icons.email;
      case 'wifi':
        return Icons.wifi;
      case 'contact':
        return Icons.contact_page;
      default:
        return Icons.text_snippet;
    }
  }
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final ThemeManager _themeManager = ThemeManager();

  @override
  void initState() {
    super.initState();
    _themeManager.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    _themeManager.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    setState(() {
      // Theme has changed, rebuild the app
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QScan',
      theme: ThemeData(
        primarySwatch: customBlue,
        fontFamily: 'SF Pro Display',
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        primarySwatch: customBlue,
        fontFamily: 'SF Pro Display',
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Color(0xFF2C2C2C),
        appBarTheme: AppBarTheme(
          backgroundColor: Color(0xFF2C2C2C),
          foregroundColor: Colors.white,
        ),
      ),
      themeMode: _themeManager.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: WelcomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// 1. Welcome/Onboarding Screen
class WelcomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ThemeManager themeManager = ThemeManager();
    final backgroundColor = themeManager.isDarkMode ? Color(0xFF2C2C2C) : Colors.white;
    final textColor = themeManager.isDarkMode ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Spacer(flex: 2),
              // QR Code Icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Color(0xFFE3F2FD),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.qr_code_scanner,
                  size: 60,
                  color: Color(0xFF0051AA),
                ),
              ),
              SizedBox(height: 40),
              
              // Title
              Text(
                'Welcome to QScan',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20),
              
              // Description
              Text(
                'Please give access your Camera so that we can scan and provide you what is the inside the code',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              
              Spacer(flex: 3),
              
              // Get Started Button
              Container(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => HomeScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF0051AA),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Let\'s Get Started',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

// 2. Home/Dashboard Screen
class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ThemeManager themeManager = ThemeManager();
    final backgroundColor = themeManager.isDarkMode ? Color(0xFF2C2C2C) : Colors.white;
    final textColor = themeManager.isDarkMode ? Colors.white : Colors.black;
    final cardColor = themeManager.isDarkMode ? Color(0xFF3C3C3C) : Colors.grey[50];

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        title: Text(
          'QScan',
          style: TextStyle(
            color: textColor,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.settings, color: Colors.grey[600]),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 20),
            
            // Quick Actions
            Row(
              children: [
                Expanded(
                  child: _buildActionCard(
                    context,
                    'Scan QR Code',
                    Icons.qr_code_scanner,
                    Color(0xFF0051AA),
                    () => Navigator.push(context, MaterialPageRoute(builder: (context) => ScannerScreen())),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: _buildActionCard(
                    context,
                    'Create QR Code',
                    Icons.qr_code,
                    Color(0xFF4CAF50),
                    () => Navigator.push(context, MaterialPageRoute(builder: (context) => CreatorScreen())),
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 32),
            
            // Recent Activity
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Activity',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => HistoryScreen()),
                    );
                  },
                  child: Text(
                    'View All',
                    style: TextStyle(
                      color: Color(0xFF0051AA),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 16),
            
            // Recent Items Preview
            Expanded(
              child: HistoryManager.getHistory().isEmpty 
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.history,
                          size: 64,
                          color: Colors.grey[300],
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No history yet',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[500],
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Scan or create QR codes to see them here',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[400],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: HistoryManager.getHistory().take(3).length,
                    itemBuilder: (context, index) {
                      final item = HistoryManager.getHistory()[index];
                      return _buildRecentItem(
                        item['type'],
                        item['data'].length > 30 
                          ? '${item['data'].substring(0, 30)}...'
                          : item['data'],
                        item['icon'],
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ResultScreen(
                                scannedData: item['data'],
                                dataType: item['type'],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, String title, IconData icon, Color color, VoidCallback onTap) {
    final ThemeManager themeManager = ThemeManager();
    final textColor = themeManager.isDarkMode ? Colors.white : Colors.black;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: color),
            SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentItem(String title, String subtitle, IconData icon, [VoidCallback? onTap]) {
    final ThemeManager themeManager = ThemeManager();
    final textColor = themeManager.isDarkMode ? Colors.white : Colors.black;
    final cardColor = themeManager.isDarkMode ? Color(0xFF3C3C3C) : Colors.grey[50];
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Color(0xFF0051AA).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Color(0xFF0051AA), size: 20),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}

// 3. Scanner Screen
class ScannerScreen extends StatefulWidget {
  @override
  _ScannerScreenState createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  MobileScannerController cameraController = MobileScannerController();
  bool isScanning = true;
  bool isProcessing = false; // Prevent multiple scans

  Future<void> _pickImageAndScan() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      
      if (image != null) {
        // Show loading while scanning
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                SizedBox(width: 16),
                Text('Reading QR code from image...'),
              ],
            ),
            duration: Duration(seconds: 3),
            backgroundColor: Color(0xFF0051AA),
          ),
        );
        
        // Create InputImage from the selected file
        final inputImage = mlkit.InputImage.fromFilePath(image.path);
        
        // Create barcode scanner
        final barcodeScanner = mlkit.BarcodeScanner();
        
        try {
          // Scan for barcodes in the image
          final List<mlkit.Barcode> barcodes = await barcodeScanner.processImage(inputImage);
          
          if (barcodes.isNotEmpty) {
            // Get the first QR code found
            final barcode = barcodes.first;
            if (barcode.rawValue != null && barcode.rawValue!.isNotEmpty) {
              // Successfully read QR code - process it
              _handleScanResult(barcode.rawValue!, _getDataType(barcode.rawValue!));
            } else {
              throw Exception('QR code is empty');
            }
          } else {
            // No QR code found in image
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.error, color: Colors.white),
                    SizedBox(width: 8),
                    Text('No QR code found in image'),
                  ],
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.error, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Error reading QR code: $e'),
                ],
              ),
              backgroundColor: Colors.red,
            ),
          );
        } finally {
          // Clean up
          await barcodeScanner.close();
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handleScanResult(String data, String type) async {
    if (isProcessing) return; // Prevent multiple scans

    setState(() {
      isProcessing = true;
    });

    // Trigger scan feedback (vibration and sound)
    await ScanSettingsManager().triggerScanFeedback();

    await HistoryManager.addToHistory(data, type, 'scan');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ResultScreen(
          scannedData: data,
          dataType: type,
        ),
      ),
    ).then((_) {
      // Reset processing flag when returning to scanner
      setState(() {
        isProcessing = false;
      });
    });
  }

  String _getDataType(String data) {
    // Clean the data
    final cleanData = data.trim().toLowerCase();
    
    // Check for complete URLs
    if (cleanData.startsWith('http://') || cleanData.startsWith('https://')) {
      return 'URL';
    }
    
    // Check for www.domain.com pattern
    if (cleanData.startsWith('www.') && cleanData.contains('.') && !cleanData.contains(' ')) {
      return 'URL';
    }
    
    // Check for domain.com pattern (simple domain names)
    final simpleDomainRegex = RegExp(r'^[a-zA-Z0-9-]+\.[a-zA-Z]{2,}$');
    if (simpleDomainRegex.hasMatch(cleanData)) {
      return 'URL';
    }
    
    // Check for subdomain.domain.com pattern
    final subdomainRegex = RegExp(r'^[a-zA-Z0-9-]+\.[a-zA-Z0-9-]+\.[a-zA-Z]{2,}$');
    if (subdomainRegex.hasMatch(cleanData)) {
      return 'URL';
    }
    
    // Check for email
    if (cleanData.contains('@') && cleanData.contains('.') && !cleanData.contains(' ')) {
      final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
      if (emailRegex.hasMatch(cleanData)) {
        return 'Email';
      }
    }
    
    // Check for WiFi
    if (cleanData.startsWith('wifi:')) {
      return 'WiFi';
    }
    
    // Check for phone numbers
    final phoneRegex = RegExp(r'^(\+|00)?[1-9]\d{1,14}$');
    if (phoneRegex.hasMatch(cleanData.replaceAll(RegExp(r'[\s\-\(\)]'), ''))) {
      return 'Phone';
    }
    
    return 'Text';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              color: ThemeManager().isDarkMode ? Color(0xFF2C2C2C) : Colors.white,
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.close, color: ThemeManager().isDarkMode ? Colors.white : Colors.black),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      'Scan QR code',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: ThemeManager().isDarkMode ? Colors.white : Colors.black,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.flash_off, color: Colors.grey),
                    onPressed: () {
                      cameraController.toggleTorch();
                    },
                  ),
                ],
              ),
            ),
            
            // Instructions
            Container(
              color: ThemeManager().isDarkMode ? Color(0xFF2C2C2C) : Colors.white,
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                'Place qr code inside the frame to scan please avoid shake to get results quickly',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            
            // Camera View
            Expanded(
              child: Stack(
                children: [
                  // Mobile Scanner
                  MobileScanner(
                    controller: cameraController,
                    onDetect: (capture) {
                      if (isProcessing) return; // Prevent multiple scans
                      
                      final List<Barcode> barcodes = capture.barcodes;
                      for (final barcode in barcodes) {
                        if (barcode.rawValue != null && barcode.rawValue!.isNotEmpty) {
                          _handleScanResult(
                            barcode.rawValue!,
                            _getDataType(barcode.rawValue!),
                          );
                          break;
                        }
                      }
                    },
                  ),
                  
                  // Overlay with scanning frame
                  Center(
                    child: Container(
                      width: 250,
                      height: 250,
                      decoration: BoxDecoration(
                        border: Border.all(color: Color(0xFF0051AA), width: 3),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Stack(
                        children: [
                          // Corner brackets
                          ...List.generate(4, (index) {
                            return Positioned(
                              top: index < 2 ? 0 : null,
                              bottom: index >= 2 ? 0 : null,
                              left: index % 2 == 0 ? 0 : null,
                              right: index % 2 == 1 ? 0 : null,
                              child: Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  border: Border(
                                    top: index < 2 ? BorderSide(color: Color(0xFF0051AA), width: 4) : BorderSide.none,
                                    bottom: index >= 2 ? BorderSide(color: Color(0xFF0051AA), width: 4) : BorderSide.none,
                                    left: index % 2 == 0 ? BorderSide(color: Color(0xFF0051AA), width: 4) : BorderSide.none,
                                    right: index % 2 == 1 ? BorderSide(color: Color(0xFF0051AA), width: 4) : BorderSide.none,
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Status
            Container(
              color: Colors.black,
              padding: EdgeInsets.all(16),
              child: Text(
                'Position QR code in frame',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            
            // Bottom Actions
            Container(
              color: ThemeManager().isDarkMode ? Color(0xFF2C2C2C) : Colors.white,
              padding: EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildBottomAction(Icons.photo_library, 'Gallery', _pickImageAndScan),
                  _buildBottomAction(Icons.flash_on, 'Flash', () {
                    cameraController.toggleTorch();
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomAction(IconData icon, String label, [VoidCallback? onTap]) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.grey[600]),
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }
}

// 4. Creator Screen - FIXED VERSION
class CreatorScreen extends StatefulWidget {
  @override
  _CreatorScreenState createState() => _CreatorScreenState();
}

class _CreatorScreenState extends State<CreatorScreen> {
  String selectedType = 'Text';
  TextEditingController textController = TextEditingController();

  final List<String> qrTypes = ['Text', 'URL', 'WiFi', 'Contact', 'Email'];

  @override
  Widget build(BuildContext context) {
    final ThemeManager themeManager = ThemeManager();
    final backgroundColor = themeManager.isDarkMode ? Color(0xFF2C2C2C) : Colors.white;
    final textColor = themeManager.isDarkMode ? Colors.white : Colors.black;
    final cardColor = themeManager.isDarkMode ? Color(0xFF3C3C3C) : Colors.grey[50];

    return Scaffold(
      backgroundColor: backgroundColor,
      resizeToAvoidBottomInset: true, // Ensure this is true
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        title: Text(
          'Create QR Code',
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView( // Wrap with SingleChildScrollView
        padding: EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, // Important: don't expand to full height
          children: [
            // QR Type Selector
            Text(
              'QR Code Type',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            SizedBox(height: 12),
            
            Container(
              height: 50,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: qrTypes.length,
                itemBuilder: (context, index) {
                  final type = qrTypes[index];
                  final isSelected = selectedType == type;
                  
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedType = type;
                      });
                    },
                    child: Container(
                      margin: EdgeInsets.only(right: 12),
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? Color(0xFF0051AA) : Colors.grey[100],
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Text(
                        type,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            
            SizedBox(height: 24),
            
            // Input Field
            Text(
              'Enter ${selectedType}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            SizedBox(height: 12),
            
            TextField(
              controller: textController,
              decoration: InputDecoration(
                hintText: _getHintText(selectedType),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Color(0xFF0051AA)),
                ),
                contentPadding: EdgeInsets.all(16),
              ),
              maxLines: selectedType == 'Text' ? 3 : 1,
              onChanged: (value) {
                setState(() {});
              },
            ),
            
            SizedBox(height: 24),
            
            // QR Code Preview - Only show when text is not empty and keyboard is not showing
            if (textController.text.isNotEmpty) ...[
              Text(
                'QR Code Preview',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              SizedBox(height: 12),
              
              Center(
                child: Container(
                  width: MediaQuery.of(context).viewInsets.bottom > 0 ? 150 : 200, // Smaller when keyboard is showing
                  height: MediaQuery.of(context).viewInsets.bottom > 0 ? 150 : 200,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: QrImageView(
                      data: textController.text,
                      version: QrVersions.auto,
                      size: MediaQuery.of(context).viewInsets.bottom > 0 ? 150 : 200,
                      backgroundColor: Colors.white,
                      errorCorrectionLevel: QrErrorCorrectLevel.M,
                      padding: EdgeInsets.all(8), // Add quiet zone
                    ),
                  ),
                ),
              ),
              
              SizedBox(height: 24),
            ],
            
            // Add some spacing instead of Spacer()
            SizedBox(height: MediaQuery.of(context).viewInsets.bottom > 0 ? 20 : 40),
            
            // Generate Button
            Container(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: textController.text.isNotEmpty ? () {
                  HistoryManager.addToHistory(textController.text, selectedType, 'create');
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ResultScreen(
                        scannedData: textController.text,
                        dataType: selectedType,
                        isGenerated: true,
                      ),
                    ),
                  );
                } : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF0051AA),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Generate QR Code',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            
            // Add bottom padding to ensure button is visible above keyboard
            SizedBox(height: MediaQuery.of(context).viewInsets.bottom > 0 ? 20 : 40),
          ],
        ),
      ),
    );
  }

  String _getHintText(String type) {
    switch (type) {
      case 'URL':
        return 'https://example.com';
      case 'WiFi':
        return 'Network name and password';
      case 'Contact':
        return 'Name and phone number';
      case 'Email':
        return 'email@example.com';
      default:
        return 'Enter your text here';
    }
  }
}

// 5. Result/Display Screen
class ResultScreen extends StatelessWidget {
  final String scannedData;
  final String dataType;
  final bool isGenerated;

  const ResultScreen({
    Key? key,
    required this.scannedData,
    required this.dataType,
    this.isGenerated = false,
  }) : super(key: key);

  Future<void> _downloadQRCode(BuildContext context) async {
    try {
      // Show loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
              SizedBox(width: 16),
              Text('Saving to gallery...'),
            ],
          ),
          duration: Duration(seconds: 3),
          backgroundColor: Color(0xFF0051AA),
        ),
      );

      // Generate QR code image with proper borders
      final qrValidationResult = QrValidator.validate(
        data: scannedData,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.M,
      );

      if (qrValidationResult.status == QrValidationStatus.valid) {
        final qrCode = qrValidationResult.qrCode!;
        
        // Create QR painter with white background and padding
        final size = 512.0;
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        
        // Paint white background
        final paint = Paint()..color = Colors.white;
        canvas.drawRect(Rect.fromLTWH(0, 0, size, size), paint);
        
        // Create painter
        final painter = QrPainter.withQr(
          qr: qrCode,
          color: const Color(0xFF000000),
          emptyColor: const Color(0xFFFFFFFF),
          gapless: false,
        );
        
        // Paint QR code with padding (translate canvas to add borders)
        canvas.save();
        canvas.translate(32, 32); // 32px padding on all sides
        painter.paint(canvas, Size(size - 64, size - 64));
        canvas.restore();
        
        final picture = recorder.endRecording();
        final img = await picture.toImage(size.toInt(), size.toInt());
        final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
        final buffer = byteData!.buffer.asUint8List();

        // Save to gallery using Gal package
        await Gal.putImageBytes(
          buffer,
          name: "QR_Code_${DateTime.now().millisecondsSinceEpoch}",
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('QR code saved to gallery!'),
              ],
            ),
            backgroundColor: Color(0xFF4CAF50),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 8),
              Text('Error saving QR code: $e'),
            ],
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _shareQRCode(BuildContext context) async {
    try {
      // Show loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
              SizedBox(width: 16),
              Text('Preparing to share...'),
            ],
          ),
          duration: Duration(seconds: 2),
          backgroundColor: Color(0xFF0051AA),
        ),
      );

      // Generate QR code image with proper borders
      final qrValidationResult = QrValidator.validate(
        data: scannedData,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.M,
      );

      if (qrValidationResult.status == QrValidationStatus.valid) {
        final qrCode = qrValidationResult.qrCode!;
        
        // Create QR painter with white background and padding
        final size = 512.0;
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        
        // Paint white background
        final paint = Paint()..color = Colors.white;
        canvas.drawRect(Rect.fromLTWH(0, 0, size, size), paint);
        
        // Create painter
        final painter = QrPainter.withQr(
          qr: qrCode,
          color: const Color(0xFF000000),
          emptyColor: const Color(0xFFFFFFFF),
          gapless: false,
        );
        
        // Paint QR code with padding (translate canvas to add borders)
        canvas.save();
        canvas.translate(32, 32); // 32px padding on all sides
        painter.paint(canvas, Size(size - 64, size - 64));
        canvas.restore();
        
        final picture = recorder.endRecording();
        final img = await picture.toImage(size.toInt(), size.toInt());
        final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
        final buffer = byteData!.buffer.asUint8List();

        // Save to temporary file
        final tempDir = await getTemporaryDirectory();
        final file = await File('${tempDir.path}/qr_code_share.png').create();
        await file.writeAsBytes(buffer);

        // Share the image and text
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'QR Code: $scannedData',
          subject: 'Shared from QScan',
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sharing QR code: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _openUrl(BuildContext context) async {
    if (dataType == 'URL') {
      try {
        String url = scannedData.trim();
        
        // Add protocol if missing
        if (!url.startsWith('http://') && !url.startsWith('https://')) {
          url = 'https://$url';
        }
        
        final uri = Uri.parse(url);
        
        if (await canLaunchUrl(uri)) {
          await launchUrl(
            uri, 
            mode: LaunchMode.externalApplication, // Force external browser
          );
        } else {
          throw 'Could not launch $url';
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white),
                SizedBox(width: 8),
                Text('Error opening URL: $e'),
              ],
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeManager themeManager = ThemeManager();
    final backgroundColor = themeManager.isDarkMode ? Color(0xFF2C2C2C) : Colors.white;
    final textColor = themeManager.isDarkMode ? Colors.white : Colors.black;
    final cardColor = themeManager.isDarkMode ? Color(0xFF3C3C3C) : Colors.grey[50];

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        title: Text(
          isGenerated ? 'Generated QR Code' : 'Scan Result',
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.all(24.0),
        child: Column(
          children: [
            // QR Code Display
            Center(
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: QrImageView(
                    data: scannedData,
                    version: QrVersions.auto,
                    size: 250.0,
                    backgroundColor: Colors.white,
                    errorCorrectionLevel: QrErrorCorrectLevel.M,
                    padding: EdgeInsets.all(8), // Add quiet zone (white border)
                  ),
                ),
              ),
            ),
            
            SizedBox(height: 24),
            
            // Data Type
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Color(0xFF0051AA).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                dataType,
                style: TextStyle(
                  color: Color(0xFF0051AA),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            
            SizedBox(height: 16),
            
            // Data Content
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                scannedData,
                style: TextStyle(
                  fontSize: 16,
                  color: textColor,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            
            SizedBox(height: 24),
            
            // Action Buttons
            if (isGenerated) ...[
              // For Generated QR Codes: Download + Share
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _downloadQRCode(context),
                      icon: Icon(Icons.download, color: Color(0xFF0051AA)),
                      label: Text(
                        'Download',
                        style: TextStyle(color: Color(0xFF0051AA)),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Color(0xFF0051AA)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _shareQRCode(context),
                      icon: Icon(Icons.share, color: Colors.white),
                      label: Text(
                        'Share',
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF0051AA),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              // For Scanned QR Codes: Copy + Share
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: scannedData));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Copied to clipboard'),
                            backgroundColor: Color(0xFF0051AA),
                          ),
                        );
                      },
                      icon: Icon(Icons.copy, color: Color(0xFF0051AA)),
                      label: Text(
                        'Copy',
                        style: TextStyle(color: Color(0xFF0051AA)),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Color(0xFF0051AA)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _shareQRCode(context),
                      icon: Icon(Icons.share, color: Colors.white),
                      label: Text(
                        'Share',
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF0051AA),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
              
              if (dataType == 'URL') ...[
                SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: () => _openUrl(context),
                    icon: Icon(Icons.open_in_new, color: Colors.white),
                    label: Text(
                      'Open Link',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF4CAF50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ],
            
            Spacer(),
            
            // Done Button
            Container(
              width: double.infinity,
              height: 56,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => HomeScreen()),
                    (route) => false,
                  );
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.grey[300]!),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Done',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 6. History Screen
class HistoryScreen extends StatefulWidget {
  @override
  _HistoryScreenState createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String selectedFilter = 'Scan';

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = ThemeManager().isDarkMode;
    final backgroundColor = isDarkTheme ? Color(0xFF2C2C2C) : Colors.white;
    final textColor = isDarkTheme ? Colors.white : Colors.black;
    final cardColor = isDarkTheme ? Color(0xFF3C3C3C) : Colors.grey[50];
    
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        title: Text(
          'Scanning History',
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.delete_outline, color: Colors.grey[600]),
            onPressed: () {
              _showClearHistoryDialog();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Subtitle
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Text(
              'QScan will keep your history. Clear anytime from settings.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          
          // Filter Tabs
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              children: [
                _buildFilterTab('Scan', selectedFilter == 'Scan', textColor),
                SizedBox(width: 12),
                _buildFilterTab('Create', selectedFilter == 'Create', textColor),
              ],
            ),
          ),
          
          // History List
          Expanded(
            child: _buildHistoryList(cardColor, textColor),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList(Color? cardColor, Color textColor) {
    final filteredHistory = selectedFilter == 'Scan' 
        ? HistoryManager.getHistory('scan')
        : HistoryManager.getHistory('create');
        
    if (filteredHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selectedFilter == 'Scan' ? Icons.qr_code_scanner : Icons.qr_code,
              size: 64,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16),
            Text(
              'No ${selectedFilter.toLowerCase()} history yet',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[500],
              ),
            ),
            SizedBox(height: 8),
            Text(
              selectedFilter == 'Scan' 
                  ? 'Scan QR codes to see them here'
                  : 'Create QR codes to see them here',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[400],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 24),
      itemCount: filteredHistory.length,
      itemBuilder: (context, index) {
        final item = filteredHistory[index];
        return _buildHistoryItem(item, cardColor, textColor);
      },
    );
  }

  Widget _buildFilterTab(String title, bool isSelected, Color textColor) {
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedFilter = title;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Color(0xFF0051AA) : Colors.transparent,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryItem(Map<String, dynamic> item, Color? cardColor, Color textColor) {
    final DateTime timestamp = item['timestamp'];
    final timeStr = _formatTime(timestamp);
    
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ResultScreen(
              scannedData: item['data'],
              dataType: item['type'],
              isGenerated: item['action'] == 'create',
            ),
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 16),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: ThemeManager().isDarkMode ? null : Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Color(0xFF0051AA).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                item['icon'],
                color: Color(0xFF0051AA),
                size: 24,
              ),
            ),
            
            SizedBox(width: 16),
            
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['data'].length > 35 
                      ? '${item['data'].substring(0, 35)}...'
                      : item['data'],
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '${item['type']} • ${item['action'].toUpperCase()}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    timeStr,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
            
            // Actions
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.copy, color: Colors.grey[400], size: 20),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: item['data']));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Copied to clipboard'),
                        backgroundColor: Color(0xFF0051AA),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: Icon(Icons.more_vert, color: Colors.grey[400], size: 20),
                  onPressed: () {},
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showClearHistoryDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Clear History'),
          content: Text('Are you sure you want to clear all history? This action cannot be undone.'),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text('Clear', style: TextStyle(color: Colors.red)),
              onPressed: () {
                HistoryManager.clearHistory();
                setState(() {});
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('History cleared'),
                    backgroundColor: Color(0xFF0051AA),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${timestamp.day} ${_getMonthName(timestamp.month)} ${timestamp.year}, ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }

  String _getMonthName(int month) {
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                   'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month];
  }
}

// 7. Settings Screen
class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ThemeManager _themeManager = ThemeManager();
  final ScanSettingsManager _scanSettings = ScanSettingsManager();

  @override
  void initState() {
    super.initState();
    _themeManager.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    _themeManager.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    setState(() {
      // Theme has changed, rebuild the settings screen
    });
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = _themeManager.isDarkMode ? Color(0xFF2C2C2C) : Colors.white;
    final textColor = _themeManager.isDarkMode ? Colors.white : Colors.black;
    final cardColor = _themeManager.isDarkMode ? Color(0xFF3C3C3C) : Colors.grey[50];

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        title: Text(
          'Settings',
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.all(24),
        children: [
          // General Section
          _buildSectionHeader('General', textColor),
          _buildSettingItem(
            Icons.dark_mode_outlined,
            'Dark Theme',
            'Switch between light and dark mode',
            () {},
            hasSwitch: true,
            switchValue: _themeManager.isDarkMode,
            onSwitchChanged: (value) async {
              await _themeManager.setTheme(value);
            },
            textColor: textColor,
            cardColor: cardColor,
          ),
          
          SizedBox(height: 24),
          
          // Scanner Settings
          _buildSectionHeader('Scanner', textColor),
          _buildSettingItem(
            Icons.vibration_outlined,
            'Vibration',
            'Vibrate on successful scan',
            () {},
            hasSwitch: true,
            switchValue: _scanSettings.vibrationEnabled,
            onSwitchChanged: (value) async {
              await _scanSettings.setVibration(value);
              setState(() {});
            },
            textColor: textColor,
            cardColor: cardColor,
          ),
          _buildSettingItem(
            Icons.volume_up_outlined,
            'Sound',
            'Play sound on scan',
            () {},
            hasSwitch: true,
            switchValue: _scanSettings.soundEnabled,
            onSwitchChanged: (value) async {
              await _scanSettings.setSound(value);
              setState(() {});
            },
            textColor: textColor,
            cardColor: cardColor,
          ),
          
          SizedBox(height: 24),
          
          // Data & Privacy
          _buildSectionHeader('Data & Privacy', textColor),
          _buildSettingItem(
            Icons.history_outlined,
            'History',
            'Manage scan history',
            () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => HistoryScreen()),
              );
            },
            textColor: textColor,
            cardColor: cardColor,
          ),
          _buildSettingItem(
            Icons.delete_outline,
            'Clear History',
            'Clear all scan and create history',
            () {
              _showClearHistoryDialog();
            },
            textColor: textColor,
            cardColor: cardColor,
          ),
          
          SizedBox(height: 24),
          
          // About
          _buildSectionHeader('About', textColor),
          _buildSettingItem(
            Icons.info_outline,
            'About QScan',
            'Version 1.0.0',
            () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AboutScreen()),
              );
            },
            textColor: textColor,
            cardColor: cardColor,
          ),
          _buildSettingItem(
            Icons.privacy_tip_outlined,
            'Privacy Policy',
            'Read our privacy policy',
            () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => PrivacyPolicyScreen()),
              );
            },
            textColor: textColor,
            cardColor: cardColor,
          ),
          _buildSettingItem(
            Icons.description_outlined,
            'Terms of Service',
            'Read terms and conditions',
            () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => TermsOfServiceScreen()),
              );
            },
            textColor: textColor,
            cardColor: cardColor,
          ),
          _buildSettingItem(
            Icons.star_outline,
            'Rate App',
            'Rate us on App Store',
            () {},
            textColor: textColor,
            cardColor: cardColor,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color textColor) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildSettingItem(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap, {
    bool hasSwitch = false,
    bool switchValue = false,
    Function(bool)? onSwitchChanged,
    required Color textColor,
    required Color? cardColor,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Color(0xFF0051AA).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Color(0xFF0051AA), size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: textColor,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        trailing: hasSwitch
            ? Switch(
                value: switchValue,
                onChanged: onSwitchChanged,
                activeColor: Color(0xFF0051AA),
              )
            : Icon(Icons.chevron_right, color: Colors.grey[400]),
        onTap: hasSwitch ? null : onTap,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        tileColor: cardColor,
      ),
    );
  }

  void _showClearHistoryDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Clear All History'),
          content: Text('Are you sure you want to clear all scan and create history? This action cannot be undone.'),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text('Clear All', style: TextStyle(color: Colors.red)),
              onPressed: () async {
                await HistoryManager.clearHistory();
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('All history cleared'),
                    backgroundColor: Color(0xFF0051AA),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

// Privacy Policy Screen
class PrivacyPolicyScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ThemeManager themeManager = ThemeManager();
    final backgroundColor = themeManager.isDarkMode ? Color(0xFF2C2C2C) : Colors.white;
    final textColor = themeManager.isDarkMode ? Colors.white : Colors.black;
    final cardColor = themeManager.isDarkMode ? Color(0xFF3C3C3C) : Colors.grey[50];

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        title: Text(
          'Privacy Policy',
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your privacy is important to us. This Privacy Policy explains how QScan handles your information.',
              style: TextStyle(
                fontSize: 16,
                color: textColor,
                height: 1.5,
              ),
            ),
            SizedBox(height: 32),

            _buildPolicySection(
              'No Personal Data Collected',
              'The App does not collect, store, or share personal information. QR codes are scanned locally on your device.',
              textColor,
              cardColor,
            ),

            _buildPolicySection(
              'Permissions',
              'The App uses your device\'s camera to scan QR codes. No images, videos, or scans are stored or uploaded.',
              textColor,
              cardColor,
            ),

            _buildPolicySection(
              'Third-Party Services',
              'If a QR code directs you to a website or third-party app, their privacy policies will apply.',
              textColor,
              cardColor,
            ),

            _buildPolicySection(
              'Changes to This Policy',
              'We may update this Privacy Policy from time to time. Updates will be posted within the App.',
              textColor,
              cardColor,
            ),

            SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildPolicySection(String title, String content, Color textColor, Color? cardColor) {
    return Container(
      margin: EdgeInsets.only(bottom: 24),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Color(0xFF0051AA).withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0051AA),
            ),
          ),
          SizedBox(height: 12),
          Text(
            content,
            style: TextStyle(
              fontSize: 15,
              color: textColor,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

// Terms of Service Screen
class TermsOfServiceScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ThemeManager themeManager = ThemeManager();
    final backgroundColor = themeManager.isDarkMode ? Color(0xFF2C2C2C) : Colors.white;
    final textColor = themeManager.isDarkMode ? Colors.white : Colors.black;
    final cardColor = themeManager.isDarkMode ? Color(0xFF3C3C3C) : Colors.grey[50];

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        title: Text(
          'Terms of Service',
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'By using QScan, you agree to these Terms of Service.',
              style: TextStyle(
                fontSize: 16,
                color: textColor,
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 32),

            _buildTermsSection(
              'Use of the App',
              'You may use the App only for lawful purposes.\n\nYou are responsible for any actions you take after scanning a QR code.',
              textColor,
              cardColor,
            ),

            _buildTermsSection(
              'No Guarantee',
              'The App is provided "as is" without warranties of any kind.\n\nWe are not responsible for the content of QR codes you scan (e.g., links to external websites).',
              textColor,
              cardColor,
            ),

            _buildTermsSection(
              'Limitation of Liability',
              'We are not liable for any damages or losses resulting from use of the App, including harmful links or third-party content.',
              textColor,
              cardColor,
            ),

            _buildTermsSection(
              'Updates and Changes',
              'We may modify or discontinue the App at any time without prior notice.\n\nContinued use after updates means you accept the changes.',
              textColor,
              cardColor,
            ),

            SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildTermsSection(String title, String content, Color textColor, Color? cardColor) {
    return Container(
      margin: EdgeInsets.only(bottom: 24),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Color(0xFF0051AA).withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0051AA),
            ),
          ),
          SizedBox(height: 12),
          Text(
            content,
            style: TextStyle(
              fontSize: 15,
              color: textColor,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

// About Screen
class AboutScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ThemeManager themeManager = ThemeManager();
    final backgroundColor = themeManager.isDarkMode ? Color(0xFF2C2C2C) : Colors.white;
    final textColor = themeManager.isDarkMode ? Colors.white : Colors.black;
    final cardColor = themeManager.isDarkMode ? Color(0xFF3C3C3C) : Colors.grey[50];

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        title: Text(
          'About QScan',
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // App Icon
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Color(0xFFE3F2FD),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.qr_code_scanner,
                size: 50,
                color: Color(0xFF0051AA),
              ),
            ),
            SizedBox(height: 24),

            // App Name and Version
            Text(
              'QScan',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Version 1.0.0',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 32),

            // Description
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Color(0xFF0051AA).withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Text(
                'QScan is a fast and easy tool to scan and create QR codes. With features like flashlight night mode, vibration and sound feedback, and scan history, you can scan codes anytime with ease. The app also lets you create custom QR codes for text, Wi-Fi, URLs, contacts, and emails, making it a complete solution for all your QR needs.',
                style: TextStyle(
                  fontSize: 16,
                  color: textColor,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: 32),

            // Features List
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Color(0xFF0051AA).withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Key Features',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0051AA),
                    ),
                  ),
                  SizedBox(height: 16),
                  _buildFeatureItem('🔍', 'Fast QR code scanning', textColor),
                  _buildFeatureItem('📱', 'Create custom QR codes', textColor),
                  _buildFeatureItem('🔦', 'Flashlight for night scanning', textColor),
                  _buildFeatureItem('📳', 'Vibration and sound feedback', textColor),
                  _buildFeatureItem('📝', 'Scan history tracking', textColor),
                  _buildFeatureItem('🌐', 'Support for URLs, Wi-Fi, contacts, and more', textColor),
                ],
              ),
            ),
            SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(String emoji, String feature, Color textColor) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text(
            emoji,
            style: TextStyle(fontSize: 20),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              feature,
              style: TextStyle(
                fontSize: 15,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}