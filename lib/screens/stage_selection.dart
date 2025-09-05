// import 'package:flutter/material.dart';
// import 'minigame_screen.dart';
// import '../../services/firestore_service.dart';

// class StageSelectionScreen extends StatefulWidget {
//   final String gameType; // "alphabet" หรือ "vowel"
//   const StageSelectionScreen({super.key, required this.gameType});

//   @override
//   State<StageSelectionScreen> createState() => _StageSelectionScreenState();
// }

// class _StageSelectionScreenState extends State<StageSelectionScreen> {
//   late int maxLevel;
//   int unlockedLevel = 1;

//   @override
//   void initState() {
//     super.initState();

//     // กำหนดจำนวนด่านตามชนิดเกม
//     if (widget.gameType == "alphabet") {
//       maxLevel = 3; // ตัวอักษรมี 3 ด่าน
//     } else if (widget.gameType == "vowel") {
//       maxLevel = 5; // สระมี 5 ด่าน
//     }

//     _loadUnlockedLevel();
//   }

//   void _loadUnlockedLevel() async {
//     final stats = await FirestoreService().getUserStats();
//     setState(() {
//       unlockedLevel = stats['level'] ?? 1;
//     });
//   }

//   void _startLevel(int level) async {
//     final result = await Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (_) => MinigameScreen(
//           gameType: widget.gameType,
//           startLevel: level,
//         ),
//       ),
//     );

//     if (result != null && result is int) {
//       setState(() {
//         unlockedLevel = result > unlockedLevel ? result : unlockedLevel;
//       });
//     }
//   }

//   String _getLevelDisplayName(int level) {
//     if (widget.gameType == "alphabet") {
//       switch (level) {
//         case 1:
//           return "อักษร 1–10";
//         case 2:
//           return "อักษร 11–20";
//         case 3:
//           return "อักษร 21–29";
//         default:
//           return "อักษร Level $level";
//       }
//     } else {
//       return "Vowels Level $level";
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text(widget.gameType == "alphabet"
//             ? "เลือกตัวอักษร Level"
//             : "เลือก Vowels Level"),
//         centerTitle: true,
//         backgroundColor: Colors.deepPurple,
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16),
//         child: GridView.builder(
//           gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//               crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 16),
//           itemCount: maxLevel,
//           itemBuilder: (context, index) {
//             int level = index + 1;
//             bool unlocked = level <= unlockedLevel;

//             return GestureDetector(
//               onTap: unlocked ? () => _startLevel(level) : null,
//               child: Stack(
//                 children: [
//                   Container(
//                     decoration: BoxDecoration(
//                       color:
//                           unlocked ? Colors.deepPurple : Colors.grey.shade300,
//                       borderRadius: BorderRadius.circular(20),
//                     ),
//                     child: Center(
//                       child: Text(
//                         _getLevelDisplayName(level),
//                         textAlign: TextAlign.center,
//                         style: TextStyle(
//                           color: unlocked ? Colors.white : Colors.grey.shade600,
//                           fontSize: 18,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                     ),
//                   ),
//                   if (!unlocked)
//                     Positioned.fill(
//                       child: Container(
//                         decoration: BoxDecoration(
//                           color: Colors.black.withOpacity(0.4),
//                           borderRadius: BorderRadius.circular(20),
//                         ),
//                         child: const Center(
//                           child: Icon(
//                             Icons.lock,
//                             color: Colors.white,
//                             size: 40,
//                           ),
//                         ),
//                       ),
//                     ),
//                 ],
//               ),
//             );
//           },
//         ),
//       ),
//     );
//   }
// }
