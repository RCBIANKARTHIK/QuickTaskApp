import 'dart:async';
import 'package:flutter/material.dart';
import 'package:parse_server_sdk/parse_server_sdk.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final keyApplicationId = '34S9GhJXjzyIayTAMOQmNrS8xNrz7KIVU7fFWmvj';
  final keyClientKey = 'jdQgcdCEF2mq2Ov4eF7oXoMI1309ki8SQJBsT5HD';
  final keyParseServerUrl = 'https://parseapi.back4app.com';

  await Parse().initialize(
    keyApplicationId,
    keyParseServerUrl,
    clientKey: keyClientKey,
    autoSendSessionId: true,
    liveQueryUrl: 'mybitsassignment.b4a.io',
    debug: true,
  );
  runApp(const MaterialApp(
    home: Home(),
  ));
}

class Home extends StatefulWidget {
  const Home({Key? key}) : super(key: key);

  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  List<ParseObject> taskList = [];
  late StreamController<List<ParseObject>> streamController;
  late LiveQuery liveQuery;
  late Subscription<ParseObject> subscription;
  Color _deleteIconColor = Colors.red;
  bool showCompletedTasks = true;

  @override
  void initState() {
    super.initState();
    streamController = StreamController<List<ParseObject>>();
    liveQuery = LiveQuery(debug: true);
    getTaskList();
    startLiveQuery();
  }

  void startLiveQuery() async {
    final QueryBuilder<ParseObject> queryTask = QueryBuilder<ParseObject>(ParseObject('Task'))
      ..orderByDescending('completedAt')
      ..orderByDescending('createdAt')
      ..setAmountToSkip(0);

    subscription = await liveQuery.client.subscribe(queryTask);

    subscription.on(LiveQueryEvent.create, (value) {
      debugPrint('*** CREATE ***: $value ');
      taskList.add(value);
      streamController.add(taskList);
    });

    subscription.on(LiveQueryEvent.update, (value) {
      debugPrint('*** UPDATE ***: $value ');
      taskList[taskList.indexWhere((element) => element.objectId == value.objectId)] = value;
      streamController.add(taskList);
    });

    subscription.on(LiveQueryEvent.delete, (value) {
      debugPrint('*** DELETE ***: $value ');
      taskList.removeWhere((element) => element.objectId == value.objectId);
      streamController.add(taskList);
    });
  }

  void cancelLiveQuery() async {
    liveQuery.client.unSubscribe(subscription);
  }

  Future<void> saveTask(String title, String description) async {
    final task = ParseObject('Task')
      ..set('title', title)
      ..set('description', description)
      ..set('done', false);
    await task.save();
  }

  Future<void> getTaskList() async {
    setState(() {
      taskList.clear();
    });

    final QueryBuilder<ParseObject> queryTask = QueryBuilder<ParseObject>(ParseObject('Task'))
      ..orderByDescending('completedAt')
      ..orderByDescending('createdAt')
      ..setAmountToSkip(0);

    final ParseResponse apiResponse = await queryTask.query();

    if (apiResponse.success && apiResponse.results != null) {
      taskList = List<ParseObject>.from(apiResponse.results as List<ParseObject>);
      streamController.add(taskList);
    }
  }

  Future<void> updateTask(String id, bool done) async {
    var task = ParseObject('Task')
      ..objectId = id;

    if (done) {
      // Set the completed timestamp when the task is marked as done
      task..set('done', done)..set('completedAt', DateTime.now());
    } else {
      task..set('done', done);
    }

    await task.save();
    getTaskList();
  }

