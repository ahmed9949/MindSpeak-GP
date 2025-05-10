// import 'dart:async';
// import 'dart:math';
// import 'package:flutter/material.dart';
// import 'package:flutter_3d_controller/flutter_3d_controller.dart';
// import 'package:mind_speak_app/Repositories/sessionrepoC.dart';
// import 'package:mind_speak_app/controllers/sessioncontrollerCl.dart';
// import 'package:mind_speak_app/models/avatar.dart';
// import 'package:mind_speak_app/pages/avatarpages/sessionviewcl.dart';
// import 'package:mind_speak_app/providers/color_provider.dart';
// import 'package:mind_speak_app/providers/session_provider.dart';
// import 'package:mind_speak_app/providers/theme_provider.dart';
// import 'package:mind_speak_app/service/avatarservice/openai.dart';
// import 'package:provider/provider.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter_dotenv/flutter_dotenv.dart';

// class StartSessionPage extends StatefulWidget {
//   const StartSessionPage({super.key});

//   @override
//   State<StartSessionPage> createState() => _StartSessionPageState();
// }

// class _StartSessionPageState extends State<StartSessionPage> {
//   final Flutter3DController _testController = Flutter3DController();
//   final Flutter3DController _preloadController = Flutter3DController();
//   bool _isTestingAnimations = false;
//   String? _currentTestAnimation;
//   List<String> _detectedAnimations = [];

//   bool _isLoading = false;
//   bool _isPreloadingAvatar = false;
//   bool _isAvatarReady = false;
//   bool _isWelcomeMessageReady = false;
//   String? _errorMessage;
//   late ChatGptModel _model;
//   late SessionRepository _sessionRepository;
//   late SessionController _sessionController;
//   late SessionAnalyzerController _analyzerController;
//   AvatarModel? _selectedAvatar;
//   late PageController _pageController;

//   // Variables for avatar preloading
//   String? _initialResponse;
//   Map<String, dynamic>? _preloadedChildData;
//   bool _avatarPreloaded = false;

//   // Loading screen state
//   bool _showLoadingScreen = false;
//   double _avatarLoadProgress = 0.0;
//   double _welcomeMessageLoadProgress = 0.0;

//   final List<AvatarModel> avatars = [
//     AvatarModel(
//       name: 'nadara',
//       imagePath: 'assets/avatars/avatarimage/nadara.png',
//       modelPath: 'assets/avatars/3dmodels/banotabenadara.glb',
//     ),
//     AvatarModel(
//       name: 'batman',
//       imagePath: 'assets/avatars/avatarimage/batman.png',
//       modelPath: 'assets/avatars/3dmodels/batman.glb',
//       greetingAnimation: 'Armature.001|mixamo.com|Layer0',
//     ),
//   ];

//   @override
//   void initState() {
//     super.initState();
//     _initializeServices();

//     if (avatars.isNotEmpty) {
//       _selectedAvatar = avatars[0];
//     }

//     // Initialize the page controller
//     _pageController = PageController(
//       viewportFraction: 0.6,
//       initialPage: 0,
//     );

//     // Setup preload controller listener
//     _preloadController.onModelLoaded.addListener(_onPreloadModelLoaded);
//   }

//   void _initializeServices() {
//     final apiKey = dotenv.env['OPEN_AI_API_KEY']!;
//     _model = ChatGptModel(apiKey: apiKey);
//     _sessionRepository = FirebaseSessionRepository();
//     _sessionController = SessionController(_sessionRepository);
//     _analyzerController = SessionAnalyzerController(_model);
//   }

//   @override
//   void dispose() {
//     _pageController.dispose();
//     _preloadController.onModelLoaded.removeListener(_onPreloadModelLoaded);
//     super.dispose();
//   }

//   // Method to validate avatar animations
//   void _validateSelectedAvatar() {
//     if (_selectedAvatar != null) {
//       print("\n🔍 VALIDATING SELECTED AVATAR MODEL");
//       print("Avatar Name: ${_selectedAvatar!.name}");
//       print("Avatar Model Path: ${_selectedAvatar!.modelPath}");
//       print("Animation Names:");
//       print("- idle: '${_selectedAvatar!.idleAnimation}'");
//       print("- talking: '${_selectedAvatar!.talkingAnimation}'");
//       print("- thinking: '${_selectedAvatar!.thinkingAnimation}'");
//       print("- clapping: '${_selectedAvatar!.clappingAnimation}'");
//       print("- greeting: '${_selectedAvatar!.greetingAnimation}'");
//       print("\n");
//     }
//   }

