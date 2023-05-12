import 'package:english_words/english_words.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

void main() async {
  runApp(MyApp());
}

//MyApp
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MyAppState(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Namer App',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
              seedColor: Color.fromARGB(255, 40, 234, 208)),
        ),
        home: MyHomePage(),
      ),
    );
  }
}

class MyAppState extends ChangeNotifier {
  var current = WordPair.random();

  void getNext() {
    current = WordPair.random();
    notifyListeners();
  }
}

//MyHomePage
class MyHomePage extends StatefulWidget {
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  var selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    Widget page;
    switch (selectedIndex) {
      case 0:
        page = GeneratorPage();
        break;
      case 1:
        page = FavoritesPage();
        break;
      default:
        throw UnimplementedError('no widget for $selectedIndex');
    }

    return LayoutBuilder(builder: (context, constraints) {
      return Scaffold(
        body: Row(
          children: [
            SafeArea(
              child: NavigationRail(
                extended: constraints.maxWidth >= 600,
                destinations: [
                  NavigationRailDestination(
                    icon: Icon(Icons.home),
                    label: Text('Home'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.favorite),
                    label: Text('Favorites'),
                  ),
                ],
                selectedIndex: selectedIndex,
                onDestinationSelected: (value) {
                  setState(() {
                    selectedIndex = value;
                  });
                },
              ),
            ),
            Expanded(
              child: Container(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: page,
              ),
            ),
          ],
        ),
      );
    });
  }
}

//GeneratorPage
class GeneratorPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();
    var pair = appState.current;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          BigCard(pair: pair),
          SizedBox(height: 10),
          ButtonsRow(pair: pair, appState: appState),
        ],
      ),
    );
  }
}

class BigCard extends StatelessWidget {
  const BigCard({
    super.key,
    required this.pair,
  });

  final WordPair pair;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.displayMedium!
        .copyWith(color: theme.colorScheme.onPrimary);

    return Card(
      color: theme.colorScheme.primary,
      child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text(
            pair.asLowerCase,
            style: style,
            semanticsLabel: "${pair.first}${pair.second}",
          )),
    );
  }
}

class ButtonsRow extends StatelessWidget {
  const ButtonsRow({
    super.key,
    required this.pair,
    required this.appState,
  });

  final WordPair pair;
  final MyAppState appState;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton.icon(
          onPressed: () {
            FavouritesManager().addToFavourites(pair.asCamelCase);
            appState.getNext();
          },
          icon: Icon(Icons.favorite_border),
          label: Text('Like'),
        ),
        SizedBox(width: 10),
        ElevatedButton(
          onPressed: () {
            appState.getNext();
          },
          child: Text('Next'),
        ),
      ],
    );
  }
}

//FavoritesPage
class FavoritesPage extends StatefulWidget {
  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  List<Word> _words = [];

  void _refreshList() async {
    final data = await FavouritesManager().retrieveFavourites();
    setState(() {
      _words = data;
    });
  }

  @override
  void initState() {
    super.initState();
    _refreshList();
  }

  @override
  Widget build(BuildContext context) {
    final myController = TextEditingController();

    //Pop-up
    Future<void> displayInputPopUp(Word word) {
      return showDialog<void>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text(word.name),
              content: TextFormField(
                controller: myController,
                decoration: InputDecoration(
                    border: UnderlineInputBorder(), labelText: 'Update to:'),
              ),
              actions: <Widget>[
                ElevatedButton(
                    onPressed: () {
                      FavouritesManager().updateFavourite(
                          Word(id: word.id, name: myController.text));
                      _refreshList();
                      Navigator.pop(context, 'Cancel');
                    },
                    child: Text('Save'))
              ],
            );
          });
    }

    if (_words.isEmpty) {
      return Center(
        child: Text('No favorites in db yet.'),
      );
    }

    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Text('You have '
              '${_words.length} db entries:'),
        ),
        for (var word in _words)
          ListTile(
            //Edit
            leading: IconButton(
              icon: Icon(Icons.edit),
              onPressed: () {
                displayInputPopUp(word);
              },
            ),
            title: Text(word.name),
            //Delete
            trailing: IconButton(
              icon: Icon(Icons.delete_forever_rounded),
              onPressed: () {
                FavouritesManager().deleteFavourite(word.id);
                _refreshList();
              },
            ),
          )
      ],
    );
  }
}

//Business Logic
// DTO
class Word {
  final int id;
  final String name;

  const Word({required this.id, required this.name});

  Map<String, dynamic> toMap() {
    return {'id': id, 'word': name};
  }
}

//Manager
class FavouritesManager {
  void addToFavourites(String name) async {
    var counter = await Repository().getCount();
    Repository().insertPair(Word(id: counter++, name: name));
  }

  Future<List<Word>> retrieveFavourites() async {
    return await Repository().getPairs();
  }

  void updateFavourite(Word word) {
    Repository().updatePair(word);
  }

  void deleteFavourite(int id) {
    Repository().deletePair(id);
  }
}

//DAL
class Repository {
  Future<Database> openConnection() async {
    WidgetsFlutterBinding.ensureInitialized();
    return openDatabase(
      join(await getDatabasesPath(), 'words_database.db'),
      onCreate: (db, version) {
        return db.execute(
          'CREATE TABLE words(id INTEGER PRIMARY KEY, word TEXT)',
        );
      },
      version: 1,
    );
  }

  Future<int> getCount() async {
    final db = await openConnection();
    return Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM words'))!;
  }

  Future<void> insertPair(Word word) async {
    final db = await openConnection();

    await db.insert('words', word.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Word>> getPairs() async {
    final db = await openConnection();

    List<Map<String, dynamic>> maps = await db.query('words');

    return List.generate(maps.length, (index) {
      return Word(
        id: maps[index]['id'],
        name: maps[index]['word'],
      );
    });
  }

  Future<void> updatePair(Word word) async {
    final db = await openConnection();

    await db
        .update('words', word.toMap(), where: 'id = ?', whereArgs: [word.id]);
  }

  Future<void> deletePair(int id) async {
    final db = await openConnection();

    await db.delete('words', where: 'id = ?', whereArgs: [id]);
  }
}
