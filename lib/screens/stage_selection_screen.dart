// import 'package:flutter/material.dart';
// import 'minigame_screen.dart';

// class StageSelectionScreen extends StatelessWidget {
//   const StageSelectionScreen({super.key});

//   final List<Map<String, dynamic>> stages = const [
//     {"name": "หมู่บ้านตัวอักษร", "type": "alphabet", "sub": 3},
//     {"name": "โอเอซิสแห่งสระ", "type": "vowel", "sub": 5},
//     {"name": "นครแห่งอายะห์", "type": "ayah", "sub": 2},
//   ];

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text("เลือกด่าน")),
//       body: ListView.builder(
//         itemCount: stages.length,
//         itemBuilder: (context, index) {
//           final stage = stages[index];
//           return ListTile(
//             title: Text(stage['name']),
//             subtitle: Text('ด่านย่อย ${stage['sub']} ด่าน'),
//             onTap: () {
//               if(stage['type'] == 'ayah'){
//                 // เลือก Surah
//                 final surahs = ['Al-Fatiha','Al-Ikhlas'];
//                 Navigator.push(
//                   context,
//                   MaterialPageRoute(
//                     builder: (_) => MinigameScreen(
//                       gameType: stage['type'],
//                       subStageCount: stage['sub'],
//                       surahName: surahs[0],
//                       totalAyah: 7, // สมมติ Al-Fatiha มี 7 อายะห์
//                     ),
//                   ),
//                 );
//               } else {
//                 Navigator.push(
//                   context,
//                   MaterialPageRoute(
//                     builder: (_) => MinigameScreen(
//                       gameType: stage['type'],
//                       subStageCount: stage['sub'],
//                     ),
//                   ),
//                 );
//               }
//             },
//           );
//         },
//       ),
//     );
//   }
// }