//   Future<Map<String, dynamic>?> _fetchChildData(String childId) async {
//     try {
//       DocumentSnapshot childDoc = await FirebaseFirestore.instance
//           .collection('child')
//           .doc(childId)
//           .get();

//       if (!childDoc.exists) {
//         setState(() => _errorMessage = 'Child data not found');
//         return null;
//       }

//       return childDoc.data() as Map<String, dynamic>;
//     } catch (e) {
//       setState(() => _errorMessage = 'Error fetching child data: $e');
//       return null;
//     }
//   }

//   void _onPreloadModelLoaded() {
//     if (_preloadController.onModelLoaded.value &&
//         mounted &&
//         _isPreloadingAvatar) {
//       print("✅ Preloaded 3D avatar model loaded successfully");
//       setState(() {
//         _isAvatarReady = true;
//         _avatarLoadProgress = 1.0;
//         _isPreloadingAvatar = false;
//         _avatarPreloaded = true;
//       });

//       _checkAllComponentsReady();
//     }
//   }

//   void _checkAllComponentsReady() {
//     print(
//         "🔍 Checking components: Avatar ready: $_isAvatarReady, Welcome message ready: $_isWelcomeMessageReady");
//     if (_isAvatarReady &&
//         _isWelcomeMessageReady &&
//         mounted &&
//         _initialResponse != null &&
//         _preloadedChildData != null) {
//       // Add a small delay to ensure state is properly updated
//       Future.delayed(Duration(milliseconds: 100), () {
//         if (mounted) {
//           _navigateToSessionView();
//         }
//       });
//     }
//   }

//   String _generateInitialPrompt(Map<String, dynamic> childData) {
//     final name = childData['name'] ?? '';
//     final age = childData['age']?.toString() ?? '';
//     final interest = childData['childInterest'] ?? '';

//     return '''
// Act as a therapist for children with autism, trying to enhance communication skills.
// Talk with the child in Egyptian Arabic.

// Child Information:
// - Name: $name
// - Age: $age
// - child Interests: $interest

// Task:
// You are a therapist helping this child improve their communication skills.
// 1. Start by engaging with their interest in $interest choose random  interest to talk about to not make the child confusd if a the one interest contain many details choose one detail
// 2. Gradually expand the conversation beyond this interest
// 3. Keep responses short simple clear and easy to understand 
// 4. Use positive reinforcement
// 5. Be patient and encouraging
// 6. Speak in egyptian slang
// 7. make sure to end your response with a quesiton to tigger the child to talk 

// Please provide the initial therapeutic approach and first question you'll ask the child, focusing on their interest in $interest.
// Remember to:
// - Keep responses under 2 sentences
// - Be warm and encouraging
// - Start with their comfort zone ($interest)
// - Later guide them to broader topics
// ''';
//   }

//   Future<void> _preloadAvatar(AvatarModel avatar) async {
//     if (_isPreloadingAvatar) return;

//     setState(() {
//       _isPreloadingAvatar = true;
//       _avatarPreloaded = false;
//       _isAvatarReady = false;
//       _avatarLoadProgress = 0.2; // Start at 20%
//     });

//     // Create an offscreen container with the 3D model
//     final preloadContainer = SizedBox(
//       width: 1, // Minimal size
//       height: 1,
//       child: Opacity(
//         opacity: 0.0, // Invisible
//         child: Flutter3DViewer(
//           src: avatar.modelPath,
//           controller: _preloadController,
//         ),
//       ),
//     );

//     // Add the container to the widget tree temporarily
//     if (mounted) {
//       setState(() {
//         // Render the preload container
//         WidgetsBinding.instance.addPostFrameCallback((_) {
//           if (mounted) {
//             // Add to overlay for offscreen rendering
//             final overlay = Overlay.of(context);
//             final entry = OverlayEntry(builder: (context) => preloadContainer);
//             overlay.insert(entry);

