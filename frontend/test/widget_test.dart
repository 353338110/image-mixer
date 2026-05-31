import 'package:flutter_test/flutter_test.dart';

import 'package:imagemixer_desktop/main.dart';

void main() {
  testWidgets('ImageMixer home page smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ImageMixerApp());
    await tester.pump();

    expect(find.text('ImageMixer 本地图片处理'), findsOneWidget);
    expect(find.text('后端地址'), findsOneWidget);
    expect(find.text('一键处理'), findsOneWidget);
  });
}
