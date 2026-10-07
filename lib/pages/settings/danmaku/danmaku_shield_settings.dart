import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:kazumi/bean/settings/settings_detail_scaffold.dart';
import 'package:kazumi/pages/my/my_controller.dart';
import 'package:kazumi/pages/settings/danmaku/danmaku_shield_editor.dart';
import 'package:kazumi/utils/device.dart';

class DanmakuShieldSettings extends StatelessWidget {
  const DanmakuShieldSettings({super.key});

  @override
  Widget build(BuildContext context) {
    // 圆表：本页不是纯跳转页，自带 DanmakuShieldEditor；外层只有 Center +
    // ConstrainedBox(1000)，圆屏下等于不限宽 ⇒ 内容盒 x∈[16,217]。
    // body 可视带 y∈[44,188]（WatchScaffold 只加 top44/bottom），行顶滚到 y=44 时
    // 左边缘 x=16 到圆心的距离 √(100.5²+72.5²)=123.9 > R116.5 ⇒ 卡角被圆边切 ≈7.4dp。
    // 收到 180 后内容盒 x∈[26.5,206.5]，同一角点距离 115.6 ≤ R ⇒ 整块落进圆内；
    // 宽屏/手机 maxWidth 仍是 1000，行为与改前一致。
    final round = isRoundWatch(MediaQuery.sizeOf(context));
    return SettingsDetailScaffold(
      title: const Text('屏蔽规则'),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: round ? 180 : 1000),
          child: DanmakuShieldEditor(
            controller: inject<MyController>(),
            padding: const EdgeInsets.all(16),
          ),
        ),
      ),
    );
  }
}