//             // Update progress periodically
//             Timer.periodic(Duration(milliseconds: 500), (timer) {
//               if (mounted && !_isAvatarReady) {
//                 setState(() {
//                   // Increment progress until 80%
//                   _avatarLoadProgress = min(0.8, _avatarLoadProgress + 0.1);
//                 });
//               } else {
//                 timer.cancel();
//               }
//             });

//             // Remove after a timeout (safety measure)
//             Future.delayed(Duration(seconds: 15), () {
//               if (!_isAvatarReady && mounted) {
//                 print("⚠️ Avatar preload timeout, proceeding anyway");
//                 setState(() {
//                   _isAvatarReady = true;
//                   _avatarLoadProgress = 1.0;
//                   _isPreloadingAvatar = false;
//                   _avatarPreloaded = true;
//                 });

//                 _checkAllComponentsReady();
//               }
//               try {
//                 entry.remove();
//               } catch (e) {
//                 // Entry might already be removed
//               }
//             });
//           }
//         });
//       });
//     }
//   }

//   void _navigateToSessionView() {
//     if (!mounted) {
//       print("⚠️ Cannot navigate: widget not mounted");
//       return;
//     }

//     if (_selectedAvatar == null) {
//       print("⚠️ Cannot navigate: no avatar selected");
//       return;
//     }

//     if (_initialResponse == null) {
//       print("⚠️ Cannot navigate: initial response is null");
//       return;
//     }

//     if (_preloadedChildData == null) {
//       print("⚠️ Cannot navigate: child data is null");
//       return;
//     }

//     try {
//       // Hide loading screen before navigation
//       setState(() {
//         _showLoadingScreen = false;
//         _isLoading = false;
//       });

//       // Additional safety check - don't pass null values to the constructor
//       final avatar = _selectedAvatar!;
//       final response = _initialResponse!;
//       final childData = _preloadedChildData!;

//       print(
//           "✅ Navigating to SessionView with preloaded avatar: ${avatar.name}");

//       Navigator.push(
//         context,
//         MaterialPageRoute(
//           builder: (context) => MultiProvider(
//             providers: [
//               ChangeNotifierProvider.value(value: _sessionController),
//               Provider.value(value: _analyzerController),
//               Provider.value(value: _model),
//             ],
//             child: SessionView(
//               initialPrompt: "",
//               initialResponse: response,
//               childData: childData,
//               avatarModel: avatar,
//               avatarPreloaded: _avatarPreloaded,
//               isFullyPreloaded: true, // Add this new flag
//             ),
//           ),
//         ),
//       );

//       // Reset preload state after navigation
//       setState(() {
//         _isLoading = false;
//         _initialResponse = null;
//         _preloadedChildData = null;
//         _avatarPreloaded = false;
//         _isAvatarReady = false;
//         _isWelcomeMessageReady = false;
//         _avatarLoadProgress = 0.0;
//         _welcomeMessageLoadProgress = 0.0;
//       });
//     } catch (e) {
//       print("❌ Error navigating to SessionView: $e");
//       setState(() {
//         _errorMessage = "Error starting session: $e";
//         _isLoading = false;
//         _showLoadingScreen = false;
//       });
//     }
//   }

//   Future<void> _startSession() async {
//     if (_selectedAvatar == null) {
//       setState(() {
//         _errorMessage = 'Please select an avatar first';
//       });
//       return;
//     }

//     setState(() {
//       _isLoading = true;
//       _errorMessage = null;
//       _showLoadingScreen = true;
//       _isAvatarReady = false;
//       _isWelcomeMessageReady = false;
//       _avatarLoadProgress = 0.0;
//       _welcomeMessageLoadProgress = 0.0;
//     });

//     // Validate animation names before starting
//     _validateSelectedAvatar();

//     try {
//       final childId =
//           Provider.of<SessionProvider>(context, listen: false).childId;
//       if (childId == null || childId.isEmpty) {
//         throw Exception('No child selected');
//       }

//       final childData = await _fetchChildData(childId);
//       if (childData == null) {
//         throw Exception('Failed to fetch child data.');
//       }

//       final therapistId = childData['therapistId'] ?? '';
//       if (therapistId.isEmpty) {
//         throw Exception('No therapist assigned to this child.');
//       }

