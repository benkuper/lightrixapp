import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ltxremote/pages/livecontrol.dart';
import 'package:ltxremote/pages/nodelist.dart';
import 'package:ltxremote/pages/showcontrol.dart';

import 'engines/nodeengine.dart';

void main() => runApp(LightrixRemoteApp());

class MenuPage {
  MenuPage({this.name, this.content, this.icon, this.color});
  final String name;
  final Widget content;
  final IconData icon;
  final Color color;
}

class LightrixRemoteApp extends StatelessWidget {
  final NodeEngine nodeEngine = new NodeEngine();

  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    return MaterialApp(
        title: 'Lightrix Remote',
        theme: ThemeData(
            primaryColor: Colors.blue,
            accentColor: Colors.orange,
            fontFamily: "Titillium"),
        home: MainPage());
  }
}

class MainPage extends StatefulWidget {
  MainPage({Key key}) : super(key: key);

  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage>
    with SingleTickerProviderStateMixin {
  TabController _tabController;

  int curTabIndex = 0;
  final Color mainColor = Color(0xff008080);

  static const TextStyle optionStyle =
      TextStyle(fontSize: 30, fontWeight: FontWeight.bold);

  static List<MenuPage> pages = <MenuPage>[
    // MenuPage(name: "Home", content: DashboardPage(), icon: Icons.home, color:Colors.primaries[0]),
    MenuPage(
        name: "Props",
        content: NodeListPage(),
        icon: Icons.settings_applications), //, color:Colors.primaries[10]),
    MenuPage(
        name: "Show",
        content: ShowControlPage(),
        icon: Icons.slideshow), //, color:Colors.primaries[4]),
    MenuPage(
        name: "Play All",
        content: LiveControlPage(),
        icon: Icons.palette) //, color:Colors.primaries[8]),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = new TabController(vsync: this, length: pages.length);
    _tabController.animation
      ..addListener(() {
        setState(() {
          curTabIndex = (_tabController.animation.value)
              .round(); //_tabController.animation.value returns double
        });
      });
    // */
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: <Widget>[
            Text(pages[curTabIndex].name),
            Spacer(),
            LimitedBox(
                maxHeight: 40,
                child: Image(
                    image: AssetImage("assets/icons/playlogo.png"),
                    fit: BoxFit.fitHeight)),
          ],
        ),
        centerTitle: true,
        backgroundColor: mainColor, //pages[curTabIndex].color,
      ),
      body: TabBarView(
        controller: _tabController,
        children: <Widget>[
          for (var page in pages) page.content,
        ],
      ),
      bottomNavigationBar: TabBar(
        indicatorWeight: 4,
        controller: _tabController,
        tabs: [
          for (var page in pages) Tab(text: page.name, icon: Icon(page.icon))
        ],
        labelColor: mainColor, //pages[curTabIndex].color,
        unselectedLabelColor: Colors.grey,
        indicatorColor: mainColor, //pages[curTabIndex].color,
      ),
    );
  }
}
