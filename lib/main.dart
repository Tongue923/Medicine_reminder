import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'login_screen.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

void main() {
  tz.initializeTimeZones();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Medicine Reminder App',
      theme: ThemeData(
        primarySwatch: Colors.green,
      ),
      home: LoginScreen(),
    );
  }
}

class ReminderScreen extends StatefulWidget {
  final String username;
  ReminderScreen({required this.username});

  @override
  _ReminderScreenState createState() => _ReminderScreenState();
}

class _ReminderScreenState extends State<ReminderScreen> {
  final AudioPlayer audioPlayer = AudioPlayer();
  List<Reminder> reminders = [];
  List<Reminder> activeReminders = [];
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _medicineNameController = TextEditingController();
  final TextEditingController _pillAmountController = TextEditingController();
  final TextEditingController _durationAmountController =
      TextEditingController();
  TimeOfDay? _selectedTime;
  String _duration = 'Days';
  String _mealTime = 'Before Meal';
  bool _isAlarmPlaying = false;
  String? _alarmFilePath;
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _loadAlarmFile();
    _requestPermissions();
    _initializeNotifications();
    _loadReminders();
  }

  Future<void> _requestPermissions() async {
    if (await Permission.storage.isDenied) {
      await Permission.storage.request();
    }
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
  }

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings();
    final InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> _loadAlarmFile() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/alarm.mp3';
    final file = File(path);
    if (!file.existsSync()) {
      final data = await rootBundle.load('assets/alarm.mp3');
      final bytes = data.buffer.asUint8List();
      await file.writeAsBytes(bytes, flush: true);
    }
    setState(() {
      _alarmFilePath = path;
    });
  }

  void _playAlarm(List<Reminder> remindersToPlay) {
    if (_alarmFilePath != null) {
      audioPlayer.play(DeviceFileSource(_alarmFilePath!));
      _showNotification();
      setState(() {
        _isAlarmPlaying = true;
        activeReminders = remindersToPlay;
      });
    }
  }

  void _stopAlarm() {
    audioPlayer.stop();
    List<Reminder> updatedReminders = [];
    setState(() {
      for (var reminder in activeReminders) {
        reminder.durationAmount--;
        updatedReminders.add(reminder);
        if (reminder.durationAmount <= 0) {
          reminders.remove(reminder);
        }
      }
      _saveReminders();
      _isAlarmPlaying = false;
      _showMedicineDialog(updatedReminders);
      activeReminders.clear();
    });
  }

  Future<void> _scheduleAlarm(Reminder reminder) async {
    final now = DateTime.now();
    final scheduledTime = DateTime(
      now.year,
      now.month,
      now.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );
    final duration = scheduledTime.difference(now);
    if (duration.isNegative) {
      // If the time is in the past, schedule it for the next day
      final nextDayScheduledTime = scheduledTime.add(Duration(days: 1));
      final nextDayDuration = nextDayScheduledTime.difference(now);
      Timer(nextDayDuration, () => _triggerAlarms(nextDayScheduledTime));
    } else {
      Timer(duration, () => _triggerAlarms(scheduledTime));
    }
  }

  void _triggerAlarms(DateTime scheduledTime) {
    final remindersToPlay = reminders.where((reminder) {
      final reminderTime = TimeOfDay(
        hour: int.parse(reminder.time.split(":")[0]),
        minute: int.parse(reminder.time.split(":")[1].split(" ")[0]),
      );
      return reminderTime.hour == scheduledTime.hour &&
          reminderTime.minute == scheduledTime.minute;
    }).toList();

    if (remindersToPlay.isNotEmpty) {
      _playAlarm(remindersToPlay);
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  int _convertDurationToDays(int amount, String durationType) {
    switch (durationType) {
      case 'Days':
        return amount;
      case 'Weeks':
        return amount * 7;
      case 'Months':
        return amount * 30;
      case 'Years':
        return amount * 365;
      default:
        return amount;
    }
  }

  void _addReminder() {
    if (_formKey.currentState!.validate()) {
      if (_selectedTime == null) {
        _showError('Please select a reminder time');
        return;
      }

      final durationAmount = int.parse(_durationAmountController.text);
      final totalDays = _convertDurationToDays(durationAmount, _duration);

      final newReminder = Reminder(
        id: DateTime.now().millisecondsSinceEpoch,
        name: _medicineNameController.text,
        pillAmount: int.parse(_pillAmountController.text),
        time: _selectedTime!.format(context),
        durationAmount: totalDays,
        duration: _duration,
        mealTime: _mealTime,
      );

      setState(() {
        reminders.add(newReminder);
      });

      _saveReminders();
      _scheduleAlarm(newReminder);
      _medicineNameController.clear();
      _pillAmountController.clear();
      _durationAmountController.clear();
      _selectedTime = null;
    }
  }

  void _removeReminder(Reminder reminder) {
    setState(() {
      reminders.remove(reminder);
    });
    _saveReminders();
  }

  Future<void> _saveReminders() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> reminderJsonList =
        reminders.map((r) => jsonEncode(r.toJson())).toList();
    await prefs.setStringList('reminders_${widget.username}', reminderJsonList);
  }

  Future<void> _loadReminders() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? reminderJsonList =
        prefs.getStringList('reminders_${widget.username}');
    if (reminderJsonList != null) {
      setState(() {
        reminders = reminderJsonList
            .map((r) => Reminder.fromJson(jsonDecode(r)))
            .toList();
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, style: TextStyle(color: Colors.red))),
    );
  }

  Future<void> _showNotification() async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'your_channel_id',
      'your_channel_name',
      channelDescription: 'your_channel_description',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: false,
    );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await flutterLocalNotificationsPlugin.show(
      0,
      'Medicine Reminder',
      "It's time to take your medicine",
      platformChannelSpecifics,
      payload: 'reminder',
    );
  }

  void _showMedicineDialog(List<Reminder> reminders) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Medicine Reminder'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Medicines you need to take:'),
              ...reminders
                  .map((reminder) => Text(
                      '${reminder.name} (${reminder.mealTime}) - ${reminder.durationAmount} days left'))
                  .toList(),
            ],
          ),
          actions: [
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('username');
    await prefs.remove('password');
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Medicine Reminder'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _medicineNameController,
                    decoration: InputDecoration(labelText: 'Medicine Name'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter medicine name';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: _pillAmountController,
                    decoration: InputDecoration(labelText: 'Amount of Pills'),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter amount of pills';
                      }
                      return null;
                    },
                  ),
                  ListTile(
                    title: Text(
                        'Reminder Time: ${_selectedTime?.format(context) ?? 'Not set'}'),
                    trailing: Icon(Icons.access_time),
                    onTap: () => _selectTime(context),
                  ),
                  TextFormField(
                    controller: _durationAmountController,
                    decoration: InputDecoration(labelText: 'Duration Amount'),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter duration amount';
                      }
                      return null;
                    },
                  ),
                  DropdownButtonFormField<String>(
                    value: _duration,
                    decoration: InputDecoration(labelText: 'Duration'),
                    onChanged: (value) {
                      setState(() {
                        _duration = value!;
                      });
                    },
                    items: [
                      DropdownMenuItem(value: 'Days', child: Text('Days')),
                      DropdownMenuItem(value: 'Weeks', child: Text('Weeks')),
                      DropdownMenuItem(value: 'Months', child: Text('Months')),
                      DropdownMenuItem(value: 'Years', child: Text('Years')),
                    ],
                  ),
                  DropdownButtonFormField<String>(
                    value: _mealTime,
                    decoration: InputDecoration(labelText: 'Meal Time'),
                    onChanged: (value) {
                      setState(() {
                        _mealTime = value!;
                      });
                    },
                    items: [
                      DropdownMenuItem(
                          value: 'Before Meal', child: Text('Before Meal')),
                      DropdownMenuItem(
                          value: 'After Meal', child: Text('After Meal')),
                    ],
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _addReminder,
                    child: Text('Add Reminder'),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: reminders.length,
                itemBuilder: (context, index) {
                  final reminder = reminders[index];
                  return ListTile(
                    title: Text(reminder.name),
                    subtitle: Text(
                        '${reminder.pillAmount} pills at ${reminder.time}, ${reminder.mealTime} meal for ${reminder.durationAmount} days'),
                    trailing: IconButton(
                      icon: Icon(Icons.delete),
                      onPressed: () => _removeReminder(reminder),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _isAlarmPlaying
          ? FloatingActionButton(
              onPressed: _stopAlarm,
              child: Icon(Icons.stop),
              backgroundColor: Colors.red,
            )
          : null,
    );
  }
}

class Reminder {
  final int id;
  final String name;
  final int pillAmount;
  final String time;
  final String duration;
  int durationAmount;
  final String mealTime;

  Reminder({
    required this.id,
    required this.name,
    required this.pillAmount,
    required this.time,
    required this.duration,
    required this.durationAmount,
    required this.mealTime,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'pillAmount': pillAmount,
      'time': time,
      'duration': duration,
      'durationAmount': durationAmount,
      'mealTime': mealTime,
    };
  }

  factory Reminder.fromJson(Map<String, dynamic> json) {
    return Reminder(
      id: json['id'],
      name: json['name'],
      pillAmount: json['pillAmount'],
      time: json['time'],
      duration: json['duration'],
      durationAmount: json['durationAmount'],
      mealTime: json['mealTime'],
    );
  }
}