//       await _sessionController.startSession(childId, therapistId);

//       final prompt = _generateInitialPrompt(childData);
//       debugPrint(
//           'Sending initial prompt to API: ${prompt.substring(0, min(100, prompt.length))}...');

//       _model.clearConversation();

//       // Start preloading the avatar while waiting for the API response
//       _preloadAvatar(_selectedAvatar!);

//       // Update welcome message progress while waiting
//       setState(() => _welcomeMessageLoadProgress = 0.3);

//       // Start welcome message generation in parallel with avatar loading
//       _getWelcomeMessage(prompt, childData);
//     } catch (e) {
//       debugPrint('❌ Error starting session: $e');
//       setState(() {
//         _errorMessage = 'Error starting session: $e';
//         _isLoading = false;
//         _showLoadingScreen = false;
//       });
//     }
//   }

//   Future<void> _getWelcomeMessage(
//       String prompt, Map<String, dynamic> childData) async {
//     try {
//       // Update progress
//       setState(() => _welcomeMessageLoadProgress = 0.5);

//       final responseText =
//           await _model.sendMessage(prompt, childData: childData);

//       setState(() => _welcomeMessageLoadProgress = 0.8);

//       debugPrint('API response received: $responseText');

//       if (responseText.isEmpty) {
//         throw Exception('Failed to generate initial response');
//       }

//       await _sessionController.addTherapistMessage(responseText);

//       // Store data for later navigation
//       _initialResponse = responseText;
//       _preloadedChildData = childData;

//       setState(() {
//         _isWelcomeMessageReady = true;
//         _welcomeMessageLoadProgress = 1.0;
//       });

//       // Check if avatar is already preloaded, if so navigate immediately
//       _checkAllComponentsReady();
//     } catch (e) {
//       print("❌ Error getting welcome message: $e");
//       setState(() {
//         _errorMessage = 'Error getting welcome message: $e';
//         _isLoading = false;
//         _showLoadingScreen = false;
//       });
//     }
//   }

