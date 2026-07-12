import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:thrifty_chef/main.dart';
import 'package:thrifty_chef/providers/app_state.dart';
import 'package:thrifty_chef/services/local_store.dart';
import 'package:thrifty_chef/services/thrifty_chef_repository.dart';

void main() {
  testWidgets('ThriftyChef app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider(create: (_) => ThriftyChefRepository()),
          Provider(create: (_) => LocalStore()),
          ChangeNotifierProvider(
            create: (ctx) => AppState(ctx.read<ThriftyChefRepository>(), ctx.read<LocalStore>()),
          ),
        ],
        child: const ThriftyChefApp(),
      ),
    );
    expect(find.textContaining('Thrifty'), findsWidgets);
  });
}
