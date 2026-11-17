import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'models/catalog.dart';
import 'providers/session.dart';
import 'screens/access.dart';
import 'screens/business_editor.dart';
import 'screens/dashboard.dart';
import 'screens/location_screen.dart';
import 'screens/public_catalog.dart';
import 'services/api.dart';
import 'services/product_queue.dart';
import 'theme/taricrea_theme.dart';
import 'widgets/common.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TariCreaApp());
}

class TariCreaApp extends StatelessWidget {
  const TariCreaApp({this.session, super.key});

  final Session? session;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'TariCrea',
    theme: taricreaTheme(),
    locale: const Locale('es', 'BO'),
    supportedLocales: const [Locale('es', 'BO')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    debugShowCheckedModeBanner: false,
    home: AppShell(session: session),
  );
}

class AppShell extends StatefulWidget {
  const AppShell({this.session, super.key});
  final Session? session;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final navigation = GlobalKey<NavigatorState>();
  final messenger = GlobalKey<ScaffoldMessengerState>();
  final tab = ValueNotifier<int>(0);
  late final Session session;
  late final Listenable rootChanges;

  @override
  void initState() {
    super.initState();
    session = widget.session ?? Session(Api(), ProductQueue());
    rootChanges = Listenable.merge([session, tab]);
    session.onExpired = expired;
    session.restore();
  }

  void go(int tab) {
    navigation.currentState?.popUntil((route) => route.isFirst);
    setState(() => this.tab.value = tab);
  }

  void expired() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || session.account != null) return;
      go(2);
      messenger.currentState?.showSnackBar(
        const SnackBar(
          content: Text('Tu sesión venció. Vuelve a iniciar sesión.'),
        ),
      );
    });
  }

  void loggedIn(Business? business) {
    go(2);
    if (business == null) {
      navigation.currentState?.push<Business>(
        MaterialPageRoute(builder: (_) => BusinessEditor(session)),
      );
    }
  }

  @override
  void dispose() {
    session.onExpired = null;
    if (widget.session == null) session.dispose();
    tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaffoldMessenger(
    key: messenger,
    child: Scaffold(
      body: NavigatorPopHandler<Object?>(
        onPopWithResult: (result) => navigation.currentState?.pop(result),
        child: Navigator(
          key: navigation,
          onGenerateRoute: (_) => MaterialPageRoute(
            builder: (context) => ListenableBuilder(
              listenable: rootChanges,
              builder: (context, _) => Scaffold(
                appBar: brandBar(),
                body: SafeArea(
                  top: false,
                  child: IndexedStack(
                    index: tab.value,
                    children: [
                      ExploreScreen(session),
                      if (tab.value == 1)
                        BusinessLocationsScreen(session.api)
                      else
                        const SizedBox.shrink(),
                      privatePane(),
                      session.account == null
                          ? privatePane()
                          : AccountPane(session, onSignedOut: () => go(3)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        height: 63,
        selectedIndex: tab.value,
        onDestinationSelected: go,
        indicatorColor: mint,
        backgroundColor: Colors.white,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            label: 'Explorar',
          ),
          NavigationDestination(
            icon: Icon(Icons.location_on_outlined),
            label: 'Ubicación',
          ),
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            label: 'Gestionar',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Cuenta',
          ),
        ],
      ),
    ),
  );

  Widget privatePane() {
    if (!session.restored) return const Center(child: Busy());
    return session.account == null
        ? LoginScreen(session, onLogin: loggedIn)
        : Dashboard(session, onExplore: () => go(0));
  }
}