//   // Loading screen widget
//   Widget _buildLoadingScreen() {
//     return Container(
//       color: Colors.black.withOpacity(0.8),
//       child: Center(
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             CircularProgressIndicator(
//               valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
//             ),
//             SizedBox(height: 24),
//             Text(
//               "Preparing your session...",
//               style: TextStyle(
//                 color: Colors.white,
//                 fontSize: 18,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//             SizedBox(height: 40),

//             // Avatar loading progress
//             Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Row(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     Icon(Icons.person,
//                         color: _isAvatarReady ? Colors.green : Colors.white),
//                     SizedBox(width: 8),
//                     Text(
//                       "Loading avatar:",
//                       style: TextStyle(color: Colors.white),
//                     ),
//                     SizedBox(width: 8),
//                     Text(
//                       "${(_avatarLoadProgress * 100).toInt()}%",
//                       style: TextStyle(
//                         color: _isAvatarReady ? Colors.green : Colors.white,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                   ],
//                 ),
//                 SizedBox(height: 8),
//                 Container(
//                   width: 250,
//                   height: 8,
//                   decoration: BoxDecoration(
//                     color: Colors.grey[700],
//                     borderRadius: BorderRadius.circular(4),
//                   ),
//                   child: FractionallySizedBox(
//                     alignment: Alignment.centerLeft,
//                     widthFactor: _avatarLoadProgress,
//                     child: Container(
//                       decoration: BoxDecoration(
//                         color: _isAvatarReady ? Colors.green : Colors.blue,
//                         borderRadius: BorderRadius.circular(4),
//                       ),
//                     ),
//                   ),
//                 ),
//               ],
//             ),

//             SizedBox(height: 16),

//             // Welcome message loading progress
//             Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Row(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     Icon(Icons.chat,
//                         color: _isWelcomeMessageReady
//                             ? Colors.green
//                             : Colors.white),
//                     SizedBox(width: 8),
//                     Text(
//                       "Preparing welcome:",
//                       style: TextStyle(color: Colors.white),
//                     ),
//                     SizedBox(width: 8),
//                     Text(
//                       "${(_welcomeMessageLoadProgress * 100).toInt()}%",
//                       style: TextStyle(
//                         color: _isWelcomeMessageReady
//                             ? Colors.green
//                             : Colors.white,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                   ],
//                 ),
//                 SizedBox(height: 8),
//                 Container(
//                   width: 250,
//                   height: 8,
//                   decoration: BoxDecoration(
//                     color: Colors.grey[700],
//                     borderRadius: BorderRadius.circular(4),
//                   ),
//                   child: FractionallySizedBox(
//                     alignment: Alignment.centerLeft,
//                     widthFactor: _welcomeMessageLoadProgress,
//                     child: Container(
//                       decoration: BoxDecoration(
//                         color:
//                             _isWelcomeMessageReady ? Colors.green : Colors.blue,
//                         borderRadius: BorderRadius.circular(4),
//                       ),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   // void _checkAllComponentsReady() {
//   //   if (_isAvatarReady && _isWelcomeMessageReady && mounted) {
//   //     _navigateToSessionView();
//   //   }
//   // }

//   void _selectAndStartSession(AvatarModel avatar) async {
//     setState(() {
//       _selectedAvatar = avatar;
//     });

//     // Start the session immediately
//     await _startSession();
//   }

//   Widget _buildAvatarSelector() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Padding(
//           padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
//           child: Text(
//             "Select Your Avatar",
//             style: TextStyle(
//               fontSize: 20,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//         ),
//         SizedBox(
//           height: 220,
//           child: PageView.builder(
//             controller: _pageController,
//             itemCount: avatars.length,
//             onPageChanged: (index) {
//               setState(() {
//                 _selectedAvatar = avatars[index];
//               });
//             },
//             itemBuilder: (context, index) {
//               final avatar = avatars[index];
//               final isSelected = _selectedAvatar == avatar;

//               return GestureDetector(
//                 onTap: () {
//                   // When tapping on an avatar, just select it (don't start session)
//                   setState(() {
//                     _selectedAvatar = avatar;
//                     _pageController.animateToPage(
//                       index,
//                       duration: Duration(milliseconds: 300),
//                       curve: Curves.easeInOut,
//                     );
//                   });
//                 },
//                 child: AnimatedContainer(
//                   duration: const Duration(milliseconds: 300),
//                   margin: EdgeInsets.symmetric(
//                     horizontal: 10,
//                     vertical: isSelected ? 0 : 30,
//                   ),
//                   decoration: BoxDecoration(
//                     borderRadius: BorderRadius.circular(20),
//                     boxShadow: isSelected
//                         ? [
//                             BoxShadow(
//                               color: Colors.blue.withOpacity(0.6),
//                               spreadRadius: 4,
//                               blurRadius: 8,
//                             )
//                           ]
//                         : [],
//                   ),
//                   child: Stack(
//                     children: [
//                       // Avatar image
//                       ClipRRect(
//                         borderRadius: BorderRadius.circular(20),
//                         child: Image.asset(
//                           avatar.imagePath,
//                           height: 200,
//                           width: double.infinity,
//                           fit: BoxFit.cover,
//                         ),
//                       ),

//                       // Avatar name with gradient background
//                       Positioned(
//                         bottom: 0,
//                         left: 0,
//                         right: 0,
//                         child: Container(
//                           padding: const EdgeInsets.all(8.0),
//                           decoration: BoxDecoration(
//                             borderRadius: BorderRadius.only(
//                               bottomLeft: Radius.circular(20),
//                               bottomRight: Radius.circular(20),
//                             ),
//                             gradient: LinearGradient(
//                               begin: Alignment.bottomCenter,
//                               end: Alignment.topCenter,
//                               colors: [
//                                 Colors.black.withOpacity(0.8),
//                                 Colors.transparent,
//                               ],
//                             ),
//                           ),
//                           child: Column(
//                             mainAxisSize: MainAxisSize.min,
//                             children: [
//                               Text(
//                                 avatar.name,
//                                 style: const TextStyle(
//                                   color: Colors.white,
//                                   fontSize: 18,
//                                   fontWeight: FontWeight.bold,
//                                 ),
//                                 textAlign: TextAlign.center,
//                               ),
//                               if (isSelected)
//                                 Padding(
//                                   padding: const EdgeInsets.only(top: 8.0),
//                                   child: ElevatedButton(
//                                     onPressed: () =>
//                                         _selectAndStartSession(avatar),
//                                     child: Text("Start with this Avatar"),
//                                     style: ElevatedButton.styleFrom(
//                                       backgroundColor: Colors.blue,
//                                       foregroundColor: Colors.white,
//                                       textStyle: TextStyle(
//                                           fontWeight: FontWeight.bold),
//                                       shape: RoundedRectangleBorder(
//                                         borderRadius: BorderRadius.circular(10),
//                                       ),
//                                     ),
//                                   ),
//                                 ),
//                             ],
//                           ),
//                         ),
//                       ),

//                       // Selection indicator
//                       if (isSelected)
//                         Positioned(
//                           top: 10,
//                           right: 10,
//                           child: Container(
//                             padding: const EdgeInsets.all(4),
//                             decoration: BoxDecoration(
//                               color: Colors.blue,
//                               shape: BoxShape.circle,
//                             ),
//                             child: Icon(
//                               Icons.check,
//                               color: Colors.white,
//                               size: 20,
//                             ),
//                           ),
//                         ),
//                     ],
//                   ),
//                 ),
//               );
//             },
//           ),
//         ),
//       ],
//     );
//   }

//   // Loading indicator with avatar preloading status
//   Widget _buildLoadingIndicator() {
//     return Column(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         CircularProgressIndicator(),
//         SizedBox(height: 16),
//         Text(
//           _isPreloadingAvatar
//               ? "Loading avatar (${_avatarPreloaded ? "Ready" : "Loading..."})"
//               : "Starting session...",
//           style: TextStyle(fontSize: 16),
//         ),
//       ],
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     final themeProvider = Provider.of<ThemeProvider>(context);
//     final colorProvider = Provider.of<ColorProvider>(context);
//     final primaryColor = colorProvider.primaryColor;
//     final isDark = themeProvider.isDarkMode;

//     return Theme(
//       data: themeProvider.currentTheme,
//       child: Scaffold(
//         appBar: AppBar(
//           elevation: 0,
//           title: const Text('Start Therapy Session'),
//           flexibleSpace: Container(
//             decoration: BoxDecoration(
//               gradient: LinearGradient(
//                 colors: isDark
//                     ? [Colors.grey[900]!, Colors.black]
//                     : [primaryColor, primaryColor.withOpacity(0.9)],
//                 begin: Alignment.topLeft,
//                 end: Alignment.bottomRight,
//               ),
//             ),
//           ),
//         ),
//         body: Center(
//           child: Padding(
//             padding: const EdgeInsets.all(16.0),
//             child: Column(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 _buildAvatarSelector(),
//                 const SizedBox(height: 24),
//                 if (_isLoading)
//                   _buildLoadingIndicator()
//                 else
//                   ElevatedButton.icon(
//                     onPressed: _selectedAvatar != null ? _startSession : null,
//                     icon: const Icon(Icons.play_circle_outline),
//                     label: const Text('Start Session'),
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: isDark ? Colors.grey[800] : primaryColor,
//                       foregroundColor: Colors.white,
//                       disabledBackgroundColor: Colors.grey,
//                       padding: const EdgeInsets.symmetric(
//                         horizontal: 32,
//                         vertical: 16,
//                       ),
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(12),
//                       ),
//                     ),
//                   ),
//                 if (_errorMessage != null)
//                   Padding(
//                     padding: const EdgeInsets.only(top: 16),
//                     child: Text(
//                       _errorMessage!,
//                       style: const TextStyle(color: Colors.red),
//                     ),
//                   ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }


import 'dart:math';
import 'package:flutter/material.dart';
import 'package:mind_speak_app/Repositories/sessionrepoC.dart';
import 'package:mind_speak_app/controllers/sessioncontrollerCl.dart';
import 'package:mind_speak_app/pages/avatarpages/sessionviewcl.dart';
import 'package:mind_speak_app/providers/color_provider.dart';
import 'package:mind_speak_app/providers/session_provider.dart';
import 'package:mind_speak_app/providers/theme_provider.dart';
import 'package:mind_speak_app/service/avatarservice/openai.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class StartSessionPage extends StatefulWidget {
  const StartSessionPage({super.key});

  @override
  State<StartSessionPage> createState() => _StartSessionPageState();
}

