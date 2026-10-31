import 'package:campus_core/campus_core.dart';
import 'package:material_ui/material_ui.dart';

/// Chọn "Bạn là": chỉ Sinh viên hoặc Giảng viên. Vai trò (bảo vệ, quản trị) và các đối tượng khác
/// chỉ quản trị gán trong màn Tài khoản.
class MemberTypePicker extends StatelessWidget {
  const MemberTypePicker({super.key, required this.value, required this.onChanged, this.errorText});

  final MemberType? value;
  final ValueChanged<MemberType> onChanged;
  final String? errorText;

  static IconData _icon(MemberType m) =>
      m == MemberType.lecturer ? Icons.co_present_outlined : Icons.school_outlined;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Bạn là', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final m in MemberType.selfSelectable) ...[
              Expanded(
                child: ChoiceChip(
                  avatar: Icon(_icon(m), size: 20),
                  label: SizedBox(width: double.infinity, child: Text(m.label, textAlign: TextAlign.center)),
                  selected: value == m,
                  showCheckmark: false,
                  onSelected: (_) => onChanged(m),
                ),
              ),
              if (m != MemberType.selfSelectable.last) const SizedBox(width: 12),
            ],
          ],
        ),
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Text(errorText!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
        ],
      ],
    );
  }
}
