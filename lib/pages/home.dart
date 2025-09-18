import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/config/config.dart';
import 'package:flutter_application_1/pages/checkReward.dart';
import 'package:flutter_application_1/pages/lottoHistory.dart';
import 'package:flutter_application_1/pages/profile.dart';
import 'package:http/http.dart' as http;

class HomePage extends StatefulWidget {
  final bool isAdmin; // กำหนดว่าเป็น admin หรือไม่
  const HomePage({super.key, this.isAdmin = false});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String url = "";
  bool isLoadingConfig = true;
  bool isLoadingTickets = true;
  bool currentDrawOpen = false; // สถานะงวดปัจจุบัน

  final List<Map<String, dynamic>> lottoList = [];

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final config = await AppConfig.load();
    setState(() {
      url = config.apiEndpoint;
      isLoadingConfig = false;
    });

    await fetchTickets();
  }

  // สร้างงวดใหม่
  Future<String> createLottoDraw() async {
    if (!widget.isAdmin) return "คุณไม่มีสิทธิ์สร้างงวดใหม่";
    if (currentDrawOpen) return "ยังมีงวดที่เปิดอยู่ ไม่สามารถสร้างใหม่ได้";

    try {
      final response = await http.post(Uri.parse("$url/tickets/draws"));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // ดึงเลขของ draw ล่าสุดจาก API
        await fetchTickets(); // fetchTickets() จะกรองเฉพาะ draw ล่าสุด status = active

        return "สร้างงวดใหม่สำเร็จ (ID: ${data['drawId']})";
      } else {
        return "สร้างงวดไม่สำเร็จ (${response.statusCode})";
      }
    } catch (e) {
      return "เกิดข้อผิดพลาด: $e";
    }
  }

  // ปิดการซื้อขาย
  Future<void> closeCurrentDraw() async {
    if (!widget.isAdmin || !currentDrawOpen) return;

    try {
      final drawId = lottoList.isNotEmpty ? lottoList.first['round'] : null;
      if (drawId == null) return;

      final response =
          await http.post(Uri.parse("$url/tickets/draws/$drawId/close"));
      if (response.statusCode == 200) {
        setState(() {
          currentDrawOpen = false;
          lottoList.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("ปิดการซื้อขายเรียบร้อย")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("ปิดการซื้อขายไม่สำเร็จ (${response.statusCode})")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("เกิดข้อผิดพลาด: $e")),
      );
    }
  }

  // ดึงเลขล็อตโต้ล่าสุด (เฉพาะ draw ที่ status = active)
  Future<void> fetchTickets() async {
    if (url.isEmpty) return;
    setState(() {
      isLoadingTickets = true;
    });

    try {
      final response = await http.get(Uri.parse("$url/tickets"));
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);

        if (data.isNotEmpty) {
          // หา draw_id ล่าสุด
          final latestDrawId = data
              .map((item) => item['draw_id'] as int)
              .reduce((a, b) => a > b ? a : b);

          // เลือก ticket ของ draw ล่าสุด
          final latestTickets =
              data.where((item) => item['draw_id'] == latestDrawId);

          setState(() {
            lottoList.clear();
            lottoList.addAll(latestTickets.map((item) => {
                  'number': item['ticket_number'],
                  'price': item['price'],
                  'status':
                      item['status'] == 'available' ? 'มีอยู่' : 'ซื้อแล้ว',
                  'round': item['draw_id'],
                }));
            // ตรวจสอบว่างวดล่าสุดยังเปิดขายหรือไม่
            currentDrawOpen =
                lottoList.any((item) => item['status'] == 'มีอยู่');
          });
        } else {
          setState(() {
            lottoList.clear();
            currentDrawOpen = false;
          });
        }
      }
    } catch (e) {
      print("Error fetchTickets: $e");
    } finally {
      setState(() {
        isLoadingTickets = false;
      });
    }
  }

  void buyData(int index) {
    setState(() {
      if (lottoList[index]['status'] == 'มีอยู่' && currentDrawOpen) {
        lottoList[index]['status'] = 'ซื้อแล้ว';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Image.network(
          'https://raw.githubusercontent.com/FarmHouse2263/lotto/refs/heads/main/image%202.png',
          height: 30,
          width: 80,
          fit: BoxFit.cover,
        ),
      ),
      body: SafeArea(
        child: isLoadingConfig
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header + ปุ่มตรวจรางวัล + ปุ่ม admin
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'LOTTO',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                            ),
                          ),
                          Row(
                            children: [
                              TextButton(
                                style: TextButton.styleFrom(
                                  backgroundColor: Colors.orange[200],
                                  foregroundColor: Colors.black,
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          CheckRewardPage(loctoList: lottoList),
                                    ),
                                  );
                                },
                                child: const Text('ตรวจรางวัล'),
                              ),
                              const SizedBox(width: 8),
                              if (widget.isAdmin) ...[
                                TextButton(
                                  style: TextButton.styleFrom(
                                    backgroundColor: currentDrawOpen
                                        ? Colors.grey
                                        : Colors.green[200],
                                    foregroundColor: Colors.black,
                                  ),
                                  onPressed: currentDrawOpen
                                      ? null
                                      : () async {
                                          final result =
                                              await createLottoDraw();
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(content: Text(result)),
                                            );
                                          }
                                        },
                                  child: const Text('สร้าง Lotto'),
                                ),
                                const SizedBox(width: 8),
                                TextButton(
                                  style: TextButton.styleFrom(
                                    backgroundColor: currentDrawOpen
                                        ? Colors.red[200]
                                        : Colors.grey,
                                    foregroundColor: Colors.black,
                                  ),
                                  onPressed:
                                      currentDrawOpen ? closeCurrentDraw : null,
                                  child: const Text('ปิดการซื้อขาย'),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // แสดงเลขล็อตโต้ หรือข้อความเมื่อไม่มี draw active
                    if (isLoadingTickets)
                      const Center(child: CircularProgressIndicator())
                    else if (lottoList.isEmpty)
                      const Center(
                        child: Text(
                          'ยังไม่มีการซื้อขาย หรือกำลังประกาศรางวัล',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                      )
                    else
                      ...lottoList.map(
                        (item) => Container(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color.fromARGB(255, 232, 232, 232),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'เลขหวย: ${item["number"]}',
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'ราคา: ${item["price"]}',
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'สถานะ: ${item["status"]}',
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'งวดที่: ${item["round"]}',
                                    style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600),
                                  ),
                                  FilledButton(
                                    onPressed: item['status'] == 'มีอยู่' &&
                                            currentDrawOpen
                                        ? () => buyData(lottoList.indexOf(item))
                                        : null,
                                    style: FilledButton.styleFrom(
                                      backgroundColor:
                                          item['status'] == 'มีอยู่' &&
                                                  currentDrawOpen
                                              ? Colors.lightGreenAccent
                                              : Colors.grey,
                                      foregroundColor: Colors.black,
                                    ),
                                    child: Text(
                                      item['status'] == 'มีอยู่' &&
                                              currentDrawOpen
                                          ? 'ซื้อ'
                                          : 'ซื้อแล้ว',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: Colors.purple[300],
        unselectedItemColor: Colors.grey[600],
        onTap: (index) {
          if (index == 0) {
            // อยู่หน้า Home
          } else if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => CheckRewardPage(loctoList: lottoList)),
            );
          } else if (index == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const CheckRewardHistoryPage()),
            );
          } else if (index == 3) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfilePage()),
            );
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long), label: 'ตรวจหวย'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'ประวัติ'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