class _StartSessionPageState extends State<StartSessionPage> {
  bool _isLoading = false;
  String? _errorMessage;
  late ChatGptModel _model;
  late SessionRepository _sessionRepository;
  late SessionController _sessionController;
  late SessionAnalyzerController _analyzerController;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  void _initializeServices() {
    final apiKey = dotenv.env['OPEN_AI_API_KEY']!;
    _model = ChatGptModel(apiKey: apiKey);
    _sessionRepository = FirebaseSessionRepository();
    _sessionController = SessionController(_sessionRepository);
    _analyzerController = SessionAnalyzerController(_model);
  }

  Future<Map<String, dynamic>?> _fetchChildData(String childId) async {
    try {
      DocumentSnapshot childDoc = await FirebaseFirestore.instance
          .collection('child')
          .doc(childId)
          .get();

      if (!childDoc.exists) {
        setState(() => _errorMessage = 'Child data not found');
        return null;
      }

      return childDoc.data() as Map<String, dynamic>;
    } catch (e) {
      setState(() => _errorMessage = 'Error fetching child data: $e');
      return null;
    }
  }

  String _generateInitialPrompt(Map<String, dynamic> childData) {
    final name = childData['name'] ?? '';
    final age = childData['age']?.toString() ?? '';
    final interest = childData['childInterest'] ?? '';

    return '''
Act as a therapist for children with autism, trying to enhance communication skills.
Talk with the child in Egyptian Arabic.

Child Information:
- Name: $name
- Age: $age
- Main Interest: $interest

Task:
You are a therapist helping this child improve their communication skills.
1. Start by engaging with their interest in $interest
2. Gradually expand the conversation beyond this interest
3. Keep responses short and clear
4. Use positive reinforcement
5. Be patient and encouraging
6. Speak in Arabic

Please provide the initial therapeutic approach and first question you'll ask the child, focusing on their interest in $interest.
Remember to:
- Keep responses under 2 sentences
- Be warm and encouraging
- Start with their comfort zone ($interest)
- Later guide them to broader topics
''';
  }

