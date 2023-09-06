import 'package:file_picker/file_picker.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:repos_synchronizer/state/git_provider.dart';
import 'package:system_theme/system_theme.dart';

class SettingsPage extends StatelessWidget {
  SettingsPage({super.key, required this.provider}) {
    _repoDirController.text = provider.currentPath;
  }

  final GitProvider provider;
  final TextEditingController _repoDirController = TextEditingController();

  Future save() async {
    provider.currentPath = _repoDirController.text;
    await provider.update();
  }

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      title: const Text('Settings'),
      content: Table(
        columnWidths: const <int, TableColumnWidth>{
          0: IntrinsicColumnWidth(),
          1: FlexColumnWidth(),
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          TableRow(
            children: [
              const Padding(
                padding: EdgeInsets.only(right: 8.0),
                child: Text('Repo directory: '),
              ),
              TextBox(
                controller: _repoDirController,
                placeholder: 'Repo directory',
                suffix: IconButton(
                  icon: const Icon(FluentIcons.folder_open),
                  onPressed: () async {
                    var ret = await FilePicker.platform.getDirectoryPath(
                      dialogTitle: 'Select repo directory',
                    );

                    if (ret != null) {
                      _repoDirController.text = ret;
                    }
                  },
                ),
              )
            ],
          ),
        ],
      ),
      actions: [
        Button(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        Button(
          style: ButtonStyle(
            backgroundColor: ButtonState.all(
              SystemTheme.accentColor.accent.toAccentColor(),
            ),
          ),
          onPressed: () async {
            Navigator.pop(context);
            await save();
          },
          child: const Text('Save'),
        )
      ],
    );
  }
}
