import 'package:escive/utils/haptic.dart';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';

void showSelectModal({
  required BuildContext context,
  required String title,
  required List values,
  bool isRadio = false,
  String? value,
  required Function(int) onChanged,
}) async {
  await showMaterialModalBottomSheet(
    duration: const Duration(milliseconds: 300),
    clipBehavior: Clip.hardEdge,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12))),
    context: context,
    builder: (context) {
      int currentValue = values.indexWhere((element) => element['id'] == value);

      return Material(
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          padding: const EdgeInsets.only(left: 12, right: 18, top: 14, bottom: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center( // "Grab"
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).hintColor,
                    borderRadius: const BorderRadius.all(Radius.circular(10)),
                  ),
                  height: 3,
                  width: 112,
                  margin: const EdgeInsets.only(bottom: 24),
                ),
              ),

              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),

              const SizedBox(height: 16),

              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: values.length,
                  physics: const ClampingScrollPhysics(),
                  padding: EdgeInsets.only(bottom: 26),
                  itemBuilder: (context, index) {
                    String subtitle = values[index]['subtitle'] ?? '';

                    return ListTile(
                      title: Text(values[index]['title']),
                      subtitle: subtitle == '' ? null : Text(subtitle),
                      contentPadding: isRadio ? const EdgeInsets.all(0) : const EdgeInsets.only(left: 14),
                      onTap: () {
                        Haptic().light();
                        onChanged(index);
                        Navigator.pop(context);
                      },
                      leading: !isRadio ? null : RadioGroup(
                        groupValue: currentValue,
                        onChanged: (value) {
                          onChanged(index);
                          Navigator.pop(context);
                        },
                        child: Radio(
                          value: index,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
  Haptic().light();
}

class SettingsSection extends StatelessWidget {
  final String title;

  const SettingsSection({
    required this.title,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[600]),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}

class SettingsTile extends StatelessWidget {
  final BuildContext context;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final bool isDangerous;
  final VoidCallback? onTap;
  final Widget? leading;

  const SettingsTile({
    required this.context,
    required this.title,
    this.subtitle = '',
    this.trailing,
    this.isDangerous = false,
    this.onTap,
    this.leading,
    super.key,
  });

  factory SettingsTile.toggle({
    required BuildContext context,
    required String title,
    String subtitle = '',
    bool isDangerous = false,
    required bool value,
    required ValueChanged<bool> onChanged,
    Widget? leading,
    Key? key,
  }) {
    return SettingsTile(
      context: context,
      title: title,
      subtitle: subtitle,
      key: key,
      leading: leading,
      trailing: Switch.adaptive(
        value: value,
        onChanged: onChanged,
      ),
      isDangerous: isDangerous,
      onTap: () {
        onChanged(!value);
      },
    );
  }

  factory SettingsTile.select({
    required BuildContext context,
    required String title,
    String subtitle = '',
    bool isDangerous = false,
    required String value,
    required List values,
    required ValueChanged<String> onChanged,
    Widget? leading,
    Key? key,
  }) {
    return SettingsTile(
      context: context,
      title: title,
      subtitle: subtitle,
      key: key,
      leading: leading,
      trailing: Icon(LucideIcons.chevronRight, size: 22),
      isDangerous: isDangerous,
      onTap: () {
        Haptic().light();
        showSelectModal(
          context: context,
          title: title,
          values: values,
          value: value,
          isRadio: true,
          onChanged: (value) {
            onChanged(values[value]['id']);
          },
        );
      },
    );
  }

  factory SettingsTile.action({
    required BuildContext context,
    required String title,
    String subtitle = '',
    bool isDangerous = false,
    required ValueChanged<bool> onChanged,
    Widget? leading,
    Key? key,
  }) {
    return SettingsTile(
      context: context,
      title: title,
      subtitle: subtitle,
      key: key,
      leading: leading,
      isDangerous: isDangerous,
      onTap: () {
        onChanged(true);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: Colors.grey.shade300,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade200,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
          borderRadius: BorderRadius.circular(10),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          title: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: isDangerous ? Colors.red.shade500 : Colors.grey[900])),
          subtitle: subtitle.isEmpty
            ? null
            : Column(
              children: [
                trailing is Widget ? SizedBox() : SizedBox(height: 3),
                SizedBox(
                  width: double.infinity, 
                  child: Text(subtitle, textAlign: TextAlign.start)
                ),
              ]
          ),
          leading: leading,
          trailing: trailing,
          onTap: onTap,
        ),
      ),
    );
  }
}