  Future<void> _startSession() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final childId =
          Provider.of<SessionProvider>(context, listen: false).childId;
      if (childId == null || childId.isEmpty) {
        throw Exception('No child selected');
      }

      final childData = await _fetchChildData(childId);
      if (childData == null) {
        throw Exception('Failed to fetch child data.');
      }

      final therapistId = childData['therapistId'] ?? '';
      if (therapistId.isEmpty) {
        throw Exception('No therapist assigned to this child.');
      }

      await _sessionController.startSession(childId, therapistId);

      final prompt = _generateInitialPrompt(childData);
      debugPrint(
          'Sending initial prompt to API: ${prompt.substring(0, min(100, prompt.length))}...');

      _model.clearConversation();

      final responseText =
          await _model.sendMessage(prompt, childData: childData);

      debugPrint('API response received: $responseText');

      if (responseText.isEmpty) {
        throw Exception('Failed to generate initial response');
      }

      await _sessionController.addTherapistMessage(responseText);

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MultiProvider(
              providers: [
                ChangeNotifierProvider.value(value: _sessionController),
                Provider.value(value: _analyzerController),
                Provider.value(value: _model),
              ],
              child: SessionView(
                initialPrompt: prompt,
                initialResponse: responseText,
                childData: childData,
              ),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error starting session: $e');
      setState(() {
        _errorMessage = 'Error starting session: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final colorProvider = Provider.of<ColorProvider>(context);
    final primaryColor = colorProvider.primaryColor;
    final isDark = themeProvider.isDarkMode;

    return Theme(
      data: themeProvider.currentTheme,
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          title: const Text('Start Therapy Session'),
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [Colors.grey[900]!, Colors.black]
                    : [primaryColor, primaryColor.withOpacity(0.9)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isLoading)
                  const CircularProgressIndicator()
                else
                  ElevatedButton.icon(
                    onPressed: _startSession,
                    icon: const Icon(Icons.play_circle_outline),
                    label: const Text('Start Session'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? Colors.grey[800] : primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red),
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