  Future<void> deleteTask(String id) async {
    var task = ParseObject('Task')..objectId = id;
    await task.delete();
    getTaskList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Get it done...BOSS!"),
        backgroundColor: Colors.blueAccent,
        centerTitle: true,
        actions: [
          PopupMenuButton(
            icon: Icon(Icons.filter_list),
            itemBuilder: (context) => [
              PopupMenuItem(
                child: ListTile(
                  title: Text("Completed Tasks"),
                  trailing: Checkbox(
                    value: showCompletedTasks,
                    onChanged: (value) {
                      setState(() {
                        showCompletedTasks = value!;
                        getTaskList(); // Refresh the task list based on the new filter status
                        Navigator.pop(context); // Close the menu and go back
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      body: StreamBuilder<List<ParseObject>>(
        stream: streamController.stream,
        builder: (context, snapshot) {
          switch (snapshot.connectionState) {
            case ConnectionState.none:
            case ConnectionState.waiting:
              return const Center(
                child: SizedBox(
                  width: 100,
                  height: 100,
                  child: CircularProgressIndicator(),
                ),
              );
            default:
              if (snapshot.hasError) {
                return const Center(
                  child: Text("Error..."),
                );
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(
                  child: Text("Loading..."),
                );
              } else {
                // Filter tasks based on completion status
                final filteredTasks = snapshot.data!.where((task) => showCompletedTasks || !task.get<bool>('done')!).toList();

                return Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.only(top: 10.0),
                        itemCount: filteredTasks.length,
                        itemBuilder: (context, index) {
                          final varTask = filteredTasks[index];
                          final varTitle = varTask.get<String>('title')!;
                          final varDescription = varTask.get<String>('description')!;
                          final varDone = varTask.get<bool>('done')!;
                          final createdAt = varTask.get<DateTime>('createdAt');
                          final completedAt = varTask.get<DateTime>('completedAt');

                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => EditTaskScreen(
                                    taskId: varTask.objectId!,
                                    initialTitle: varTask.get<String>('title')!,
                                    initialDescription: varTask.get<String>('description')!,
                                  ),
                                ),
                              ).then((value) {
                                if (value == true) {
                                  getTaskList();
                                }
                              });
                            },
                            child: ListTile(
                              title: Text(varTitle),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(varDescription),
                                  Text(
                                    varDone
                                        ? 'Completed At: ${completedAt?.toLocal()}'
                                        : 'Created At: ${createdAt?.toLocal()}',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                              leading: AnimatedContainer(
                                duration: Duration(milliseconds: 500),
                                curve: Curves.easeInOut,
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: varDone ? Colors.green : Colors.blue,
                                ),
                                child: Icon(
                                  varDone ? Icons.check : Icons.error,
                                  color: Colors.white,
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Checkbox(
                                    value: varDone,
                                    onChanged: (value) async {
                                      await updateTask(varTask.objectId!, value!);
                                    },
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30.0),
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () async {
                                      await deleteTask(varTask.objectId!);
                                      const snackBar = SnackBar(
                                        content: Text("Task deleted!"),
                                        duration: Duration(seconds: 2),
                                      );
                                      ScaffoldMessenger.of(context)
                                        ..removeCurrentSnackBar()
                                        ..showSnackBar(snackBar);
                                    },
                                    child: MouseRegion(
                                      cursor: SystemMouseCursors.click,
                                      child: AnimatedContainer(
                                        duration: Duration(milliseconds: 300),
                                        padding: EdgeInsets.all(8.0),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: _deleteIconColor,
                                        ),
                                        child: Icon(
                                          Icons.delete,
                                          color: Colors.white,
                                        ),
                                      ),
                                      onEnter: (_) {
                                        setState(() {
                                          _deleteIconColor = Colors.red;
                                        });
                                      },
                                      onExit: (_) {
                                        setState(() {
                                          _deleteIconColor = Colors.red;
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              }
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AddTaskScreen()),
          ).then((value) {
            if (value == true) {
              getTaskList();
            }
          });
        },
        child: Icon(Icons.add),
      ),
    );
  }

  @override
  void dispose() {
    cancelLiveQuery();
    streamController.close();
    super.dispose();
  }
}

class EditTaskScreen extends StatefulWidget {
  final String taskId;
  final String initialTitle;
  final String initialDescription;

  const EditTaskScreen({
    required this.taskId,
    required this.initialTitle,
    required this.initialDescription,
    Key? key,
  }) : super(key: key);

  @override
  _EditTaskScreenState createState() => _EditTaskScreenState();
}

class _EditTaskScreenState extends State<EditTaskScreen> {
  late TextEditingController taskController;
  late TextEditingController descriptionController;

  @override
  void initState() {
    super.initState();
    taskController = TextEditingController(text: widget.initialTitle);
    descriptionController = TextEditingController(text: widget.initialDescription);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Task"),
        backgroundColor: Colors.blueAccent,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              autocorrect: true,
              textCapitalization: TextCapitalization.sentences,
              controller: taskController,
              decoration: const InputDecoration(
                labelText: "Task Title",
                labelStyle: TextStyle(color: Colors.blueAccent),
              ),
            ),
            TextField(
              autocorrect: true,
              textCapitalization: TextCapitalization.sentences,
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: "Task Description",
                labelStyle: TextStyle(color: Colors.blueAccent),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                onPrimary: Colors.white,
                primary: Colors.blueAccent,
              ),
              onPressed: () async {
                await saveTask(widget.taskId, taskController.text, descriptionController.text);
                Navigator.pop(context, true);
              },
              child: const Text("SAVE"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> saveTask(String taskId, String title, String description) async {
    final task = ParseObject('Task')
      ..objectId = taskId
      ..set('title', title)
      ..set('description', description)
      ..set('done', false);
    await task.save();
  }
}

class AddTaskScreen extends StatefulWidget {
  const AddTaskScreen({Key? key}) : super(key: key);

  @override
  _AddTaskScreenState createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final taskController = TextEditingController();
  final descriptionController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Add Task"),
        backgroundColor: Colors.blueAccent,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              autocorrect: true,
              textCapitalization: TextCapitalization.sentences,
              controller: taskController,
              decoration: const InputDecoration(
                labelText: "Task Title",
                labelStyle: TextStyle(color: Colors.blueAccent),
              ),
            ),
            TextField(
              autocorrect: true,
              textCapitalization: TextCapitalization.sentences,
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: "Task Description",
                labelStyle: TextStyle(color: Colors.blueAccent),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                onPrimary: Colors.white,
                primary: Colors.blueAccent,
              ),
              onPressed: () async {
                await saveTask(taskController.text, descriptionController.text);
                Navigator.pop(context, true);
              },
              child: const Text("ADD"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> saveTask(String title, String description) async {
    final task = ParseObject('Task')
      ..set('title', title)
      ..set('description', description)
      ..set('done', false);
    await task.save();
  }
}
