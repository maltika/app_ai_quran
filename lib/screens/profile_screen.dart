import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/firestore_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  int _calculateLevel(int xp) => (xp ~/ 100) + 1;
  int _xpForNextLevel(int xp) => 100 - (xp % 100);

  // คำนวณเหรียญรางวัลจากข้อมูลผู้ใช้
  List<Achievement> _calculateAchievements(Map<String, dynamic> userData, List<Map<String, dynamic>> historyData) {
    final totalXp = userData["totalXp"] ?? 0;
    final level = _calculateLevel(totalXp);
    final excellentCount = historyData.where((h) => (h["result"] ?? "").contains("ดีเยี่ยม")).length;
    final totalExercises = historyData.length;
    
    List<Achievement> achievements = [
      // Level-based achievements
      Achievement(
        id: "first_step", 
        title: "ก้าวแรก", 
        description: "เริ่มต้นการฝึกครั้งแรก",
        icon: Icons.play_arrow,
        color: Colors.blue,
        isUnlocked: totalExercises > 0
      ),
      Achievement(
        id: "bronze_level", 
        title: "ระดับบรอนซ์", 
        description: "ถึงเลเวล 5",
        icon: Icons.workspace_premium,
        color: const Color(0xFFCD7F32),
        isUnlocked: level >= 5
      ),
      Achievement(
        id: "silver_level", 
        title: "ระดับเงิน", 
        description: "ถึงเลเวล 10",
        icon: Icons.military_tech,
        color: Colors.grey[400]!,
        isUnlocked: level >= 10
      ),
      Achievement(
        id: "gold_level", 
        title: "ระดับทอง", 
        description: "ถึงเลเวล 20",
        icon: Icons.emoji_events,
        color: Colors.amber,
        isUnlocked: level >= 20
      ),
      
      // Performance-based achievements
      Achievement(
        id: "perfectionist", 
        title: "นักสมบูรณ์แบบ", 
        description: "ได้คะแนนดีเยี่ยม 5 ครั้ง",
        icon: Icons.star,
        color: Colors.purple,
        isUnlocked: excellentCount >= 5
      ),
      Achievement(
        id: "consistent", 
        title: "นักฝึกมั่นคง", 
        description: "ฝึกครบ 10 ครั้ง",
        icon: Icons.fitness_center,
        color: Colors.green,
        isUnlocked: totalExercises >= 10
      ),
      Achievement(
        id: "master", 
        title: "ปรมาจารย์", 
        description: "ได้คะแนนดีเยี่ยม 20 ครั้ง",
        icon: Icons.school,
        color: Colors.indigo,
        isUnlocked: excellentCount >= 20
      ),
      Achievement(
        id: "veteran", 
        title: "ผู้ชำนาญการ", 
        description: "ฝึกครบ 50 ครั้ง",
        icon: Icons.local_fire_department,
        color: Colors.red,
        isUnlocked: totalExercises >= 50
      ),
    ];
    
    return achievements;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF4CAF50), // สีเขียว
              Color(0xFF81C784), // สีเขียวอ่อน
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Custom App Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                    ),
                    const Expanded(
                      child: Text(
                        "โปรไฟล์",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 48), // Balance the back button
                  ],
                ),
              ),
              
              // Main Content
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(top: 20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: StreamBuilder<DocumentSnapshot>(
                    stream: FirestoreService().getUserStream(),
                    builder: (context, userSnapshot) {
                      if (!userSnapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF4CAF50),
                          ),
                        );
                      }

                      final userData = userSnapshot.data!.data() as Map<String, dynamic>? ?? {};
                      final totalXp = userData["totalXp"] ?? 0;
                      final level = _calculateLevel(totalXp);

                      return StreamBuilder<QuerySnapshot>(
                        stream: FirestoreService().getHistory(),
                        builder: (context, historySnapshot) {
                          final historyData = historySnapshot.hasData 
                            ? historySnapshot.data!.docs.map((doc) => doc.data() as Map<String, dynamic>).toList()
                            : <Map<String, dynamic>>[];
                          
                          final achievements = _calculateAchievements(userData, historyData);
                          final unlockedAchievements = achievements.where((a) => a.isUnlocked).length;

                          return SingleChildScrollView(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                const SizedBox(height: 20),
                                
                                // Profile Avatar
                                Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.green.withOpacity(0.3),
                                        blurRadius: 20,
                                        offset: const Offset(0, 10),
                                      ),
                                    ],
                                  ),
                                  child: CircleAvatar(
                                    radius: 50,
                                    backgroundColor: const Color(0xFF4CAF50),
                                    child: const Icon(
                                      Icons.person,
                                      size: 60,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                
                                // User Email
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.green.withOpacity(0.2)),
                                  ),
                                  child: Text(
                                    user?.email ?? "ไม่ทราบ",
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF2E7D32),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 30),
                                
                                // Level & XP Card
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF4CAF50), Color(0xFF388E3C)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.green.withOpacity(0.3),
                                        blurRadius: 15,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                "เลเวล",
                                                style: TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              Text(
                                                "$level",
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 32,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              const Text(
                                                "คะแนนรวม",
                                                style: TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              Row(
                                                children: [
                                                  const Icon(Icons.star, color: Colors.yellow, size: 20),
                                                  const SizedBox(width: 5),
                                                  Text(
                                                    "$totalXp XP",
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 24,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 20),
                                      
                                      // Progress Bar
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              const Text(
                                                "ความคืบหน้าเลเวลถัดไป",
                                                style: TextStyle(color: Colors.white70, fontSize: 12),
                                              ),
                                              Text(
                                                "อีก ${_xpForNextLevel(totalXp)} XP",
                                                style: const TextStyle(color: Colors.white, fontSize: 12),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(10),
                                            child: LinearProgressIndicator(
                                              value: (totalXp % 100) / 100,
                                              backgroundColor: Colors.white.withOpacity(0.3),
                                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                              minHeight: 8,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 30),
                                
                                // Achievements Section
                                Row(
                                  children: [
                                    Icon(Icons.emoji_events, color: Colors.amber[700], size: 24),
                                    const SizedBox(width: 10),
                                    Text(
                                      "เหรียญรางวัล",
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green[800],
                                      ),
                                    ),
                                    const Spacer(),
                                    GestureDetector(
                                      onTap: () {
                                        // Navigate to full achievements page
                                        // Navigator.push(context, MaterialPageRoute(builder: (context) => AchievementsScreen()));
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(15),
                                          border: Border.all(color: Colors.amber.withOpacity(0.3)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              "$unlockedAchievements/${achievements.length}",
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.amber[800],
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Icon(
                                              Icons.arrow_forward_ios,
                                              size: 12,
                                              color: Colors.amber[800],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 15),
                                
                                // Achievements Horizontal List
                                if (achievements.where((a) => a.isUnlocked).isEmpty)
                                  Container(
                                    height: 100,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[50],
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.grey[200]!),
                                    ),
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.lock_outline, color: Colors.grey[400], size: 32),
                                          const SizedBox(height: 8),
                                          Text(
                                            "เริ่มฝึกเพื่อรับเหรียญรางวัล",
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                else
                                  SizedBox(
                                    height: 100,
                                    child: ListView.builder(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: achievements.where((a) => a.isUnlocked).length,
                                      itemBuilder: (context, index) {
                                        final unlockedAchievements = achievements.where((a) => a.isUnlocked).toList();
                                        final achievement = unlockedAchievements[index];
                                        return Container(
                                          width: 90,
                                          margin: const EdgeInsets.only(right: 12),
                                          child: CompactAchievementCard(achievement: achievement),
                                        );
                                      },
                                    ),
                                  ),
                                const SizedBox(height: 30),
                                
                                // History Section Header
                                Row(
                                  children: [
                                    Icon(Icons.history, color: Colors.green[700], size: 24),
                                    const SizedBox(width: 10),
                                    Text(
                                      "ประวัติการฝึก",
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green[800],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 15),
                                
                                // History List
                                if (!historySnapshot.hasData)
                                  const Center(
                                    child: CircularProgressIndicator(
                                      color: Color(0xFF4CAF50),
                                    ),
                                  )
                                else if (historySnapshot.data!.docs.isEmpty)
                                  Container(
                                    padding: const EdgeInsets.all(40),
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.history_edu,
                                          size: 60,
                                          color: Colors.grey[400],
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          "ยังไม่มีประวัติการฝึก",
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  ListView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: historySnapshot.data!.docs.length,
                                    itemBuilder: (context, index) {
                                      final data = historySnapshot.data!.docs[index].data() as Map<String, dynamic>;
                                      final isExcellent = (data["result"] ?? "").contains("ดีเยี่ยม");
                                      
                                      return Container(
                                        margin: const EdgeInsets.only(bottom: 12),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(15),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.grey.withOpacity(0.1),
                                              blurRadius: 8,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                          border: Border.all(
                                            color: isExcellent 
                                              ? Colors.green.withOpacity(0.3) 
                                              : Colors.orange.withOpacity(0.3),
                                          ),
                                        ),
                                        child: ListTile(
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                          leading: Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: isExcellent 
                                                ? Colors.green.withOpacity(0.1) 
                                                : Colors.orange.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Icon(
                                              isExcellent ? Icons.check_circle : Icons.fitness_center,
                                              color: isExcellent ? Colors.green : Colors.orange,
                                              size: 24,
                                            ),
                                          ),
                                          title: Text(
                                            data["type"] ?? "-",
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 16,
                                            ),
                                          ),
                                          subtitle: Padding(
                                            padding: const EdgeInsets.only(top: 4),
                                            child: Text(
                                              "ผล: ${data["result"] ?? "-"}",
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                          trailing: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              gradient: const LinearGradient(
                                                colors: [Color(0xFF4CAF50), Color(0xFF388E3C)],
                                              ),
                                              borderRadius: BorderRadius.circular(15),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.star, color: Colors.yellow, size: 16),
                                                const SizedBox(width: 4),
                                                Text(
                                                  "+${data["xpGained"] ?? 0}",
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Achievement Model
class Achievement {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final bool isUnlocked;

  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.isUnlocked,
  });
}

// Compact Achievement Card Widget for horizontal scroll
class CompactAchievementCard extends StatelessWidget {
  final Achievement achievement;

  const CompactAchievementCard({super.key, required this.achievement});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            achievement.color.withOpacity(0.15),
            achievement.color.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: achievement.color.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: achievement.color.withOpacity(0.2),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Achievement Icon
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: achievement.color.withOpacity(0.2),
              ),
              child: Icon(
                achievement.icon,
                size: 24,
                color: achievement.color,
              ),
            ),
            const SizedBox(height: 6),
            
            // Achievement Title
            Text(
              achievement.title,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: achievement.color,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}